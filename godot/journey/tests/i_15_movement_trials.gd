extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/movement_trials/model.gd")
const FEATURE := preload("res://journey/features/i_movement_trials.gd")


func run() -> void:
    label = "I15_MOVEMENT_TRIALS"
    var context := field_fixture("i15_movement_trials")
    await exercise(context, M, FEATURE, "movement_trials", "samples")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var config := M.capture(context.snapshot())
    config.origin = [0, 0]
    config.radius = 1000.0
    var session := M.new()
    session.begin(config, 100)
    var frame := {
        "region": config.region,
        "exploring": true,
        "player":
        {"position": [0, 0], "velocity": [100, 0], "hp": 5.0, "energy": 100.0, "grounded": false}
    }
    session.sample(frame, 100)
    frame.player.position = [10, 0]
    frame.player.grounded = true
    session.sample(frame, 100.1)
    session.idle(101)
    frame.player.position = [200, 0]
    session.sample(frame, 102)
    frame.player.position = [210, 0]
    session.sample(frame, 102.1)
    session.end("人工样本结束")
    var result := session.result()
    check(M.validate(result), "segmented sampled result validates")
    var metrics := M.metrics(result)
    check(
        is_equal_approx(metrics.distance, 20),
        "overlay gap and reposition are not joined into fake travel distance"
    )
    check(metrics.landings == 1, "observed airborne-to-grounded transition counted once")
    check(result.excluded >= 0.8, "non-exploration clock is excluded")

    config.duration = 60.0
    session = M.new()
    check(session.begin(config, 0.0), "maximum-duration trial starts")
    frame.player.position = [0, 0]
    for i in 601:
        session.sample(frame, float(i) / 10.0)
    result = session.result()
    check(result.completed and result.samples.size() == 601 and is_equal_approx(result.elapsed, 60.0), "60 second trial includes time-zero and final endpoint without early capacity stop")
    check(M.validate(result), "full-length trial remains serializable")
    var library := RECORDS.fresh()
    for i in M.RECORD_LIMIT:
        library = RECORDS.append(library, "完整区间%d" % i, result)
    check(RECORDS.valid(library, M.validate), "advertised full-length record capacity fits the unchanged JSON node budget")
    check(RECORDS.export_package(library, "movement_trials", context.store.scope).to_utf8_buffer().size() < 2097152, "complete maximum-count sample library fits the unchanged auxiliary byte budget")
    var old_library := RECORDS.fresh()
    var short_trial := result.duplicate(true)
    short_trial.samples = short_trial.samples.slice(0, 2)
    short_trial.elapsed = 0.1
    short_trial.completed = false
    for i in M.RECORD_LIMIT + 1:
        old_library = RECORDS.append(old_library, "旧短记录%d" % i, short_trial)
    var panel := FEATURE.new()
    panel.setup(context)
    panel.data = old_library
    check(panel.valid(old_library), "existing short-record libraries remain readable after full-trial capacity correction")
    var overflow := RECORDS.append(old_library, "额外记录", short_trial)
    check(not panel.save_candidate(overflow), "new sessions cannot expand a legacy library beyond the corrected limit")
