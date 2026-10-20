extends RefCounted
## Shared capture/load policy. Builds a complete candidate before touching InputMap.
const RESERVED_KEYS := [KEY_ESCAPE, KEY_B, KEY_F9]
const RESERVED_BUTTONS := [JOY_BUTTON_LEFT_STICK]

static func normalize(value: Variant) -> InputEvent:
    if not value is InputEvent:return null
    var event := value.duplicate() as InputEvent
    if event is InputEventKey:
        if event.physical_keycode == 0 and event.keycode == 0:return null
        event.pressed = false
        event.echo = false
    elif event is InputEventMouseButton:
        if event.button_index <= 0 or event.button_index > MOUSE_BUTTON_XBUTTON2:return null
        event.pressed = false
        event.double_click = false
    elif event is InputEventJoypadButton:
        if event.button_index < 0 or event.button_index >= JOY_BUTTON_MAX:return null
        event.pressed = false
        event.pressure = 0.0
    elif event is InputEventJoypadMotion:
        if event.axis < 0 or event.axis >= JOY_AXIS_MAX or not is_finite(event.axis_value) or absf(event.axis_value) < 0.5:return null
        event.axis_value = 1.0 if event.axis_value > 0 else -1.0
    else:return null
    event.device = -1
    return event

static func is_reserved(event: InputEvent) -> bool:
    if event is InputEventKey:
        return event.physical_keycode in RESERVED_KEYS or event.keycode in RESERVED_KEYS
    return event is InputEventJoypadButton and event.button_index in RESERVED_BUTTONS

static func family(event: InputEvent) -> String:
    if event is InputEventKey:return "keyboard"
    if event is InputEventMouseButton:return "mouse"
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:return "controller"
    return ""

static func overlaps(first: InputEvent, second: InputEvent) -> bool:
    if family(first) != family(second):return false
    # Device IDs are transient. Extra modifiers do not isolate gameplay actions.
    if first is InputEventKey and second is InputEventKey:
        if first.physical_keycode != 0 and second.physical_keycode != 0:
            return first.physical_keycode == second.physical_keycode
        var a: int = _logical_key(first)
        var b: int = _logical_key(second)
        return a == b
    if first is InputEventMouseButton and second is InputEventMouseButton:
        return first.button_index == second.button_index
    if first is InputEventJoypadButton and second is InputEventJoypadButton:
        return first.button_index == second.button_index
    if first is InputEventJoypadMotion and second is InputEventJoypadMotion:
        return first.axis == second.axis and signf(first.axis_value) == signf(second.axis_value)
    return false

static func _logical_key(event: InputEventKey) -> int:
    if event.physical_keycode == 0:return event.keycode
    # Headless has no keyboard layout service; retain the physical code rather
    # than calling an unsupported display-server API and emitting engine errors.
    if DisplayServer.get_name() == "headless":return event.physical_keycode
    return DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)

static func snapshot() -> Dictionary:
    var result := {}
    for action in InputMap.get_actions():result[String(action)] = InputMap.action_get_events(action)
    return result

static func conflicts(event: InputEvent, action: String, bindings: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for other in bindings:
        if other == action or String(other).begins_with("ui_") or other == "close_overlay":continue
        for old in bindings[other]:
            if overlaps(event, old):
                result.append(String(other))
                break
    return result

static func _candidate(original: Dictionary, replacements: Dictionary) -> Dictionary:
    var result := original.duplicate()
    for action in replacements:
        var events: Array = []
        for old in original[action]:
            if not replacements[action].has(family(old)):events.append(old)
        for group in replacements[action]:events.append_array(replacements[action][group])
        result[action] = events
    return result

static func restore(original: Dictionary, saved: Dictionary, actions: Dictionary) -> Dictionary:
    var replacements := {}
    var rejected := 0
    for action in actions:
        if not original.has(action) or not saved.has(action):continue
        var raw: Variant = saved[action]
        if not raw is Array or raw.is_empty():
            rejected += 1
            continue
        var groups := {}
        for value in raw:
            var event := normalize(value)
            if event == null or is_reserved(event):
                rejected += 1
                continue
            var group := family(event)
            if not groups.has(group):groups[group] = []
            var duplicate := false
            for old in groups[group]:
                if overlaps(event, old):duplicate = true
            if not duplicate:groups[group].append(event)
        # Missing or wholly invalid device families keep their working bindings.
        if not groups.is_empty():replacements[action] = groups
    # Validate all changes together: valid swaps must not depend on load order.
    # Reverting a bad group can expose another conflict with a restored default,
    # so repeat until no more groups need reverting. Each pass removes a group.
    while true:
        var candidate := _candidate(original, replacements)
        var invalid: Array = []
        for action in replacements:
            for group in replacements[action]:
                for event in replacements[action][group]:
                    if not conflicts(event, action, candidate).is_empty():
                        invalid.append([action, group])
                        break
        if invalid.is_empty():return {"bindings":candidate,"rejected":rejected}
        for pair in invalid:
            replacements[pair[0]].erase(pair[1])
            rejected += 1
    return {"bindings":original,"rejected":rejected}
