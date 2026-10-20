extends SceneTree
## Paused World with deliberately saturated accents; not natural gameplay or comfort acceptance.
## Run under real GL with --path godot --script res://../tools/capture_secondary_visual_budget.gd.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const MELEE := preload("res://scripts/player_melee_feedback.gd")
var output := ""

func _initialize() -> void:
    call_deferred("_run")

func _shot(label: String) -> void:
    for index in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_webp(output.path_join(label + ".webp"), true, 0.9)

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real renderer required")
        quit(1)
        return
    output = ProjectSettings.globalize_path("res://../artifacts/v04_secondary_visual")
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(1280, 720)
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://visual_budget_capture.json"
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    for actor in get_nodes_in_group("enemy"):
        actor.set_physics_process(false)
    for index in range(25):
        await physics_frame
    world.set_process(false)
    var player = world.player
    player.set_physics_process(false)
    player.set_process(false)
    var point: Vector2 = player.global_position
    var camera: Camera2D = player.get_node("Camera2D")
    camera.reset_smoothing()
    var enemy = ENEMY.new()
    enemy.configure({"id":"visual_probe", "kind":"gear_sentinel", "hp":100}, "")
    enemy.position = point + Vector2(125, 0)
    world.add_child(enemy)
    enemy.set_physics_process(false)
    var beam: Node2D = enemy._effect("beam", point + Vector2(-170, -50), Vector2.RIGHT, {"beam_length":340, "radius":8}, 2.0, 1.0)
    beam.set_physics_process(false)
    var orb: Node2D = enemy._effect("projectile", point + Vector2(65, -70), Vector2.ZERO, {"radius":13}, 0.0, 3.0)
    orb.skin = "spore"
    orb.set_physics_process(false)
    player._start_attack(&"attack_1")
    player._update_attack(player.attack_windup + 0.001)
    player._update_attack_pose()
    var trace: Node2D = player.get_node_or_null("AttackSlashVfx")
    if trace != null:
        trace._process(0.0)
        trace.set_process(false)
    # Fill all 24 secondary units using actual production factories.
    for index in 20:
        world._spawn_pickup_effect(point + Vector2(55 + index * 2, -30))
    for index in 20:
        player.global_position = point + Vector2(-105 + index * 9, 0)
        player._spawn_dash_ghost()
    player.global_position = point
    player._spawn_heal_effect()
    player._ability_ring(64, Color(0.55,0.82,0.70))
    for tween in get_processed_tweens(): tween.pause()
    var policy := preload("res://scripts/combat_visual_policy.gd")
    var counts := {"total":0,"motion":0,"state":0,"environment":0}
    for accent in get_nodes_in_group(policy.SECONDARY_GROUP):
        var cost := int(accent.get_meta("secondary_units",1))
        counts.total += cost
        counts[String(accent.get_meta("secondary_category"))] += cost
    print("SECONDARY_VISUAL_CAPTURE_BUDGET ",JSON.stringify(counts))
    for index in range(12):
        var mark := MELEE.spawn_hit(world, point + Vector2(-100 + index * 20, -50), Vector2.RIGHT, &"attack_2")
        if mark != null:
            mark.set_process(false)
    await _shot("warning_over_secondary")
    beam.age = beam.arm_delay + 0.01
    beam.queue_redraw()
    await _shot("active_over_secondary")
    world._release_region_audio()
    await preload("res://scripts/audio_retirement.gd").drain(self,2000)
    world.queue_free()
    await process_frame
    await process_frame
    print("SECONDARY_VISUAL_CAPTURE screenshots=2 fixture=true")
    quit(0)
