extends SceneTree
class FakeFeel extends "res://scripts/feel_kit.gd":
    var now := 1000000
    func _now_usec() -> int:return now
    func _is_headless() -> bool:return false
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var feel := FakeFeel.new();root.add_child(feel);feel.set_process(false)
    Engine.time_scale = 1.0
    for duration in [NAN, INF, -1.0, 0.0]:feel.hitstop(duration)
    for scale in [NAN, INF, -1.0, 0.0, 2.0]:feel.hitstop(100, scale)
    check(Engine.time_scale == 1.0 and feel._hitstop_deadline_usec == 0, "invalid durations/scales never alter global clock")
    feel.hitstop(100)
    check(is_equal_approx(Engine.time_scale, 0.05), "accepted hitstop slows simulation")
    var deadline := feel._hitstop_deadline_usec
    feel.hitstop(30)
    check(feel._hitstop_deadline_usec == deadline, "shorter accent cannot restart deadline")
    feel.now += 100001;feel._process(0)
    check(Engine.time_scale == 1.0 and feel._hitstop_remaining == 0, "wall clock ends hitstop even with zero simulation delta")
    Engine.time_scale = 0.5;feel.hitstop(100)
    feel.now += 100001;feel._process(0)
    check(Engine.time_scale == 0.5, "preexisting slow motion is restored exactly")
    feel.hitstop(100);Engine.time_scale = 0.7;feel.now += 100001;feel._process(0)
    check(Engine.time_scale == 0.7, "later clock owner is not overwritten")
    Engine.time_scale = 1.0;feel.hitstop(100);paused = true;feel._process(0)
    check(Engine.time_scale == 1.0 and feel._hitstop_deadline_usec == 0, "pause releases global slowdown")
    feel.hitstop(100);check(feel._hitstop_deadline_usec == 0, "paused world cannot start new hitstop")
    paused = false;feel.hitstop(9999)
    check(feel._hitstop_deadline_usec - feel.now == 250000, "accepted duration retains 250ms cap")
    feel._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(Engine.time_scale == 1.0, "focus loss cancels slowdown")
    feel.add_trauma(NAN);check(is_finite(feel._trauma), "invalid trauma cannot poison camera noise")
    feel.hitstop(100);feel.free()
    check(Engine.time_scale == 1.0, "freeing active owner restores global clock")
    for failure in failures:push_error(failure)
    print("RELIABILITY_HITSTOP_CLOCK checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
