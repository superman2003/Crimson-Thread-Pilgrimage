extends SceneTree

var failures := 0

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCRIPT := preload("res://scripts/enemy_actor.gd")
const CONFIG_PATH := "res://data/demo_ch01_moss_bell_court.json"
const LARVA_SPRITE := "res://assets/third_party/dark_fantasy_bestiary/ansimuz-shambler-short-pal2-alpha_0.png"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config := _load_json(CONFIG_PATH)
    _assert(config.has("ai_profiles"), "ai profile table exists")
    var profiles: Dictionary = config.get("ai_profiles", {})
    var expected_types := {"moss_larva": ["melee", "lunge"], "bronze_moth": ["dive", "fan"], "spore_bellmaker": ["fan", "pool"], "gear_sentinel": ["guard", "melee"]}
    for kind in expected_types:
        _assert(profiles.has(kind), "%s has an ai profile" % kind)
        var profile: Dictionary = profiles.get(kind, {})
        var count: int = profile.get("attacks", []).size()
        _assert(count == 2, "%s has two distinct authored attacks" % kind)
        _assert(_profile_has_types(profile, expected_types[kind]), "%s retains its distinct attack mechanics" % kind)
    var boss_profile: Dictionary = profiles.get("rust_crown_guardian", {})
    _assert(boss_profile.get("attacks", []).size() == 4, "boss has four distinct authored attacks")
    _assert(_profile_has_types(boss_profile, ["melee", "wave", "fan", "rootline"]), "boss retains ground, projectile and phase mechanics")

    _add_floor(180)
    var player := PLAYER_SCENE.instantiate()
    root.add_child(player)
    player.global_position = Vector2(100, 180)
    await _frames(3)
    _assert(_has_mouse("attack", MOUSE_BUTTON_LEFT), "left mouse is bound to player attack")
    _assert(_has_mouse("heal", MOUSE_BUTTON_RIGHT), "right mouse is bound to healing")
    _assert(_has_key("skill_1", KEY_L), "L is bound to skill")
    _assert(_has_key("lantern_phase", KEY_E), "E is reserved for traversal phase")
    _assert(_has_key("interact", KEY_F), "F is bound to interaction")

    var slash_enemy := _spawn_enemy(Vector2(155, 140), 3, profiles.get("moss_larva", {}))
    await _frames(3)
    _assert(_enemy_has_runtime_visual(slash_enemy), "enemy runtime uses open gothicvania visual")
    var before: int = int(slash_enemy.hp)
    player.facing = 1
    player._start_attack(&"attack_1")
    await _frames(16)
    _assert(is_instance_valid(slash_enemy) and slash_enemy.hp < before, "player slash hits enemy hurtbox")
    _assert(player.energy >= player.energy_per_hit, "slash hit grants energy")
    slash_enemy.queue_free()
    await _frames(2)

    var left_enemy := _spawn_enemy(Vector2(45, 140), 3, profiles.get("moss_larva", {}))
    player.global_position = Vector2(100, 180)
    player.velocity = Vector2.ZERO
    player.facing = -1
    before = int(left_enemy.hp)
    player._start_attack(&"attack_1")
    await _frames(16)
    _assert(is_instance_valid(left_enemy) and left_enemy.hp < before, "left slash hits enemy on left side")
    left_enemy.queue_free()
    await _frames(2)

    var up_enemy := _spawn_enemy(Vector2(100, 106), 3, profiles.get("moss_larva", {}))
    player.global_position = Vector2(100, 180)
    player.velocity = Vector2.ZERO
    Input.action_press("aim_up")
    before = int(up_enemy.hp)
    player._start_attack(&"attack_1")
    Input.action_release("aim_up")
    await _frames(16)
    _assert(is_instance_valid(up_enemy) and up_enemy.hp < before, "up slash hits enemy above player")
    up_enemy.queue_free()
    await _frames(2)

    var down_enemy := _spawn_enemy(Vector2(100, 140), 3, profiles.get("moss_larva", {}))
    player.global_position = Vector2(100, 100)
    player.velocity = Vector2(0.0, 260.0)
    Input.action_press("aim_down")
    before = int(down_enemy.hp)
    player._start_attack(&"attack_1")
    Input.action_release("aim_down")
    await _frames(16)
    _assert(is_instance_valid(down_enemy) and down_enemy.hp < before, "down slash hits enemy below player")
    _assert(player.velocity.y < -220.0, "down slash bounces player upward after hit")
    down_enemy.queue_free()
    await _frames(2)

    var contact_enemy := _spawn_enemy(Vector2(100, 140), 3, profiles.get("moss_larva", {}))
    player.global_position = Vector2(100, 180)
    player.velocity = Vector2.ZERO
    player.hp = player.max_hp
    player._start_attack(&"attack_1")
    contact_enemy._on_body_entered(player)
    _assert(player.hp == player.max_hp, "enemy body contact is ignored during player slash")
    player.attack_timer = 0.0
    player.enemy_contact_guard_timer = 0.0
    contact_enemy.contact_timer = 0.0
    contact_enemy._on_body_entered(player)
    _assert(player.hp == player.max_hp - 1, "enemy body contact damages player after slash guard ends")
    contact_enemy.queue_free()
    await _frames(2)

    var hook_enemy := _spawn_enemy(Vector2(226, 140), 3, profiles.get("moss_larva", {}))
    player.global_position = Vector2(100, 180)
    player.velocity = Vector2.ZERO
    player.facing = 1
    player.hurt_timer = 0.0
    before = int(hook_enemy.hp)
    player._start_attack(&"hook_throw")
    await _frames(28)
    _assert(is_instance_valid(hook_enemy) and hook_enemy.hp < before, "hook attack hits at extended range")
    hook_enemy.queue_free()
    await _frames(2)

    var burst_enemy := _spawn_enemy(Vector2(154, 140), 4, profiles.get("moss_larva", {}))
    await _frames(3)
    player.energy = player.skill_energy_cost
    player._try_skill_burst()
    await _frames(20)
    _assert(is_instance_valid(burst_enemy) and burst_enemy.hp <= 2, "L skill spends energy and deals 2 damage")
    _assert(player.energy <= player.energy_per_hit, "L skill consumes energy and does not refund on its own hit")

    burst_enemy.queue_free()
    player._reset_traversal_state()
    player.hurt_timer = 0.0
    player.global_position = Vector2(100, 180)
    player.velocity = Vector2.ZERO
    await _frames(3)
    player.hp = 3
    player.energy = player.heal_energy_cost
    _assert(player._try_heal(), "right mouse heal starts while grounded and idle")
    _assert(player.hp == 3 and player.energy == 0, "heal reserves 60 energy until completion")
    await _frames(int(ceil(player.heal_duration * 60.0)) + 2)
    _assert(player.hp == 4, "right mouse heal restores 1 HP after channel completes")

    var ai_player := PLAYER_SCENE.instantiate()
    root.add_child(ai_player)
    ai_player.global_position = Vector2(420, 180)
    var ai_enemy := _spawn_enemy(Vector2(482, 140), 5, profiles.get("moss_larva", {}))
    await _frames(6)
    var ai_debug: Dictionary = ai_enemy.get_ai_debug_state()
    _assert(bool(ai_debug.get("reads_player_commands", false)), "enemy ai reads player command state")
    _assert(int(ai_debug.get("command_read_count", 0)) > 0, "enemy ai samples player commands")
    _assert(float(ai_debug.get("max_attack_range", 0.0)) >= 90.0, "enemy ai exposes active attack range")
    ai_player.facing = 1
    ai_player._start_attack(&"attack_1")
    await _frames(8)
    ai_debug = ai_enemy.get_ai_debug_state()
    _assert(String(ai_debug.get("last_player_command", "")) == "slash_forward", "enemy ai reads player slash command")
    await _frames_until_enemy_damage(ai_player, 240)
    _assert(is_instance_valid(ai_enemy), "ai enemy remains active during combat validation")
    ai_debug = ai_enemy.get_ai_debug_state()
    _assert(not String(ai_debug.get("last_attack_id", "")).is_empty(), "enemy attack desire starts an active command")
    _assert(ai_player.hp < ai_player.max_hp, "enemy command ai can damage the player")

    if failures > 0:
        quit(1)
        return
    print("COMBAT_VALIDATION_PASS player_hits=true hook_hits=true skill_L=true heal_RMB=true interact_F=true ai_profiles=5 enemy_ai_damage=true enemy_reads_commands=true")
    quit(0)


