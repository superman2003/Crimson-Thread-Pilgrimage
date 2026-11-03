extends "res://scripts/boss_move_matrix_validation.gd"
## C01/B01: every authored attack of every field enemy kind spawned in a
## chapter, sampled the same way as the Boss moves. Each kind's first live
## instance is moved onto its chapter's Boss-arena floor (wide and flat, the
## Boss is not spawned) so placement never depends on a narrow ledge; flyers
## hover at their usual height above it.
const MINOR_OFFSETS := [-160.0, 70.0, 150.0, 260.0, 400.0]
const FLIGHT_HEIGHT := 110.0


func _chapters() -> Array:
    return CHAPTERS.slice(0, 2)


func _marker() -> String:
    return "ENEMY_MOVE_MATRIX"


func _offsets() -> Array:
    return MINOR_OFFSETS


## Field enemies may strike faster than a Boss but never without a windup.
func _min_windup() -> float:
    return 0.25


func _run() -> void:
    var only := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--only="):
            only = arg.trim_prefix("--only=")
    for path: String in _chapters():
        if not only.is_empty() and not path.contains(only):
            continue
        report.append_array(await _run_field_chapter(path))
    print(_marker() + "_REPORT " + JSON.stringify(report))
    print("%s_COST attack_frames=%d elapsed_ms=%d" % [_marker(), physics_frames, Time.get_ticks_msec()])
    if failures > 0:
        print("%s_FAIL failures=%d checks=%d" % [_marker(), failures, checks])
        quit(1)
        return
    print("%s_PASS kinds=%d moves=%d checks=%d" % [_marker(), report.size(), _move_count(), checks])
    quit(0)


func _run_field_chapter(path: String) -> Array:
    var scene: Node = MAIN_SCENE.instantiate()
    scene.set("config_path", path)
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    print("%s_LOADED %s ms=%d" % [_marker(), path.get_file(), Time.get_ticks_msec()])
    await _frames(3)
    for node in scene.find_children("*", "Control", true, false):
        if node.get_script() != null and node.get_script().resource_path.ends_with("pilgrimage_interface.gd"):
            node.set_process(false)
    # Let deferred region jobs (enemy spawn/respawn) settle before choosing
    # instances; a slow host can still be running them right after ready.
    for frame in 30:
        await physics_frame
    var player: CharacterBody2D = scene.player
    player.debug_invulnerable = false
    player.bell_guard_unlocked = true
    var boss_data: Dictionary = scene.config.get("boss", {})
    var home: Vector2 = scene._resolve_enemy_spawn_position(boss_data)
    var checkpoint: Vector2 = scene._vec2(scene.config.get("boss_checkpoint", home + Vector2(-520, 0)))
    var front := -1 if checkpoint.x < home.x else 1
    var floor_id: String = scene._platform_under_position(home, float(boss_data.get("clearance", 40.0)))
    var bounds: Array = scene._enemy_platform_movement_bounds(floor_id, home, boss_data)
    stands.clear()
    var chosen := {}
    for enemy in get_nodes_in_group("enemy"):
        if bool(enemy.get("is_boss")) or enemy.has_meta("seal_training_target") or enemy.has_meta("tool_training_target"):
            continue
        var kind := String(enemy.kind)
        if chosen.has(kind) or enemy.ai_profile.get("attacks", []).is_empty():
            enemy._cancel_attack_effects()
            enemy.queue_free()
        else:
            chosen[kind] = enemy
    await _frames(2)
    var entries: Array = []
    for kind: String in chosen:
        var enemy: Node2D = chosen[kind]
        if not is_instance_valid(enemy):
            continue
        var flyer := String(enemy.locomotion) == "flight"
        var spot := home - Vector2(0, FLIGHT_HEIGHT if flyer else 0.0)
        enemy.spawn_position = spot
        enemy.global_position = spot
        if bounds.size() >= 2 and enemy.has_method("set_platform_movement_bounds"):
            enemy.set_platform_movement_bounds(float(bounds[0]), float(bounds[1]))
        for other: Node2D in chosen.values():
            if is_instance_valid(other) and other != enemy:
                other.process_mode = Node.PROCESS_MODE_DISABLED
        enemy.process_mode = Node.PROCESS_MODE_INHERIT
        stand_drop = FLIGHT_HEIGHT if flyer else 0.0
        var commands: Array = enemy.ai_profile.get("attacks", []).duplicate(true)
        enemy.ai_commands = []
        var moves: Array = []
        for command: Dictionary in commands:
            if bool(command.get("elite_only", false)) and not bool(enemy.get("is_elite")):
                continue
            moves.append(await _sample_move(scene, enemy, player, command, spot, front))
        entries.append({"kind": kind, "chapter": path.get_file(), "locomotion": enemy.locomotion, "hp": enemy.max_hp, "moves": moves})
        enemy._cancel_attack_effects()
        enemy.process_mode = Node.PROCESS_MODE_DISABLED
        enemy.global_position = home + Vector2(0, 4000)
    scene.queue_free()
    await _frames(3)
    return entries
