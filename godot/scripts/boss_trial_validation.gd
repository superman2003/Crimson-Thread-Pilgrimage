extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const BOSS_TRIAL_CONFIG_PATH := "res://data/demo_ch01_boss_trial.json"
const BOSS01_MANIFEST_PATH := "res://assets/sprites/bosses/boss_01_moss_bell_matriarch/manifest.json"
const BOSS01_REQUIRED_DIRECTIONAL_BASES := [
    "walk",
    "attack",
    "boss_01_atk_01",
    "boss_01_atk_02",
    "boss_01_atk_03",
]
const BOSS01_MIN_DIRECTIONAL_FRAMES := 8
const BOSS01_MIN_WALK_FRAMES := 16

var failure_count := 0
var boss_trial_config: Dictionary = {}


func _init() -> void:
    var scene := MAIN_SCENE.instantiate()
    scene.set("config_path", BOSS_TRIAL_CONFIG_PATH)
    scene.set("boss_trial_mode", true)
    root.add_child(scene)
    boss_trial_config = _load_json(BOSS_TRIAL_CONFIG_PATH)
    await process_frame
    await process_frame
    await process_frame
    _sample_boss_tactics(scene)
    var state: Dictionary = scene.get_demo_state()
    _assert_boss_trial_state(state, "initial")
    scene._reset_encounters_after_player_death()
    await process_frame
    await process_frame
    state = scene.get_demo_state()
    _assert_boss_trial_state(state, "after death reset")
    _assert_boss01_directional_manifest("runtime")
    if failure_count > 0:
        quit(1)
        return
    print("BOSS_TRIAL_VALIDATION_PASS config=%s spawn=%s boss=%s boss_spawned=%s" % [
        state.get("config_id", ""),
        str(state.get("active_spawn", [])),
        str(state.get("boss_position", [])),
        str(state.get("boss_spawned", false))
    ])
    scene.queue_free()
    quit(0)


func _assert_boss_trial_state(state: Dictionary, phase: String) -> void:
    _assert_true(String(state.get("config_id", "")) == "demo_ch01_boss_trial", "boss trial config loaded")
    _assert_true(bool(state.get("boss_trial_mode", false)), phase + " boss trial mode enabled")
    _assert_true(bool(state.get("boss_unlocked", false)), phase + " boss route unlocked")
    _assert_true(bool(state.get("shortcut_open", false)), phase + " shortcut open")
    _assert_true(bool(state.get("boss_spawned", false)), phase + " boss spawned")
    _assert_true(String(state.get("boss_asset_path", "")).contains("boss_01_moss_bell_matriarch/manifest.json"), phase + " boss uses boss_01 manifest")
    _assert_true(state.get("boss_attack_types", []).has("shockwave"), phase + " boss has boss_01 root line attack")
    _assert_true(bool(state.get("boss_tactical_ai", false)), phase + " boss tactical AI enabled")
    _assert_true(not String(state.get("boss_tactic", "")).is_empty(), phase + " boss exposes tactical intent")
    _assert_true(int(state.get("normal_enemy_defeated", -1)) == int(state.get("normal_enemy_total", -2)), phase + " normal enemies skipped")
    var spawn: Array = state.get("active_spawn", [])
    var boss_position: Array = state.get("boss_position", [])
    _assert_true(spawn is Array and spawn.size() == 2 and float(spawn[0]) >= 360.0 and float(spawn[0]) <= 500.0, phase + " player starts in dedicated boss room")
    _assert_true(boss_position is Array and boss_position.size() == 2, phase + " boss position exposed")
    if spawn is Array and spawn.size() == 2 and boss_position is Array and boss_position.size() == 2:
        _assert_true(absf(float(boss_position[0]) - float(spawn[0])) <= 760.0, phase + " boss visible from initial camera")
    _assert_true(float(state.get("world_width", 0.0)) <= 1600.0, phase + " one-screen boss room width")
    _assert_true(int(state.get("platform_total", 0)) <= 4, phase + " dedicated boss room platform count")
    _assert_boss_grounded(state, phase)


func _sample_boss_tactics(scene: Node) -> void:
    var player := scene.get("player") as CharacterBody2D
    var boss := scene.get("boss_actor") as Area2D
    _assert_true(player != null, "boss tactic sample has player")
    _assert_true(boss != null, "boss tactic sample has boss")
    if player == null or boss == null:
        return
    var seen_decisions := {}
    var seen_tactics := {}
    var sample_offsets := [-34.0, -260.0, 230.0, -82.0, 310.0]
    for offset in sample_offsets:
        boss.set("state", "patrol")
        boss.set("active_attack", {})
        boss.set("attack_has_hit", false)
        boss.set("attack_desire", 0.0)
        var cooldowns: Dictionary = boss.get("cooldowns")
        for key in cooldowns.keys():
            cooldowns[key] = 1.2
        boss.set("cooldowns", cooldowns)
        player.global_position = boss.global_position + Vector2(offset, 0.0)
        await _advance_frames(scene, 18)
        var state: Dictionary = scene.get_demo_state()
        var decision := String(state.get("boss_last_ai_decision", ""))
        var tactic := String(state.get("boss_tactic", ""))
        if not decision.is_empty():
            seen_decisions[decision] = true
        if not tactic.is_empty():
            seen_tactics[tactic] = true
    _assert_true(seen_tactics.size() >= 2, "boss tactical AI changes intent")
    _assert_true(seen_decisions.size() >= 2, "boss tactical AI changes decisions")
    _assert_true(seen_tactics.has("evade") or seen_decisions.has("tactic:evade"), "boss can evade close pressure")


