extends RefCounted
## Persistent, JSON-only loadout model. Main owns wallet and checkpoint proximity;
## Player owns action timing and calls tick exactly once per physics frame.
const CATALOG_PATH := "res://data/build_catalog.json"
var catalog: Dictionary = {}
var state: Dictionary = {}
var cooldowns: Dictionary = {}

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    if parsed is Dictionary:
        catalog = parsed
    reset()

func reset() -> void:
    state = {"version": 2, "crest": "crimson", "skill": "cleave", "tool": "shard",
        "skills": ["cleave", ""], "tools": ["shard", ""], "active_skill_slot": 0, "active_tool_slot": 0,
        "passives": [], "unlocked_crests": ["crimson"], "unlocked_skills": ["cleave"],
        "unlocked_tools": ["shard"], "unlocked_passives": ["stride"], "mechanisms": [],
        "tool_counts": {}, "skill_levels": {}, "loadouts": {}}
    for id in catalog.tools:
        state.tool_counts[id] = int(catalog.tools[id].capacity) if id == "shard" else 0
    for id in catalog.skills:
        state.skill_levels[id] = 0
    cooldowns.clear()

func _ok(extra: Dictionary = {}) -> Dictionary:
    var result := {"ok": true, "reason": ""}
    result.merge(extra, true)
    return result

func _fail(reason: String) -> Dictionary:
    return {"ok": false, "reason": reason}

func _unlock(field: String, id: String) -> void:
    if not state[field].has(id):
        state[field].append(id)

func sync_progress(inventory_counts: Dictionary, _region_id: String = "", story_flags: Dictionary = {}) -> void:
    # No region or permanent exploration ability grants equipment. Dialogue and relics do.
    var tables := {"crests": "unlocked_crests", "skills": "unlocked_skills", "tools": "unlocked_tools", "passives": "unlocked_passives"}
    for table in tables:
        for id in catalog[table]:
            var item: Dictionary = catalog[table][id]
            var flag := String(item.get("unlock_flag", ""))
            var relic := String(item.get("unlock_item", ""))
            if (not flag.is_empty() and story_flags.get(flag, false) == true) or (not relic.is_empty() and int(inventory_counts.get(relic, 0)) > 0):
                _unlock(tables[table], id)
    for id in catalog.crests:
        if story_flags.get(String(catalog.crests[id].mechanism_flag), false) == true:
            _unlock("mechanisms", id)

func unlock_event(event_id: String) -> Dictionary:
    if not catalog.events.has(event_id):
        return _fail("未知获得事件")
    var event: Dictionary = catalog.events[event_id]
    for table in ["crests", "skills", "tools", "passives"]:
        for id in event.get(table, []):
            _unlock("unlocked_" + table, id)
    if event.has("mechanism"):
        _unlock("mechanisms", String(event.mechanism))
    return _ok()

func switch_crest(id: String, at_bell: bool = true) -> Dictionary:
    if not at_bell:
        return _fail("请在钟龛休整时切换契印")
    if not state.unlocked_crests.has(id) or not catalog.crests.has(id):
        return _fail("契印尚未发现")
    if id == state.crest:
        return _ok()
    state.crest = id
    # A lower slot capacity trims the last equipped item deterministically.
    while slots_used() > slots_total():
        state.passives.pop_back()
    return _ok()

func _slot(slot: int, field: String) -> int:
    return int(state["active_" + field + "_slot"]) if slot == -1 else slot

func _sync_aliases() -> void:
    state.skill = state.skills[int(state.active_skill_slot)]
    state.tool = state.tools[int(state.active_tool_slot)]

func select_skill(id: String, slot: int = -1) -> Dictionary:
    slot = _slot(slot, "skill")
    if slot < 0 or slot > 1:
        return _fail("技能槽位无效")
    if not id.is_empty() and (not state.unlocked_skills.has(id) or not catalog.skills.has(id)):
        return _fail("先通过人物传授或遗物发现学习技能")
    if not id.is_empty() and state.skills[1 - slot] == id:
        return _fail("同一技能不能占据两个槽位")
    state.skills[slot] = id
    state.active_skill_slot = slot
    _sync_aliases()
    return _ok()

