extends SceneTree
## C03: every combat action fires from its default keyboard key, the mouse
## (attack) and its default gamepad button, trigger or stick, sent through
## Input.parse_input_event exactly like a device, and changes real Player or
## build state. Abilities and an endgame build are granted up front: this
## measures the input path, not acquisition (covered by the route suites).
const CONFIG := "res://data/demo_ch01_moss_bell_court.json"

var failures := 0
var checks := 0
var scene: Node
var player: CharacterBody2D
var build: RefCounted
var rows: Array = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    # Build shortcuts (tool cast, skill/tool cycle) only run on the World host.
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://combat_input_events.json"
    var region: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
    var source: Array = region.save_points[0].position
    scene.entry_spawn_override_enabled = true
    scene.entry_spawn_override = Vector2(source[0], source[1])
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    await _frames(4)
    scene._close_overlays()
    for enemy in get_nodes_in_group("enemy"):
        enemy._cancel_attack_effects()
        enemy.queue_free()
    player = scene.player
    player.debug_invulnerable = true
    for flag in ["dash_unlocked", "bell_guard_unlocked", "lantern_phase_unlocked", "crown_resonance_unlocked"]:
        player.set(flag, true)
    build = scene.get_build_system()
    build.state.unlocked_crests = build.catalog.crests.keys()
    build.state.unlocked_skills = build.catalog.skills.keys()
    build.state.unlocked_tools = build.catalog.tools.keys()
    build.state.mechanisms = build.catalog.crests.keys()
    build.state.crest = "bell"
    for family in ["thread_skill", "tool"]:
        for slot in 2:
            var part := String(build._slot_spec(family, slot).get("requires_part", ""))
            if not part.is_empty() and not build.has_part(part):
                build.state.crafted.append(build.part_recipe(part))
    build._normalize_active_slots()
    var skills: Array = build._slot_spec("thread_skill", 0).get("compatible", [])
    var spare_skills: Array = build._slot_spec("thread_skill", 1).get("compatible", []).filter(func(id: String) -> bool: return id != String(skills[0]))
    var tools: Array = build._slot_spec("tool", 0).get("compatible", [])
    var spare_tools: Array = build._slot_spec("tool", 1).get("compatible", []).filter(func(id: String) -> bool: return id != String(tools[0]))
    var first_skill: Dictionary = build.select_skill(String(skills[0]), 0)
    var second_skill: Dictionary = build.select_skill(String(spare_skills[0]), 1)
    _check(first_skill.ok and second_skill.ok, "two thread skills equipped for cycling %s %s" % [first_skill, second_skill])
    var first_tool: Dictionary = build.select_tool(String(tools[0]), 0)
    var second_tool: Dictionary = build.select_tool(String(spare_tools[0]), 1)
    _check(first_tool.ok and second_tool.ok, "two tools equipped for cycling %s %s" % [first_tool, second_tool])
    tools = build.catalog.tools.keys()
    scene._sync_player_build()
    for id in tools:
        build.state.tool_counts[id] = build.tool_capacity(String(id))
    await _frames(10)
    var spawn: Vector2 = player.global_position
    for row: Array in _cases():
        await _case(spawn, String(row[0]), String(row[1]), row[2] as InputEvent, row[3] as Callable)
    await _interruptions(spawn)
    await _remapped_attack(spawn)
    print("COMBAT_INPUT_EVENTS_REPORT " + JSON.stringify(rows))
    if failures > 0:
        print("COMBAT_INPUT_EVENTS_FAIL failures=%d checks=%d" % [failures, checks])
        quit(1)
        return
    print("COMBAT_INPUT_EVENTS_PASS cases=%d checks=%d" % [rows.size(), checks])
    quit(0)


