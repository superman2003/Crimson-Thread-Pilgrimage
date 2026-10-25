extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/rhythm/model.gd")
const FEATURE := preload("res://journey/features/i_rhythm.gd")


func run() -> void:
    label = "I12_RHYTHM"
    var context := field_fixture("i12_rhythm")
    await exercise(context, M, FEATURE, "rhythm", "bpm")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var config := M.capture(context.snapshot())
    config.bpm = 60.0
    config.beats = 4.0
    config.lead = 1.0
    var session := M.new()
    check(session.begin(config, 100.0), "monotonic session starts")
    check(session.tap(101.0), "actual software timestamp accepts one target tap")
    session.pause(101.2)
    session.resume(106.2)
    check(session.tap(107.0), "pause duration is excluded from target clock")
    session.end("人工测试结束")
    var result := session.result()
    var aligned := M.align(result)
    check(
        aligned.matches.size() == 2 and aligned.extras.is_empty(),
        "ordered alignment matches both target timestamps after pause"
    )
    check(
        M.statistics(aligned).max_absolute < 0.001,
        "exact software timestamps produce zero software-clock error"
    )
    var invalid := result.duplicate(true)
    invalid.taps = [2.0, 1.0]
    check(not M.validate(invalid), "descending tap clocks rejected")
