extends RefCounted
const POLICY := preload("res://scripts/input_binding_policy.gd")

static func encode(event: InputEvent) -> Dictionary:
    var clean: InputEvent=POLICY.normalize(event)
    if clean==null:return {}
    if clean is InputEventKey:return {"type":"key","physical":clean.physical_keycode,"logical":clean.keycode,"shift":clean.shift_pressed,"alt":clean.alt_pressed,"ctrl":clean.ctrl_pressed,"meta":clean.meta_pressed}
    if clean is InputEventMouseButton:return {"type":"mouse","button":clean.button_index,"shift":clean.shift_pressed,"alt":clean.alt_pressed,"ctrl":clean.ctrl_pressed,"meta":clean.meta_pressed}
    if clean is InputEventJoypadButton:return {"type":"button","button":clean.button_index}
    if clean is InputEventJoypadMotion:return {"type":"axis","axis":clean.axis,"value":clean.axis_value}
    return {}

static func integer(value: Variant, maximum: int) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0.0 and float(value)<=maximum and float(value)==floor(float(value))

static func decode(raw: Variant) -> InputEvent:
    if not raw is Dictionary or not raw.get("type") is String:return null
    var event: InputEvent
    match raw.type:
        "key":
            if not integer(raw.get("physical"),4294967295) or not integer(raw.get("logical"),4294967295):return null
            var key:=InputEventKey.new();key.physical_keycode=int(raw.physical);key.keycode=int(raw.logical)
            for field in ["shift","alt","ctrl","meta"]:
                if not raw.get(field) is bool:return null
            key.shift_pressed=raw.shift;key.alt_pressed=raw.alt;key.ctrl_pressed=raw.ctrl;key.meta_pressed=raw.meta;event=key
        "mouse":
            if not integer(raw.get("button"),MOUSE_BUTTON_XBUTTON2):return null
            var mouse:=InputEventMouseButton.new();mouse.button_index=int(raw.button);event=mouse
            for field in ["shift","alt","ctrl","meta"]:
                if not raw.get(field) is bool:return null
            mouse.shift_pressed=raw.shift;mouse.alt_pressed=raw.alt;mouse.ctrl_pressed=raw.ctrl;mouse.meta_pressed=raw.meta
        "button":
            if not integer(raw.get("button"),JOY_BUTTON_MAX-1):return null
            var button:=InputEventJoypadButton.new();button.button_index=int(raw.button);event=button
        "axis":
            if not integer(raw.get("axis"),JOY_AXIS_MAX-1) or typeof(raw.get("value")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw.value)) or absf(float(raw.value))!=1.0:return null
            var axis:=InputEventJoypadMotion.new();axis.axis=int(raw.axis);axis.axis_value=float(raw.value);event=axis
        _:return null
    return POLICY.normalize(event)

static func capture(actions: Dictionary) -> Dictionary:
    var result:={}
    for action in actions:
        var events: Array=[]
        for event in InputMap.action_get_events(action):
            var raw:=encode(event)
            if not raw.is_empty():events.append(raw)
        result[action]=events
    return result

static func legacy_build_bindings(raw: Dictionary, actions: Dictionary) -> Dictionary:
    var result:=raw.duplicate(true)
    if not actions.has("build_menu") or raw.has("build_menu"):return {"ok":true,"bindings":result,"legacy":false}
    if raw.size()!=actions.size()-1:return {"ok":false,"reason":"旧方案缺少动作，不是完整的历史设置方案。"}
    for action in actions:
        if action!="build_menu" and not raw.has(action):return {"ok":false,"reason":"旧方案缺少动作："+String(actions[action])}
    for action in raw:
        if not actions.has(action):return {"ok":false,"reason":"旧方案含未知动作。"}
        if not raw[action] is Array:return {"ok":false,"reason":"旧方案按键格式无效。"}
        for value in raw[action]:
            var event:=decode(value)
            if event is InputEventKey and (event.physical_keycode==KEY_B or event.keycode==KEY_B):return {"ok":false,"reason":"旧方案含当时保留的构筑输入。"}
            if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_LEFT_STICK:return {"ok":false,"reason":"旧方案含当时保留的构筑输入。"}
    var current:=capture({"build_menu":"构筑"})
    if current.build_menu.is_empty():return {"ok":false,"reason":"构筑快捷键尚未就绪，请重新打开设置。"}
    result.build_menu=current.build_menu
    return {"ok":true,"bindings":result,"legacy":true}

static func restore(raw: Dictionary, actions: Dictionary) -> Dictionary:
    var migrated:=legacy_build_bindings(raw,actions)
    if not migrated.ok:return migrated
    var source: Dictionary=migrated.bindings
    var result:={}
    for action in actions:
        if not source.get(action) is Array:return {"ok":false,"reason":"按键方案缺少动作："+String(actions[action])}
        var events: Array=[]
        if source[action].is_empty() or source[action].size()>12:return {"ok":false,"reason":"按键事件数量无效。"}
        for value in source[action]:
            var event:=decode(value)
            if event==null or POLICY.is_reserved(event) or not POLICY.allowed_for(String(action),event):return {"ok":false,"reason":"按键方案含无效或保留输入。"}
            events.append(event)
        result[action]=events
    var candidate: Dictionary=POLICY.restore(POLICY.snapshot(),result,actions)
    if candidate.rejected>0:return {"ok":false,"reason":"整套按键存在冲突；未应用任何动作，请修正后重新保存方案。"}
    return {"ok":true,"bindings":candidate.bindings,"legacy":migrated.legacy}