## [action, device, event, effect(before: Dictionary) -> bool]
func _cases() -> Array:
    var attacked := func(_before: Dictionary) -> bool: return player.attack_timer > 0.0 and player.current_attack != &"hook_throw"
    var hooked := func(_before: Dictionary) -> bool: return player.current_attack == &"hook_throw" or player.grapple_timer > 0.0
    var jumped := func(_before: Dictionary) -> bool: return player.velocity.y < -1.0
    var dashed := func(_before: Dictionary) -> bool: return player.dash_timer > 0.0
    var cast := func(before: Dictionary) -> bool: return player.energy < int(before.energy)
    var guarded := func(_before: Dictionary) -> bool: return player.guard_timer > 0.0
    var healing := func(_before: Dictionary) -> bool: return player.heal_timer > 0.0
    var phased := func(_before: Dictionary) -> bool: return player.phase_active
    var resonated := func(before: Dictionary) -> bool: return player.resonance_cooldown > 0.0 and player.energy < int(before.energy)
    var tool_used := func(before: Dictionary) -> bool: return _tool_total() < int(before.tools)
    var skill_cycled := func(before: Dictionary) -> bool: return int(build.state.active_skill_slot) != int(before.skill_slot)
    var tool_cycled := func(before: Dictionary) -> bool: return int(build.state.active_tool_slot) != int(before.tool_slot)
    var went_left := func(_before: Dictionary) -> bool: return player.velocity.x < -1.0
    var went_right := func(_before: Dictionary) -> bool: return player.velocity.x > 1.0
    return [
        ["attack", "key J", _key(KEY_J), attacked],
        ["attack", "mouse left", _mouse(MOUSE_BUTTON_LEFT), attacked],
        ["attack", "pad X", _pad(JOY_BUTTON_X), attacked],
        ["hook", "key K", _key(KEY_K), hooked],
        ["hook", "pad RB", _pad(JOY_BUTTON_RIGHT_SHOULDER), hooked],
        ["jump", "key Space", _key(KEY_SPACE), jumped],
        ["jump", "pad A", _pad(JOY_BUTTON_A), jumped],
        ["dash", "key Shift", _key(KEY_SHIFT), dashed],
        ["dash", "pad B", _pad(JOY_BUTTON_B), dashed],
        ["skill_1", "key L", _key(KEY_L), cast],
        ["skill_1", "pad Y", _pad(JOY_BUTTON_Y), cast],
        ["bell_guard", "key Q", _key(KEY_Q), guarded],
        ["bell_guard", "pad left", _pad(JOY_BUTTON_DPAD_LEFT), guarded],
        ["heal", "key H", _key(KEY_H), healing],
        ["heal", "pad LB", _pad(JOY_BUTTON_LEFT_SHOULDER), healing],
        ["lantern_phase", "key E", _key(KEY_E), phased],
        ["lantern_phase", "pad right", _pad(JOY_BUTTON_DPAD_RIGHT), phased],
        ["crown_resonance", "key R", _key(KEY_R), resonated],
        ["crown_resonance", "pad up", _pad(JOY_BUTTON_DPAD_UP), resonated],
        ["tool_cast", "key T", _key(KEY_T), tool_used],
        ["tool_cast", "pad down", _pad(JOY_BUTTON_DPAD_DOWN), tool_used],
        ["skill_cycle", "key C", _key(KEY_C), skill_cycled],
        ["skill_cycle", "pad LT", _axis(JOY_AXIS_TRIGGER_LEFT, 1.0), skill_cycled],
        ["tool_cycle", "key G", _key(KEY_G), tool_cycled],
        ["tool_cycle", "pad RT", _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), tool_cycled],
        ["move_left", "key A", _key(KEY_A), went_left],
        ["move_left", "stick left", _axis(JOY_AXIS_LEFT_X, -1.0), went_left],
        ["move_right", "key D", _key(KEY_D), went_right],
        ["move_right", "stick right", _axis(JOY_AXIS_LEFT_X, 1.0), went_right],
    ]


func _case(spawn: Vector2, action: String, device: String, event: InputEvent, effect: Callable) -> void:
    await _settle(spawn, action == "heal")
    var before := {"energy": player.energy, "tools": _tool_total(), "skill_slot": int(build.state.active_skill_slot), "tool_slot": int(build.state.active_tool_slot)}
    var mapped := InputMap.event_is_action(event, action)
    Input.parse_input_event(event)
    var fired := false
    for frame in 8:
        await physics_frame
        await process_frame
        fired = fired or bool(effect.call(before))
    Input.parse_input_event(_released(event))
    await _frames(2)
    rows.append({"action": action, "device": device, "mapped": mapped, "fired": fired})
    _check(mapped, "%s %s is a default binding" % [action, device])
    _check(fired, "%s from %s changes real gameplay state" % [action, device])


func _settle(spawn: Vector2, wounded: bool) -> void:
    for action in InputMap.get_actions():
        Input.action_release(action)
    player.restore_at_save_point()
    player.global_position = spawn
    player.velocity = Vector2.ZERO
    player.attack_timer = 0.0
    player.attack_cancel_lock = 0.0
    player.guard_cooldown = 0.0
    player.resonance_cooldown = 0.0
    player.dash_cooldown = 0.0
    player.skill_cooldown = 0.0
    player.current_attack = &""
    build.cooldowns.clear()
    for frame in 30:
        await physics_frame
    if wounded:
        player.hp = player.max_hp - 1
    await process_frame


