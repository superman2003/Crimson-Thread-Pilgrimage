extends RefCounted
## A bounded JSON interchange format. Import creates a named stored profile;
## applying live preferences remains the existing, separately confirmed action.
const MODEL:=preload("res://scripts/settings_profiles.gd")
const CODEC:=preload("res://scripts/settings_profile_codec.gd")
const FORMAT:="crimson-settings"
const VERSION:=2
const MAX_BYTES:=65536
static func failure(reason: String) -> Dictionary:return {"ok":false,"reason":reason}
static func keys_are(value: Dictionary, allowed: Array) -> bool:
    if value.size()!=allowed.size():return false
    for key in value:
        if not allowed.has(key):return false
    return true

static func validate(profile: Variant, actions: Dictionary, allow_legacy: bool=false) -> Dictionary:
    if not profile is Dictionary or not keys_are(profile,["values","bindings"]):return failure("分享码缺少设置或按键方案。")
    if not profile.values is Dictionary or not profile.bindings is Dictionary:return failure("设置与按键内容格式无效。")
    var defaults:=MODEL.values({})
    if not keys_are(profile.values,defaults.keys()):return failure("设置字段不完整或版本不兼容。")
    var values:=MODEL.values(profile.values)
    for key in defaults:
        var raw: Variant=profile.values[key]
        if defaults[key] is bool:
            if not raw is bool:return failure("开关字段无效："+String(key))
        elif typeof(raw) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw)) or float(raw)!=float(values[key]):
            return failure("设置数值超出范围："+String(key))
    var stored: Dictionary=profile.bindings
    if not keys_are(stored,actions.keys()):
        if not allow_legacy:return failure("动作清单与本版本不一致。")
        var migrated:=CODEC.legacy_build_bindings(stored,actions)
        if not migrated.ok or not migrated.legacy:return failure("旧动作清单不完整，尚未导入。")
        stored=migrated.bindings
    for action in stored:
        var events: Variant=stored[action]
        if not events is Array or events.is_empty() or events.size()>12:return failure("按键事件数量无效。")
        for event in events:
            if not event is Dictionary:return failure("按键事件格式无效。")
            var fields: Array={"key":["type","physical","logical","shift","alt","ctrl","meta"],"mouse":["type","button","shift","alt","ctrl","meta"],"button":["type","button"],"axis":["type","axis","value"]}.get(event.get("type",""),[])
            if fields.is_empty() or not keys_are(event,fields):return failure("按键事件字段无效。")
    var restored:=CODEC.restore(stored,actions)
    if not restored.ok:return restored
    var canonical:={}
    for action in actions:
        var events: Array=[]
        for raw in stored[action]:events.append(CODEC.encode(CODEC.decode(raw)))
        canonical[action]=events
    return {"ok":true,"profile":{"values":values,"bindings":canonical}}

static func export_code(name: String, profile: Dictionary, actions: Dictionary) -> Dictionary:
    if not MODEL.valid_name(name):return failure("请选择名称有效的已存方案。")
    var checked:=validate(profile,actions,true)
    if not checked.ok:return checked
    var text:=JSON.stringify({"format":FORMAT,"version":VERSION,"name":name,"profile":checked.profile},"  ",true,true)
    if text.to_utf8_buffer().size()>MAX_BYTES:return failure("方案过大，无法生成分享码。")
    return {"ok":true,"text":text,"reason":"分享码已生成；当前设置没有变化。"}

static func parse_code(text: String, actions: Dictionary) -> Dictionary:
    if text.to_utf8_buffer().size()>MAX_BYTES:return failure("分享码最多64 KiB，请检查粘贴内容。")
    var parser:=JSON.new()
    if parser.parse(text.strip_edges())!=OK:return failure("分享码格式不完整（第%d行），尚未保存。" % parser.get_error_line())
    var packet: Variant=parser.data
    if not packet is Dictionary or not keys_are(packet,["format","version","name","profile"]):return failure("不是本游戏的完整设置分享码。")
    if packet.format!=FORMAT or not CODEC.integer(packet.version,VERSION) or int(packet.version) not in [1,VERSION]:return failure("分享码版本不受支持。")
    if not MODEL.valid_name(packet.name):return failure("分享码中的方案名称无效。")
    if int(packet.version)==1 and actions.has("build_menu") and packet.get("profile") is Dictionary and packet.profile.get("bindings") is Dictionary and packet.profile.bindings.has("build_menu"):return failure("旧版分享码含不属于该版本的构筑动作。")
    var result:=validate(packet.profile,actions,int(packet.version)==1)
    if result.ok:
        result.name_hint=String(packet.name)
        result.fingerprint=text.sha256_text()
    return result

static func preview(text: String, ui: Control) -> Dictionary:
    var result:=parse_code(text,ui.REMAPPABLE_ACTIONS)
    if not result.ok:return result
    var detached:=MODEL.new()
    detached.profiles={"导入预览":result.profile.duplicate(true)}
    var compared:=detached.quote("导入预览",ui,0)
    if not compared.ok:return compared
    result.lines=compared.lines.duplicate()
    result.reason="仅创建一套方案；当前声音、画面与输入不变。应用需返回方案管理另行确认。"
    return result

static func import_new(model: RefCounted, name: String, text: String, ui: Control, expected: String) -> Dictionary:
    if expected.is_empty() or expected!=text.sha256_text():return failure("分享码已变化，请重新预览。")
    var candidate:=parse_code(text,ui.REMAPPABLE_ACTIONS)
    if not candidate.ok:return candidate
    var saved: Dictionary=model.manage("save","",name,candidate.profile)
    if not saved.ok:return saved
    return {"ok":true,"reason":"已新增方案「%s」；当前设置未应用。" % name}
