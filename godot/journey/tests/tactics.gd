extends "res://journey/tests/support.gd"
const MODEL := preload("res://journey/tactics/model.gd")
func run() -> void:
    label = "TACTICS"
    var context := fixture("tactics")
    check(MODEL.known({}).is_empty(), "unknown enemy names and attacks stay private")
    check(MODEL.known({"journal_enemy_moss_larva":1}).is_empty(), "numeric truth does not reveal enemy")
    context.latest.flags.journal_enemy_moss_larva = true
    var rows := MODEL.known(context.latest.flags)
    check(rows.size() == 1 and rows[0].attacks.size() == 2, "one actual defeated enemy exposes exactly its catalog")
    var entries := MODEL.attacks(rows, "", "all")
    var first: Dictionary = entries[0]
    var second: Dictionary = entries[1]
    check(MODEL.phase(first.attack, 0.0).id == "windup", "timeline begins at real windup")
    check(MODEL.phase(first.attack, float(first.attack.windup) + 0.001).id == "active", "timeline crosses into active field")
    check(MODEL.phase(first.attack, MODEL.duration(first.attack) + 1).id == "finished", "timeline has finite end")
    var data := MODEL.annotate(MODEL.fresh(), rows, String(first.key), "等扑身落稳")
    data = MODEL.check_phase(data, rows, String(first.key), "windup", true)
    check(MODEL.valid(data) and data.checks[first.key].windup, "reading check remains auxiliary data")
    check(MODEL.annotate(data, rows, "unknown:secret", "假线索") == data, "cannot annotate undiscovered attack")
    var sequence := [{"key":first.key, "gap":0.2}, {"key":second.key, "gap":0.5}]
    var composed := MODEL.compose(rows, sequence)
    check(composed.ok and is_equal_approx(composed.duration, MODEL.duration(first.attack) + MODEL.duration(second.attack) + 0.7), "composer preserves actual phase durations plus explicit gaps")
    check(not MODEL.compose(rows, [{"key":"unknown:secret", "gap":0.0}]).ok, "composer cannot preview hidden attack")
    data = MODEL.save_sequence(data, rows, "观察组合", sequence)
    check(MODEL.valid(data) and data.sequences.size() == 1, "composed study sequence persists valid bounded data")
    var flags := VALUES.fingerprint(context.latest.flags)
    var feature := preload("res://journey/features/tactics.gd").new()
    feature.setup(context)
    feature.data = data
    feature.selected = String(first.key)
    feature.comparison = String(second.key)
    feature.draft_sequence = sequence
    for tab in ["catalog", "stage", "checks", "sequence"]:
        var box := node_container()
        feature.tab = tab
        feature.draw(box)
        await process_frame
        check(box.get_child_count() > 3, "tactics tab renders: " + tab)
        box.free()
    check(VALUES.fingerprint(context.latest.flags) == flags, "tactical diagrams grant no defeat or practice progress")
    finish()
