extends SceneTree
const ROOMS = preload("res://scripts/room_camera.gd")
const FOCUS = preload("res://scripts/camera_focus.gd")
const DOORWAYS = preload("res://scripts/room_camera_doorway_validation.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func room(id: Variant = "hall") -> Dictionary:
    return {"id": id, "layout_rect": [0, 0, 2000, 2000], "camera_bounds": [0, 0, 2100, 2100]}
func _initialize() -> void:
    var f := FOCUS.new();f.region_bounds = Rect2(0, 0, 5000, 3000)
    var r := ROOMS.new()
    var malformed: Array = [false, "room", room(""), room(true), {"id": "bad", "visit_rects": 4, "camera_bounds": [0, 0, 300, 300]}, {"id": "nan", "layout_rect": [NAN, 0, 30, 40], "camera_bounds": [0, 0, 300, 300]}, room(), room()]
    r.configure(malformed, f)
    check(r.zones.size() == 1 and r.zones[0].id == "hall", "malformed identities/triggers and duplicate room IDs cannot enter selection")
    r.update(f, Vector2(500, 500))
    check(r.current.id == "hall" and f.locks.has(ROOMS.LOCK_ID), "valid fallback room still frames")
    var before := r.display_bounds
    r.update(f, Vector2(NAN, 10), 0.1)
    check(r.current.id == "hall" and r.display_bounds == before, "invalid position preserves live room lock")
    r.update(f, Vector2(500, 500), NAN)
    check(r.display_bounds.position.is_finite() and r.display_bounds.size.is_finite(), "invalid elapsed time cannot poison eased limits")
    r.configure([], null)
    check(r.current.id == "hall", "missing focus cannot partially clear current selection")
    var source := room("detached")
    r.configure([source], f);source.camera_bounds[2] = 1
    r.update(f, Vector2(500, 500))
    check(r.current.bounds.size.x == 2100, "room config mutation cannot alter copied framing geometry")
    r.update(f, Vector2(4000, 2500))
    check(r.current.is_empty() and not f.locks.has(ROOMS.LOCK_ID), "leaving all triggers removes exploration lock")
    var nested := {"id": "small", "layout_rect": [400, 400, 300, 300], "camera_bounds": [300, 300, 700, 700]}
    for ordered in [[room(), nested], [nested, room()]]:
        r.configure(ordered, f);r.update(f, Vector2(500, 500))
        check(r.current.id == "small", "nested selection is independent of config order")
    var mixed := {"id": "mixed", "visit_rects": [false, [0, 0, 0, 1], [0, 0, 30, 50]], "camera_bounds": [0, 0, 500, 500]}
    r.configure([mixed], f)
    check(r.zones.size() == 1 and r.zones[0].triggers.size() == 1, "one malformed trigger does not discard another valid trigger")
    DOORWAYS.new().run(check)
    for failure in failures:push_error(failure)
    print("RELIABILITY_ROOM_FRAMING checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
