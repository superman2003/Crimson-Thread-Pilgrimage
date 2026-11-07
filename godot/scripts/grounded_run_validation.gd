extends SceneTree
const GAIT := preload("res://scripts/grounded_run_cycle.gd")
var checks := 0
var failures: Array[String] = []
var max_slip := 0.0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func frames(count: int = 1) -> void:
    for i in count:
        await physics_frame
        await process_frame
func _geometry() -> void:
    for art_scale in [0.55, 0.66, 0.8]:
        for slope in [-.3, 0.0, .3]:
            for index in 240:
                var pose := GAIT.sample(float(index) / 240.0, art_scale, slope)
                for key in ["near", "far"]:
                    var leg: Dictionary = pose[key]
                    check(absf(leg.hip.distance_to(leg.knee) - GAIT.THIGH) < .0001, "thigh changes length")
                    check(absf(leg.knee.distance_to(leg.ankle) - GAIT.SHIN) < .0001, "shin changes length")
            for direction in [-1.0, 1.0]:
                for key in ["near", "far"]:
                    var first := Vector2.INF
                    for index in 31:
                        var phase: float = (0.0 if key == "near" else .5) + GAIT.STANCE * index / 30.0
                        var leg: Dictionary = GAIT.sample(phase, art_scale, slope * direction)[key]
                        var body := Vector2(phase * GAIT.CYCLE_DISTANCE * direction, phase * GAIT.CYCLE_DISTANCE * direction * slope)
                        var world: Vector2 = body + (leg.sole - Vector2(192, GAIT.SOLE_Y)) * art_scale * Vector2(direction, 1)
                        if first == Vector2.INF: first = world
                        check(world.distance_to(first) < .001, "support sole slides in world space")
    for boundary in [0.0, GAIT.STANCE, .5, .5 + GAIT.STANCE, 1.0]:
        var before := GAIT.sample(boundary - .00001)
        var after := GAIT.sample(boundary + .00001)
        for key in ["near", "far"]:
            check(before[key].sole.distance_to(after[key].sole) < .01, "foot jumps at contact or loop seam")
            check(before[key].knee.distance_to(after[key].knee) < .02, "knee flips at contact or loop seam")
func _live_player() -> void:
    var stage := Node2D.new()
    root.add_child(stage)
    var floor_body := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(10000, 20)
    collision.shape = shape
    floor_body.position = Vector2(3000, 610)
    floor_body.add_child(collision)
    stage.add_child(floor_body)
    var player = load("res://scenes/Player.tscn").instantiate()
    stage.add_child(player)
    player.feel = null
    player.configure_camera_focus(Rect2(-1000, -1000, 12000, 4000))
    for move_speed in [285.0, 165.3, 340.0]:
        for direction in [-1, 1]:
            player.respawn_at(Vector2(3000, 600))
            player.speed = move_speed
            await frames(12)
            var action := "move_right" if direction > 0 else "move_left"
            Input.action_press(action)
            var previous: Dictionary = {}
            var contacts := 0
            var phase_before := 0.0
            for tick in 80:
                await frames()
                check(player.grounded_run.active, "production grounded run did not take ownership")
                var phase: float = player.run_cycle_phase
                if phase < phase_before: previous.clear()
                phase_before = phase
                for leg in player.grounded_run.legs:
                    var points: Dictionary = player.grounded_run.pose.near if leg.near else player.grounded_run.pose.far
                    var name := "near" if leg.near else "far"
                    if not points.planted:
                        previous.erase(name)
                        continue
                    var foot: Sprite2D = leg.foot
                    var sole := foot.to_global(GAIT.FOOT_SOLE / foot.scale)
                    if previous.has(name):
                        var slip: float = sole.distance_to(previous[name])
                        max_slip = maxf(max_slip, slip)
                        check(slip < .02, "actual production foot slides while grounded")
                    else: contacts += 1
                    previous[name] = sole
            Input.action_release(action)
            await frames(20)
            check(contacts >= 3, "live test did not include both feet and repeated contacts")
            check(not player.grounded_run.active and player.sprite.material == player.flash_material, "idle does not restore the original player presentation")
    Input.action_press("move_right")
    await frames(12)
    Input.action_press("attack")
    await frames(2)
    check(not player.grounded_run.active and player.sprite.material == player.flash_material, "attack retains the run rig or mask")
    Input.action_release("attack")
    await frames(40)
    check(player.grounded_run.active, "attack recovery fails to resume planted running")
    Input.action_press("jump")
    await frames(3)
    check(not player.grounded_run.active, "airborne animation keeps the grounded leg rig")
    Input.action_release("jump")
    await frames(75)
    check(player.grounded_run.active, "moving landing does not restore continuous running")
    Input.action_release("move_right")
    player.respawn_at(Vector2(1000, 600))
    await frames(15)
    check(not player.grounded_run.active and player.sprite.material == player.flash_material, "respawn retains masked or stale running parts")
    stage.queue_free()
    await frames(3)
func _run() -> void:
    _geometry()
    await _live_player()
    for failure in failures: push_error(failure)
    print("GROUNDED_RUN checks=%d failures=%d max_live_sole_slip=%.6f" % [checks, failures.size(), max_slip])
    quit(0 if failures.is_empty() else 1)
