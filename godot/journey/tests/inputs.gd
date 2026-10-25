extends "res://journey/tests/support.gd"
const MODEL := preload("res://journey/inputs/model.gd")
func run() -> void:
    label = "INPUTS"
    var context := fixture("inputs")
    var originals := {}
    for action in ["jump", "attack"]:
        originals[action] = InputMap.action_get_events(action) if InputMap.has_action(action) else null
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        InputMap.action_erase_events(action)
        var binding := InputEventKey.new()
        binding.physical_keycode = KEY_SPACE
        InputMap.action_add_event(action, binding)
    check(MODEL.conflicts().size() >= 1, "formal input policy finds shared physical key")
    var event := InputEventKey.new()
    event.physical_keycode = KEY_SPACE
    event.pressed = true
    var axes := {}
    var first := MODEL.event_row(event, 0.1, axes)
    check(first.actions.has("jump") and first.actions.has("attack"), "received key is associated with actual InputMap actions")
    var session := MODEL.append(MODEL.session("观察"), first)
    event.pressed = false
    session = MODEL.append(session, MODEL.event_row(event, 0.3, axes))
    var statistics := MODEL.statistics(session)
    check(statistics.held_at_end == 0 and statistics.durations.size() == 1, "matching release closes held physical input")
    check(MODEL.coverage(session).covered == 2, "one overlapping key exposes two mapped actions")
    event.echo = true
    check(MODEL.event_row(event, 0.4, axes).is_empty(), "keyboard echo is omitted")
    var axis := InputEventJoypadMotion.new()
    axis.axis = JOY_AXIS_LEFT_X
    axis.axis_value = 0.8
    var positive := MODEL.event_row(axis, 0.5, axes)
    axis.axis_value = 0.0
    var neutral := MODEL.event_row(axis, 0.6, axes)
    var movement := MODEL.session("摇杆")
    movement = MODEL.append(movement, positive)
    movement = MODEL.append(movement, neutral)
    check(MODEL.statistics(movement).held_at_end == 0, "neutral axis closes same signed-independent physical axis")
    axis.axis_value = NAN
    check(MODEL.event_row(axis, 0.7, axes).is_empty(), "nonfinite device samples rejected")
    var saved := MODEL.save(MODEL.fresh(), session)
    check(MODEL.valid(saved), "input session validates persistent schema")
    check(MODEL.filtered(session, "keyboard", "Space").size() == 2, "event filtering uses visible input descriptions")
    var feature := preload("res://journey/features/input_diagnostics.gd").new()
    feature.setup(context)
    feature.data = saved
    for tab in ["bindings", "conflicts", "controller", "events"]:
        var box := node_container()
        feature.tab = tab
        feature.show_coverage = true
        feature.draw(box)
        await process_frame
        check(box.get_child_count() > 2, "input inspector tab renders: " + tab)
        box.free()
    for action in originals:
        InputMap.erase_action(action)
        if originals[action] != null:
            InputMap.add_action(action)
            for binding in originals[action]:
                InputMap.action_add_event(action, binding)
    finish()
