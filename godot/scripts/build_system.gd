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
    state = {"version": 1, "crest": "crimson", "skill": "cleave", "tool": "shard",
        "passives": [], "unlocked_crests": ["crimson"], "unlocked_skills": ["cleave"],
        "unlocked_passives": ["stride"], "tool_counts": {"shard": 3, "mine": 0},
        "skill_levels": {"cleave": 0, "needle": 0, "snare": 0, "ward": 0}, "loadouts": {}}
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

func sync_progress(inventory_counts: Dictionary, region_id: String = "") -> void:
    # Inventory remains authoritative for exploration abilities, never consumed.
    for id in catalog.skills:
        var required := String(catalog.skills[id].get("unlock_item", ""))
        if required.is_empty() or int(inventory_counts.get(required, 0)) > 0:
            _unlock("unlocked_skills", id)
    if int(inventory_counts.get("silk_wall_grip", 0)) > 0 or "ch02" in region_id or "rain" in region_id:
        _unlock("unlocked_crests", "bell")
    if int(inventory_counts.get("echo_hook", 0)) > 0 or "ch03" in region_id or "salt" in region_id:
        _unlock("unlocked_crests", "salt")
    # Older builds called the acoustic ability by two names.
    if int(inventory_counts.get("bell_resonance", inventory_counts.get("resonant_bell", 0))) > 0:
        _unlock("unlocked_skills", "ward")

func switch_crest(id: String, at_bell: bool = true) -> Dictionary:
    if not at_bell:
        return _fail("请在钟龛休整时切换纹章")
    if not state.unlocked_crests.has(id) or not catalog.crests.has(id):
        return _fail("纹章尚未发现")
    if id == state.crest:
        return _ok()
    state.crest = id
    # A lower slot capacity trims the last equipped item deterministically.
    while slots_used() > slots_total():
        state.passives.pop_back()
    return _ok()

func select_skill(id: String) -> Dictionary:
    if not state.unlocked_skills.has(id) or not catalog.skills.has(id):
        return _fail("探索获得对应能力后可学习此技能")
    state.skill = id
    return _ok()

func select_tool(id: String) -> Dictionary:
    if not catalog.tools.has(id):
        return _fail("未知工具")
    state.tool = id
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
        return "纹章槽位不足"
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
    # Accumulate modifiers from the immutable base once. No repeated multiplication.
    var modifiers := {}
    for id in state.passives:
        for key in catalog.passives[id].modifiers:
            modifiers[key] = float(modifiers.get(key, 0.0)) + float(catalog.passives[id].modifiers[key])
    for key in modifiers:
        if key == "max_hp" or key == "max_energy":
            result[key] = int(result.get(key, 0)) + int(modifiers[key])
        elif key == "heal_duration":
            result[key] = maxf(0.3, float(result[key]) * (1.0 + float(modifiers[key])))
        else:
            result[key] = clampf(float(result.get(key, 1.0)) + float(modifiers[key]), 0.5, 1.5)
    result.speed_multiplier = result.move_mult
    result.attack_bonus = int(round(2.0 * (float(result.attack_damage_mult) - 1.0)))
    result.energy_per_hit = int(round(24.0 * float(result.energy_gain_mult)))
    result.heal_energy_cost = int(result.heal_cost)
    result.guard_refund = 20 if state.crest == "bell" else (16 if state.crest == "salt" else 18)
    return result

func stats() -> Dictionary:
    return profile()

func selected_skill() -> Dictionary:
    var id := String(state.skill)
    var skill: Dictionary = catalog.skills[id].duplicate(true)
    var level := int(state.skill_levels.get(id, 0))
    skill.id = id
    skill.skill_id = id
    skill.level = level
    skill.energy_cost = maxi(1, int(ceil(float(skill.energy_cost) * float(profile().skill_cost_mult))))
    skill.damage = int(skill.damage) + (level if id != "ward" else 0)
    skill.warmup = skill.windup
    skill.pierce = 1 + (level if id == "needle" else 0)
    if id == "cleave":
        skill.range = float(skill.range) + 40.0 * level
    elif id == "needle":
        skill.range = float(skill.range) + 80.0 * level
    elif id == "snare":
        skill.range = float(skill.range) + 20.0 * level
        skill.duration = float(skill.duration) + 0.5 * level
    elif id == "ward":
        skill.duration = float(skill.duration) + 0.35 * level
    skill.cooldown_remaining = float(cooldowns.get(id, 0.0))
    return skill

func try_cast(energy: int) -> Dictionary:
    var skill := selected_skill()
    if float(cooldowns.get(state.skill, 0.0)) > 0.0:
        return _fail("技能尚在冷却")
    if energy < int(skill.energy_cost):
        return _fail("能量不足")
    cooldowns[state.skill] = float(skill.cooldown)
    return _ok(skill)

func tick(delta: float) -> void:
    for id in cooldowns:
        cooldowns[id] = maxf(0.0, float(cooldowns[id]) - maxf(0.0, delta))

func use_tool() -> Dictionary:
    var id := String(state.tool)
    if int(state.tool_counts.get(id, 0)) <= 0:
        return _fail("工具已用尽，请向工匠购买补给")
    state.tool_counts[id] = int(state.tool_counts[id]) - 1
    var tool: Dictionary = catalog.tools[id].duplicate(true)
    tool.id = id
    return _ok(tool)

func refund_tool(id: String) -> void:
    # Main uses this only when a consumed tool cannot begin its runtime action.
    if catalog.tools.has(id):
        state.tool_counts[id] = mini(int(catalog.tools[id].capacity), int(state.tool_counts.get(id, 0)) + 1)

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
    state.loadouts[name] = {"crest": state.crest, "skill": state.skill, "tool": state.tool, "passives": state.passives.duplicate()}
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
    for key in ["crest", "skill", "tool", "passives"]:
        state[key] = build[key].duplicate() if build[key] is Array else build[key]
    return _ok()

