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
