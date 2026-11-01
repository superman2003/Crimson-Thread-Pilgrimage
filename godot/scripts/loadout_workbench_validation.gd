extends SceneTree
const BUILD = preload("res://scripts/build_system.gd")
const MANAGER = preload("res://scripts/loadout_manager.gd")
var checks := 0
var failures: Array[String] = []
var calls := 0
var at_bell := true

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)

func run() -> void:
    var build := BUILD.new()
    build.cooldowns.cleave = 3.25
    build.state.tool_counts.shard = 1
    check(build.save_loadout("  原方案  ").ok and build.state.loadouts.has("原方案"), "save normalizes harmless outer whitespace")
    var baseline: Dictionary = build.serialize()
    for name in [null, true, 1, "", "   ", "x".repeat(25), "a\nb", "a\tb", "a" + String.chr(127)]:
        check(not build.preview_loadout_management("原方案", name).ok and build.serialize() == baseline, "invalid name cannot mutate saved builds: " + str(name))
    check(not build.save_loadout("x".repeat(25)).ok and build.serialize() == baseline, "save rejects long names instead of silently overwriting a truncated name")
    check(not build.preview_loadout_management("不存在", "新名").ok, "missing source cannot be managed")
    check(not build.preview_loadout_management("原方案", "原方案").ok, "unchanged name is not an accidental copy")
    var road: Dictionary = build.preview_loadout_management("原方案", "新名", false, false)
    check(road.ok and not road.can_apply and not road.reason.is_empty(), "read-only management preview explains workstation boundary")
    check(not build.rename_loadout("原方案", "新名", false).ok and not build.copy_loadout("原方案", "新名", false).ok and build.serialize() == baseline, "road cannot rename or copy")
    check(build.copy_loadout("原方案", "副本").ok and build.state.loadouts.size() == 2, "copy creates a separate saved build")
    build.state.loadouts["副本"].equipped_families.tool[0] = ""
    check(build.state.loadouts["原方案"].equipped_families.tool[0] == "shard", "nested family arrays never alias between copies")
    build.state.loadouts["副本"] = build.state.loadouts["原方案"].duplicate(true)
    var before_rename: Dictionary = build.serialize()
    check(build.rename_loadout("原方案", "守灯").ok and build.state.loadouts.keys() == ["守灯", "副本"], "rename preserves list position and all other identities")
    check(build.state.tool_counts == before_rename.tool_counts and build.cooldowns == before_rename.cooldowns and build.state.equipped_families == before_rename.equipped_families, "naming never replenishes stock or changes equipment or recovery")
    var collision: Dictionary = build.serialize()
    check(not build.rename_loadout("守灯", "副本").ok and not build.copy_loadout("守灯", "副本").ok and build.serialize() == collision, "collisions never overwrite another saved plan")
    for index in 6:check(build.copy_loadout("守灯", "副本%d" % index).ok, "copy fills only actual free plan capacity")
    var full: Dictionary = build.serialize()
    check(not build.copy_loadout("守灯", "第九份").ok and build.serialize() == full, "full capacity rejects a ninth copy")
    check(build.rename_loadout("守灯", "八份内改名").ok and build.state.loadouts.size() == 8, "full capacity still permits a rename")
    var restored := BUILD.new()
    check(restored.restore(build.serialize()).ok and restored.serialize() == build.serialize(), "renamed and copied plans round-trip the production schema")

    var compare := BUILD.new()
    compare.save_loadout("针击")
    compare.unlock_event("skill_needle_learned")
    check(compare.select_skill("needle", 0).ok, "comparison begins with a real compatible slot edit")
    var before: Dictionary = compare.serialize()
    var quote: Dictionary = compare.preview_loadout("针击")
    check(quote.ok and quote.changes.any(func(row):return row.kind == "slot" and row.family == "thread_skill" and row.slot == 0 and row.from == "needle" and row.to == "cleave"), "preview identifies the exact changed family slot")
    check(compare.serialize() == before and quote.current_profile == compare.profile(), "difference preview stays read-only and uses real current profile")
    compare.unlock_event("repair_bell")
    compare.switch_crest("bell")
    quote = compare.preview_loadout("针击")
    check(quote.changes.any(func(row):return row.kind == "crest" and row.from == "bell" and row.to == "crimson"), "preview identifies actual crest change")
    check(quote.current_profile.heal_amount != quote.profile.heal_amount, "comparison uses real crest-specific healing rather than a fixed label")
    quote.changes.clear()
    check(not compare.preview_loadout("针击").changes.is_empty(), "caller cannot mutate later difference previews")

    var editor := MANAGER.new()
    root.add_child(editor)
    var managed := BUILD.new()
    managed.save_loadout("原方案")
    editor.open("原方案", func(name: String, copy: bool):return managed.preview_loadout_management("原方案", name, copy, at_bell),
        func(name: String, copy: bool):
            calls += 1
            return managed.copy_loadout("原方案", name, at_bell) if copy else managed.rename_loadout("原方案", name, at_bell))
    check(editor.get_cancel_button().has_focus() and editor.get_ok_button().disabled, "manager opens with cancel focus and rejects unchanged input")
    editor.target_input.text = "新旅途"
    editor.target_input.text_changed.emit(editor.target_input.text)
    check(not editor.get_ok_button().disabled and calls == 0, "typing a valid name is only a preview")
    editor.choose_copy_mode(true)
    check(editor.get_ok_button().text.contains("复制") and calls == 0, "copy mode clearly changes the confirmation action")
    managed.unlock_event("skill_needle_learned")
    managed.select_skill("needle", 0)
    managed.save_loadout("原方案")
    editor._confirm_action()
    check(calls == 0 and editor.error_label.text.contains("复核"), "concurrently overwritten source requires another confirmation")
    editor._confirm_action()
    check(calls == 1 and managed.state.loadouts.has("新旅途") and managed.state.loadouts.has("原方案") and not editor.visible, "explicit second confirm copies the latest saved snapshot")
    editor.open("原方案", func(name: String, copy: bool):return managed.preview_loadout_management("原方案", name, copy, at_bell), func(_name: String, _copy: bool):calls += 1;return {"ok":true})
    editor.target_input.text = "路边"
    editor.target_input.text_changed.emit(editor.target_input.text)
    at_bell = false
    editor._confirm_action()
    check(calls == 1 and editor.get_ok_button().disabled, "leaving the shrine invalidates an open manager before apply")
    editor.free()
    await process_frame
    if failures.is_empty():print("LOADOUT_WORKBENCH checks=%d failures=0" % checks)
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
