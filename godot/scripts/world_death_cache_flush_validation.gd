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
    var shrine: Area2D = null
    for child in scene.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "save_point":
            shrine = child
            break
    check(shrine != null, "actual World has a loaded shrine for checkpoint respawn")
    if shrine != null:
        scene._activate_save_point(shrine)
        check(scene.active_save_point_id == String(shrine.name)
            and scene.player.spawn_position == shrine.global_position,
            "actual shrine activation installs the player's checkpoint spawn")
    var checkpoint: Vector2 = scene.player.spawn_position
    var checkpoint_id: String = scene.active_save_point_id
    var respawn_events := {"count": 0, "position": Vector2.INF}
    var on_respawn := func() -> void:
        respawn_events.count += 1
        respawn_events.position = scene.player.global_position
    scene.player.player_respawned.connect(on_respawn)
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
    # Continue the real controller through the existing death timer. No direct
    # call to _hard_respawn, forced HP restoration or new invulnerability.
    scene.player.set_physics_process(true)
    var saw_reveal := false
    for frame in 180:
        await physics_frame
        await process_frame
        if respawn_events.count > 0:
            saw_reveal = saw_reveal or scene.player.respawn_reveal_timer > 0.0
            if scene.player.respawn_reveal_timer <= 0.0:
                break
    scene.player.set_physics_process(false)
    check(respawn_events.count == 1, "World death completes exactly one production respawn")
    check(scene.player.hp == scene.player.max_hp and scene.player.energy == 0,
        "World respawn retains the normal health and energy rules")
    check(Vector2(respawn_events.position) == checkpoint,
        "World respawn signal occurs at the exact activated shrine checkpoint")
    check(saw_reveal
        and is_equal_approx(float(scene.player.flash_material.get_shader_parameter("presentation_alpha")), 1.0),
        "World checkpoint presentation becomes fully visible after the reveal")
    # Authored shrine anchors are above their supporting floor. The controller
    # must settle normally after relocation, rather than freezing at that Y.
    scene.player.set_physics_process(true)
    for frame in 30:
        await physics_frame
        await process_frame
        if scene.player.is_on_floor() and scene.player.sprite.animation == &"idle":
            break
    scene.player.set_physics_process(false)
    check(absf(scene.player.global_position.x - checkpoint.x) < 2.0
        and scene.player.is_on_floor() and scene.player.sprite.animation == &"idle"
        and scene.player.velocity == Vector2.ZERO,
        "The shrine return settles onto its floor and completes landing into idle")
    check(not scene.death_recorded and not scene.boss_spawned,
        "World respawn resets death recording and encounter state")
    check(scene.currency_count == 50 and int(scene.world_state.data.death_cache.get("currency", 0)) == 50,
        "Respawn does not charge currency loss twice or delete the recovery knot")
    var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    check(saved is Dictionary and int(saved.get("hp", 0)) == scene.player.max_hp,
        "Normal World respawn writes the restored player state to disk")
    var region: Dictionary = scene.world_state.get_region(String(scene.config.get("id", "")))
    check(String(region.checkpoint_id) == checkpoint_id,
        "The saved region retains the activated shrine identity")
    Input.action_press("move_right")
    scene.player._physics_process(1.0 / 60.0)
    Input.action_release("move_right")
    check(scene.player.velocity.x > 0.0 and scene.player._can_start_action(),
        "Normal movement and action input are available after the complete World respawn")
    await remote_recall(scene, shrine)
    scene.player.player_respawned.disconnect(on_respawn)
    scene.free()
    await process_frame
    for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    for label in failures: push_error(label)
    print("WORLD_DEATH_CACHE_FLUSH checks=%d failures=%d" % [checks, failures.size()])
    call_deferred("quit", 0 if failures.is_empty() else 1)

## G02 late-game remote recovery: offered only on a deliberate shrine rest
## after three guardians, never on respawn, and keeps only 60%.
func remote_recall(scene: Node, shrine: Area2D) -> void:
    var recall := preload("res://scripts/death_recall.gd")
    var dialog: ConfirmationDialog = scene.get_node_or_null(recall.DIALOG)
    check(dialog != null and not dialog.visible and scene.active_overlay == "", "respawning never offers the remote recall")
    var knot: int = int(scene.world_state.data.death_cache.get("currency", 0))
    var wallet: int = scene.currency_count
    scene.player.global_position = shrine.global_position
    scene._activate_save_point(shrine)
    check(not dialog.visible and int(scene.world_state.data.death_cache.get("currency", 0)) == knot, "before three guardians fall a rest offers no recall")
    for chapter in ["ch01", "ch02", "ch03"]: scene.story_flags["boss_down_" + chapter] = true
    scene._activate_save_point(shrine)
    check(dialog.visible and scene.active_overlay == "recall" and scene.player.ui_input_locked, "a rest after three guardians offers the recall and locks gameplay input")
    check(dialog.get_cancel_button().has_focus() and dialog.dialog_text.contains(str(int(floor(knot * recall.KEEP_RATIO)))), "the offer focuses walking back and states the 60% amount")
    dialog.canceled.emit()
    check(not dialog.visible and scene.active_overlay == "" and int(scene.world_state.data.death_cache.get("currency", 0)) == knot and scene.currency_count == wallet, "declining keeps the knot where it lies")
    scene._activate_save_point(shrine)
    scene._toggle_map()
    check(not dialog.visible and scene.active_overlay == "map", "opening the map closes the recall offer")
    scene._close_overlays()
    scene._activate_save_point(shrine)
    dialog.confirmed.emit()
    var kept := int(floor(knot * recall.KEEP_RATIO))
    check(scene.currency_count == wallet + kept and scene.world_state.data.death_cache.is_empty(), "recalling keeps exactly 60% and clears the knot")
    check(scene.death_cache_area == null and scene.active_overlay == "", "the recalled knot leaves the world and control returns")
    var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    check(saved is Dictionary and int(saved.get("currency", -1)) == scene.currency_count, "the recall is written to disk")
    scene._activate_save_point(shrine)
    check(not dialog.visible, "with no knot left a rest offers nothing")