func select_tool(id: String, slot: int = -1) -> Dictionary:
    slot = _slot(slot, "tool")
    if slot < 0 or slot > 1:
        return _fail("战具槽位无效")
    if not id.is_empty() and (not catalog.tools.has(id) or not state.unlocked_tools.has(id)):
        return _fail("战具尚未获得")
    if not id.is_empty() and state.tools[1 - slot] == id:
        return _fail("同一战具不能占据两个槽位")
    state.tools[slot] = id
    state.active_tool_slot = slot
    _sync_aliases()
    return _ok()

func cycle_skill() -> Dictionary:
    if not String(state.skills[1 - int(state.active_skill_slot)]).is_empty():
        state.active_skill_slot = 1 - int(state.active_skill_slot)
    _sync_aliases()
    return _ok()

func cycle_tool() -> Dictionary:
    if not String(state.tools[1 - int(state.active_tool_slot)]).is_empty():
        state.active_tool_slot = 1 - int(state.active_tool_slot)
    _sync_aliases()
    return _ok()

func slots_total() -> int:
    return int(catalog.crests.get(state.crest, {}).get("slots", 0))

func slots_used() -> int:
    var total := 0
    for id in state.passives:
        total += int(catalog.passives[id].cost)
    return total

func _validate_passives(ids: Array, crest: String) -> String:
    var used := 0
    var seen := {}
    var groups := {}
    for id in ids:
        if not id is String or not catalog.passives.has(id) or not state.unlocked_passives.has(id):
            return "被动装备尚未获得"
        if seen.has(id):
            return "同一被动不能重复装备"
        seen[id] = true
        var item: Dictionary = catalog.passives[id]
        used += int(item.cost)
        var group := String(item.group)
        if not group.is_empty():
            if groups.has(group):
                return "回能线轴与尖针契约互斥"
            groups[group] = true
    if used > int(catalog.crests[crest].slots):
        return "契印槽位不足"
    return ""

func equip_passives(ids: Array) -> Dictionary:
    var reason := _validate_passives(ids, state.crest)
    if not reason.is_empty():
        return _fail(reason)
    state.passives = ids.duplicate()
    return _ok()

func equip_passive(id: String, toggle: bool = true) -> Dictionary:
    var ids: Array = state.passives.duplicate()
    if ids.has(id) and toggle:
        ids.erase(id)
    elif not ids.has(id):
        ids.append(id)
    return equip_passives(ids)

func profile() -> Dictionary:
    var result: Dictionary = catalog.crests[state.crest].duplicate(true)
    var modifiers := {}
    for id in state.passives:
        for key in catalog.passives[id].modifiers:
            modifiers[key] = float(modifiers.get(key, 0.0)) + float(catalog.passives[id].modifiers[key])
    for key in modifiers:
        if key == "tool_capacity_bonus":
            result[key] = int(result.get(key, 0)) + int(modifiers[key])
        elif key == "heal_duration":
            result[key] = maxf(0.3, float(result[key]) * (1.0 + float(modifiers[key])))
        else:
            result[key] = clampf(float(result.get(key, 1.0)) + float(modifiers[key]), 0.5, 1.5)
    result.crest_id = state.crest
    result.mechanism_unlocked = state.mechanisms.has(state.crest)
    result.crimson_repaired = state.mechanisms.has("crimson")
    result.downstrike_bounce_mult = result.pogo_bounce_mult
    result.skill_range_mult = result.ranged_range_mult
    result.speed_multiplier = result.move_mult
    result.attack_bonus = int(round(2.0 * (float(result.attack_damage_mult) - 1.0)))
    result.energy_per_hit = int(round(24.0 * float(result.energy_gain_mult) * float(result.melee_energy_mult)))
    result.heal_energy_cost = int(result.heal_cost)
    result.status_resist_duration = 3.0 if state.passives.has("mender") else 0.0
    result.guard_refund = 0 # Perfect guards build pressure, never create free energy loops.
    return result

func stats() -> Dictionary:
    return profile()