func _validate_loadout(build: Dictionary) -> String:
    for key in ["crest", "skill", "tool"]:
        if not build.get(key) is String:
            return "方案引用格式无效"
    if not state.unlocked_crests.has(build.get("crest")) or not state.unlocked_skills.has(build.get("skill")) or not catalog.tools.has(build.get("tool")):
        return "方案引用未获得的内容"
    if not build.get("passives") is Array:
        return "方案槽位数据无效"
    return _validate_passives(build.passives, build.crest)

func serialize() -> Dictionary:
    var snapshot := state.duplicate(true)
    snapshot["cooldowns"] = cooldowns.duplicate(true)
    return snapshot

func _counter(value: Variant, maximum: int = 1000000) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum and float(value) == floor(float(value))

func restore(snapshot: Dictionary) -> Dictionary:
    # Restore into a separate model so malformed JSON cannot partially replace a run.
    var candidate := get_script().new() as RefCounted
    var allowed_fields := ["version", "crest", "skill", "tool", "passives", "unlocked_crests", "unlocked_skills", "unlocked_passives", "tool_counts", "skill_levels", "loadouts", "cooldowns"]
    for field in snapshot:
        if not allowed_fields.has(field):
            return _fail("未知构筑存档字段")
    if not _counter(snapshot.get("version"), 1) or int(snapshot.get("version", 0)) != 1:
        return _fail("不支持的构筑存档版本")
    for field in ["unlocked_crests", "unlocked_skills", "unlocked_passives", "passives"]:
        if not snapshot.get(field) is Array:
            return _fail("构筑列表数据损坏")
    var tables := {"unlocked_crests": "crests", "unlocked_skills": "skills", "unlocked_passives": "passives"}
    for field in tables:
        var seen := {}
        for id in snapshot[field]:
            if not id is String or not catalog[tables[field]].has(id) or seen.has(id):
                return _fail("未知或重复的构筑条目")
            seen[id] = true
    for field in ["tool_counts", "skill_levels", "loadouts"]:
        if not snapshot.get(field) is Dictionary:
            return _fail("构筑计数数据损坏")
    if snapshot.tool_counts.size() != catalog.tools.size() or snapshot.skill_levels.size() != catalog.skills.size():
        return _fail("构筑计数条目数量无效")
    for id in catalog.tools:
        if not _counter(snapshot.tool_counts.get(id), int(catalog.tools[id].capacity)):
            return _fail("工具携带量无效")
    for id in catalog.skills:
        if not _counter(snapshot.skill_levels.get(id), 2):
            return _fail("技能强化等级无效")
    if snapshot.loadouts.size() > 8:
        return _fail("构筑方案数量超限")
    candidate.state = snapshot.duplicate(true)
    var reason: String = candidate._validate_loadout(candidate.state)
    if not reason.is_empty():
        return _fail(reason)
    for name in snapshot.loadouts:
        if not name is String or name.is_empty() or name.length() > 24 or not snapshot.loadouts[name] is Dictionary:
            return _fail("构筑方案格式无效")
        if snapshot.loadouts[name].size() != 4:
            return _fail("构筑方案字段数量无效")
        reason = candidate._validate_loadout(snapshot.loadouts[name])
        if not reason.is_empty():
            return _fail(reason)
    var restored_cooldowns: Variant = snapshot.get("cooldowns", {})
    if not restored_cooldowns is Dictionary:
        return _fail("冷却数据无效")
    for id in restored_cooldowns:
        var value: Variant = restored_cooldowns[id]
        if not catalog.skills.has(id) or not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 60.0:
            return _fail("冷却时间无效")
    candidate.state.erase("cooldowns")
    candidate.state.version = 1
    for id in catalog.tools:
        candidate.state.tool_counts[id] = int(candidate.state.tool_counts[id])
    for id in catalog.skills:
        candidate.state.skill_levels[id] = int(candidate.state.skill_levels[id])
    state = candidate.state.duplicate(true)
    cooldowns = restored_cooldowns.duplicate(true)
    return _ok()

func get_snapshot() -> Dictionary:
    var result := {"crest": state.crest, "skill": state.skill, "tool": state.tool,
        "passives": state.passives.duplicate(), "slots_used": slots_used(), "slots_total": slots_total(),
        "crests": [], "skills": [], "tools": [], "passive_options": [], "recipes": [],
        "loadouts": state.loadouts.keys(), "stats": profile()}
    for id in catalog.crests:
        var entry: Dictionary = catalog.crests[id].duplicate(true)
        entry.merge({"id": id, "unlocked": state.unlocked_crests.has(id), "selected": state.crest == id}, true)
        result.crests.append(entry)
    for id in catalog.skills:
        var entry: Dictionary = catalog.skills[id].duplicate(true)
        entry.merge({"id": id, "unlocked": state.unlocked_skills.has(id), "selected": state.skill == id,
            "level": int(state.skill_levels[id]), "cooldown_remaining": float(cooldowns.get(id, 0.0))}, true)
        entry.energy_cost = maxi(1, int(ceil(float(entry.energy_cost) * float(profile().skill_cost_mult))))
        result.skills.append(entry)
    for id in catalog.tools:
        var entry: Dictionary = catalog.tools[id].duplicate(true)
        entry.merge({"id": id, "unlocked": true, "selected": state.tool == id, "count": int(state.tool_counts[id])}, true)
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
