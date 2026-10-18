extends SceneTree
const Narrative = preload("res://scripts/world_narrative.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred("run_checks")
func finish(result: Dictionary, flags: Dictionary) -> void:
    for flag in Narrative.completion_flags(result, result.get("lines", []).size() - 1, flags):
        flags[String(flag)] = true
func run_checks() -> void:
    var narrative := Narrative.new()
    var skills: Array = ["thread_dash", "silk_wall_grip", "double_thread_jump", "echo_hook", "bell_guard", "thorn_downstrike", "lantern_phase", "crown_resonance"]
    var events: Array = [
        {"npc":"npc_threadsmith_apprentice", "items":{}, "flags":{"quest_bring_names_canal_heard":true,"quest_bring_names_archive_heard":true},"unlocks":["quest_bring_names_complete","skill_crosscut_learned","charm_reflux_found"]},
        {"npc":"npc_rain_smith_liu", "items":{"worker_badge":1},"flags":{"quest_bring_names_started":true},"unlocks":["seal_bell_repaired","skill_ward_learned","skill_shockwave_learned","tool_mine_found","charm_shell_found"]},
        {"npc":"npc_salt_librarian_ye", "items":{"testimony_03":1},"flags":{},"unlocks":["seal_salt_restored","skill_needle_learned","skill_snare_learned","tool_fog_found","charm_spur_found"]},
        {"npc":"npc_beeswax_vendor", "items":{"pollen_wax":1},"flags":{},"unlocks":["tool_lure_found","charm_mender_found"]},
        {"npc":"npc_deserter_flagbearer", "items":{"silent_order":1},"flags":{},"unlocks":["charm_needlecase_found"]}
    ]
    for event in events:
        var flags: Dictionary = event.flags.duplicate(true)
        var before: Dictionary = flags.duplicate(true)
        var result: Dictionary = narrative.resolve(event.npc, [], skills, flags, event.items)
        check(not result.is_empty(), "Acquisition dialogue exists: " + event.npc)
        check(flags == before, "Reading a dialogue never grants equipment")
        check(Narrative.completion_flags(result, 0, flags).is_empty(), "Interrupted acquisition remains locked")
        finish(result, flags)
        for unlock in event.unlocks:
            check(bool(flags.get(unlock, false)), "Completed NPC event grants " + unlock)
        var reloaded: Dictionary = JSON.parse_string(JSON.stringify(flags))
        check(Narrative.completion_flags(result, 999, reloaded).is_empty(), "Reload prevents repeat acquisition")
    var empty: Dictionary = {}
    for npc in ["npc_rain_smith_liu", "npc_salt_librarian_ye"]:
        var no_item: Dictionary = narrative.resolve(npc, [], skills, empty, {})
        var unlocked: Array = Narrative.completion_flags(no_item, 999, empty)
        check(not unlocked.has("seal_bell_repaired") and not unlocked.has("seal_salt_restored"), "Permanent abilities cannot replace relic acquisition")
    check(not Narrative.completion_flags(narrative.resolve("npc_rain_smith_liu", [], skills, {"quest_bring_names_started":true}, {"worker_badge":0}), 999, {}).has("seal_bell_repaired"), "Zero-count relic cannot repair crest")
    var smith_reply: Dictionary = narrative.resolve("npc_rain_smith_liu", [], [], {"seal_bell_repaired":true}, {})
    check(smith_reply.state == "seal_bell_acknowledged", "Smith acknowledges completed repair")
    var library_reply: Dictionary = narrative.resolve("npc_salt_librarian_ye", [], [], {"seal_salt_restored":true}, {})
    check(library_reply.state == "seal_salt_acknowledged", "Librarian acknowledges restored record")
    var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_routes.json"))
    var seen: Dictionary = {}
    for practice in routes.get("seal_practice_plan", []):
        seen[String(practice.skill_id)] = true
        check(not bool(practice.requires_equipment) and int(practice.damage_to_player) == 0, "Practice does not gate progress or deal damage")
        var room_found := false
        for room in routes.chapters[practice.region_id].map_rooms:
            if room.id == practice.room_id:
                room_found = true
                check(room.combat_practice.skill_id == practice.skill_id, "Map practice agrees with runtime plan")
        check(room_found, "Practice references a real workshop")
    check(seen.size() == 6, "All six skills have distinct practice assignments")
    for skill in ["cleave", "needle", "snare", "ward", "shockwave", "crosscut"]:
        check(seen.has(skill), "Practice includes " + skill)
    var tool_seen: Dictionary = {}
    for practice in routes.get("tool_practice_plan", []):
        tool_seen[String(practice.tool_id)] = true
        check(int(practice.damage_to_player) == 0, "Tool practice does not deal damage")
        check(bool(practice.safe), "Tool practice stays a safe rack")
        var tool_room_found := false
        for room in routes.chapters[practice.region_id].map_rooms:
            if room.id == practice.room_id:
                tool_room_found = true
        check(tool_room_found, "Tool practice references a real workshop " + String(practice.room_id))
    check(tool_seen.size() == 4, "All four tools have distinct practice assignments")
    for tool_id in ["shard", "mine", "fog", "lure"]:
        check(tool_seen.has(tool_id), "Tool practice includes " + tool_id)
    var encounter_seen: Dictionary = {}
    for encounter in routes.get("tool_encounter_plan", []):
        encounter_seen[String(encounter.tool_id)] = true
        check(not String(encounter.get("note", "")).is_empty(), "Tool encounter tip is authored for " + String(encounter.tool_id))
        check(routes.chapters.has(encounter.region_id), "Tool encounter references region " + String(encounter.region_id))
        var chapter_path := "res://data/%s.json" % String(encounter.region_id)
        var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chapter_path))
        var encounter_room_found := false
        for room in chapter.get("map_rooms", []):
            if room.id == encounter.room_id:
                encounter_room_found = true
                check(String(room.get("guide", "")).find(String(encounter.note)) >= 0, "Encounter tip appears in room guide for " + String(encounter.room_id))
                break
        check(encounter_room_found, "Tool encounter references a real combat room " + String(encounter.room_id))
    check(encounter_seen.size() == 4, "All four tools have a suitable authored encounter tip")
    var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_catalog.json"))
    for skill_id in ["cleave", "needle", "snare", "ward", "shockwave", "crosscut"]:
        var skill: Dictionary = catalog.skills[skill_id]
        check(skill.has("growth") and skill.growth.has("level_1") and skill.growth.has("level_2"), "Skill growth notes exist for " + skill_id)
        check(not String(skill.growth.level_1).is_empty() and not String(skill.growth.level_2).is_empty(), "Skill growth notes are authored for " + skill_id)
        var recipe: Dictionary = catalog.recipes["upgrade_" + skill_id]
        check(String(recipe.description).find(String(skill.growth.level_1)) >= 0, "Upgrade recipe cites level 1 growth for " + skill_id)
        check(String(recipe.description).find(String(skill.growth.level_2)) >= 0, "Upgrade recipe cites level 2 growth for " + skill_id)
    for practice in routes.get("seal_practice_plan", []):
        check(String(practice.get("label", "")).find("校习") >= 0, "Practice label mentions upgrade direction for " + String(practice.skill_id))
    var build: RefCounted = load("res://scripts/build_system.gd").new()
    build.state.unlocked_skills = ["cleave", "needle", "snare", "ward", "shockwave", "crosscut"]
    build.state.skills = ["cleave", "needle"]
    build.state.equipped_families.thread_skill = ["cleave", "needle"]
    build.state.skill = "cleave"
    build.state.skill_levels.cleave = 0
    var base_skill: Dictionary = build.selected_skill(0)
    check(not String(base_skill.get("next_growth", "")).is_empty(), "Unupgraded skill exposes next growth note")
    var base_damage := int(base_skill.damage)
    var base_range := float(base_skill.range)
    build.state.skill_levels.cleave = 1
    var upgraded: Dictionary = build.selected_skill(0)
    check(int(upgraded.damage) > base_damage, "Cleave level 1 raises damage")
    check(float(upgraded.range) > base_range, "Cleave level 1 raises reach")
    check(String(upgraded.get("next_growth", "")).find("校习二") >= 0, "Level 1 skill points at level 2 growth note")
    # Ward is crest-compatible on bell slot 0; duration growth is the playstyle fork (no damage).
    build.state.crest = "bell"
    build.state.unlocked_crests = ["crimson", "bell", "salt"]
    build.state.skills = ["ward", ""]
    build.state.equipped_families.thread_skill = ["ward", ""]
    build.state.skill = "ward"
    build.state.skill_levels.ward = 0
    var ward_base: Dictionary = build.selected_skill(0)
    build.state.skill_levels.ward = 1
    var ward_up: Dictionary = build.selected_skill(0)
    check(not ward_base.is_empty() and not ward_up.is_empty(), "Ward selectable on bell crest")
    check(float(ward_up.get("duration", 0)) > float(ward_base.get("duration", 0)), "Ward level extends duration instead of raw damage")
    check(int(ward_up.get("damage", -1)) == 0, "Ward growth does not invent damage")
    print("SEAL_ACQUISITION_VALIDATION: ", checks, " checks; ", failures, " failures")
    quit(1 if failures else 0)