func selected_skill(slot: int = -1) -> Dictionary:
    slot = _slot(slot, "skill")
    if slot < 0 or slot > 1:
        return {}
    var id := String(state.skills[slot])
    if not catalog.skills.has(id):
        return {}
    var skill: Dictionary = catalog.skills[id].duplicate(true)
    var level := int(state.skill_levels.get(id, 0))
    var derived := profile()
    skill.id = id
    skill.skill_id = id
    skill.level = level
    skill.crest_id = state.crest
    skill.mechanism_unlocked = derived.mechanism_unlocked
    skill.energy_cost = maxi(1, int(ceil(float(skill.energy_cost) * float(derived.skill_cost_mult))))
    skill.cost = skill.energy_cost
    skill.damage = maxi(0, int(round(float(int(skill.damage) + (level if id != "ward" else 0)) * float(derived.skill_damage_mult))))
    skill.warmup = skill.windup
    skill.prep = skill.windup
    skill.pierce = 1
    skill.range = float(skill.range) + (40.0 if id == "cleave" else 20.0) * level
    if id == "needle":
        skill.range = (float(catalog.skills[id].range) + 80.0 * level) * float(derived.ranged_range_mult)
    if id == "snare" or id == "ward":
        skill.duration = float(skill.duration) + 0.2 * level
    skill.cooldown_remaining = float(cooldowns.get(id, 0.0))
    return skill

func try_cast(energy: int, slot: int = -1) -> Dictionary:
    var skill := selected_skill(slot)
    if skill.is_empty():
        return _fail("此技能槽位为空")
    if float(cooldowns.get(skill.id, 0.0)) > 0.0:
        return _fail("技能尚在冷却")
    if energy < int(skill.energy_cost):
        return _fail("能量不足")
    cooldowns[skill.id] = float(skill.cooldown)
    return _ok(skill)

func tick(delta: float) -> void:
    for id in cooldowns:
        cooldowns[id] = maxf(0.0, float(cooldowns[id]) - maxf(0.0, delta))

func tool_capacity(id: String) -> int:
    if not catalog.tools.has(id):
        return 0
    return int(catalog.tools[id].capacity) + (int(profile().tool_capacity_bonus) if id in ["shard", "mine"] else 0)

func use_tool(slot: int = -1) -> Dictionary:
    slot = _slot(slot, "tool")
    if slot < 0 or slot > 1:
        return _fail("战具槽位无效")
    var id := String(state.tools[slot])
    if not catalog.tools.has(id) or not state.unlocked_tools.has(id):
        return _fail("此战具槽位为空")
    if int(state.tool_counts.get(id, 0)) <= 0:
        return _fail("战具已用尽，请在钟龛免费补给")
    state.tool_counts[id] = int(state.tool_counts[id]) - 1
    var tool: Dictionary = catalog.tools[id].duplicate(true)
    tool.id = id
    tool.capacity = tool_capacity(id)
    return _ok(tool)

func refund_tool(id: String) -> void:
    if catalog.tools.has(id):
        var stored_capacity := int(catalog.tools[id].capacity) + (1 if id in ["shard", "mine"] and state.unlocked_passives.has("needlecase") else 0)
        state.tool_counts[id] = mini(stored_capacity, int(state.tool_counts.get(id, 0)) + 1)

func refill_tools(at_bell: bool = false) -> Dictionary:
    if not at_bell:
        return _fail("请在钟龛补给战具")
    for id in state.unlocked_tools:
        state.tool_counts[id] = tool_capacity(id)
    return _ok()

