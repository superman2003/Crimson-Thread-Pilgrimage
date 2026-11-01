extends RefCounted
## Named station-order drafts, separate from the live itinerary and gameplay save.
const SAVE:=preload("res://scripts/settings_persistence.gd")
const TRANSACTION:=preload("res://scripts/journal_mark_transaction.gd")
const LIMIT:=8
var persistence:=SAVE.new()
var scope:=""
var path:=""
var drafts: Dictionary={}
var source_hash:="missing"
var writable:=true
var error:=""

static func valid_name(value: Variant) -> bool:
    if not value is String or value.is_empty() or value.length()>24 or value.strip_edges()!=value:return false
    for index in value.length():
        if value.unicode_at(index)<32 or value.unicode_at(index)==127:return false
    return true

static func valid_stops(value: Variant) -> bool:
    if not value is Array or value.is_empty() or value.size()>6:return false
    var seen:={}
    for key in value:
        if not key is String or key.is_empty() or key.length()>180 or key.count(":")<2 or seen.has(key):return false
        seen[key]=true
    return true

static func valid_library(value: Variant) -> bool:
    if not value is Dictionary or value.size()>LIMIT:return false
    for name in value:
        if not valid_name(name) or not valid_stops(value[name]):return false
    return true

static func known_rows(known: Array) -> Dictionary:
    var result:={}
    for row in known.slice(0,4096):
        if row is Dictionary and row.get("key") is String:result[row.key]=row
    return result

func _hash() -> String:
    return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func _blocked(reason: String) -> Dictionary:
    writable=false;error=reason
    return {"ok":false,"reason":reason}

func configure(journey: String, reload: bool=false) -> void:
    if scope==journey and not path.is_empty() and not reload:return
    scope=journey;path="user://expedition_drafts_"+journey.sha256_text()+".cfg"
    drafts={};writable=true;error=""
    if persistence.recover(path)!=OK:_blocked("行程草案暂不可读取，请稍后重读。");return
    source_hash=_hash()
    if source_hash=="missing":return
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>262144:_blocked("行程草案文件不可读或过大；保留原文件。");return
    file.close()
    var config:=ConfigFile.new()
    if config.load(path)!=OK or config.get_sections()!=PackedStringArray(["drafts"]):_blocked("行程草案版本无效；保留原文件。");return
    var data: Variant=config.get_value("drafts","records",{})
    var version: Variant=config.get_value("drafts","version",-1)
    if config.get_section_keys("drafts").size()!=2 or not config.has_section_key("drafts","records") or not version is int or version!=1 or not valid_library(data):_blocked("行程草案格式无效；保留原文件。");return
    if _hash()!=source_hash:_blocked("行程草案在读取时变化，请重新读取。");return
    drafts=data.duplicate(true)

func _commit(candidate: Dictionary) -> Dictionary:
    if not writable:return {"ok":false,"reason":error}
    if not valid_library(candidate):return {"ok":false,"reason":"草案候选无效。"}
    if _hash()!=source_hash:return _blocked("另一实例已修改行程草案，请先重读；不覆盖新记录。")
    var config:=ConfigFile.new();config.set_value("drafts","version",1);config.set_value("drafts","records",candidate)
    var transaction:=TRANSACTION.new();transaction.expected_hash=source_hash;persistence.transaction=transaction
    var result: Error=persistence.save(config,path)
    if result!=OK or transaction.installed_hash.is_empty():
        error="草案未保存；原记录保留，可重新提交。"
        return {"ok":false,"reason":error}
    drafts=candidate.duplicate(true);source_hash=transaction.installed_hash;error=""
    return {"ok":true,"reason":"行程草案已保存；只保存站点顺序，不保存完成或活动状态。"}

func save_new(name: String, state: Dictionary, known: Array) -> Dictionary:
    if not valid_name(name):return {"ok":false,"reason":"草案名需1至24字，不能有首尾空白或控制字符。"}
    if drafts.has(name):return {"ok":false,"reason":"同名草案已存在，请换名；不会静默覆盖。"}
    if drafts.size()>=LIMIT:return {"ok":false,"reason":"最多保存8份草案，请先删除不需要的草案。"}
    if not valid_stops(state.get("stops")):return {"ok":false,"reason":"请先安排1至6处不重复的站点。"}
    var rows:=known_rows(known)
    for key in state.stops:
        if not rows.has(key):return {"ok":false,"reason":"行程含当前未公开的地点，未保存草案。"}
    var candidate:=drafts.duplicate(true);candidate[name]=state.stops.duplicate()
    return _commit(candidate)

func quote_restore(name: String, state: Dictionary, known: Array) -> Dictionary:
    if not drafts.has(name) or not valid_stops(drafts[name]):return {"ok":false,"reason":"草案不存在或已变化，请重选。"}
    if _hash()!=source_hash:return {"ok":false,"reason":"草案文件已变化，请先重读。"}
    var rows:=known_rows(known);var labels: Array[String]=[]
    for key in drafts[name]:
        if not rows.has(key):return {"ok":false,"reason":"部分站点不在当前公开目录中，不能载入；原行程保留。"}
        labels.append(String(rows[key].get("region_name","已知地区"))+" · "+String(rows[key].get("title","已知地点")))
    var candidate:={"stops":drafts[name].duplicate(),"done":[],"deferred":[],"active":false}
    var fingerprint:=var_to_str([scope,source_hash,name,drafts[name],state,rows.keys()]).sha256_text()
    return {"ok":true,"reason":"将替换当前站序并清除本行程勾选/暂缓，保持暂停；不传送、不补绘、不发奖励。","labels":labels,"candidate":candidate,"fingerprint":fingerprint}

func restore(name: String, expected: String, plan: RefCounted, known: Array) -> Dictionary:
    var quote:=quote_restore(name,plan.state,known)
    if not quote.ok:return quote
    if quote.fingerprint!=expected:return {"ok":false,"reason":"草案、当前行程或知识已变化，请重新预览确认。"}
    if not plan.store.write(quote.candidate):return {"ok":false,"reason":String(plan.store.error)}
    plan.state=quote.candidate.duplicate(true)
    return {"ok":true,"reason":"已载入站点顺序，行程保持暂停；请现场核对路线后开始。"}

func remove(name: String, expected_hash: String) -> Dictionary:
    if expected_hash!=source_hash or not drafts.has(name):return {"ok":false,"reason":"草案列表已变化，请重新确认删除。"}
    var candidate:=drafts.duplicate(true);candidate.erase(name)
    return _commit(candidate)
