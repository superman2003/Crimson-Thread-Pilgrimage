extends "res://journey/tests/support.gd"
const MODEL := preload("res://journey/build_lab/model.gd")
func run() -> void:
    label = "BUILD_LAB"
    var context := fixture("build_lab")
    var snapshot: Dictionary = context.snapshot()
    var identity := VALUES.fingerprint(snapshot.build_state)
    var started := MODEL.start(MODEL.fresh(), snapshot)
    check(not started.draft.is_empty(), "sandbox starts from real live build schema")
    var evaluation := MODEL.machine(snapshot, started.draft)
    var baseline: Dictionary = BUILD.new().stats()
    var equal: bool = evaluation.ok
    for key in baseline:
        var a: Variant = baseline[key]
        var b: Variant = evaluation.get("stats", {}).get(key)
        if VALUES.number(a) and VALUES.number(b):
            if not is_equal_approx(float(a), float(b)):
                print("PROFILE_DIFFERENCE ", key, " ", a, " ", b)
                equal = false
        elif a != b:
            print("PROFILE_DIFFERENCE ", key, " ", a, " ", b)
            equal = false
    check(equal, "sandbox uses actual current BuildSystem profile")
    var invalid := MODEL.edit(started, snapshot, "equip", "needle", "thread_skill", 0)
    check(not invalid.get("ok", false), "unearned equipment cannot enter sandbox")
    var changed := MODEL.edit(started, snapshot, "clear", "", "thread_skill", 0)
    check(changed.ok and changed.data.draft.skills[0] == "", "sandbox can clear a compatible owned slot")
    check(VALUES.fingerprint(snapshot.build_state) == identity, "sandbox edit leaves live snapshot unchanged")
    var forged: Dictionary = started.draft.duplicate(true)
    forged.unlocked_skills.append("needle")
    forged.skills[0] = "needle"
    forged.equipped_families.thread_skill[0] = "needle"
    check(not MODEL.machine(snapshot, forged).ok, "forged ownership is replaced by live authority")
    var diff := MODEL.differences(snapshot, snapshot.build_state, changed.data.draft)
    check(diff.ok and diff.skills[0].after.name == "空槽", "comparison resolves actual equipped slot changes")
    var budget := MODEL.sustainability(evaluation, 100, 3, 10)
    check(budget.ok and budget.remaining >= 0 and budget.heals >= 0, "resource budget is bounded and independent")
    var saved := MODEL.save_scenario(started, "基准", "实际获得装备", snapshot)
    check(MODEL.valid(saved) and saved.scenarios.size() == 1, "scenario stores valid detached state")
    check(MODEL.save_scenario(saved, "基准", "", snapshot) == saved, "duplicate scenario names rejected")
    var loaded := MODEL.load_scenario(saved, String(saved.scenarios[0].id), snapshot)
    check(loaded.ok and loaded.data.draft == evaluation.state, "saved scenario revalidates against current ownership")
    check(not MODEL.import_draft(saved, snapshot, "{broken").ok, "malformed draft import rejected")
    check(MODEL.import_draft(saved, snapshot, JSON.stringify({"version":1, "state":evaluation.state})).ok, "valid draft imports only into sandbox")
    check(MODEL.constraints(snapshot, started.draft).size() > 1, "slot constraints come from actual snapshot")
    var feature := preload("res://journey/features/build_lab.gd").new()
    feature.setup(context)
    feature.data = saved
    for tab in ["edit", "compare", "resources", "saved"]:
        var box := node_container()
        feature.tab = tab
        feature.draw(box)
        await process_frame
        check(box.get_child_count() > 3, "build lab tab renders: " + tab)
        box.free()
    check(VALUES.fingerprint(context.latest.build_state) == identity, "all UI previews preserve actual source build")
    finish()