func transact(recipe_id: String, wallet: Dictionary) -> Dictionary:
    # Validate every precondition before spending; failure never mutates either owner.
    if not catalog.recipes.has(recipe_id):
        return _fail("未知制作方案")
    if not wallet.get("inventory_counts") is Dictionary or not _counter(wallet.get("currency")):
        return _fail("无效钱包")
    var recipe: Dictionary = catalog.recipes[recipe_id]
    var target := String(recipe.target)
    var kind := String(recipe.kind)
    if kind == "skill":
        if not state.unlocked_skills.has(target):
            return _fail("先取得技能再强化")
        if int(state.skill_levels.get(target, 0)) >= 2:
            return _fail("技能已达到当前强化上限")
    if kind == "passive" and state.unlocked_passives.has(target):
        return _fail("此装备已经获得")
    if kind == "refill" and int(state.tool_counts[target]) >= int(catalog.tools[target].capacity):
        return _fail("携带量已满")
    var cost := int(recipe.currency)
    if kind == "skill":
        cost += int(state.skill_levels[target]) * 20
    if int(wallet.currency) < cost:
        return _fail("松脂碎片不足：需要%d" % cost)
    for material in recipe.materials:
        if not _counter(wallet.inventory_counts.get(material, 0)) or int(wallet.inventory_counts.get(material, 0)) < int(recipe.materials[material]):
            return _fail("材料不足：%s" % material)
    var next_wallet := wallet.duplicate(true)
    next_wallet.currency = int(next_wallet.currency) - cost
    for material in recipe.materials:
        next_wallet.inventory_counts[material] = int(next_wallet.inventory_counts[material]) - int(recipe.materials[material])
    if kind == "refill":
        state.tool_counts[target] = mini(int(catalog.tools[target].capacity), int(state.tool_counts[target]) + int(recipe.amount))
    elif kind == "passive":
        _unlock("unlocked_passives", target)
    elif kind == "skill":
        state.skill_levels[target] = int(state.skill_levels[target]) + 1
    return _ok({"wallet": next_wallet, "currency_spent": cost, "recipe_id": recipe_id})

func save_loadout(name: String) -> Dictionary:
    name = name.strip_edges().left(24)
    if name.is_empty():
        return _fail("方案名称不能为空")
    if state.loadouts.size() >= 8 and not state.loadouts.has(name):
        return _fail("最多保存8个构筑方案")
    state.loadouts[name] = {"crest": state.crest, "skills": state.skills.duplicate(), "tools": state.tools.duplicate(), "passives": state.passives.duplicate(), "active_skill_slot": state.active_skill_slot, "active_tool_slot": state.active_tool_slot}
    return _ok()

func restore_loadout(name: String, at_bell: bool = true) -> Dictionary:
    if not at_bell:
        return _fail("请在钟龛恢复构筑")
    if not state.loadouts.has(name):
        return _fail("方案不存在")
    var build: Dictionary = state.loadouts[name]
    var reason := _validate_loadout(build)
    if not reason.is_empty():
        return _fail(reason)
    for key in ["crest", "skills", "tools", "passives", "active_skill_slot", "active_tool_slot"]:
        state[key] = build[key].duplicate() if build[key] is Array else build[key]
    _sync_aliases()
    return _ok()

func _validate_slots(ids: Variant, table: String) -> bool:
    if not ids is Array or ids.size() != 2:
        return false
    var seen := {}
    for id in ids:
        if not id is String:
            return false
        if id.is_empty():
            continue
        if not catalog[table].has(id) or not state["unlocked_" + table].has(id) or seen.has(id):
            return false
        seen[id] = true
    return true

func _validate_loadout(build: Dictionary) -> String:
    if not build.get("crest") is String or not state.unlocked_crests.has(build.get("crest")):
        return "方案引用未获得的契印"
    if not _validate_slots(build.get("skills"), "skills") or not _validate_slots(build.get("tools"), "tools"):
        return "方案双槽数据无效或引用未获得内容"
    for key in ["active_skill_slot", "active_tool_slot"]:
        if not _counter(build.get(key), 1):
            return "活动槽位无效"
    if not build.get("passives") is Array:
        return "铭饰容量数据无效"
    return _validate_passives(build.passives, build.crest)

func serialize() -> Dictionary:
    var snapshot := state.duplicate(true)
    snapshot["cooldowns"] = cooldowns.duplicate(true)
    return snapshot

func _counter(value: Variant, maximum: int = 1000000) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum and float(value) == floor(float(value))

