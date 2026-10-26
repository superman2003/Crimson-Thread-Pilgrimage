extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/landmarks/model.gd")
const FEATURE := preload("res://journey/features/i_landmarks.gd")


func run() -> void:
    label = "I05_LANDMARKS"
    var context := field_fixture("i05_landmarks")
    await exercise(context, M, FEATURE, "landmarks", "markers")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    check(
        is_equal_approx(M.angle(Vector2(0, -10)), 90),
        "Godot Y-down coordinates convert to north bearing"
    )
    check(is_equal_approx(M.delta_angle(1, 359), 2), "angle difference wraps around zero")
    var stats := M.circular_statistics([359, 1])
    check(
        stats.concentration > 0.99 and (stats.mean < 2 or stats.mean > 358),
        "circular mean handles north/east wrap"
    )
    check(
        not M.intersect_rays(Vector2.ZERO, 0, Vector2(0, 10), 0).ok,
        "parallel ray geometry rejected"
    )
    var payload := M.capture(context.snapshot())
    payload.markers = [{"id": "same", "name": "同点", "point": payload.origin, "kind": "room"}]
    check(
        not M.rows(payload)[0].bearing_defined and M.visible(payload).is_empty(),
        "coincident landmark has no fake compass direction"
    )

    check(M.recommend_windows(payload).is_empty(), "undefined bearing never becomes an uncovered recommendation target")
    check(M.uncertainty_windows(payload)[0]["窗口稳定性"] == "方位未定义", "coincident landmark uncertainty remains undefined")
    payload.origin = [0, 0]
    payload.radius = 100.0
    payload.fov = 1.0
    payload.markers = [{"id":"edge", "name":"边界", "point":[100,0], "kind":"room"}]
    check(M.range_bands(payload)[2]["地标数"] == 1 and M.range_bands(payload)[3]["地标数"] == 0, "exact-radius landmark remains inside the outer distance band")
    payload.markers[0].point = [99, -10]
    check(M.recommend_windows(payload).size() == 1, "narrow FOV recommendation tests actual bearings rather than fixed 15-degree grid")
    payload.markers[0].id = ""
    check(not M.validate(payload), "empty stable landmark identity is rejected")

