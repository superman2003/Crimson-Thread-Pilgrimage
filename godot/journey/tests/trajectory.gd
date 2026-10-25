extends "res://journey/tests/support.gd"
const MODEL := preload("res://journey/trajectory/model.gd")
func run() -> void:
    label = "TRAJECTORY"
    var context := fixture("trajectory")
    var run := MODEL.start(context.snapshot(), "回访路线")
    var original: Dictionary = context.latest.player.duplicate(true)
    for index in 20:
        context.latest.player.position = [200 + index * 10, 300 - index * 2]
        context.latest.player.velocity = [100,-20]
        context.latest.player.grounded = index < 5
        run = MODEL.sample(run, context.snapshot(), 0.1)
    check(run.samples.size() == 20 and run.duration > 1.9, "actual time and movement samples retained")
    var stats := MODEL.statistics(run)
    check(stats.distance > 100 and stats.jumps == 1 and stats.airtime > 0, "derived path and transition statistics use sampled values")
    context.latest.exploring = false
    var paused := MODEL.sample(run, context.snapshot(), 0.1)
    check(paused.samples.size() == run.samples.size() and paused.duration == run.duration and paused.paused > run.paused, "overlay pauses samples without fabricating movement")
    context.latest.region = "other"
    check(not String(MODEL.sample(run, context.snapshot(), 0.1).reason).is_empty(), "region transition retires trace")
    context.latest.region = REGION
    check(not String(MODEL.sample(run, context.snapshot(), 3.0).reason).is_empty(), "long frame cannot manufacture smooth data")
    var data := MODEL.save(MODEL.fresh(), run)
    check(MODEL.valid(data) and data.runs.size() == 1, "trace serializes into bounded auxiliary record")
    var clip := MODEL.trim(data.runs[0], 0.5, 1.5, "中段")
    check(clip.ok and clip.run.samples.size() < run.samples.size(), "clip contains only existing samples")
    check(not MODEL.trim(run, 1, 1, "").ok, "empty interval rejected")
    check(MODEL.compare(data.runs[0], clip.run).size() == 9, "comparison exposes derived metrics")
    check(MODEL.csv(run).split("\n").size() == 21, "CSV exports every actual sample once")
    var feature := preload("res://journey/features/trajectory.gd").new()
    feature.setup(context)
    feature.data = data
    feature.comparison = String(data.runs[0].id)
    var box := node_container()
    feature.draw(box)
    await process_frame
    check(box.get_child_count() > 10, "trace charts and clipping controls render")
    box.free()
    context.latest.player = original
    context.latest.exploring = true
    feature.active = run.duplicate(true)
    feature.shutdown()
    check(context.store.read("trajectory", MODEL.fresh()).runs.size() >= 1, "shutdown preserves a valid pending observation")
    finish()