func _spawn_enemy(position_value: Vector2, enemy_hp: int, profile: Dictionary) -> Area2D:
    var enemy := Area2D.new()
    enemy.set_script(ENEMY_SCRIPT)
    enemy.global_position = position_value
    enemy.configure({
        "id": "T",
        "kind": "moss_larva",
        "hp": enemy_hp,
        "damage": 1,
        "patrol": 0,
        "sprite": LARVA_SPRITE,
        "sprite_region": [0, 0, 32, 32],
        "visual_scale": 1.55
    }, LARVA_SPRITE, false, profile)
    root.add_child(enemy)
    return enemy


func _add_floor(y: float) -> void:
    var body := StaticBody2D.new()
    body.position = Vector2(360, y + 22)
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(900, 44)
    shape.shape = rectangle
    body.add_child(shape)
    root.add_child(body)


func _frames(count: int) -> void:
    for _i in range(count):
        await physics_frame


func _frames_until_enemy_damage(target: CharacterBody2D, max_frames: int) -> void:
    for _i in range(max_frames):
        if target.hp < target.max_hp:
            return
        await physics_frame


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var data = JSON.parse_string(file.get_as_text())
    return data if typeof(data) == TYPE_DICTIONARY else {}


func _has_mouse(action_name: StringName, button: int) -> bool:
    for event in InputMap.action_get_events(action_name):
        if event is InputEventMouseButton and event.button_index == button:
            return true
    return false


func _has_key(action_name: StringName, keycode: int) -> bool:
    for event in InputMap.action_get_events(action_name):
        if event is InputEventKey and event.physical_keycode == keycode:
            return true
    return false


func _profile_has_types(profile: Dictionary, required: Array) -> bool:
    var types: Array = []
    for attack in profile.get("attacks", []):
        types.append(String(attack.get("type", "")))
    for attack_type in required:
        if not types.has(attack_type):
            return false
    return true


func _enemy_has_runtime_visual(enemy: Area2D) -> bool:
    var animated := enemy.get_node_or_null("EnemyAnimatedSprite") as AnimatedSprite2D
    if animated != null and animated.sprite_frames != null:
        return animated.sprite_frames.has_animation("idle") and animated.sprite_frames.get_frame_count("idle") > 0
    var static_sprite := enemy.get_node_or_null("EnemySprite") as Sprite2D
    if static_sprite != null and static_sprite.texture != null:
        return true
    var part_root := enemy.get_node_or_null("EnemyPartSprite")
    if part_root == null:
        return false
    for child in part_root.get_children():
        var part := child as Sprite2D
        if part != null and part.texture != null:
            return true
    return false


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    failures += 1
    push_error("FAIL: " + label)
