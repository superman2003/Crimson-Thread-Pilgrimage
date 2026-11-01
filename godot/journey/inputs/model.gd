extends RefCounted
const V := preload("res://journey/core/values.gd")
const POLICY := preload("res://scripts/input_binding_policy.gd")
const MAX_EVENTS := 500
const MAX_SESSIONS := 5
const NAMES := {"jump":"跳跃", "attack":"普攻", "heal":"疗伤", "skill_1":"施放线术", "skill_cycle":"切换线术", "tool_cast":"使用战具", "tool_cycle":"切换战具", "dash":"冲刺", "interact":"互动", "move_left":"左移", "move_right":"右移", "aim_up":"向上", "aim_down":"向下", "hook":"掷钩", "bell_guard":"钟壳", "lantern_phase":"相位", "crown_resonance":"共鸣", "inventory":"行囊", "map":"地图", "audio_settings":"设置"}

static func fresh() -> Dictionary:
    return {"version":1, "sequence":0, "sessions":[]}

static func valid(data: Dictionary) -> bool:
    if data.get("version") != 1 or not V.count(data.get("sequence")) or not data.get("sessions") is Array or data.sessions.size() > MAX_SESSIONS:
        return false
    var ids := {}
    for session in data.sessions:
        if not session is Dictionary or not session.get("id") is String or ids.has(session.id):
            return false
        if not session.get("events") is Array or session.events.size() > MAX_EVENTS:
            return false
        if not session.get("name") is String or session.name.length() > 60:
            return false
        if not V.number(session.get("duration")) or float(session.duration) < 0 or float(session.duration) > 3600 or not V.count(session.get("started"), 9999999999) or not session.get("bindings") is Array:
            return false
        var previous := -1.0
        for event in session.events:
            if not event is Dictionary or not V.number(event.get("time")) or float(event.time) < previous:
                return false
            if not event.get("type") is String or not event.get("label") is String or not event.get("actions") is Array:
                return false
            if event.type not in ["keyboard", "mouse", "controller"] or event.label.length() > 100 or event.actions.size() > NAMES.size():
                return false
            if not event.get("pressed") is bool or not event.get("signature") is String or event.signature.length() > 100:
                return false
            if not V.number(event.get("device")) or floor(float(event.device)) != float(event.device) or absf(float(event.device)) > 2147483647:
                return false
            if not V.number(event.get("amount")) or absf(float(event.amount)) > 1 or float(event.time) < 0 or float(event.time) > 3600:
                return false
            for action in event.actions:
                if not action is String or not NAMES.has(action):
                    return false
            previous = float(event.time)
        ids[session.id] = true
    return V.json_safe(data, 0, [V.MAX_ITEMS])

static func bindings() -> Array:
    var result := []
    for action in NAMES:
        if not InputMap.has_action(action):
            continue
        var events := []
        var families := {}
        for event in InputMap.action_get_events(action):
            var family := POLICY.family(event)
            families[family] = true
            events.append({"family":family, "text":event.as_text(), "reserved":POLICY.is_reserved(event), "signature":signature(event)})
        result.append({"id":action, "name":NAMES[action], "events":events, "families":families.keys(), "deadzone":InputMap.action_get_deadzone(action)})
    return result