func restore(snapshot: Dictionary) -> Dictionary:
    # Strict transactional migration: unknown IDs/fields fail without replacing live state.
    var version: Variant = snapshot.get("version")
    if not _counter(version, 2) or int(version) not in [1, 2]:
        return _fail("不支持的构筑存档版本")
    var allowed := ["version", "crest", "skill", "tool", "passives", "unlocked_crests", "unlocked_skills", "unlocked_passives", "tool_counts", "skill_levels", "loadouts", "cooldowns"]
    if int(version) == 2:
        allowed.append_array(["skills", "tools", "active_skill_slot", "active_tool_slot", "unlocked_tools", "mechanisms"])
    for field in snapshot:
        if not allowed.has(field):
            return _fail("未知构筑存档字段")
    var candidate := get_script().new() as RefCounted
    var migrated := snapshot.duplicate(true)
    for field in ["unlocked_crests", "unlocked_skills", "unlocked_passives", "passives"]:
        if not migrated.get(field) is Array:
            return _fail("构筑列表数据损坏")
    for field in ["tool_counts", "skill_levels", "loadouts"]:
        if not migrated.get(field) is Dictionary:
            return _fail("构筑计数数据损坏")
    if int(version) == 1:
        if not migrated.get("skill") is String or not migrated.get("tool") is String:
            return _fail("旧构筑引用无效")
        for id in ["shard", "mine"]:
            if not migrated.tool_counts.has(id):
                return _fail("旧战具计数缺失")
        for id in ["cleave", "needle", "snare", "ward"]:
            if not migrated.skill_levels.has(id):
                return _fail("旧技能等级缺失")
        migrated["skills"] = [migrated.skill, ""]
        migrated["tools"] = [migrated.tool, ""]
        migrated["active_skill_slot"] = 0
        migrated["active_tool_slot"] = 0
        migrated["unlocked_tools"] = ["shard", "mine"]
        migrated["mechanisms"] = [] # Old possession does not invent completed story events.
        for id in catalog.tools:
            if not migrated.tool_counts.has(id):
                migrated.tool_counts[id] = 0
        for id in catalog.skills:
            if not migrated.skill_levels.has(id):
                migrated.skill_levels[id] = 0
        # Old tools could hold six shards / three mines. Clamp downward, never refill.
        for id in migrated.tool_counts:
            if not catalog.tools.has(id) or not _counter(migrated.tool_counts[id], 6):
                return _fail("旧战具携带量无效")
            migrated.tool_counts[id] = mini(int(migrated.tool_counts[id]), int(catalog.tools[id].capacity))
        for name in migrated.loadouts:
            var old: Variant = migrated.loadouts[name]
            if not old is Dictionary or old.size() != 4 or not old.get("skill") is String or not old.get("tool") is String:
                return _fail("旧构筑方案无效")
            migrated.loadouts[name] = {"crest": old.get("crest"), "skills": [old.skill, ""], "tools": [old.tool, ""], "passives": old.get("passives"), "active_skill_slot": 0, "active_tool_slot": 0}
    var tables := {"unlocked_crests": "crests", "unlocked_skills": "skills", "unlocked_tools": "tools", "unlocked_passives": "passives", "mechanisms": "crests"}
    for field in tables:
        if not migrated.get(field) is Array:
            return _fail("构筑列表数据损坏")
        var seen := {}
        for id in migrated[field]:
            if not id is String or not catalog[tables[field]].has(id) or seen.has(id):
                return _fail("未知或重复构筑条目")
            seen[id] = true
    candidate.state = migrated.duplicate(true)
    var reason: String = candidate._validate_loadout(migrated)
    if not reason.is_empty():
        return _fail(reason)
    if migrated.get("skill") != migrated.skills[int(migrated.active_skill_slot)] or migrated.get("tool") != migrated.tools[int(migrated.active_tool_slot)]:
        return _fail("活动槽位与引用不一致")
    if migrated.tool_counts.size() != catalog.tools.size() or migrated.skill_levels.size() != catalog.skills.size():
        return _fail("构筑计数条目数量无效")
    for id in catalog.tools:
        # Stock previously supplied with an owned needlecase survives unequipping.
        var stock_bonus := 1 if id in ["shard", "mine"] and migrated.unlocked_passives.has("needlecase") else 0
        if not _counter(migrated.tool_counts.get(id), int(catalog.tools[id].capacity) + stock_bonus):
            return _fail("战具携带量无效")
    for id in catalog.skills:
        if not _counter(migrated.skill_levels.get(id), 2):
            return _fail("技能强化等级无效")
    if migrated.loadouts.size() > 8:
        return _fail("方案数量超限")
    for name in migrated.loadouts:
        if not name is String or name.is_empty() or name.length() > 24 or not migrated.loadouts[name] is Dictionary or migrated.loadouts[name].size() != 6:
            return _fail("构筑方案格式无效")
        reason = candidate._validate_loadout(migrated.loadouts[name])
        if not reason.is_empty():
            return _fail(reason)
    var restored_cooldowns: Variant = migrated.get("cooldowns", {})
    if not restored_cooldowns is Dictionary:
        return _fail("冷却数据无效")
    for id in restored_cooldowns:
        var value: Variant = restored_cooldowns[id]
        if not catalog.skills.has(id) or not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 60:
            return _fail("冷却时间无效")
    candidate.state.erase("cooldowns")
    candidate.state.version = 2
    for key in ["active_skill_slot", "active_tool_slot"]:
        candidate.state[key] = int(candidate.state[key])
    for id in catalog.tools:
        candidate.state.tool_counts[id] = int(candidate.state.tool_counts[id])
    for id in catalog.skills:
        candidate.state.skill_levels[id] = int(candidate.state.skill_levels[id])
    for name in candidate.state.loadouts:
        candidate.state.loadouts[name].active_skill_slot = int(candidate.state.loadouts[name].active_skill_slot)
        candidate.state.loadouts[name].active_tool_slot = int(candidate.state.loadouts[name].active_tool_slot)
    state = candidate.state.duplicate(true)
    cooldowns = restored_cooldowns.duplicate(true)
    return _ok()

