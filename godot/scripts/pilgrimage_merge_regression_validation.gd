extends SceneTree

const TERRAIN := preload("res://scripts/chapter_terrain.gd")
const MAIN := preload("res://scripts/main_level.gd")
const PLAYER := preload("res://scenes/Player.tscn")
var failures := 0
var checks := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await _validate_one_way_physics()
    _validate_terrain_clearance()
    await _validate_snare()
    print("PILGRIMAGE_MERGE_REGRESSION checks=%d failures=%d" % [checks, failures])
    quit(1 if failures > 0 else 0)


func _validate_one_way_physics() -> void:
    var terrain := TERRAIN.new()
    terrain.configure({
        "terrain": [{"id": "mixed_floor", "surface": [[0, 220], [180, 220]], "depth": 30}],
        "platforms": [
            {"id": "upper_landing", "terrain_id": "mixed_floor", "rect": [0, 220, 90, 15], "collision_role": "one_way"},
            {"id": "solid_floor", "terrain_id": "mixed_floor", "rect": [90, 220, 90, 15], "collision_role": "floor"}
        ]
    }, "moss_cavern")
    root.add_child(terrain)
    await physics_frame
    var probe := CharacterBody2D.new()
    probe.collision_layer = 0
    probe.collision_mask = 1
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(8, 8)
    collision.shape = shape
    probe.add_child(collision)
    root.add_child(probe)
    probe.global_position = Vector2(40, 270)
    await _move_probe(probe, -240)
    _check(probe.global_position.y < 216, "one-way contour can be crossed from below")
    probe.global_position = Vector2(40, 170)
    await _move_probe(probe, 240)
    _check(probe.is_on_floor() and absf(probe.global_position.y - 216.0) < 1.0, "one-way contour catches downward landings")
    probe.global_position = Vector2(140, 270)
    await _move_probe(probe, -240)
    _check(probe.global_position.y >= 253.0, "adjacent solid terrain still blocks its underside")
    probe.queue_free()
    terrain.queue_free()
    await process_frame


func _move_probe(probe: CharacterBody2D, vertical_speed: float) -> void:
    for _i in range(30):
        await physics_frame
        probe.velocity = Vector2(0, vertical_speed)
        probe.move_and_slide()


func _validate_terrain_clearance() -> void:
    var terrain := TERRAIN.new()
    terrain.configure({"terrain": [{"id": "slope", "surface": [[0, 120], [200, 120], [300, 160]], "depth": 30}]}, "moss_cavern")
    var scene := MAIN.new()
    scene.chapter_terrain = terrain
    scene.config = {"platforms": [{"id": "legacy_wall", "rect": [400, 100, 20, 100]}]}
    _check(not scene._enemy_spawn_rect_clear(Vector2(50, 125), 4, 4), "flying spawn inside continuous terrain is rejected")
    _check(scene._enemy_spawn_rect_clear(Vector2(50, 50), 4, 4), "unobstructed air remains available")
    _check(scene._enemy_spawn_rect_clear(Vector2(270, 128), 4, 4), "empty air inside a slope bounding box remains available")
    _check(not scene._enemy_spawn_rect_clear(Vector2(410, 110), 4, 4), "existing rectangular wall clearance remains enforced")
    scene.free()
    terrain.free()


func _validate_snare() -> void:
    var last_player: CharacterBody2D = null
    for hz in [30, 60, 120]:
        var player: CharacterBody2D = PLAYER.instantiate()
        root.add_child(player)
        player.set_physics_process(false)
        player.global_position = Vector2(0, -1000)
        player.apply_snare(2.0)
        Input.action_press("move_right")
        for _i in range(hz):
            player._physics_process(1.0 / float(hz))
        _check(absf(player.velocity.x - player.speed * 0.58) < 0.5, "snare keeps 58 percent target speed at %d Hz" % hz)
        Input.action_release("move_right")
        if last_player != null:
            last_player.queue_free()
        last_player = player
    last_player.snare_timer = 0.0
    Input.action_press("move_right")
    for _i in range(15):
        last_player._physics_process(1.0 / 60.0)
    _check(absf(last_player.velocity.x - last_player.speed) < 0.5, "snare expiry restores normal movement speed")
    Input.action_release("move_right")
    last_player.apply_snare(2.0)
    last_player.dash_timer = 0.1
    last_player._physics_process(1.0 / 60.0)
    _check(last_player.snare_timer == 0.0 and absf(last_player.velocity.x) == last_player.dash_speed, "dash escapes the snare")
    last_player.queue_free()
    await process_frame


func _check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("PASS: " + label)
    else:
        failures += 1
        push_error("FAIL: " + label)
