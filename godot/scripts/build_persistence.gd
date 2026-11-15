extends RefCounted
## Serializing the build and restoring it, including migrating legacy family arrays.
## Moved out of build_system.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func serialize(system: RefCounted) -> Dictionary:
    var snapshot = system.state.duplicate(true)
    snapshot["cooldowns"] = system.cooldowns.duplicate(true)
    return snapshot


static func counter(system: RefCounted, value: Variant, maximum: int) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum and float(value) == floor(float(value))


static func legacy_family_arrays(system: RefCounted, crest: String, skills: Array, tools: Array, passives: Array) -> Dictionary:
    var families := {"tool": ["", ""], "combat_accessory": ["", "", ""],
        "travel_accessory": ["", "", ""], "thread_skill": ["", ""]}
    system._legacy_assign_family(families, "tool", tools, crest)
    system._legacy_assign_family(families, "thread_skill", skills, crest)
    for id_value in passives:
        if not id_value is String or not system.catalog.passives.has(id_value): continue
        var family := String(system.catalog.passives[id_value].get("family", ""))
        if not families.has(family): continue
        system._legacy_assign_family(families, family, [String(id_value)], crest)
    return families


static func legacy_assign_family(system: RefCounted, families: Dictionary, family: String, ids: Array, crest: String) -> void:
    var values: Array = families[family]
    for id_value in ids:
        var id := String(id_value)
        if id.is_empty() or values.has(id): continue
        var target := -1
        for slot in range(values.size()):
            if String(values[slot]).is_empty() and system._slot_unlocked(family, slot, crest) and system._slot_accepts(family, slot, id, crest):
                target = slot
                break
        if target < 0:
            for slot in range(values.size()):
                if String(values[slot]).is_empty() and system._slot_accepts(family, slot, id, crest):
                    target = slot
                    break
        if target >= 0: values[target] = id


static func migration_active_slot(system: RefCounted, family: String, requested: int, values: Array, crest: String) -> int:
    if requested >= 0 and requested < values.size() and system._slot_unlocked(family, requested, crest) \
            and not String(values[requested]).is_empty() and system._slot_accepts(family, requested, String(values[requested]), crest):
        return requested
    for slot in range(values.size()):
        if system._slot_unlocked(family, slot, crest) and not String(values[slot]).is_empty() \
                and system._slot_accepts(family, slot, String(values[slot]), crest):
            return slot
    return 0


static func loadout_from_legacy(system: RefCounted, old: Dictionary, version: int, crest_fallback: String) -> Dictionary:
    var crest := String(old.get("crest", crest_fallback))
    var skills: Array = old.get("skills", [old.get("skill", ""), ""])
    var tools: Array = old.get("tools", [old.get("tool", ""), ""])
    var passives: Array = old.get("passives", [])
    if version == 1:
        skills = [old.get("skill", ""), ""]
        tools = [old.get("tool", ""), ""]
    var families: Dictionary = system._legacy_family_arrays(crest, skills, tools, passives)
    var active_skill := int(old.get("active_skill_slot", 0))
    var active_tool := int(old.get("active_tool_slot", 0))
    if active_skill < 0 or active_skill > 1: active_skill = 0
    if active_tool < 0 or active_tool > 1: active_tool = 0
    var skill_id := String(skills[active_skill]) if active_skill < skills.size() else ""
    var tool_id := String(tools[active_tool]) if active_tool < tools.size() else ""
    active_skill = system._migration_active_slot("thread_skill", active_skill, families.thread_skill, crest)
    active_tool = system._migration_active_slot("tool", active_tool, families.tool, crest)
    var migrated_passives: Array = system._active_accessories(families, crest)
    return {"crest": crest, "skills": families.thread_skill.duplicate(), "tools": families.tool.duplicate(),
        "passives": migrated_passives, "active_skill_slot": active_skill, "active_tool_slot": active_tool,
        "equipped_families": families}


