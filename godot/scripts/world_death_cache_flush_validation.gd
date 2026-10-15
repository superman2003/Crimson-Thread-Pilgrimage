extends SceneTree
const SAVE := "user://world_death_cache_flush.json"
var failures: Array[String] = []
var checks := 0
var observed_flush := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
func run() -> void:
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    scene.currency_count = 100
    scene.player.hp = scene.player.max_hp
    scene.player.arrival_guard_timer = 0
    scene.player.hurt_timer = 0
    scene.player.death_timer = 0
    scene.player.debug_invulnerable = false
    scene.death_recorded = false
    var trigger := Area2D.new()
    trigger.collision_layer = 0
    trigger.collision_mask = 1
    trigger.position = scene.player.global_position
    var collision := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 60
    collision.shape = shape
    trigger.add_child(collision)
    trigger.body_entered.connect(func(body: Node):
        if body == scene.player and not observed_flush:
            observed_flush = true
            body.take_damage(body.max_hp, body.global_position + Vector2(100, 0), false)
            check(not scene.death_recorded, "fatal body-entered callback defers physics cache mutation"))
    root.add_child(trigger)
    for frame in 30:
        await physics_frame
        await process_frame
        if scene.death_recorded: break
    check(observed_flush and scene.player.hp == 0, "normal damage causes death inside real Area physics callback")
    check(scene.death_recorded and scene.currency_count == 50, "deferred record settles currency exactly once")
    check(is_instance_valid(scene.death_cache_area), "recovery Area is installed after query flushing")
    check(int(scene.world_state.data.death_cache.get("currency", 0)) == 50, "cache retains the lost currency")
    trigger.free()
    scene.free()
    await process_frame
    for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    for label in failures: push_error(label)
    print("WORLD_DEATH_CACHE_FLUSH checks=%d failures=%d" % [checks, failures.size()])
    call_deferred("quit", 0 if failures.is_empty() else 1)
