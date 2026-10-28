extends RefCounted
## Explicit local reading marks. No text, story flags or gameplay saves enter disk.
const SAVE:=preload("res://scripts/settings_persistence.gd")
const TRANSACTION:=preload("res://scripts/journal_mark_transaction.gd")
const LIMIT:=64
const MAX_SCROLL:=1000000.0
const MAX_BYTES:=262144
var persistence:=SAVE.new()
var path:=""
var scope:=""
var records: Dictionary={}
var pending: Dictionary={}
var has_pending:=false
var writable:=true
var error:=""
var source_hash:="missing"

static func hash_valid(value: Variant) -> bool:
    return value is String and value.length()==64 and value.is_valid_hex_number(false)

static func number(value: Variant, maximum: float) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0.0 and float(value)<=maximum

static func identity(document: Dictionary) -> bool:
    return document.get("key") is String and not document.key.is_empty() and document.key.length()<=128 and hash_valid(document.get("fingerprint"))

static func valid_record(value: Variant) -> bool:
    if not value is Dictionary or value.size()!=5 or not hash_valid(value.get("fingerprint")):return false
    for field in ["offset","maximum","width","font"]:
        if not number(value.get(field),MAX_SCROLL):return false
    return value.offset<=value.maximum and value.width>0 and value.font>0

static func valid_records(value: Variant) -> bool:
    if not value is Dictionary or value.size()>LIMIT:return false
    for key in value:
        if not key is String or key.is_empty() or key.length()>128 or not valid_record(value[key]):return false
    return true

func _hash() -> String:
    return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func configure(journey: String, reload: bool=false) -> void:
    if scope==journey and not path.is_empty() and not reload:return
    scope=journey;path="user://journal_marks_"+journey.sha256_text()+".cfg"
    records={};pending={};has_pending=false;writable=true;error=""
    if persistence.recover(path)!=OK:_block("阅读标记暂时被占用，未读取或覆盖。请稍后重读。");return
    source_hash=_hash()
    if source_hash=="missing":return
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>MAX_BYTES:_block("阅读标记不可读或过大；保留原文件。");return
    file.close()
    var config:=ConfigFile.new()
    if config.load(path)!=OK or config.get_sections()!=PackedStringArray(["marks"]):_block("阅读标记损坏或版本未知；保留原文件。");return
    var keys:=config.get_section_keys("marks")
    var version: Variant=config.get_value("marks","version",-1)
    var data: Variant=config.get_value("marks","records",{})
    if keys.size()!=2 or not config.has_section_key("marks","records") or typeof(version)!=TYPE_INT or version!=1 or not valid_records(data):_block("阅读标记格式无效；保留原文件。");return
    if _hash()!=source_hash:_block("阅读标记在读取时变化，请重新读取。");return
    records=data.duplicate(true)

func _block(reason: String) -> Dictionary:
    writable=false;error=reason
    return {"ok":false,"reason":reason}

func position(document: Dictionary, maximum: float, width: float, font: float) -> Dictionary:
    if not identity(document) or not number(maximum,MAX_SCROLL) or not number(width,MAX_SCROLL) or not number(font,MAX_SCROLL) or width<=0 or font<=0:return {"ok":false,"reason":"当前阅读布局无效。"}
    var record: Dictionary=records.get(document.key,{})
    if record.is_empty():return {"ok":false,"reason":"这条记录尚无已保存的阅读标记。"}
    if record.fingerprint!=document.fingerprint:return {"ok":false,"reason":"记录内容已变化；旧标记保留，可保存当前位置替换。"}
    var offset:=float(record.offset)
    var relative:=not is_equal_approx(float(record.width),width) or not is_equal_approx(float(record.font),font)
    if relative:offset=maximum*float(record.offset)/float(record.maximum) if record.maximum>0 else 0.0
    return {"ok":true,"offset":clampf(offset,0.0,maximum),"relative":relative,"reason":"版式已变，将按原阅读比例定位。" if relative else "恢复已保存的阅读位置。"}

func capture(document: Dictionary, offset: float, maximum: float, width: float, font: float) -> Dictionary:
    if has_pending:return {"ok":false,"reason":"先重试未保存的标记，或明确重读文件后再操作。"}
    if not identity(document):return {"ok":false,"reason":"请先选择一条已知旅记。"}
    var record:={"fingerprint":document.fingerprint,"offset":offset,"maximum":maximum,"width":width,"font":font}
    if not valid_record(record):return {"ok":false,"reason":"当前阅读布局无效，未保存。"}
    var candidate:=records.duplicate(true)
    if not candidate.has(document.key) and candidate.size()>=LIMIT:return {"ok":false,"reason":"已保存64条阅读标记，请先删除不再需要的标记。"}
    candidate[document.key]=record
    return _commit(candidate)

func remove(document: Dictionary) -> Dictionary:
    if has_pending:return {"ok":false,"reason":"先重试未保存的标记，或明确重读文件后再操作。"}
    if not identity(document) or not records.has(document.key):return {"ok":false,"reason":"这条记录没有已保存标记。"}
    var candidate:=records.duplicate(true);candidate.erase(document.key)
    return _commit(candidate)

func retry() -> Dictionary:
    if not has_pending:return {"ok":false,"reason":"没有待重试的阅读标记。"}
    return _commit(pending.duplicate(true))

func _commit(candidate: Dictionary) -> Dictionary:
    if not writable:return {"ok":false,"reason":error}
    if not valid_records(candidate):return {"ok":false,"reason":"阅读标记候选无效。"}
    if _hash()!=source_hash:return _block("阅读标记已被另一个窗口或进程修改，请先重读；不会覆盖新记录。")
    pending=candidate.duplicate(true);has_pending=true
    var config:=ConfigFile.new();config.set_value("marks","version",1);config.set_value("marks","records",candidate)
    var transaction:=TRANSACTION.new();transaction.expected_hash=source_hash
    persistence.transaction=transaction
    var result: Error=persistence.save(config,path)
    if result==OK and transaction.installed_hash.is_empty():result=ERR_FILE_CORRUPT
    if result!=OK:
        error="阅读标记未保存（%d）；原标记保留，可重试。" % result
        return {"ok":false,"reason":error}
    records=candidate.duplicate(true);source_hash=transaction.installed_hash;pending={};has_pending=false;error=""
    return {"ok":true,"reason":"阅读标记已保存；不改变旅途进度或已读状态。"}