func get_snapshot() -> Dictionary:
    var result := {"crest": state.crest, "skill": state.skill, "tool": state.tool,
        "passives": state.passives.duplicate(), "slots_used": slots_used(), "slots_total": slots_total(),
        "crests": [], "skills": [], "tools": [], "passive_options": [], "recipes": [],
        "loadouts": state.loadouts.keys(), "stats": profile(), "skills_equipped": state.skills.duplicate(), "tools_equipped": state.tools.duplicate(), "active_skill_slot": state.active_skill_slot, "active_tool_slot": state.active_tool_slot}
    for id in catalog.crests:
        var entry: Dictionary = catalog.crests[id].duplicate(true)
        entry.merge({"id": id, "unlocked": state.unlocked_crests.has(id), "selected": state.crest == id, "mechanism_unlocked": state.mechanisms.has(id)}, true)
        result.crests.append(entry)
    for id in catalog.skills:
        var entry: Dictionary = catalog.skills[id].duplicate(true)
        entry.merge({"id": id, "unlocked": state.unlocked_skills.has(id), "selected": state.skill == id,
            "equipped_slots": _equipped_slots(state.skills, id), "level": int(state.skill_levels[id]), "cooldown_remaining": float(cooldowns.get(id, 0.0))}, true)
        entry.energy_cost = maxi(1, int(ceil(float(entry.energy_cost) * float(profile().skill_cost_mult))))
        result.skills.append(entry)
    for id in catalog.tools:
        var entry: Dictionary = catalog.tools[id].duplicate(true)
        entry.merge({"id": id, "unlocked": state.unlocked_tools.has(id), "selected": state.tool == id, "count": int(state.tool_counts[id]), "capacity": tool_capacity(id), "equipped_slots": _equipped_slots(state.tools, id)}, true)
        result.tools.append(entry)
    for id in catalog.passives:
        var entry: Dictionary = catalog.passives[id].duplicate(true)
        entry.merge({"id": id, "unlocked": state.unlocked_passives.has(id), "selected": state.passives.has(id)}, true)
        result.passive_options.append(entry)
    for id in catalog.recipes:
        var entry: Dictionary = catalog.recipes[id].duplicate(true)
        entry.id = id
        if entry.kind == "skill":
            entry.currency = int(entry.currency) + int(state.skill_levels[entry.target]) * 20
        result.recipes.append(entry)
    return result

func _equipped_slots(ids: Array, id: String) -> Array:
    var slots := []
    for index in range(ids.size()):
        if ids[index] == id:
            slots.append(index)
    return slots