static func signature(event: InputEvent) -> String:
    if event is InputEventKey:
        return "key:" + str(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
    if event is InputEventMouseButton:
        return "mouse:" + str(event.button_index)
    if event is InputEventJoypadButton:
        return "button:" + str(event.button_index)
    if event is InputEventJoypadMotion:
        return "axis:%d:%d" % [event.axis, 1 if event.axis_value > 0 else -1]
    return ""

static func conflicts() -> Array:
    var result := []
    var actions: Array = NAMES.keys()
    for index in actions.size():
        var action := String(actions[index])
        if not InputMap.has_action(action):
            continue
        for other_index in range(index + 1, actions.size()):
            var other := String(actions[other_index])
            if not InputMap.has_action(other):
                continue
            var matches := []
            for a in InputMap.action_get_events(action):
                for b in InputMap.action_get_events(other):
                    if POLICY.overlaps(a, b) and not matches.has(a.as_text()):
                        matches.append(a.as_text())
            if not matches.is_empty():
                result.append({"first":action, "second":other, "name":String(NAMES[action]) + " / " + String(NAMES[other]), "bindings":matches})
    return result

static func event_row(event: InputEvent, time: float, previous_axes: Dictionary) -> Dictionary:
    if not V.number(time) or time < 0:
        return {}
    var type := POLICY.family(event)
    if type.is_empty():
        return {}
    if event is InputEventKey and event.echo:
        return {}
    var pressed := event.is_pressed()
    var amount := 1.0 if pressed else 0.0
    if event is InputEventJoypadMotion:
        if not is_finite(event.axis_value):
            return {}
        var key := str(event.device) + ":" + str(event.axis)
        var before := float(previous_axes.get(key, 0.0))
        if absf(event.axis_value - before) < 0.05 and signf(event.axis_value) == signf(before):
            return {}
        amount = clampf(event.axis_value, -1.0, 1.0)
        pressed = absf(amount) > 0.2
        previous_axes[key] = amount
    var actions := []
    for action in NAMES:
        if InputMap.has_action(action) and InputMap.event_is_action(event, action):
            actions.append(action)
    return {"time":time, "type":type, "label":event.as_text().left(100), "signature":("axis:" + str(event.axis)) if event is InputEventJoypadMotion else signature(event), "pressed":pressed, "amount":amount, "device":event.device, "actions":actions}

static func session(name: String) -> Dictionary:
    var clean := V.text(name, 60)
    return {"name":clean if not clean.is_empty() else "输入观察", "events":[], "started":int(Time.get_unix_time_from_system()), "duration":0.0, "bindings":bindings()}

static func append(session: Dictionary, event: Dictionary) -> Dictionary:
    var result := session.duplicate(true)
    if not event.is_empty() and result.events.size() < MAX_EVENTS:
        result.events.append(event.duplicate(true))
        result.duration = maxf(float(result.duration), float(event.time))
    return result

static func save(data: Dictionary, session: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    if session.get("events", []).is_empty():
        return result
    result.sequence = int(result.sequence) + 1
    var record := session.duplicate(true)
    record["id"] = "input_" + str(int(result.sequence))
    result.sessions.push_front(record)
    while result.sessions.size() > MAX_SESSIONS:
        result.sessions.pop_back()
    return result if valid(result) else data.duplicate(true)

static func statistics(session: Dictionary) -> Dictionary:
    var families := {}
    var actions := {}
    var pressed_at := {}
    var durations := []
    var unmatched := 0
    var shortest_gap := INF
    var previous := -1.0
    for event in session.get("events", []):
        families[event.type] = int(families.get(event.type, 0)) + 1
        if event.actions.is_empty():
            unmatched += 1
        for action in event.actions:
            actions[action] = int(actions.get(action, 0)) + 1
        if previous >= 0:
            shortest_gap = minf(shortest_gap, float(event.time) - previous)
        previous = float(event.time)
        var key := str(event.device) + ":" + String(event.signature)
        if event.pressed and not pressed_at.has(key):
            pressed_at[key] = float(event.time)
        elif not event.pressed and pressed_at.has(key):
            durations.append({"label":event.label, "duration":float(event.time) - float(pressed_at[key])})
            pressed_at.erase(key)
    return {"families":families, "actions":actions, "unmatched":unmatched, "durations":durations, "held_at_end":pressed_at.size(), "shortest_gap":shortest_gap if is_finite(shortest_gap) else 0.0}

static func filtered(session: Dictionary, family: String, query: String) -> Array:
    var result := []
    for event in session.get("events", []):
        if family != "all" and event.type != family:
            continue
        var names := []
        for action in event.actions:
            names.append(String(NAMES.get(action, action)))
        if V.matches(query, [String(event.label), " ".join(names)]):
            result.append(event.duplicate(true))
    return result

static func remove(data: Dictionary, id: String) -> Dictionary:
    var result := data.duplicate(true)
    for index in range(result.sessions.size() - 1, -1, -1):
        if result.sessions[index].id == id:
            result.sessions.remove_at(index)
    return result

static func document(session: Dictionary) -> String:
    var lines: Array[String] = ["输入诊断记录", "时间为工作台接收事件的间隔，不是硬件到屏幕的端到端延迟。", ""]
    for event in session.get("events", []):
        var actions := []
        for action in event.actions:
            actions.append(String(NAMES.get(action, action)))
        lines.append("%.4f秒 · %s · %s · %s · %s" % [event.time, event.type, "按下" if event.pressed else "松开/中立", event.label, " / ".join(actions)])
    return "\n".join(lines)

static func coverage(session: Dictionary) -> Dictionary:
    var pressed := {}
    var released := {}
    var chords := {}
    var physical := {}
    var examples := []
    for event in session.get("events", []):
        var key := str(event.device) + ":" + String(event.signature)
        var previous: Array = physical.get(key, [])
        var current: Array = event.actions if event.pressed else []
        for action in current:
            if not previous.has(action):
                pressed[action] = int(pressed.get(action, 0)) + 1
        for action in previous:
            if not current.has(action):
                released[action] = int(released.get(action, 0)) + 1
        if current.is_empty():
            physical.erase(key)
        else:
            physical[key] = current.duplicate()
        var held := {}
        for actions in physical.values():
            for action in actions:
                held[action] = true
        var simultaneous: Array = held.keys()
        simultaneous.sort()
        if simultaneous.size() >= 2:
            var signature := "+".join(simultaneous)
            if not chords.has(signature):
                chords[signature] = true
                examples.append({"time":event.time, "actions":simultaneous.duplicate()})
    var rows := []
    for action in NAMES:
        rows.append({"id":action, "name":NAMES[action], "pressed":int(pressed.get(action, 0)), "released":int(released.get(action, 0)), "seen":pressed.has(action)})
    return {"rows":rows, "chords":examples, "covered":pressed.size(), "total":NAMES.size()}


static func bindings_document() -> String:
    var lines: Array[String] = ["当前游戏动作绑定", "这里只导出动作和输入事件说明，不改变InputMap。", ""]
    for row in bindings():
        lines.append(String(row.name) + "（" + String(row.id) + "）")
        lines.append("动作死区 %.3f" % row.deadzone)
        for event in row.events:
            lines.append("  " + String(event.family) + " · " + String(event.text))
        if row.events.is_empty():
            lines.append("  未绑定")
    return "\n".join(lines)
