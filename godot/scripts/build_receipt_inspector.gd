extends RefCounted
## Read-only consistency against the adjacent release manifest, not publisher authentication.
const MANIFEST:="BUILD_MANIFEST.json"
const MAX_BYTES:=262144
const CHUNK:=262144
const BLOCKS_PER_TICK:=2
var root:=""
var error:=""
var metadata: Dictionary={}
var _rows: Array[Dictionary]=[]
var _manifest_hash:=""
var _index:=0
var _file: FileAccess
var _context: HashingContext
var _started_modified:=0
var working:=false
var complete:=false
var cancelled:=false
var bytes_read:=0

static func hex(value: Variant, length: int) -> bool:
    return value is String and value.length()==length and value.is_valid_hex_number(false)

static func relative_path(value: Variant) -> bool:
    if not value is String or value.is_empty() or value.length()>200 or value.begins_with("/") or value.contains("\\") or value.contains(":"):return false
    var parts: PackedStringArray=String(value).split("/",true)
    if parts.size()>8:return false
    for part in parts:
        if part in ["",".",".."]:return false
    for index in value.length():
        if value.unicode_at(index)<32 or value.unicode_at(index)==127:return false
    return value!=MANIFEST

static func file_record(value: Variant) -> bool:
    if not value is Dictionary or value.size()!=2 or not hex(value.get("sha256"),64):return false
    var size: Variant=value.get("bytes")
    return typeof(size) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(size)) and float(size)>=0 and float(size)<=4294967295.0 and floor(float(size))==float(size)

static func valid_manifest(value: Variant) -> bool:
    if not value is Dictionary or typeof(value.get("schema_version")) not in [TYPE_INT,TYPE_FLOAT] or value.schema_version!=1:return false
    if not hex(value.get("source_commit"),40) or not value.get("source_dirty") is bool or value.get("target") not in ["linux","windows"]:return false
    for field in ["engine","qualification"]:
        if not value.get(field) is String or value[field].is_empty() or value[field].length()>1024:return false
    if not value.get("validation") is Array or value.validation.size()>32:return false
    for label in value.validation:
        if not label is String or label.is_empty() or label.length()>120:return false
    if not value.get("files") is Dictionary or value.files.is_empty() or value.files.size()>256:return false
    for path in value.files:
        if not relative_path(path) or not file_record(value.files[path]):return false
    return true

func _regular(relative: String) -> bool:
    var current:=root
    for part in relative.split("/"):
        var directory:=DirAccess.open(current)
        if directory==null or directory.is_link(part):return false
        current=current.path_join(part)
    return true

func load_manifest(directory: String) -> bool:
    cancel();root=ProjectSettings.globalize_path(directory).simplify_path();metadata={};_rows=[];error="";complete=false;cancelled=false;bytes_read=0
    var path:=root.path_join(MANIFEST)
    if not _regular(MANIFEST):error="未找到可读取的发行清单；开发运行不提供包一致性结论。";return false
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>MAX_BYTES:error="发行清单不存在或超过读取上限。";return false
    _manifest_hash=FileAccess.get_sha256(path)
    if _manifest_hash.is_empty():file.close();error="无法取得清单身份，未开始核对。";return false
    var parser:=JSON.new();var result:=parser.parse(file.get_as_text());file.close()
    if result!=OK or not valid_manifest(parser.data):error="发行清单格式或版本无效，无法核对。";return false
    if FileAccess.get_sha256(path)!=_manifest_hash:error="清单在读取期间变化，请重新读取。";return false
    var data: Dictionary=parser.data
    for field in ["source_commit","source_dirty","target","engine","qualification","validation"]:metadata[field]=data[field].duplicate() if data[field] is Array else data[field]
    var keys: Array=data.files.keys();keys.sort()
    for relative in keys:_rows.append({"path":relative,"bytes":int(data.files[relative].bytes),"expected":String(data.files[relative].sha256).to_lower(),"status":"待核对"})
    return true

func start() -> bool:
    if metadata.is_empty() or _rows.is_empty():return false
    cancel();error="";complete=false;cancelled=false;_index=0;bytes_read=0
    for row in _rows:row.status="待核对"
    if FileAccess.get_sha256(root.path_join(MANIFEST))!=_manifest_hash:error="清单已变化，请重新读取。";return false
    working=true;return true

func _close_row(status: String) -> void:
    if _file!=null:_file.close()
    _file=null;_context=null;_rows[_index].status=status;_index+=1

func _open_row() -> void:
    var row: Dictionary=_rows[_index];var path:=root.path_join(String(row.path))
    if not _regular(String(row.path)):_close_row("不可读取或是链接");return
    _file=FileAccess.open(path,FileAccess.READ)
    if _file==null:_close_row("缺失或不可读取");return
    if _file.get_length()!=int(row.bytes):_close_row("大小不符");return
    _started_modified=FileAccess.get_modified_time(path)
    _context=HashingContext.new();_context.start(HashingContext.HASH_SHA256);row.status="核对中"

func tick() -> void:
    if not working:return
    for unused in BLOCKS_PER_TICK:
        if _index>=_rows.size():
            working=false;complete=true
            if FileAccess.get_sha256(root.path_join(MANIFEST))!=_manifest_hash:error="核对期间清单已变化，请重新读取。";complete=false
            return
        if _file==null:_open_row()
        if _file==null:continue
        var wanted:=mini(CHUNK,int(_file.get_length()-_file.get_position()))
        var block:=_file.get_buffer(wanted)
        if block.size()!=wanted:_close_row("读取未完成");continue
        if not block.is_empty():_context.update(block)
        bytes_read+=block.size()
        if _file.get_position()>=_file.get_length():
            var row: Dictionary=_rows[_index];var path:=root.path_join(String(row.path))
            var unchanged:=_regular(String(row.path)) and FileAccess.get_modified_time(path)==_started_modified
            var digest:=_context.finish().hex_encode()
            _close_row("一致" if unchanged and digest==row.expected else "读取期间变化" if not unchanged else "摘要不符")

func cancel() -> void:
    if _file!=null:_file.close()
    _file=null;_context=null
    if working:cancelled=true
    working=false;complete=false
    for row in _rows:
        if row.status=="核对中":row.status="未完成"

func report() -> Dictionary:
    var matches:=0
    for row in _rows:
        if row.status=="一致":matches+=1
    return {"metadata":metadata.duplicate(true),"files":_rows.duplicate(true),"error":error,"working":working,"complete":complete,"cancelled":cancelled,"matches":matches,"total":_rows.size(),"passed":complete and error.is_empty() and matches==_rows.size(),"bytes_read":bytes_read}

func summary() -> String:
    var value:=report()
    if metadata.is_empty():return error
    var total_bytes:=0
    for row in _rows:total_bytes+=int(row.bytes)
    return "来源提交：%s\n含未提交修改：%s\n发行目标：%s\n构建引擎：%s\n当前核对：%s · 一致%d/%d\n本次已读取：%d / %d 字节\n仅核对随包清单和此次读取，不验证发行者身份或完整游玩验收。" % [metadata.source_commit,"是" if metadata.source_dirty else "否",metadata.target,metadata.engine,"进行中" if working else "已停止" if cancelled else "已完成" if complete else "未完成",value.matches,value.total,bytes_read,total_bytes]