func _advance_frames(scene: Node, frame_count: int) -> void:
    for _i in range(frame_count):
        await process_frame


func _assert_boss01_directional_manifest(phase: String) -> void:
    var file := FileAccess.open(BOSS01_MANIFEST_PATH, FileAccess.READ)
    _assert_true(file != null, phase + " boss_01 manifest readable")
    if file == null:
        return
    var manifest = JSON.parse_string(file.get_as_text())
    _assert_true(typeof(manifest) == TYPE_DICTIONARY, phase + " boss_01 manifest json valid")
    if typeof(manifest) != TYPE_DICTIONARY:
        return

    var animations_by_name := {}
    for animation in manifest.get("animations", []):
        if typeof(animation) != TYPE_DICTIONARY:
            continue
        var animation_name := String(animation.get("name", ""))
        if not animation_name.is_empty():
            animations_by_name[animation_name] = animation

    for base_name in BOSS01_REQUIRED_DIRECTIONAL_BASES:
        var left_name := String(base_name) + "_left"
        var right_name := String(base_name) + "_right"
        var left_count := _boss01_directional_frame_count(animations_by_name, left_name, phase)
        var right_count := _boss01_directional_frame_count(animations_by_name, right_name, phase)
        if left_count >= 0 and right_count >= 0:
            _assert_true(left_count == right_count, phase + " boss_01 " + String(base_name) + " left/right frame count equal")


func _boss01_directional_frame_count(animations_by_name: Dictionary, animation_name: String, phase: String) -> int:
    _assert_true(animations_by_name.has(animation_name), phase + " boss_01 manifest has " + animation_name)
    if not animations_by_name.has(animation_name):
        return -1
    var animation: Dictionary = animations_by_name[animation_name]
    var frames = animation.get("frames", [])
    _assert_true(frames is Array, phase + " boss_01 " + animation_name + " frames is array")
    if not (frames is Array):
        return -1
    var minimum_frames := BOSS01_MIN_WALK_FRAMES if animation_name.begins_with("walk_") else BOSS01_MIN_DIRECTIONAL_FRAMES
    _assert_true(frames.size() >= minimum_frames, phase + " boss_01 " + animation_name + " has >= " + str(minimum_frames) + " frames")
    return frames.size()


func _assert_boss_grounded(state: Dictionary, phase: String) -> void:
    var boss_position: Array = state.get("boss_position", [])
    _assert_true(boss_position is Array and boss_position.size() == 2, phase + " boss position available for grounding")
    if not (boss_position is Array and boss_position.size() == 2):
        return
    var boss_data: Dictionary = boss_trial_config.get("boss", {})
    var floor_rect := _platform_rect_by_id(boss_trial_config, String(boss_data.get("platform_id", "trial_floor")))
    _assert_true(floor_rect.size.x > 0.0, phase + " boss floor exists")
    if floor_rect.size.x <= 0.0:
        return
    var clearance := float(boss_data.get("clearance", 40.0))
    var grounded_y := float(boss_position[1]) + clearance
    _assert_true(absf(grounded_y - floor_rect.position.y) <= 1.0, phase + " boss origin plus clearance sits on floor")
    var visual_scale := float(state.get("boss_visual_scale", 0.0))
    var visual_offset: Array = boss_data.get("visual_offset", [0, 0])
    var sprite_center_y := float(boss_position[1]) - 30.0 + (float(visual_offset[1]) if visual_offset is Array and visual_offset.size() >= 2 else 0.0)
    var visible_bottom_y := sprite_center_y + (246.0 - 128.0) * visual_scale
    _assert_true(absf(visible_bottom_y - floor_rect.position.y) <= 3.0, phase + " boss visible feet align with floor")


func _platform_rect_by_id(config: Dictionary, platform_id: String) -> Rect2:
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        if String(data.get("id", "")) != platform_id:
            continue
        var rect: Array = data.get("rect", [])
        if rect.size() < 4:
            return Rect2()
        return Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
    return Rect2()


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _assert_true(value: bool, label: String) -> void:
    if value:
        return
    failure_count += 1
    push_error("BOSS_TRIAL_VALIDATION_FAIL: " + label)