static func restore(system: RefCounted, snapshot: Dictionary) -> Dictionary:
    # Strict transactional migration. Parse into an isolated candidate and commit
    # only after all IDs, slot layouts, stock and cooldowns pass validation.
    var version: Variant = snapshot.get("version")
    if not system._counter(version, 3) or int(version) not in [1, 2, 3]: return system._fail("不支持的构筑存档版本")
    var allowed := ["version", "crest", "skill", "tool", "passives", "unlocked_crests", "unlocked_skills", "unlocked_passives", "tool_counts", "skill_levels", "loadouts", "cooldowns"]
    if int(version) >= 2: allowed.append_array(["skills", "tools", "active_skill_slot", "active_tool_slot", "unlocked_tools", "mechanisms"])
    if int(version) >= 3: allowed.append("equipped_families")
    allowed.append_array(["crafted", "part_rules"])
    for field in snapshot:
        if not allowed.has(field): return system._fail("未知构筑存档字段")
    var candidate = system.get_script().new() as RefCounted
    var migrated: Dictionary = snapshot.duplicate(true)
    for field in ["unlocked_crests", "unlocked_skills", "unlocked_passives", "passives"]:
        if not migrated.get(field) is Array: return system._fail("构筑列表数据损坏")
    for field in ["tool_counts", "skill_levels", "loadouts"]:
        if not migrated.get(field) is Dictionary: return system._fail("构筑计数数据损坏")
    if migrated.has("crafted"):
        if not migrated.crafted is Array: return system._fail("工匠制作记录损坏")
        var made := {}
        for id in migrated.crafted:
            if not id is String or made.has(id) or not String(system.catalog.recipes.get(id, {}).get("kind", "")) in ["tool_capacity", "slot_part"]:
                return system._fail("未知或重复的工匠制作记录")
            made[id] = true
        for id in migrated.crafted:
            for prerequisite in system.catalog.recipes[id].get("requires_crafted", []):
                if not made.has(prerequisite):return system._fail("二阶改制缺少前阶记录")
    else:
        # E04 legacy: the third travel slot used to open with the crest's mechanism
        # alone. Saves from before the clasp keep that slot: any repaired mechanism
        # grants the clasp, and the slot still needs that crest's own mechanism.
        migrated["crafted"] = []
        var legacy_mechanisms: Variant = migrated.get("mechanisms", [])
        var clasp: String = system.part_recipe("travel_clasp")
        if legacy_mechanisms is Array and not legacy_mechanisms.is_empty() and not clasp.is_empty():
            migrated.crafted.append(clasp)
    # Saves from before part rules 2 opened the third combat-accessory slot and
    # the second thread-skill slot with a repaired mechanism alone; they keep
    # them (both new parts granted). Saves made under the new rules never do.
    var rules: Variant = migrated.get("part_rules", 1)
    if not system._counter(rules, system.PART_RULES) or int(rules) < 1: return system._fail("工匠零件规则版本损坏")
    if int(rules) < system.PART_RULES:
        var mechanisms: Variant = migrated.get("mechanisms", [])
        if mechanisms is Array and not mechanisms.is_empty():
            for part in ["combat_clasp", "skill_spindle"]:
                var recipe: String = system.part_recipe(part)
                if not recipe.is_empty() and not migrated.crafted.has(recipe):
                    migrated.crafted.append(recipe)
    migrated["part_rules"] = system.PART_RULES
    if int(version) == 1:
        if not migrated.get("skill") is String or not migrated.get("tool") is String: return system._fail("旧构筑引用无效")
        for id in ["shard", "mine"]:
            if not migrated.tool_counts.has(id): return system._fail("旧战具计数缺失")
        for id in ["cleave", "needle", "snare", "ward"]:
            if not migrated.skill_levels.has(id): return system._fail("旧技能等级缺失")
        migrated["skills"] = [migrated.skill, ""]
        migrated["tools"] = [migrated.tool, ""]
        migrated["active_skill_slot"] = 0
        migrated["active_tool_slot"] = 0
        migrated["unlocked_tools"] = ["shard", "mine"]
        migrated["mechanisms"] = []
        for id in system.catalog.tools:
            if not migrated.tool_counts.has(id): migrated.tool_counts[id] = 0
        for id in system.catalog.skills:
            if not migrated.skill_levels.has(id): migrated.skill_levels[id] = 0
        # A migration clamps legacy overstock down to modern capacity; it never adds charges.
        for id in migrated.tool_counts:
            if not system.catalog.tools.has(id) or not system._counter(migrated.tool_counts[id], 6): return system._fail("旧战具携带量无效")
            migrated.tool_counts[id] = mini(int(migrated.tool_counts[id]), int(system.catalog.tools[id].capacity))
    else:
        if not migrated.get("skills") is Array or not migrated.get("tools") is Array or not migrated.get("unlocked_tools") is Array or not migrated.get("mechanisms") is Array:
            return system._fail("构筑列表数据损坏")
        if migrated.skills.size() != 2 or migrated.tools.size() != 2 or not system._counter(migrated.get("active_skill_slot"), 1) or not system._counter(migrated.get("active_tool_slot"), 1):
            return system._fail("旧构筑槽位数据无效")
        if int(version) == 2 and migrated.has("equipped_families"):
            return system._fail("版本二构筑字段无效")
    if not system.catalog.crests.has(migrated.get("crest", "")): return system._fail("未知契印")
    if not migrated.get("unlocked_tools") is Array: return system._fail("构筑列表数据损坏")
    candidate.state = migrated.duplicate(true)
    if int(version) < 3:
        if not candidate._validate_slots(migrated.skills, "skills") or not candidate._validate_slots(migrated.tools, "tools"):
            return system._fail("旧构筑引用无效")
        var old_passive_reason: String = candidate._validate_passives(migrated.passives, String(migrated.crest))
        if not old_passive_reason.is_empty(): return system._fail(old_passive_reason)
        migrated["equipped_families"] = candidate._legacy_family_arrays(String(migrated.crest), migrated.skills, migrated.tools, migrated.passives)
        migrated["active_skill_slot"] = candidate._migration_active_slot("thread_skill", int(migrated.active_skill_slot), migrated.equipped_families.thread_skill, String(migrated.crest))
        migrated["active_tool_slot"] = candidate._migration_active_slot("tool", int(migrated.active_tool_slot), migrated.equipped_families.tool, String(migrated.crest))
        migrated["version"] = 3
        for name in migrated.loadouts:
            var old: Variant = migrated.loadouts[name]
            if not old is Dictionary: return system._fail("旧构筑方案无效")
            var expected_old_size := 4 if int(version) == 1 else 6
            if old.size() != expected_old_size: return system._fail("旧构筑方案无效")
            if int(version) == 1 and (not old.get("skill") is String or not old.get("tool") is String or not old.get("passives") is Array):
                return system._fail("旧构筑方案无效")
            if int(version) == 2 and (not old.get("skills") is Array or not old.get("tools") is Array or not old.get("passives") is Array or old.skills.size() != 2 or old.tools.size() != 2):
                return system._fail("旧构筑方案无效")
            migrated.loadouts[name] = candidate._loadout_from_legacy(old, int(version), String(migrated.crest))
    candidate.state = migrated.duplicate(true)
    var tables := {"unlocked_crests": "crests", "unlocked_skills": "skills", "unlocked_tools": "tools", "unlocked_passives": "passives", "mechanisms": "crests"}
    for field in tables:
        if not migrated.get(field) is Array: return system._fail("构筑列表数据损坏")
        var seen := {}
        for id in migrated[field]:
            if not id is String or not system.catalog[tables[field]].has(id) or seen.has(id): return system._fail("未知或重复构筑条目")
            seen[id] = true
    if not candidate.state.get("equipped_families") is Dictionary:
        return system._fail("构筑家族槽位数据损坏")
    migrated["version"] = 3
    if int(version) == 3:
        var expected_passives: Array = candidate._active_accessories(migrated.equipped_families, String(migrated.crest))
        if migrated.get("skills") != migrated.equipped_families.get("thread_skill") or migrated.get("tools") != migrated.equipped_families.get("tool") or migrated.get("passives") != expected_passives:
            return system._fail("构筑家族装备别名不一致")
        if not migrated.get("skills") is Array or not migrated.get("tools") is Array or migrated.get("skill") != migrated.skills[int(migrated.get("active_skill_slot", 0))] or migrated.get("tool") != migrated.tools[int(migrated.get("active_tool_slot", 0))]:
            return system._fail("活动槽位与引用不一致")
    else:
        migrated["skills"] = migrated.equipped_families.get("thread_skill", [])
        migrated["tools"] = migrated.equipped_families.get("tool", [])
        migrated["passives"] = candidate._active_accessories(migrated.equipped_families, String(migrated.crest))
        migrated["skill"] = migrated.skills[int(migrated.get("active_skill_slot", 0))]
        migrated["tool"] = migrated.tools[int(migrated.get("active_tool_slot", 0))]
    candidate.state = migrated.duplicate(true)
    var family_reason: String = candidate._validate_family_arrays(migrated.equipped_families, String(migrated.crest), false)
    if not family_reason.is_empty(): return system._fail(family_reason)
    var loadout_reason: String = candidate._validate_loadout({"crest": migrated.crest, "skills": migrated.skills, "tools": migrated.tools,
        "passives": migrated.passives, "active_skill_slot": migrated.active_skill_slot, "active_tool_slot": migrated.active_tool_slot,
        "equipped_families": migrated.equipped_families})
    if not loadout_reason.is_empty(): return system._fail(loadout_reason)
    if migrated.tool_counts.size() != system.catalog.tools.size() or migrated.skill_levels.size() != system.catalog.skills.size(): return system._fail("构筑计数条目数量无效")
    for id in system.catalog.tools:
        var stock_bonus: int = system.crafted_capacity(id, migrated.crafted) + (1 if id in ["shard", "mine"] and migrated.unlocked_passives.has("needlecase") else 0)
        if not system._counter(migrated.tool_counts.get(id), int(system.catalog.tools[id].capacity) + stock_bonus): return system._fail("战具携带量无效")
    for id in system.catalog.skills:
        if not system._counter(migrated.skill_levels.get(id), 2): return system._fail("技能强化等级无效")
    if migrated.loadouts.size() > 8: return system._fail("方案数量超限")
    for name in migrated.loadouts:
        var saved: Variant = migrated.loadouts[name]
        if not name is String or name.is_empty() or name.length() > 24 or not saved is Dictionary:
            return system._fail("构筑方案格式无效")
        var normalized: Dictionary = saved
        if not normalized.has("equipped_families"):
            normalized = candidate._loadout_from_legacy(normalized, 2, String(migrated.crest))
            migrated.loadouts[name] = normalized
        if normalized.size() != 7: return system._fail("构筑方案格式无效")
        var saved_reason: String = candidate._validate_loadout(normalized)
        if not saved_reason.is_empty(): return system._fail(saved_reason)
    var restored_cooldowns: Variant = migrated.get("cooldowns", {})
    if not restored_cooldowns is Dictionary: return system._fail("冷却数据无效")
    for id in restored_cooldowns:
        var value: Variant = restored_cooldowns[id]
        if not system.catalog.skills.has(id) or not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 60:
            return system._fail("冷却时间无效")
    candidate.state = migrated.duplicate(true)
    candidate.state.version = 3
    for id in system.catalog.tools: candidate.state.tool_counts[id] = int(candidate.state.tool_counts[id])
    for id in system.catalog.skills: candidate.state.skill_levels[id] = int(candidate.state.skill_levels[id])
    for name in candidate.state.loadouts:
        candidate.state.loadouts[name] = candidate.state.loadouts[name].duplicate(true)
        candidate.state.loadouts[name].active_skill_slot = int(candidate.state.loadouts[name].active_skill_slot)
        candidate.state.loadouts[name].active_tool_slot = int(candidate.state.loadouts[name].active_tool_slot)
    candidate.state.active_skill_slot = int(candidate.state.active_skill_slot)
    candidate.state.active_tool_slot = int(candidate.state.active_tool_slot)
    system.state = candidate.state.duplicate(true)
    system.cooldowns = restored_cooldowns.duplicate(true)
    system._normalize_active_slots()
    return system._ok()
