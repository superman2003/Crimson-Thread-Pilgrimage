extends RefCounted
const CODEC := preload("res://scripts/settings_profile_codec.gd")
const COMFORT := preload("res://scripts/controller_preferences.gd")
const LIMIT := 6
const VISUAL := ["subtitle_size","subtitle_speed","flash_enabled","camera_shake","camera_lookahead"]
const CONTROLLER := ["controller_deadzone","vibration_enabled","vibration_strength"]
const EXTRA := ["npc_landmarks","tutorial_hints","navigation_assist"]
var profiles: Dictionary={}
var store:=preload("res://scripts/journey_desk_store.gd").new()
var apply_writer: Callable

func configure(scope: String="global") -> void:
    profiles={}
    store.configure("settings_profiles",scope)
    var data:=store.read()
    if data.get("profiles") is Dictionary:
        for name in data.profiles:
            if valid_name(name) and data.profiles[name] is Dictionary and profiles.size()<LIMIT:
                var profile: Variant=data.profiles[name]
                if profile.get("values") is Dictionary and profile.get("bindings") is Dictionary:profiles[name]=profile.duplicate(true)

static func valid_name(value: Variant) -> bool:
    if not value is String or value.is_empty() or value.length()>24 or value!=value.strip_edges():return false
    for character in value:
        if character.unicode_at(0)<32:return false
    return true

static func values(raw: Dictionary) -> Dictionary:
    var result: Dictionary=COMFORT.normalize(raw)
    for key in EXTRA:result[key]=raw[key] if raw.get(key) is bool else false
    return result

func capture(ui: Control) -> Dictionary:
    return {"values":values(ui.accessibility),"bindings":CODEC.capture(ui.REMAPPABLE_ACTIONS)}

func manage(command: String, source: String, target: String, snapshot: Dictionary={}) -> Dictionary:
    var candidate:=profiles.duplicate(true)
    if command not in ["delete","replace"] and not valid_name(target):return {"ok":false,"reason":"名称需1—24字，不能含控制字符或首尾空白。"}
    if command in ["save","copy","rename"] and candidate.has(target):return {"ok":false,"reason":"同名方案已存在，不会覆盖。"}
    if command in ["save","copy"] and candidate.size()>=LIMIT:return {"ok":false,"reason":"最多六套设置方案。"}
    match command:
        "save":candidate[target]=snapshot.duplicate(true)
        "replace":
            if not candidate.has(source):return {"ok":false,"reason":"原方案已不存在。"}
            candidate[source]=snapshot.duplicate(true)
        "copy", "rename":
            if not candidate.has(source):return {"ok":false,"reason":"原方案已不存在。"}
            candidate[target]=candidate[source].duplicate(true)
            if command=="rename":candidate.erase(source)
        "delete":candidate.erase(source)
        _:return {"ok":false,"reason":"操作无效。"}
    if not store.write({"profiles":candidate}):return {"ok":false,"reason":store.error}
    profiles=candidate
    return {"ok":true,"reason":"设置方案已保存。"}

func quote(name: String, ui: Control, scope: int) -> Dictionary:
    if scope not in [0,1,2,3]:return {"ok":false,"reason":"设置应用范围无效。"}
    if not profiles.has(name):return {"ok":false,"reason":"请选择一套现有方案。"}
    var profile: Dictionary=profiles[name]
    var current: Dictionary=values(ui.accessibility)
    var candidate: Dictionary=current.duplicate()
    var supplied: Dictionary=values(profile.values)
    var fields: Array=VISUAL if scope==1 else CONTROLLER if scope==2 else [] if scope==3 else VISUAL+CONTROLLER+EXTRA
    var lines: Array[String]=[]
    for key in fields:
        candidate[key]=supplied[key]
        if current[key]!=candidate[key]:lines.append("%s：%s → %s" % [String(COMFORT.LABELS.get(key,{"npc_landmarks":"NPC声音地标","tutorial_hints":"探索提示","navigation_assist":"导航辅助"}.get(key,key))),str(current[key]),str(candidate[key])])
    var bindings: Dictionary=preload("res://scripts/input_binding_policy.gd").snapshot()
    if scope in [0,3]:
        var restored:=CODEC.restore(profile.bindings,ui.REMAPPABLE_ACTIONS)
        if not restored.ok:return restored
        bindings=restored.bindings
        for action in ui.REMAPPABLE_ACTIONS:
            var before: Array=InputMap.action_get_events(action).map(func(event):return CODEC.encode(event))
            var after: Array=bindings[action].map(func(event):return CODEC.encode(event))
            if before!=after:
                var labels: Array[String]=[]
                for event in bindings[action]:labels.append(preload("res://scripts/input_prompt_bindings.gd").binding_label(event))
                lines.append(String(ui.REMAPPABLE_ACTIONS[action])+"："+" / ".join(labels))
    return {"ok":true,"values":candidate,"bindings":bindings,"lines":lines,"snapshot":profile.duplicate(true),"scope":scope}

func apply(name: String, ui: Control, scope: int, expected: Dictionary) -> Dictionary:
    var candidate:=quote(name,ui,scope)
    if not candidate.ok:return candidate
    if candidate.snapshot!=expected:return {"ok":false,"reason":"方案内容已变化，请重新预览确认。"}
    var config:=ConfigFile.new()
    config.load(ui.accessibility_path)
    for key in candidate.values:config.set_value("accessibility",key,candidate.values[key])
    for action in ui.REMAPPABLE_ACTIONS:config.set_value("bindings",action,candidate.bindings[action])
    var result:=OK
    if apply_writer.is_valid():result=int(apply_writer.call(config,ui.accessibility_path))
    else:
        var temporary: String=ui.accessibility_path+".profile.tmp"
        result=config.save(temporary)
        if result==OK:result=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(ui.accessibility_path))
        if result!=OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
    if result!=OK:return {"ok":false,"reason":"设置写入失败（%d），当前输入与画面均保留。" % result}
    for key in candidate.values:ui.accessibility[key]=candidate.values[key]
    for action in ui.REMAPPABLE_ACTIONS:
        InputMap.action_erase_events(action)
        for event in candidate.bindings[action]:InputMap.action_add_event(action,event)
    ui._apply_accessibility()
    ui._refresh_remap_labels()
    return {"ok":true,"reason":"整套设置已写入并应用。"}
