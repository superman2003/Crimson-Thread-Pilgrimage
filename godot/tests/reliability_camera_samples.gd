extends SceneTree
const FOCUS = preload("res://scripts/camera_focus.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    root.size = Vector2i(1280, 720)
    var camera := Camera2D.new();root.add_child(camera)
    var focus := FOCUS.new()
    check(focus.configure(camera, Rect2(0, 0, 4000, 3000)), "valid authored bounds remain accepted")
    var old := focus.region_bounds
    check(not focus.configure(null, Rect2(0, 0, 1, 1)) and focus.region_bounds == old, "missing camera cannot partially reset region")
    focus.update(camera, NAN, -1, true, 1)
    check(focus.look_timer == 0 and focus.look_offset == 0, "invalid elapsed time does not bypass observation delay")
    focus.update(camera, 0.35, -99, true, 10)
    check(focus.look_offset == -FOCUS.LOOK_DISTANCE, "direction and preference strength stay within observation range")
    check(focus.update(camera, 0.35, 1, true, NAN) == 0, "invalid preference cancels observation safely")
    focus.reset_follow(Vector2(500, 500))
    var before := focus.follow_center_y
    focus.reset_follow(Vector2(NAN, 1))
    check(focus.follow_center_y == before, "invalid reset cannot poison persistent baseline")
    var result := focus.follow_position(camera, Vector2(NAN, 0), Vector2.ZERO, false, 1, 1, 0)
    check(result.is_finite() and focus.follow_center_y == before, "invalid player sample preserves previous framing")
    result = focus.follow_position(camera, Vector2(500, 500), Vector2(INF, NAN), true, NAN, INF, NAN)
    check(result.is_finite() and is_finite(focus.follow_observation), "invalid motion/delta/options cannot propagate non-finite follow state")
    focus.push_lock("boss", Rect2(100, 100, 500, 400), 50, true)
    check(focus.update(camera, 1, -1, true, 1) == 0 and focus.active_lock == "boss", "priority arena lock retains observation restrictions")
    var bounds := focus.effective_bounds(camera, focus.locks.boss)
    check(old.encloses(bounds) and bounds.size.x >= 1280, "small arena expands to real viewport inside region")
    root.size = Vector2i(1920, 1080)
    bounds = focus.effective_bounds(camera, focus.locks.boss)
    check(old.encloses(bounds) and bounds.size.x >= 1920, "viewport resize updates framing without changing world bounds")
    for rate in [30, 60, 120]:
        focus.reset_follow(Vector2(500, 500))
        for i in rate:
            result = focus.follow_position(camera, Vector2(500, 500), Vector2(200, 0), true, 1.0 / rate, 1, 0)
            camera.position = result
        check(result.is_finite() and absf(result.x) <= 90.0, "normal follow remains bounded at %dHz" % rate)
    camera.free()
    check(focus.follow_position(null, Vector2.ZERO, Vector2.ZERO, false, 1, 1, 0).is_finite(), "retired camera gets a neutral finite fallback")
    for failure in failures:push_error(failure)
    print("RELIABILITY_CAMERA_SAMPLES checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
