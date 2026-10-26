extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/input_trials/model.gd")
const FEATURE := preload("res://journey/features/i_input_trials.gd")


func run() -> void:
    label = "I13_INPUT_TRIALS"
    var context := field_fixture("i13_input_trials")
    await exercise(context, M, FEATURE, "input_trials", "actions")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var config := M.capture(context.snapshot())
    config.sequence = ["attack"]
    config.repeats = 1.0
    config.mode = "hold"
    config.hold = 0.5
    config.tolerance = 0.05
    var session := M.new()
    check(session.begin(config, 100.0), "scoped action trial starts")
    session.set_neutral([], 100.0)
    session.feed(["attack"], true, 100.1)
    session.feed(["attack"], false, 100.6)
    check(
        not session.active and session.result().trials[0].correct,
        "press-and-release interval meets configured hold tolerance"
    )
    var ambiguous := M.new()
    ambiguous.begin(config, 200)
    ambiguous.set_neutral([], 200)
    ambiguous.feed(["attack", "jump"], true, 200.1)
    check(ambiguous.trials.is_empty(), "overlapping mapped actions do not award a target")
    ambiguous.advance(205)
    check(
        not ambiguous.result().trials[0].correct,
        "missing unambiguous target expires without success"
    )
