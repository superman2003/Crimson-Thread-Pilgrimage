extends RefCounted
const DEFAULTS := {"controller_deadzone": 0.25, "subtitle_size": 21, "subtitle_speed": 1.0, "flash_enabled": true, "vibration_enabled": true, "vibration_strength": 1.0, "camera_shake": 1.0, "camera_lookahead": 1.0}
const LABELS := {"controller_deadzone":"摇杆死区", "subtitle_size":"字幕字号", "subtitle_speed":"字幕速度", "flash_enabled":"受击闪光", "vibration_enabled":"手柄震动", "vibration_strength":"手柄力度", "camera_shake":"镜头震动", "camera_lookahead":"镜头前瞻"}
static var original_deadzones: Dictionary = {}
static var modified: Array[String] = []

static func normalize(values: Dictionary) -> Dictionary:
    var result := DEFAULTS.duplicate()
    for key in result:
        var value: Variant = values.get(key, result[key])
        if result[key] is bool:
            if value is bool:result[key] = value
        elif (value is int or value is float) and is_finite(float(value)):
            var bounds: Array = {"controller_deadzone":[0.1,0.6],"subtitle_size":[17,26],"subtitle_speed":[0.5,2.0]}.get(key,[0.0,1.0])
            result[key] = clampf(float(value), bounds[0], bounds[1])
            if key == "subtitle_size":result[key] = int(result[key])
    return result

static func preset(current: Dictionary, id: String) -> Dictionary:
    var result := normalize(current)
    match id:
        "comfort":result.merge({"flash_enabled":false,"camera_shake":0.25,"camera_lookahead":0.5,"vibration_strength":0.25},true)
        "reading":result.merge({"subtitle_size":26,"subtitle_speed":0.75,"flash_enabled":false,"camera_shake":0.0},true)
        "controller_default":
            for key in ["controller_deadzone","vibration_enabled","vibration_strength"]:result[key] = DEFAULTS[key]
        "visual_default":
            for key in ["subtitle_size","subtitle_speed","flash_enabled","camera_shake","camera_lookahead"]:result[key] = DEFAULTS[key]
    return result

static func apply_deadzone(value: float) -> Array[String]:
    var deadzone := clampf(value,0.1,0.6) if is_finite(value) else 0.25
    var next: Array[String] = []
    for action in InputMap.get_actions():
        var stick := false
        var trigger := false
        for event in InputMap.action_get_events(action):
            if event is InputEventJoypadMotion:
                if event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:stick = true
                if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:trigger = true
        if not stick or trigger:continue
        var id := String(action)
        if not original_deadzones.has(id):original_deadzones[id] = InputMap.action_get_deadzone(action)
        InputMap.action_set_deadzone(action,deadzone)
        next.append(id)
    for action in modified:
        if not next.has(action) and InputMap.has_action(action):InputMap.action_set_deadzone(action,float(original_deadzones.get(action,0.5)))
    modified = next
    return next.duplicate()

static func devices() -> Array:
    var result: Array = []
    for id in Input.get_connected_joypads():
        var axes: Array = []
        for axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:axes.append(Input.get_joy_axis(id,axis))
        result.append({"id":id,"name":Input.get_joy_name(id),"axes":axes})
    return result
