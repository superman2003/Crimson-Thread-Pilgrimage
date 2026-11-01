extends SceneTree
const COORDS = preload("res://scripts/world_coordinates.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func _initialize() -> void:
    var original := COORDS.manifest()
    check(original.regions.size() == 6 and COORDS.layout_version() == 1, "real six-region layout compiles")
    var copy := COORDS.manifest();copy.regions.clear()
    check(COORDS.manifest().regions.size() == 6, "public catalog remains detached")
    for id in original.regions:
        var origin := Vector2(original.regions[id].origin[0], original.regions[id].origin[1])
        var consistent := true
        for i in 100:
            var local := Vector2(i * 3.0, i * 2.0)
            consistent = consistent and COORDS.to_world(id, local) == origin + local and COORDS.to_local(id, origin + local) == local
        check(consistent, "cached transforms preserve authored coordinates for " + id)
        var location := COORDS.location(id, Vector2(100, 200))
        check(COORDS.valid_location(location, id, Vector2(100, 200)), "derived save location validates")
        location.position[0] += 1
        check(not COORDS.valid_location(location, id, Vector2(100, 200)), "local/global mismatch remains rejected")
    var id: String = original.regions.keys()[0]
    check(COORDS.location(id, Vector2(NAN, 0)).is_empty(), "invalid local position never creates save location")
    check(not COORDS.to_local(id, Vector2(INF, 0)).is_finite(), "invalid global position cannot enter local frame")
    check(not COORDS.valid_location({}, "unknown", Vector2(NAN, 0)), "legacy empty-location exception does not accept invalid player position")
    check(COORDS.valid_location({}, "unknown", Vector2.ZERO), "legacy unknown-region behavior is retained")
    for invalid in [null, {}, {"version":true,"regions":{}}, {"version":1.5,"regions":{}}, {"version":1,"regions":[]}]:
        COORDS._compile(invalid)
        check(COORDS.layout_version() == 0 and not COORDS.has_region("x"), "malformed schema fails closed")
    var malformed := {"version":1,"regions":{"good":{"origin":[10,20],"size":[30,40]},"bad":{"origin":[false,0],"size":[30,40]},"zero":{"origin":[0,0],"size":[0,30]},"infinite":{"origin":[INF,0],"size":[30,40]}}}
    COORDS._compile(malformed)
    check(COORDS.has_region("good") and not COORDS.has_region("bad") and not COORDS.has_region("zero") and not COORDS.has_region("infinite"), "invalid region metadata is isolated from valid neighbor")
    malformed.regions.good.origin[0] = 999
    check(COORDS.to_world("good", Vector2.ZERO) == Vector2(10,20), "source mutation cannot alter compiled origin")
    COORDS._compile(original)
    var started := Time.get_ticks_usec()
    for i in 20000:COORDS.to_world(id, Vector2(i, 1))
    print("COORDINATE_CACHE_BENCHMARK calls=20000 elapsed_usec=", Time.get_ticks_usec() - started)
    for failure in failures:push_error(failure)
    print("RELIABILITY_COORDINATE_CACHE checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