## Held and channelled actions end the way a player ends them.
func _interruptions(spawn: Vector2) -> void:
    await _settle(spawn, false)
    Input.parse_input_event(_key(KEY_E))
    await _physics(6)
    var phasing: bool = player.phase_active
    Input.parse_input_event(_released(_key(KEY_E)))
    await _physics(3)
    _check(phasing and not player.phase_active, "releasing E ends the lantern phase it started")
    await _settle(spawn, true)
    Input.parse_input_event(_pad(JOY_BUTTON_LEFT_SHOULDER))
    await _physics(4)
    Input.parse_input_event(_released(_pad(JOY_BUTTON_LEFT_SHOULDER)))
    var channelling: bool = player.heal_timer > 0.0
    var hp_before: int = player.hp
    player.debug_invulnerable = false
    var wounded: bool = player.take_damage(1, player.global_position + Vector2(40, 0), false)
    player.debug_invulnerable = true
    await _physics(2)
    _check(channelling and wounded and player.heal_timer <= 0.0 and player.hp < hp_before, "a hit interrupts a pad-started heal without completing it")


## A keyboard rebind made through the settings capture moves attack to the
## new key; the old key stops, other devices keep their binding.
func _remapped_attack(spawn: Vector2) -> void:
    var ui: Node = scene.ui_shell
    ui.accessibility_path = "user://combat_input_events.cfg"
    ui.settings.visible = true
    await _frames(2)
    ui._begin_remap("attack")
    Input.parse_input_event(_key(KEY_U))
    await _frames(2)
    Input.parse_input_event(_released(_key(KEY_U)))
    ui.settings.visible = false
    scene._close_overlays()
    await _frames(3)
    _check(InputMap.event_is_action(_key(KEY_U), "attack") and not InputMap.event_is_action(_key(KEY_J), "attack"), "settings capture rebinds attack from J to U")
    for row: Array in [["key U (rebound)", _key(KEY_U), true], ["key J (old)", _key(KEY_J), false], ["pad X (kept)", _pad(JOY_BUTTON_X), true]]:
        await _settle(spawn, false)
        Input.parse_input_event(row[1])
        var fired := false
        for frame in 8:
            await physics_frame
            await process_frame
            fired = fired or (player.attack_timer > 0.0 and player.current_attack != &"hook_throw")
        Input.parse_input_event(_released(row[1]))
        await _frames(2)
        rows.append({"action": "attack", "device": row[0], "mapped": InputMap.event_is_action(row[1], "attack"), "fired": fired})
        _check(fired == bool(row[2]), "after rebind, %s %s attack" % [row[0], "starts" if bool(row[2]) else "no longer starts"])
    ui.settings.visible = true
    await _frames(2)
    ui._begin_remap("attack")
    Input.parse_input_event(_key(KEY_J))
    await _frames(2)
    Input.parse_input_event(_released(_key(KEY_J)))
    ui.settings.visible = false
    scene._close_overlays()
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://combat_input_events.cfg"))


func _physics(count: int) -> void:
    for index in count:
        await physics_frame


func _tool_total() -> int:
    var total := 0
    for id in build.state.tool_counts:
        total += int(build.state.tool_counts[id])
    return total


func _key(code: Key) -> InputEvent:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.pressed = true
    return event


func _mouse(button: MouseButton) -> InputEvent:
    var event := InputEventMouseButton.new()
    event.button_index = button
    event.pressed = true
    return event


func _pad(button: JoyButton) -> InputEvent:
    var event := InputEventJoypadButton.new()
    event.button_index = button
    event.pressed = true
    return event


func _axis(axis: JoyAxis, value: float) -> InputEvent:
    var event := InputEventJoypadMotion.new()
    event.axis = axis
    event.axis_value = value
    return event


func _released(event: InputEvent) -> InputEvent:
    var copy: InputEvent = event.duplicate()
    if copy is InputEventJoypadMotion:
        copy.axis_value = 0.0
    else:
        copy.set("pressed", false)
    return copy


func _frames(count: int) -> void:
    for index in count:
        await process_frame


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("COMBAT_INPUT_EVENTS " + label)
