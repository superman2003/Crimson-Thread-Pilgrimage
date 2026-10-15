extends SceneTree
## Exercise real physics occlusion and warning cleanup independently of assets.
const ENEMY_SCRIPT := preload("res://scripts/enemy_actor.gd")
var failures := 0
var checks := 0

class TestPlayer extends CharacterBody2D:
    var damage_received := 0
    func take_damage(amount: int, _origin: Vector2, _blockable: bool = true) -> void:
        damage_received += amount

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node2D.new()
    root.add_child(stage)
    var enemy = ENEMY_SCRIPT.new()
    enemy.position = Vector2(100, 100)
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    var player := TestPlayer.new()
    player.position = Vector2(150, 100)
    player.collision_layer = 2
    player.add_to_group("player")
    stage.add_child(player)
    var wall := StaticBody2D.new()
    wall.position = Vector2(125, 58)
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(8, 150)
    collider.shape = shape
    wall.add_child(collider)
    stage.add_child(wall)
    await _frames(2)
    _assert(not enemy._has_line_of_sight(player), "solid wall occludes enemy sight")
    var command := {"type": "melee", "id": "test", "hit_width": 160, "hit_height": 100, "damage": 1}
    enemy.ai_commands = [command]
    enemy.attack_desire = 10
    _assert(not enemy._try_start_attack(player), "enemy cannot begin an attack through wall")
    enemy._try_damage_player(command)
    _assert(player.damage_received == 0, "active melee cannot damage through wall")
    var beam: Node2D = enemy._effect("beam", Vector2(100, 58), Vector2.RIGHT, {"beam_length": 300}, 1.0, 0.1)
    _assert(beam.length < 25 and not beam._hits_player(Vector2(150, 58)), "beam warning and damage stop at the first solid wall")
    beam.cancel()
    wall.queue_free()
    await _frames(2)
    _assert(enemy._has_line_of_sight(player), "removing wall restores sight")
    enemy.attack_has_hit = false
    enemy._try_damage_player(command)
    _assert(player.damage_received == 1, "same attack damages visible player")
    enemy.apply_snare(1.0)
    _assert(is_equal_approx(enemy._movement_speed(), enemy.speed * 0.5), "snare halves voluntary movement")
    enemy.apply_snare(0.5)
    _assert(is_equal_approx(enemy.snare_timer, 1.0), "repeated snare cannot shorten existing control")
    enemy.cooldowns = {"test": 2.0}
    enemy._tick_timers(0.5)
    _assert(is_equal_approx(enemy.snare_timer, 0.5) and is_equal_approx(enemy.cooldowns.test, 1.5), "control and cooldown timers advance at real speed")
    enemy._tick_timers(0.6)
    _assert(is_equal_approx(enemy._movement_speed(), enemy.speed), "expired control restores movement")
    enemy.apply_snare(1.0)
    enemy.reset_for_respawn()
    _assert(is_zero_approx(enemy.snare_timer), "respawn clears control status")
    for index in range(12):
        enemy.original_visual = false
        enemy._show_telegraph(command)
        var warning_tween: Tween = enemy.telegraph_tween
        _assert(warning_tween.is_valid(), "telegraph %d starts tween" % index)
        enemy._clear_telegraph()
        _assert(not warning_tween.is_valid() and enemy.telegraph == null, "telegraph %d cancels tween before deleting node" % index)
        await _frames(1)
    _assert(enemy.combat_tweens.size() <= 2, "repeated cancelled warnings do not accumulate live tweens")

    var authored_cases := [
        ["res://data/demo_ch01_moss_bell_court.json", "moss_larva", "larva_snap", "melee"],
        ["res://data/demo_ch01_moss_bell_court.json", "moss_larva", "larva_curl", "lunge"],
        ["res://data/demo_ch01_boss_trial.json", "bronze_moth", "dust_tackle", "aoe"],
        ["res://data/demo_ch06_silent_crown_core.json", "echo_waterwheel_knight", "echo_wheel_wave", "wave"],
        ["res://data/demo_ch05_obsidian_pilgrim_road.json", "ash_banner_imp", "imp_retreat", "retreat"],
        ["res://data/demo_ch03_saltwhite_archive.json", "page_duelist", "page_feint", "feint"]
    ]
    var authored_commands: Array[Dictionary] = []
    var signatures: Array[PackedVector2Array] = []
    for entry in authored_cases:
        var authored: Dictionary = _authored_attack(String(entry[0]), String(entry[1]), String(entry[2]))
        _assert(not authored.is_empty(), "authored attack command loads: " + String(entry[2]))
        if authored.is_empty():
            continue
        _assert(String(authored.get("type", "")) == String(entry[3]), "authored attack type matches expected geometry: " + String(entry[2]))
        authored_commands.append(authored)
        enemy.hp = 5
        enemy.max_hp = 5
        enemy.original_visual = false
        enemy._begin_attack(authored)
        _assert(enemy.state == "windup" and enemy.active_attack.get("id", "") == authored.get("id", ""), "authored command enters the real windup path: " + String(entry[2]))
        var signature: Line2D = null
        if is_instance_valid(enemy.telegraph):
            signature = enemy.telegraph.get_node_or_null("AttackTypeSignature") as Line2D
        _assert(signature != null and signature.points.size() >= 2, "authored windup gets a compact type signature: " + String(entry[2]))
        _assert(enemy.windup_vfx != null and is_instance_valid(enemy.windup_vfx), "authored windup outline is tracked for cleanup: " + String(entry[2]))
        if signature != null and is_instance_valid(enemy.telegraph):
            var min_x := INF
            var min_y := INF
            var max_x := -INF
            var max_y := -INF
            for point in enemy.telegraph.polygon:
                min_x = minf(min_x, point.x)
                min_y = minf(min_y, point.y)
                max_x = maxf(max_x, point.x)
                max_y = maxf(max_y, point.y)
            var authored_rect := Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
            for point in signature.points:
                _assert(authored_rect.has_point(point), "type signature stays inside authored hitbox bounds: " + String(entry[2]))
            for previous in signatures:
                _assert(signature.points != previous, "attack type has a distinct warning shape: " + String(entry[2]))
            signatures.append(signature.points.duplicate())
        await _frames(1)

    var shockwave_fixture: Dictionary = authored_commands[0].duplicate(true) if not authored_commands.is_empty() else command.duplicate(true)
    shockwave_fixture["id"] = "validation_shockwave"
    shockwave_fixture["type"] = "shockwave"
    shockwave_fixture["hit_width"] = 220.0
    shockwave_fixture["hit_height"] = 42.0
    shockwave_fixture["offset"] = 102.0
    enemy._begin_attack(shockwave_fixture)
    var shockwave_signature: Line2D = null
    if is_instance_valid(enemy.telegraph):
        shockwave_signature = enemy.telegraph.get_node_or_null("AttackTypeSignature") as Line2D
    _assert(shockwave_signature != null and shockwave_signature.points.size() == 5, "supported shockwave branch draws its low double-ridge marker")
    if shockwave_signature != null:
        for previous in signatures:
            _assert(shockwave_signature.points != previous, "shockwave signature stays distinct from authored attack shapes")
    await _frames(1)

    if not authored_commands.is_empty():
        var melee_command: Dictionary = authored_commands[0]
        enemy.hp = 5
        enemy.max_hp = 5
        enemy._begin_attack(melee_command)
        var interrupted_fill: Polygon2D = enemy.telegraph
        var interrupted_signature := interrupted_fill.get_node_or_null("AttackTypeSignature") as Line2D if is_instance_valid(interrupted_fill) else null
        var interrupted_outline: Line2D = enemy.windup_vfx
        enemy.take_hit(1, -1)
        await _frames(2)
        _assert(not is_instance_valid(interrupted_fill) and not is_instance_valid(interrupted_signature) and not is_instance_valid(interrupted_outline), "hit interruption removes both warning layers")
        _assert(enemy.get_node_or_null("EnemyWindupVfx") == null, "hit interruption leaves no fading windup outline")

        enemy._begin_attack(melee_command)
        var tripped_fill: Polygon2D = enemy.telegraph
        var tripped_outline: Line2D = enemy.windup_vfx
        enemy.apply_trip(0.4)
        await _frames(2)
        _assert(not is_instance_valid(tripped_fill) and not is_instance_valid(tripped_outline), "trip interruption removes both warning layers")

        var aoe_command: Dictionary = authored_commands[2]
        enemy._begin_attack(aoe_command)
        var revived_fill: Polygon2D = enemy.telegraph
        var revived_outline: Line2D = enemy.windup_vfx
        enemy.reset_for_respawn()
        await _frames(2)
        _assert(not is_instance_valid(revived_fill) and not is_instance_valid(revived_outline), "respawn clears telegraph and windup outline")

        var dying_enemy = ENEMY_SCRIPT.new()
        dying_enemy.position = Vector2(260, 100)
        stage.add_child(dying_enemy)
        dying_enemy.set_physics_process(false)
        dying_enemy.original_visual = true
        dying_enemy._begin_attack(authored_commands[5])
        var dead_fill: Polygon2D = dying_enemy.telegraph
        var dead_outline: Line2D = dying_enemy.windup_vfx
        var original_signature: Line2D = null
        if is_instance_valid(dead_outline):
            original_signature = dead_outline.get_node_or_null("AttackTypeSignature") as Line2D
        _assert(dead_fill == null and is_instance_valid(dead_outline) and original_signature != null, "original-visual windup carries the same attack signature")
        dying_enemy._begin_death_dissolve()
        await _frames(2)
        _assert(not is_instance_valid(dead_fill) and not is_instance_valid(dead_outline) and not is_instance_valid(original_signature), "death clears original-visual signature and warning arc")

    stage.queue_free()
    await _frames(2)
    print("ENEMY_VISIBILITY_VALIDATION checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _authored_attack(path: String, profile_id: String, attack_id: String) -> Dictionary:
    var source := FileAccess.get_file_as_string(path)
    if source.is_empty():
        return {}
    var parsed: Variant = JSON.parse_string(source)
    if not parsed is Dictionary:
        return {}
    var profiles: Dictionary = parsed.get("ai_profiles", {})
    var profile: Dictionary = profiles.get(profile_id, {})
    for attack_variant in profile.get("attacks", []):
        if attack_variant is Dictionary and String(attack_variant.get("id", "")) == attack_id:
            return attack_variant.duplicate(true)
    return {}

func _assert(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + label)
