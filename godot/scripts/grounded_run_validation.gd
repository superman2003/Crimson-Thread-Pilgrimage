extends SceneTree
const GAIT := preload("res://scripts/thread_doll_run_cycle.gd")
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
    var low := -INF
    var high := INF
    var flight_clearance := INF
    for index in 240:
        var pose := GAIT.sample(float(index) / 240.0)
        low = maxf(low, pose.hip.y)
        high = minf(high, pose.hip.y)
        if not pose.near.planted and not pose.far.planted:
            if index % 120 >= 98 and index % 120 <= 104:
                flight_clearance = minf(flight_clearance, GAIT.SOLE_Y - maxf(pose.near.sole.y, pose.far.sole.y))
    check(low - high > 4.0, "load compression and airborne rise are not visibly distinct")
    check(flight_clearance > 2.0, "flight apex has no visible clearance under both feet")
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
                    var contact_kind := ""
                    for index in 31:
                        var phase: float = (0.0 if key == "near" else .5) + GAIT.STANCE * index / 30.0
                        var leg: Dictionary = GAIT.sample(phase, art_scale, slope * direction)[key]
                        var body := Vector2(phase * GAIT.CYCLE_DISTANCE * direction, phase * GAIT.CYCLE_DISTANCE * direction * slope)
                        var world: Vector2 = body + (leg.contact - Vector2(192, GAIT.SOLE_Y)) * art_scale * Vector2(direction, 1)
                        if first == Vector2.INF or contact_kind != leg.contact_kind:
                            first = world
                            contact_kind = leg.contact_kind
                        check(world.distance_to(first) < .001, "support sole slides in world space")
    for boundary in [0.0, GAIT.STANCE, .5, .5 + GAIT.STANCE, 1.0]:
        var before := GAIT.sample(boundary - .00001)
        var after := GAIT.sample(boundary + .00001)
        for key in ["near", "far"]:
            check(before[key].sole.distance_to(after[key].sole) < .01, "foot jumps at contact or loop seam")
            check(before[key].knee.distance_to(after[key].knee) < .02, "knee flips at contact or loop seam")
            check(before[key].ankle.distance_to(after[key].ankle) < .02, "ankle jumps between toe-off and swing")
            check(absf(before[key].foot_angle - after[key].foot_angle) < .01, "boot rotation jumps at contact")
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
    check(is_equal_approx(player.sprite.sprite_frames.get_animation_speed(&"run"), 8.0 * 285.0 / GAIT.CYCLE_DISTANCE), "fallback cadence differs from the live gait's world stride")
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
            var upper_poses := {}
            var body_low := -INF
            var body_high := INF
            for tick in 80:
                await frames()
                check(player.grounded_run.active, "production grounded run did not take ownership")
                var phase: float = player.run_cycle_phase
                if phase < phase_before: previous.clear()
                phase_before = phase
                upper_poses[player.grounded_run.body.texture.get_instance_id()] = true
                body_low = maxf(body_low, player.grounded_run.body.position.y)
                body_high = minf(body_high, player.grounded_run.body.position.y)
                for leg in player.grounded_run.legs:
                    var points: Dictionary = player.grounded_run.pose.near if leg.near else player.grounded_run.pose.far
                    var name := ("near" if leg.near else "far") + String(points.contact_kind)
                    if not points.planted:
                        previous.erase(name)
                        continue
                    var foot: Sprite2D = leg.foot
                    var sole := foot.to_global(points.contact_local / foot.scale)
                    if previous.has(name):
                        var slip: float = sole.distance_to(previous[name])
                        max_slip = maxf(max_slip, slip)
                        check(slip < .02, "actual production foot slides while grounded")
                    else: contacts += 1
                    previous[name] = sole
            Input.action_release(action)
            await frames(20)
            check(contacts >= 3, "live test did not include both feet and repeated contacts")
            check(upper_poses.size() == 8, "production running does not display all newly drawn upper-body poses")
            check(body_low - body_high > 4.0, "actual player has no visible weight transfer")
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
    if DisplayServer.get_name() != "headless":
        await _pixels()
    for failure in failures: push_error(failure)
    print("GROUNDED_RUN checks=%d failures=%d max_live_sole_slip=%.6f" % [checks, failures.size(), max_slip])
    quit(0 if failures.is_empty() else 1)

func _pixels() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(384, 384)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var player = load("res://scenes/Player.tscn").instantiate()
    viewport.add_child(player)
    player.set_physics_process(false)
    player.get_node("Camera2D").enabled = false
    player.position = Vector2(192, 240)
    player.run_cycle_phase = .41
    player.sprite.play(&"run")
    player._sync_sprite_pose_anchor()
    player.reset_physics_interpolation()
    await process_frame
    await RenderingServer.frame_post_draw
    check(viewport.get_texture().get_image().get_used_rect().has_area(), "drawn running body is invisible in native rendering")
    player.flash_material.set_shader_parameter("presentation_alpha", 0.0)
    await process_frame
    await RenderingServer.frame_post_draw
    check(viewport.get_texture().get_image().is_invisible(), "running parts ignore the original live reveal alpha")
    player.flash_material.set_shader_parameter("presentation_alpha", 1.0)
    player.flash_material.set_shader_parameter("flash_amount", 1.0)
    await process_frame
    await RenderingServer.frame_post_draw
    var image := viewport.get_texture().get_image()
    var white := 0
    var tinted := 0
    for y in image.get_height():
        for x in image.get_width():
            var pixel := image.get_pixel(x, y)
            if pixel.a > .95:
                white += 1
                # Transparent viewport readback contains premultiplied edge RGB.
                if minf(pixel.r, minf(pixel.g, pixel.b)) < .98 * pixel.a:
                    tinted += 1
    print("GROUNDED_RUN_FLASH opaque=%d tinted=%d" % [white, tinted])
    check(white > 1000 and tinted == 0, "hit flash does not reach every painted running component")
    player.sprite.play(&"idle")
    player._sync_sprite_pose_anchor()
    check(not player.grounded_run.visible and not bool(player.flash_material.get_shader_parameter("hide_source")), "leaving run retains a source mask or duplicate body")
    viewport.queue_free()
    await frames(3)
