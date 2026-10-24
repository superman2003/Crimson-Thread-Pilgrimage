extends RefCounted
## Persistent, JSON-only loadout model. Main owns wallet and checkpoint proximity;
## Player owns action timing and calls tick exactly once per physics frame.
const CATALOG_PATH := "res://data/build_catalog.json"
const FAMILY_KEYS := ["tool", "combat_accessory", "travel_accessory", "thread_skill"]
const FAMILY_TABLES := {"tool": "tools", "combat_accessory": "passives", "travel_accessory": "passives", "thread_skill": "skills"}
const FAMILY_CAPACITIES := {"tool": 2, "combat_accessory": 3, "travel_accessory": 3, "thread_skill": 2}
const FAMILY_NAMES := {"tool": "战具", "combat_accessory": "战斗饰件", "travel_accessory": "行旅饰件", "thread_skill": "线技"}
var catalog: Dictionary = {}
var state: Dictionary = {}
var cooldowns: Dictionary = {}
## Derived from world inventory, never saved in a loadout or added repeatedly.
var permanent_stats: Dictionary = {}

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    if parsed is Dictionary:
        catalog = parsed
    reset()

func reset() -> void:
    permanent_stats.clear()
    state = {"version": 3, "crest": "crimson", "skill": "cleave", "tool": "shard",
        "skills": ["cleave", ""], "tools": ["shard", ""], "active_skill_slot": 0, "active_tool_slot": 0,
        "equipped_families": {"tool": ["shard", ""], "combat_accessory": ["", "", ""],
            "travel_accessory": ["", "", ""], "thread_skill": ["cleave", ""]},
        "passives": [], "unlocked_crests": ["crimson"], "unlocked_skills": ["cleave"],
        "unlocked_tools": ["shard"], "unlocked_passives": ["stride"], "mechanisms": [],
        # skill_levels: 0 = not trained; 1 / 2 = the chosen 校习 direction (branches a / b).
        # crafted: E04 artisan recipes already made (tool capacity, slot parts); each is made once.
        "tool_counts": {}, "skill_levels": {}, "loadouts": {}, "crafted": []}
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
    permanent_stats.clear()
    for item_id in catalog.get("permanent_upgrades", {}):
        var count: Variant = inventory_counts.get(item_id, 0)
        if not _counter(count, 1000000): continue
        var upgrade: Dictionary = catalog.permanent_upgrades[item_id]
        var stat := String(upgrade.stat)
        permanent_stats[stat] = int(permanent_stats.get(stat, 0)) + int(count) * int(upgrade.amount)
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
    # Keep items in locked expansion slots dormant. If the new crest has less
    # accessory capacity, remove the last active accessory deterministically.
    while not _validate_passives(_active_accessories(state.equipped_families, id), id).is_empty():
        var removed := false
        for family in ["travel_accessory", "combat_accessory"]:
            for slot in range(state.equipped_families[family].size() - 1, -1, -1):
                if _slot_unlocked(family, slot, id) and not String(state.equipped_families[family][slot]).is_empty():
                    state.equipped_families[family][slot] = ""
                    removed = true
                    break
            if removed: break
        if not removed: break
    _normalize_active_slots()
    return _ok()

func _slot(slot: int, field: String) -> int:
    return int(state["active_" + field + "_slot"]) if slot == -1 else slot

func _sync_aliases() -> void:
    state.tools = state.equipped_families.tool.duplicate()
    state.skills = state.equipped_families.thread_skill.duplicate()
    state.passives = _active_accessories(state.equipped_families, state.crest)
    state.skill = state.skills[int(state.active_skill_slot)]
    state.tool = state.tools[int(state.active_tool_slot)]

func _layout_specs(crest: String = "") -> Dictionary:
    if crest.is_empty(): crest = String(state.get("crest", "crimson"))
    return catalog.crests.get(crest, {}).get("slot_layout", {})

func _slot_spec(family: String, slot: int, crest: String = "") -> Dictionary:
    var specs: Dictionary = _layout_specs(crest)
    var family_slots: Array = specs.get(family, [])
    if slot < 0 or slot >= family_slots.size() or not family_slots[slot] is Dictionary: return {}
    return family_slots[slot]

func _slot_unlocked(family: String, slot: int, crest: String = "") -> bool:
    var spec := _slot_spec(family, slot, crest)
    if spec.is_empty(): return false
    var part := String(spec.get("requires_part", ""))
    if not part.is_empty() and not has_part(part): return false
    var requirement := String(spec.get("requires_mechanism", ""))
    return requirement.is_empty() or state.get("mechanisms", []).has(requirement)

## E04: a slot part (承力扣) made by an artisan; it opens the matching slot on every crest.
func has_part(part: String) -> bool:
    for id in state.get("crafted", []):
        if String(catalog.recipes.get(id, {}).get("part", "")) == part: return true
    return false

func part_recipe(part: String) -> String:
    for id in catalog.recipes:
        if String(catalog.recipes[id].get("part", "")) == part: return String(id)
    return ""

## E04: permanent capacity an artisan added to this tool.
func crafted_capacity(id: String, crafted: Variant = null) -> int:
    var bonus := 0
    for recipe_id in (crafted if crafted is Array else state.get("crafted", [])):
        var recipe: Dictionary = catalog.recipes.get(recipe_id, {})
        if String(recipe.get("kind", "")) == "tool_capacity" and String(recipe.get("target", "")) == id:
            bonus += int(recipe.get("amount", 0))
    return bonus

func _slot_accepts(family: String, slot: int, item_id: String, crest: String = "") -> bool:
    if item_id.is_empty(): return true
    return _slot_spec(family, slot, crest).get("compatible", []).has(item_id)

func _active_accessories(families: Dictionary, crest: String) -> Array:
    var active: Array = []
    for family in ["combat_accessory", "travel_accessory"]:
        var equipped: Array = families.get(family, [])
        for slot in range(equipped.size()):
            var id := String(equipped[slot])
            if id.is_empty() or not _slot_unlocked(family, slot, crest): continue
            if _slot_accepts(family, slot, id, crest) and not active.has(id): active.append(id)
    return active

func _normalize_active_slots() -> void:
    for pair in [["skill", "thread_skill"], ["tool", "tool"]]:
        var field := String(pair[0])
        var family := String(pair[1])
        var active_key := "active_%s_slot" % field
        var values: Array = state.equipped_families[family]
        var active := int(state.get(active_key, 0))
        if active >= values.size() or not _slot_unlocked(family, active) or not _slot_accepts(family, active, String(values[active])):
            active = 0
            for slot in range(values.size()):
                if _slot_unlocked(family, slot) and not String(values[slot]).is_empty() and _slot_accepts(family, slot, String(values[slot])):
                    active = slot
                    break
            state[active_key] = active
    _sync_aliases()

func _validate_family_arrays(families: Variant, crest: String, strict: bool = false) -> String:
    if not families is Dictionary: return "构筑家族槽位数据损坏"
    for family in FAMILY_KEYS:
        if not families.get(family) is Array or families[family].size() != int(FAMILY_CAPACITIES[family]):
            return "构筑家族槽位数据损坏"
        var seen := {}
        var table := String(FAMILY_TABLES[family])
        for slot in range(families[family].size()):
            var item: Variant = families[family][slot]
            if not item is String: return "构筑家族装备数据损坏"
            if item.is_empty(): continue
            if not catalog[table].has(item) or not state["unlocked_" + table].has(item) or seen.has(item):
                return "构筑家族装备尚未获得或重复"
            if table == "passives" and String(catalog[table][item].get("family", "")) != family:
                return "饰件与装备家族不匹配"
            if strict and _slot_unlocked(family, slot, crest) and not _slot_accepts(family, slot, item, crest):
                return "装备与当前契印槽位不兼容"
            seen[item] = true
    var active_passives: Array = _active_accessories(families, crest)
    if active_passives.size() != _active_accessory_count(families, crest): return "饰件槽位兼容数据无效"
    return _validate_passives(active_passives, crest)

func _active_accessory_count(families: Dictionary, crest: String) -> int:
    var count := 0
    for family in ["combat_accessory", "travel_accessory"]:
        var values: Array = families.get(family, [])
        for slot in range(values.size()):
            var id := String(values[slot])
            if not id.is_empty() and _slot_unlocked(family, slot, crest) and _slot_accepts(family, slot, id, crest): count += 1
    return count

func equip_family_slot(item_id: String, family: String, slot: int, at_bell: bool = true) -> Dictionary:
    if not at_bell: return _fail("请在钟龛调整构筑")
    if not FAMILY_KEYS.has(family) or slot < 0 or slot >= int(FAMILY_CAPACITIES.get(family, 0)):
        return _fail("家族槽位无效")
    if _slot_spec(family, slot).is_empty() or not _slot_unlocked(family, slot):
        return _fail("此槽位尚未解锁")
    var table := String(FAMILY_TABLES[family])
    if not item_id.is_empty():
        if not catalog[table].has(item_id) or not state["unlocked_" + table].has(item_id):
            return _fail("装备尚未获得")
        if not _slot_accepts(family, slot, item_id): return _fail("装备与此槽位不兼容")
    var next: Dictionary = state.equipped_families.duplicate(true)
    for index in range(next[family].size()):
        if index != slot and next[family][index] == item_id and not item_id.is_empty():
            return _fail("同一装备不能占据两个槽位")
    next[family][slot] = item_id
    var reason := _validate_family_arrays(next, String(state.crest))
    if not reason.is_empty(): return _fail(reason)
    state.equipped_families = next
    if family == "tool": state.active_tool_slot = slot
    elif family == "thread_skill": state.active_skill_slot = slot
    _normalize_active_slots()
    return _ok()

func select_skill(id: String, slot: int = -1, at_bell: bool = true) -> Dictionary:
    slot = _slot(slot, "skill")
    return equip_family_slot(id, "thread_skill", slot, at_bell)

func select_tool(id: String, slot: int = -1, at_bell: bool = true) -> Dictionary:
    slot = _slot(slot, "tool")
    return equip_family_slot(id, "tool", slot, at_bell)

func cycle_skill() -> Dictionary:
    state.active_skill_slot = _cycle_family_slot("thread_skill", int(state.active_skill_slot))
    _sync_aliases()
    return _ok()

func cycle_tool() -> Dictionary:
    state.active_tool_slot = _cycle_family_slot("tool", int(state.active_tool_slot))
    _sync_aliases()
    return _ok()

func _cycle_family_slot(family: String, active: int) -> int:
    var values: Array = state.equipped_families[family]
    for offset in range(1, values.size() + 1):
        var slot := posmod(active + offset, values.size())
        if _slot_unlocked(family, slot) and not String(values[slot]).is_empty() and _slot_accepts(family, slot, String(values[slot])):
            return slot
    return active

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
                return "铭饰「%s」与「%s」互斥" % [String(catalog.passives[groups[group]].name),String(item.name)]
            groups[group] = id
    if used > int(catalog.crests[crest].slots):
        return "契印槽位不足"
    return ""

func equip_passives(ids: Array) -> Dictionary:
    if not _validate_passives(ids, String(state.crest)).is_empty():
        return _fail(_validate_passives(ids, String(state.crest)))
    var next: Dictionary = state.equipped_families.duplicate(true)
    next.combat_accessory = ["", "", ""]
    next.travel_accessory = ["", "", ""]
    for id_value in ids:
        var id := String(id_value)
        var family := String(catalog.passives[id].family)
        var placed := false
        for slot in range(next[family].size()):
            if _slot_unlocked(family, slot) and _slot_accepts(family, slot, id):
                next[family][slot] = id
                placed = true
                break
        if not placed: return _fail("当前契印没有兼容的饰件槽位")
    var family_reason := _validate_family_arrays(next, String(state.crest))
    if not family_reason.is_empty(): return _fail(family_reason)
    state.equipped_families = next
    _sync_aliases()
    return _ok()

func equip_passive(id: String, toggle: bool = true, at_bell: bool = true) -> Dictionary:
    if not at_bell: return _fail("请在钟龛调整构筑")
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
    for stat in permanent_stats:
        result[stat] = int(result.get(stat, 0)) + int(permanent_stats[stat])
    return result

func stats() -> Dictionary:
    return profile()

func selected_skill(slot: int = -1) -> Dictionary:
    slot = _slot(slot, "skill")
    if slot < 0 or slot > 1 or not _slot_unlocked("thread_skill", slot):
        return {}
    var id := String(state.skills[slot])
    if not catalog.skills.has(id) or not _slot_accepts("thread_skill", slot, id):
        return {}
    var skill: Dictionary = catalog.skills[id].duplicate(true)
    var level := int(state.skill_levels.get(id, 0))
    var derived := profile()
    skill.id = id
    skill.skill_id = id
    skill.level = level
    skill.crest_id = state.crest
    skill.mechanism_unlocked = derived.mechanism_unlocked
    # C04: a 校习 direction changes how the skill plays, not just its numbers.
    var branch := skill_branch(id)
    skill.branch = branch
    skill.branch_name = String(skill.get("branches", {}).get(branch, {}).get("name", ""))
    var modifiers: Dictionary = skill.get("branches", {}).get(branch, {}).get("modifiers", {})
    for key in modifiers:
        skill[key] = float(skill.get(key, 0.0)) + float(modifiers[key])
    skill.energy_cost = maxi(1, int(ceil(float(skill.energy_cost) * float(derived.skill_cost_mult))))
    skill.cost = skill.energy_cost
    skill.damage = maxi(0, int(round(float(skill.damage) * float(derived.skill_damage_mult))))
    skill.warmup = skill.windup
    skill.prep = skill.windup
    skill.pierce = 1
    skill.range = float(skill.range)
    if id == "needle":
        skill.range *= float(derived.ranged_range_mult)
    skill.cooldown_remaining = float(cooldowns.get(id, 0.0))
    return skill

## "a" / "b" for the chosen 校习 direction, "" while untrained.
func skill_branch(id: String) -> String:
    return {1: "a", 2: "b"}.get(int(state.skill_levels.get(id, 0)), "")

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
    return int(catalog.tools[id].capacity) + crafted_capacity(id) + (int(profile().tool_capacity_bonus) if id in ["shard", "mine"] else 0)

func use_tool(slot: int = -1) -> Dictionary:
    slot = _slot(slot, "tool")
    if slot < 0 or slot > 1 or not _slot_unlocked("tool", slot):
        return _fail("战具槽位无效")
    var id := String(state.tools[slot])
    if not catalog.tools.has(id) or not state.unlocked_tools.has(id) or not _slot_accepts("tool", slot, id):
        return _fail("此战具槽位为空")
    if int(state.tool_counts.get(id, 0)) <= 0:
        return _fail("战具已用尽，请在钟龛补给")
    state.tool_counts[id] = int(state.tool_counts[id]) - 1
    var tool: Dictionary = catalog.tools[id].duplicate(true)
    tool.id = id
    tool.capacity = tool_capacity(id)
    return _ok(tool)

func refund_tool(id: String) -> void:
    if catalog.tools.has(id):
        state.tool_counts[id] = mini(_stored_capacity(id), int(state.tool_counts.get(id, 0)) + 1)

## Most charges a save may hold: equipment bonuses count while merely owned.
func _stored_capacity(id: String) -> int:
    return int(catalog.tools[id].capacity) + crafted_capacity(id) + (1 if id in ["shard", "mine"] and state.unlocked_passives.has("needlecase") else 0)

func refill_tools(at_bell: bool = false) -> Dictionary:
    if not at_bell:
        return _fail("请在钟龛补给战具")
    return _fail("战具补给需消耗碎钱与材料")

func quote_resupply(wallet: Dictionary) -> Dictionary:
    if not wallet.get("inventory_counts") is Dictionary or not _counter(wallet.get("currency")):
        return _resupply_result(false, "无效钱包", wallet, {}, {"currency": 0, "materials": {}})
    var next_wallet: Dictionary = wallet.duplicate(true)
    var charges := {}
    var total_cost := {"currency": 0, "materials": {}}
    var deficits := {}
    for id in catalog.tools:
        var remaining := maxi(0, tool_capacity(String(id)) - int(state.tool_counts.get(id, 0)))
        deficits[id] = remaining
    var unaffordable_reason := "材料或碎钱不足"
    for id_value in catalog.tools:
        var id := String(id_value)
        if not state.unlocked_tools.has(id) or int(deficits[id]) <= 0: continue
        var unit: Dictionary = catalog.tools[id].get("resupply", {})
        var unit_currency := int(unit.get("currency", -1))
        var unit_materials: Dictionary = unit.get("materials", {})
        if unit_currency <= 0 or unit_materials.is_empty():
            unaffordable_reason = "战具补给方案无效"
            continue
        var bought := 0
        while bought < int(deficits[id]):
            if int(next_wallet.currency) < unit_currency:
                unaffordable_reason = "碎钱不足：每份需要%d" % unit_currency
                break
            var can_pay := true
            for material in unit_materials:
                var amount: Variant = unit_materials[material]
                if not _counter(amount) or int(amount) <= 0 or not _counter(next_wallet.inventory_counts.get(material, 0)) or int(next_wallet.inventory_counts.get(material, 0)) < int(amount):
                    can_pay = false
                    unaffordable_reason = "材料不足：%s" % String(material)
                    break
            if not can_pay: break
            next_wallet.currency = int(next_wallet.currency) - unit_currency
            total_cost.currency = int(total_cost.currency) + unit_currency
            for material in unit_materials:
                var amount := int(unit_materials[material])
                next_wallet.inventory_counts[material] = int(next_wallet.inventory_counts.get(material, 0)) - amount
                total_cost.materials[material] = int(total_cost.materials.get(material, 0)) + amount
            bought += 1
        if bought > 0: charges[id] = bought
    if charges.is_empty():
        var any_deficit := false
        for amount in deficits.values():
            if int(amount) > 0: any_deficit = true
        var reason := "携带量已满" if not any_deficit else unaffordable_reason
        return _resupply_result(false, reason, wallet, {}, {"currency": 0, "materials": {}})
    return _resupply_result(true, "", wallet, charges, total_cost, next_wallet)

func resupply_tools(wallet: Dictionary, at_bell: bool) -> Dictionary:
    if not at_bell:
        return _resupply_result(false, "请在钟龛补给战具", wallet, {}, {"currency": 0, "materials": {}})
    var quote := quote_resupply(wallet)
    if not bool(quote.get("ok", false)): return quote
    # The quote's detached wallet is committed only after every charge and
    # material has been validated; no stock changes on an affordability error.
    for id in quote.charges:
        state.tool_counts[id] = int(state.tool_counts.get(id, 0)) + int(quote.charges[id])
    quote.wallet = quote.remaining_wallet.duplicate(true)
    return quote

func _resupply_result(ok: bool, reason: String, wallet: Dictionary, charges: Dictionary, cost: Dictionary, remaining_wallet: Variant = null) -> Dictionary:
    var remaining: Dictionary = wallet if not remaining_wallet is Dictionary else remaining_wallet
    var deficits := {}
    var after := {}
    for id in catalog.tools:
        var current := int(state.tool_counts.get(id, 0))
        var bought := int(charges.get(id, 0))
        deficits[id] = maxi(0, tool_capacity(String(id)) - current)
        after[id] = current + bought
    return {"ok": ok, "reason": reason, "wallet": wallet.duplicate(true),
        "remaining_wallet": remaining.duplicate(true), "charges": charges.duplicate(true),
        "deficits": deficits, "remaining": after, "cost": cost.duplicate(true)}

func transact(recipe_id: String, wallet: Dictionary) -> Dictionary:
    # Validate every precondition before spending; failure never mutates either owner.
    if not catalog.recipes.has(recipe_id):
        return _fail("未知制作方案")
    if not wallet.get("inventory_counts") is Dictionary or not _counter(wallet.get("currency")):
        return _fail("无效钱包")
    var recipe: Dictionary = catalog.recipes[recipe_id]
    var target := String(recipe.target)
    var kind := String(recipe.kind)
    if kind == "skill_branch":
        if not state.unlocked_skills.has(target):
            return _fail("先取得技能再校习")
        if int(state.skill_levels.get(target, 0)) == int(recipe.branch):
            return _fail("已是这个校习方向")
    if kind == "passive" and state.unlocked_passives.has(target):
        return _fail("此装备已经获得")
    if kind == "refill" and int(state.tool_counts[target]) >= int(catalog.tools[target].capacity):
        return _fail("携带量已满")
    if kind in ["tool_capacity", "slot_part", "passive"]:
        if not state.get("crafted") is Array: state.crafted = []
        if state.crafted.has(recipe_id):
            return _fail("已经制作过「%s」" % String(recipe.get("name", recipe_id)))
        if kind == "tool_capacity" and not state.unlocked_tools.has(target):
            return _fail("先取得这件战具，工匠才能改制")
        # Patterns (challenge evidence) are shown to the artisan, never consumed.
        for item in recipe.get("requires_items", []):
            if not _counter(wallet.inventory_counts.get(item, 0)) or int(wallet.inventory_counts.get(item, 0)) <= 0:
                return _fail("缺少图样：%s" % String(item))
    var cost := int(recipe.currency)
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
    elif kind == "skill_branch":
        # Choosing the other direction later replaces this one at full price.
        state.skill_levels[target] = int(recipe.branch)
    elif kind == "tool_capacity":
        # A larger pouch holds more; it is filled at the shrine like any other charge.
        state.crafted.append(recipe_id)
    elif kind == "slot_part":
        state.crafted.append(recipe_id)
        _settle_unlocked_slots()
    return _ok({"wallet": next_wallet, "currency_spent": cost, "recipe_id": recipe_id})

## A new part may wake an item that a legacy migration parked in a locked slot.
## Keep the live build and every saved loadout valid: drop woken accessories
## that would overflow the crest's capacity, then refresh the aliases.
func _settle_unlocked_slots() -> void:
    _settle_families(state.equipped_families, String(state.crest))
    _sync_aliases()
    for name in state.loadouts:
        var saved: Dictionary = state.loadouts[name]
        _settle_families(saved.equipped_families, String(saved.crest))
        saved.passives = _active_accessories(saved.equipped_families, String(saved.crest))

func _settle_families(families: Dictionary, crest: String) -> void:
    while not _validate_passives(_active_accessories(families, crest), crest).is_empty():
        var removed := false
        for family in ["travel_accessory", "combat_accessory"]:
            for slot in range(families[family].size() - 1, -1, -1):
                if _slot_unlocked(family, slot, crest) and not String(families[family][slot]).is_empty():
                    families[family][slot] = ""
                    removed = true
                    break
            if removed: break
        if not removed: break

func save_loadout(name: String, at_bell: bool = true) -> Dictionary:
    if not at_bell: return _fail("请在钟龛保存构筑方案")
    name = name.strip_edges().left(24)
    if name.is_empty(): return _fail("方案名称不能为空")
    if state.loadouts.size() >= 8 and not state.loadouts.has(name): return _fail("最多保存8个构筑方案")
    state.loadouts[name] = {"crest": state.crest, "skills": state.skills.duplicate(), "tools": state.tools.duplicate(),
        "passives": state.passives.duplicate(), "active_skill_slot": state.active_skill_slot,
        "active_tool_slot": state.active_tool_slot, "equipped_families": state.equipped_families.duplicate(true)}
    return _ok()

## Read-only quote using the same validator and profile as an actual restore.
func preview_loadout(name: String, at_bell: bool = true) -> Dictionary:
    if not state.loadouts.has(name): return _fail("方案尚未保存")
    var saved: Variant = state.loadouts[name]
    if not saved is Dictionary: return _fail("方案数据损坏")
    var reason := _validate_loadout(saved)
    if not reason.is_empty(): return _fail(reason)
    var candidate = get_script().new()
    candidate.state = state.duplicate(true)
    candidate.cooldowns = cooldowns.duplicate(true)
    candidate.permanent_stats = permanent_stats.duplicate()
    var result: Dictionary = candidate.restore_loadout(name, true)
    if not bool(result.get("ok", false)): return result
    return _ok({"can_restore": at_bell, "reason": "" if at_bell else "请在钟龛恢复构筑",
        "profile": candidate.profile(), "equipped_families": candidate.state.equipped_families.duplicate(true),
        "currency_cost": 0, "refills_resources": false})

func restore_loadout(name: String, at_bell: bool = true) -> Dictionary:
    if not at_bell: return _fail("请在钟龛恢复构筑")
    if not state.loadouts.has(name): return _fail("方案不存在")
    var build: Dictionary = state.loadouts[name]
    var reason := _validate_loadout(build)
    if not reason.is_empty(): return _fail(reason)
    state.crest = String(build.crest)
    state.equipped_families = build.equipped_families.duplicate(true)
    state.active_skill_slot = int(build.active_skill_slot)
    state.active_tool_slot = int(build.active_tool_slot)
    _sync_aliases()
    return _ok()

func _validate_slots(ids: Variant, table: String) -> bool:
    if not ids is Array or ids.size() != 2: return false
    var seen := {}
    for id in ids:
        if not id is String: return false
        if id.is_empty(): continue
        if not catalog[table].has(id) or not state["unlocked_" + table].has(id) or seen.has(id): return false
        seen[id] = true
    return true

func _validate_loadout(build: Dictionary) -> String:
    if not build.get("crest") is String or not state.unlocked_crests.has(build.get("crest")):
        return "方案引用未获得的契印"
    if not build.get("equipped_families") is Dictionary:
        return "方案家族槽位数据无效"
    var families: Dictionary = build.equipped_families
    # Unselected slots may retain a dormant item across crest layouts. The
    # active slots below must always be compatible with the saved crest.
    var reason := _validate_family_arrays(families, String(build.crest), false)
    if not reason.is_empty(): return reason
    for key in ["active_skill_slot", "active_tool_slot"]:
        if not _counter(build.get(key), 1): return "活动槽位无效"
    var skills: Array = families.thread_skill
    var tools: Array = families.tool
    var active_skill := int(build.active_skill_slot)
    var active_tool := int(build.active_tool_slot)
    if not _active_slot_valid("thread_skill", active_skill, skills, String(build.crest)):
        return "活动线技槽位无效"
    if not _active_slot_valid("tool", active_tool, tools, String(build.crest)):
        return "活动战具槽位无效"
    var expected_passives: Array = _active_accessories(families, String(build.crest))
    if build.get("skills") != skills or build.get("tools") != tools or build.get("passives") != expected_passives:
        return "方案兼容装备别名不一致"
    return ""

## Mirrors _normalize_active_slots(): when a crest switch leaves no usable item in
## a family (e.g. only a dormant copper pot under 司铸), the active slot falls back
## to 0. That state is what the game saves, so it must also load.
func _active_slot_valid(family: String, active: int, values: Array, crest: String) -> bool:
    if _slot_unlocked(family, active, crest) and _slot_accepts(family, active, String(values[active]), crest):
        return true
    if active != 0:
        return false
    for slot in range(values.size()):
        if _slot_unlocked(family, slot, crest) and not String(values[slot]).is_empty() and _slot_accepts(family, slot, String(values[slot]), crest):
            return false
    return true

func serialize() -> Dictionary:
    var snapshot := state.duplicate(true)
    snapshot["cooldowns"] = cooldowns.duplicate(true)
    return snapshot

func _counter(value: Variant, maximum: int = 1000000) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum and float(value) == floor(float(value))

func _legacy_family_arrays(crest: String, skills: Array, tools: Array, passives: Array) -> Dictionary:
    var families := {"tool": ["", ""], "combat_accessory": ["", "", ""],
        "travel_accessory": ["", "", ""], "thread_skill": ["", ""]}
    _legacy_assign_family(families, "tool", tools, crest)
    _legacy_assign_family(families, "thread_skill", skills, crest)
    for id_value in passives:
        if not id_value is String or not catalog.passives.has(id_value): continue
        var family := String(catalog.passives[id_value].get("family", ""))
        if not families.has(family): continue
        _legacy_assign_family(families, family, [String(id_value)], crest)
    return families

func _legacy_assign_family(families: Dictionary, family: String, ids: Array, crest: String) -> void:
    var values: Array = families[family]
    for id_value in ids:
        var id := String(id_value)
        if id.is_empty() or values.has(id): continue
        var target := -1
        for slot in range(values.size()):
            if String(values[slot]).is_empty() and _slot_unlocked(family, slot, crest) and _slot_accepts(family, slot, id, crest):
                target = slot
                break
        if target < 0:
            for slot in range(values.size()):
                if String(values[slot]).is_empty() and _slot_accepts(family, slot, id, crest):
                    target = slot
                    break
        if target >= 0: values[target] = id

func _migration_active_slot(family: String, requested: int, values: Array, crest: String) -> int:
    if requested >= 0 and requested < values.size() and _slot_unlocked(family, requested, crest) \
            and not String(values[requested]).is_empty() and _slot_accepts(family, requested, String(values[requested]), crest):
        return requested
    for slot in range(values.size()):
        if _slot_unlocked(family, slot, crest) and not String(values[slot]).is_empty() \
                and _slot_accepts(family, slot, String(values[slot]), crest):
            return slot
    return 0

func _loadout_from_legacy(old: Dictionary, version: int, crest_fallback: String) -> Dictionary:
    var crest := String(old.get("crest", crest_fallback))
    var skills: Array = old.get("skills", [old.get("skill", ""), ""])
    var tools: Array = old.get("tools", [old.get("tool", ""), ""])
    var passives: Array = old.get("passives", [])
    if version == 1:
        skills = [old.get("skill", ""), ""]
        tools = [old.get("tool", ""), ""]
    var families := _legacy_family_arrays(crest, skills, tools, passives)
    var active_skill := int(old.get("active_skill_slot", 0))
    var active_tool := int(old.get("active_tool_slot", 0))
    if active_skill < 0 or active_skill > 1: active_skill = 0
    if active_tool < 0 or active_tool > 1: active_tool = 0
    var skill_id := String(skills[active_skill]) if active_skill < skills.size() else ""
    var tool_id := String(tools[active_tool]) if active_tool < tools.size() else ""
    active_skill = _migration_active_slot("thread_skill", active_skill, families.thread_skill, crest)
    active_tool = _migration_active_slot("tool", active_tool, families.tool, crest)
    var migrated_passives: Array = _active_accessories(families, crest)
    return {"crest": crest, "skills": families.thread_skill.duplicate(), "tools": families.tool.duplicate(),
        "passives": migrated_passives, "active_skill_slot": active_skill, "active_tool_slot": active_tool,
        "equipped_families": families}

func restore(snapshot: Dictionary) -> Dictionary:
    # Strict transactional migration. Parse into an isolated candidate and commit
    # only after all IDs, slot layouts, stock and cooldowns pass validation.
    var version: Variant = snapshot.get("version")
    if not _counter(version, 3) or int(version) not in [1, 2, 3]: return _fail("不支持的构筑存档版本")
    var allowed := ["version", "crest", "skill", "tool", "passives", "unlocked_crests", "unlocked_skills", "unlocked_passives", "tool_counts", "skill_levels", "loadouts", "cooldowns"]
    if int(version) >= 2: allowed.append_array(["skills", "tools", "active_skill_slot", "active_tool_slot", "unlocked_tools", "mechanisms"])
    if int(version) >= 3: allowed.append("equipped_families")
    allowed.append("crafted")
    for field in snapshot:
        if not allowed.has(field): return _fail("未知构筑存档字段")
    var candidate := get_script().new() as RefCounted
    var migrated: Dictionary = snapshot.duplicate(true)
    for field in ["unlocked_crests", "unlocked_skills", "unlocked_passives", "passives"]:
        if not migrated.get(field) is Array: return _fail("构筑列表数据损坏")
    for field in ["tool_counts", "skill_levels", "loadouts"]:
        if not migrated.get(field) is Dictionary: return _fail("构筑计数数据损坏")
    if migrated.has("crafted"):
        if not migrated.crafted is Array: return _fail("工匠制作记录损坏")
        var made := {}
        for id in migrated.crafted:
            if not id is String or made.has(id) or not String(catalog.recipes.get(id, {}).get("kind", "")) in ["tool_capacity", "slot_part"]:
                return _fail("未知或重复的工匠制作记录")
            made[id] = true
    else:
        # E04 legacy: the third travel slot used to open with the crest's mechanism
        # alone. Saves from before the clasp keep that slot: any repaired mechanism
        # grants the clasp, and the slot still needs that crest's own mechanism.
        migrated["crafted"] = []
        var legacy_mechanisms: Variant = migrated.get("mechanisms", [])
        var clasp := part_recipe("travel_clasp")
        if legacy_mechanisms is Array and not legacy_mechanisms.is_empty() and not clasp.is_empty():
            migrated.crafted.append(clasp)
    if int(version) == 1:
        if not migrated.get("skill") is String or not migrated.get("tool") is String: return _fail("旧构筑引用无效")
        for id in ["shard", "mine"]:
            if not migrated.tool_counts.has(id): return _fail("旧战具计数缺失")
        for id in ["cleave", "needle", "snare", "ward"]:
            if not migrated.skill_levels.has(id): return _fail("旧技能等级缺失")
        migrated["skills"] = [migrated.skill, ""]
        migrated["tools"] = [migrated.tool, ""]
        migrated["active_skill_slot"] = 0
        migrated["active_tool_slot"] = 0
        migrated["unlocked_tools"] = ["shard", "mine"]
        migrated["mechanisms"] = []
        for id in catalog.tools:
            if not migrated.tool_counts.has(id): migrated.tool_counts[id] = 0
        for id in catalog.skills:
            if not migrated.skill_levels.has(id): migrated.skill_levels[id] = 0
        # A migration clamps legacy overstock down to modern capacity; it never adds charges.
        for id in migrated.tool_counts:
            if not catalog.tools.has(id) or not _counter(migrated.tool_counts[id], 6): return _fail("旧战具携带量无效")
            migrated.tool_counts[id] = mini(int(migrated.tool_counts[id]), int(catalog.tools[id].capacity))
    else:
        if not migrated.get("skills") is Array or not migrated.get("tools") is Array or not migrated.get("unlocked_tools") is Array or not migrated.get("mechanisms") is Array:
            return _fail("构筑列表数据损坏")
        if migrated.skills.size() != 2 or migrated.tools.size() != 2 or not _counter(migrated.get("active_skill_slot"), 1) or not _counter(migrated.get("active_tool_slot"), 1):
            return _fail("旧构筑槽位数据无效")
        if int(version) == 2 and migrated.has("equipped_families"):
            return _fail("版本二构筑字段无效")
    if not catalog.crests.has(migrated.get("crest", "")): return _fail("未知契印")
    if not migrated.get("unlocked_tools") is Array: return _fail("构筑列表数据损坏")
    candidate.state = migrated.duplicate(true)
    if int(version) < 3:
        if not candidate._validate_slots(migrated.skills, "skills") or not candidate._validate_slots(migrated.tools, "tools"):
            return _fail("旧构筑引用无效")
        var old_passive_reason: String = candidate._validate_passives(migrated.passives, String(migrated.crest))
        if not old_passive_reason.is_empty(): return _fail(old_passive_reason)
        migrated["equipped_families"] = candidate._legacy_family_arrays(String(migrated.crest), migrated.skills, migrated.tools, migrated.passives)
        migrated["active_skill_slot"] = candidate._migration_active_slot("thread_skill", int(migrated.active_skill_slot), migrated.equipped_families.thread_skill, String(migrated.crest))
        migrated["active_tool_slot"] = candidate._migration_active_slot("tool", int(migrated.active_tool_slot), migrated.equipped_families.tool, String(migrated.crest))
        migrated["version"] = 3
        for name in migrated.loadouts:
            var old: Variant = migrated.loadouts[name]
            if not old is Dictionary: return _fail("旧构筑方案无效")
            var expected_old_size := 4 if int(version) == 1 else 6
            if old.size() != expected_old_size: return _fail("旧构筑方案无效")
            if int(version) == 1 and (not old.get("skill") is String or not old.get("tool") is String or not old.get("passives") is Array):
                return _fail("旧构筑方案无效")
            if int(version) == 2 and (not old.get("skills") is Array or not old.get("tools") is Array or not old.get("passives") is Array or old.skills.size() != 2 or old.tools.size() != 2):
                return _fail("旧构筑方案无效")
            migrated.loadouts[name] = candidate._loadout_from_legacy(old, int(version), String(migrated.crest))
    candidate.state = migrated.duplicate(true)
    var tables := {"unlocked_crests": "crests", "unlocked_skills": "skills", "unlocked_tools": "tools", "unlocked_passives": "passives", "mechanisms": "crests"}
    for field in tables:
        if not migrated.get(field) is Array: return _fail("构筑列表数据损坏")
        var seen := {}
        for id in migrated[field]:
            if not id is String or not catalog[tables[field]].has(id) or seen.has(id): return _fail("未知或重复构筑条目")
            seen[id] = true
    if not candidate.state.get("equipped_families") is Dictionary:
        return _fail("构筑家族槽位数据损坏")
    migrated["version"] = 3
    if int(version) == 3:
        var expected_passives: Array = candidate._active_accessories(migrated.equipped_families, String(migrated.crest))
        if migrated.get("skills") != migrated.equipped_families.get("thread_skill") or migrated.get("tools") != migrated.equipped_families.get("tool") or migrated.get("passives") != expected_passives:
            return _fail("构筑家族装备别名不一致")
        if not migrated.get("skills") is Array or not migrated.get("tools") is Array or migrated.get("skill") != migrated.skills[int(migrated.get("active_skill_slot", 0))] or migrated.get("tool") != migrated.tools[int(migrated.get("active_tool_slot", 0))]:
            return _fail("活动槽位与引用不一致")
    else:
        migrated["skills"] = migrated.equipped_families.get("thread_skill", [])
        migrated["tools"] = migrated.equipped_families.get("tool", [])
        migrated["passives"] = candidate._active_accessories(migrated.equipped_families, String(migrated.crest))
        migrated["skill"] = migrated.skills[int(migrated.get("active_skill_slot", 0))]
        migrated["tool"] = migrated.tools[int(migrated.get("active_tool_slot", 0))]
    candidate.state = migrated.duplicate(true)
    var family_reason: String = candidate._validate_family_arrays(migrated.equipped_families, String(migrated.crest), false)
    if not family_reason.is_empty(): return _fail(family_reason)
    var loadout_reason: String = candidate._validate_loadout({"crest": migrated.crest, "skills": migrated.skills, "tools": migrated.tools,
        "passives": migrated.passives, "active_skill_slot": migrated.active_skill_slot, "active_tool_slot": migrated.active_tool_slot,
        "equipped_families": migrated.equipped_families})
    if not loadout_reason.is_empty(): return _fail(loadout_reason)
    if migrated.tool_counts.size() != catalog.tools.size() or migrated.skill_levels.size() != catalog.skills.size(): return _fail("构筑计数条目数量无效")
    for id in catalog.tools:
        var stock_bonus := crafted_capacity(id, migrated.crafted) + (1 if id in ["shard", "mine"] and migrated.unlocked_passives.has("needlecase") else 0)
        if not _counter(migrated.tool_counts.get(id), int(catalog.tools[id].capacity) + stock_bonus): return _fail("战具携带量无效")
    for id in catalog.skills:
        if not _counter(migrated.skill_levels.get(id), 2): return _fail("技能强化等级无效")
    if migrated.loadouts.size() > 8: return _fail("方案数量超限")
    for name in migrated.loadouts:
        var saved: Variant = migrated.loadouts[name]
        if not name is String or name.is_empty() or name.length() > 24 or not saved is Dictionary:
            return _fail("构筑方案格式无效")
        var normalized: Dictionary = saved
        if not normalized.has("equipped_families"):
            normalized = candidate._loadout_from_legacy(normalized, 2, String(migrated.crest))
            migrated.loadouts[name] = normalized
        if normalized.size() != 7: return _fail("构筑方案格式无效")
        var saved_reason: String = candidate._validate_loadout(normalized)
        if not saved_reason.is_empty(): return _fail(saved_reason)
    var restored_cooldowns: Variant = migrated.get("cooldowns", {})
    if not restored_cooldowns is Dictionary: return _fail("冷却数据无效")
    for id in restored_cooldowns:
        var value: Variant = restored_cooldowns[id]
        if not catalog.skills.has(id) or not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 60:
            return _fail("冷却时间无效")
    candidate.state = migrated.duplicate(true)
    candidate.state.version = 3
    for id in catalog.tools: candidate.state.tool_counts[id] = int(candidate.state.tool_counts[id])
    for id in catalog.skills: candidate.state.skill_levels[id] = int(candidate.state.skill_levels[id])
    for name in candidate.state.loadouts:
        candidate.state.loadouts[name] = candidate.state.loadouts[name].duplicate(true)
        candidate.state.loadouts[name].active_skill_slot = int(candidate.state.loadouts[name].active_skill_slot)
        candidate.state.loadouts[name].active_tool_slot = int(candidate.state.loadouts[name].active_tool_slot)
    candidate.state.active_skill_slot = int(candidate.state.active_skill_slot)
    candidate.state.active_tool_slot = int(candidate.state.active_tool_slot)
    state = candidate.state.duplicate(true)
    cooldowns = restored_cooldowns.duplicate(true)
    _normalize_active_slots()
    return _ok()

## Only builds this version wrote (or migrates) are rebuilt; a newer game's
## build stays untouched so its progress is never overwritten by an older one.
func salvageable(snapshot: Dictionary) -> bool:
    return _counter(snapshot.get("version"), 3) and int(snapshot.version) >= 1

## T02: rebuild a build that restore() rejects (e.g. a save naming equipment this
## version no longer has). Unlocks come back from story flags and relics, then
## every saved entry this version still knows is carried over through the normal
## validated paths; whatever cannot be is listed in `dropped`. Commits only on
## success, like restore().
func salvage(snapshot: Dictionary, inventory_counts: Dictionary, story_flags: Dictionary) -> Dictionary:
    if not salvageable(snapshot): return _fail("构筑记录来自更新的版本")
    var dropped: Array = []
    var rebuilt := get_script().new() as RefCounted
    rebuilt.sync_progress(inventory_counts, "", story_flags)
    var tables := {"unlocked_crests": "crests", "unlocked_skills": "skills", "unlocked_tools": "tools", "unlocked_passives": "passives", "mechanisms": "crests"}
    for field in tables:
        var saved: Variant = snapshot.get(field, [])
        for id in (saved if saved is Array else []):
            if id is String and catalog[tables[field]].has(id): rebuilt._unlock(field, id)
            elif not dropped.has(str(id)): dropped.append(str(id))
    # E04 crafts first: the clasp opens the slot that equipment below may need.
    var crafted: Variant = snapshot.get("crafted", [])
    for id in (crafted if crafted is Array else []):
        if id is String and String(catalog.recipes.get(id, {}).get("kind", "")) in ["tool_capacity", "slot_part"] and not rebuilt.state.crafted.has(id):
            rebuilt.state.crafted.append(id)
        elif not dropped.has(str(id)):
            dropped.append(str(id))
    var levels: Variant = snapshot.get("skill_levels", {})
    for id in (levels if levels is Dictionary else {}):
        if catalog.skills.has(id) and _counter(levels[id], 2): rebuilt.state.skill_levels[id] = int(levels[id])
    var crest := String(snapshot.get("crest", "")) if snapshot.get("crest") is String else ""
    if rebuilt.state.unlocked_crests.has(crest): rebuilt.switch_crest(crest)
    elif not crest.is_empty() and not dropped.has(crest): dropped.append(crest)
    var families: Variant = snapshot.get("equipped_families", {})
    if not families is Dictionary or families.is_empty():
        families = rebuilt._legacy_family_arrays(String(rebuilt.state.crest), snapshot.get("skills", []) if snapshot.get("skills") is Array else [],
            snapshot.get("tools", []) if snapshot.get("tools") is Array else [], snapshot.get("passives", []) if snapshot.get("passives") is Array else [])
    for family in FAMILY_KEYS:
        var values: Variant = families.get(family, [])
        for slot in range(values.size() if values is Array else 0):
            var id: Variant = values[slot]
            if not id is String: continue
            if not rebuilt.equip_family_slot(id, family, slot).ok and not id.is_empty() and not rebuilt.state.equipped_families[family].has(id) and not dropped.has(id):
                dropped.append(id)
    for pair in [["active_skill_slot", "thread_skill"], ["active_tool_slot", "tool"]]:
        if _counter(snapshot.get(pair[0]), 1): rebuilt.state[pair[0]] = int(snapshot[pair[0]])
    rebuilt._normalize_active_slots()
    var counts: Variant = snapshot.get("tool_counts", {})
    for id in catalog.tools:
        if counts is Dictionary and _counter(counts.get(id), 1000):
            rebuilt.state.tool_counts[id] = mini(int(counts[id]), rebuilt._stored_capacity(String(id)))
    var loadouts: Variant = snapshot.get("loadouts", {})
    for name in (loadouts if loadouts is Dictionary else {}):
        var saved_build: Variant = loadouts[name]
        if name is String and not name.is_empty() and name.length() <= 24 and saved_build is Dictionary and rebuilt.state.loadouts.size() < 8 \
                and saved_build.has("equipped_families") and rebuilt._validate_loadout(saved_build).is_empty():
            rebuilt.state.loadouts[name] = saved_build.duplicate(true)
        else:
            dropped.append("方案「%s」" % str(name))
    # Fields this version keeps beyond the ones above (validated by restore()).
    var candidate: Dictionary = rebuilt.serialize()
    var handled := ["version", "crest", "skill", "tool", "skills", "tools", "passives", "equipped_families", "active_skill_slot", "active_tool_slot",
        "tool_counts", "skill_levels", "loadouts", "cooldowns", "unlocked_crests", "unlocked_skills", "unlocked_tools", "unlocked_passives", "mechanisms", "crafted"]
    for key in snapshot:
        if rebuilt.state.has(key) and not handled.has(key): candidate[key] = snapshot[key]
    var check := get_script().new() as RefCounted
    if not check.restore(candidate).ok:
        for key in snapshot:
            if rebuilt.state.has(key) and not handled.has(key) and not dropped.has(key): dropped.append(key)
        candidate = rebuilt.serialize()
        if not check.restore(candidate).ok: return _fail("构筑无法按剧情进度重建")
    state = check.state.duplicate(true)
    cooldowns.clear()
    return _ok({"dropped": dropped})

func get_snapshot(wallet: Variant = null) -> Dictionary:
    var result := {"crest": state.crest, "skill": state.skill, "tool": state.tool,
        "passives": state.passives.duplicate(), "slots_used": slots_used(), "slots_total": slots_total(),
        "crests": [], "skills": [], "tools": [], "passive_options": [], "recipes": [],
        "loadouts": state.loadouts.keys(), "stats": profile(), "skills_equipped": state.skills.duplicate(), "tools_equipped": state.tools.duplicate(),
        "active_skill_slot": state.active_skill_slot, "active_tool_slot": state.active_tool_slot,
        "equipped_families": state.equipped_families.duplicate(true), "slot_layout": {}, "slot_families": [],
        "tool_deficits": {}, "can_refill_tools": false,
        "resupply_quote": quote_resupply(wallet) if wallet is Dictionary else {}}
    for id in catalog.crests:
        var entry: Dictionary = catalog.crests[id].duplicate(true)
        entry.merge({"id": id, "unlocked": state.unlocked_crests.has(id), "selected": state.crest == id, "mechanism_unlocked": state.mechanisms.has(id)}, true)
        result.crests.append(entry)
    for id in catalog.skills:
        var entry: Dictionary = catalog.skills[id].duplicate(true)
        entry.merge({"id": id, "unlocked": state.unlocked_skills.has(id), "selected": state.skill == id,
            "equipped_slots": _equipped_slots(state.skills, id), "level": int(state.skill_levels[id]), "branch": skill_branch(id), "cooldown_remaining": float(cooldowns.get(id, 0.0))}, true)
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
    # Keep family options aligned with the public canonical option rows above.
    # Those rows include derived state (tool stock/capacity, scaled skill cost,
    # learned level and cooldown) that raw catalog clones do not carry.
    var canonical_options: Dictionary = {"skills": {}, "tools": {}, "passives": {}}
    for entry in result.skills: canonical_options.skills[String(entry.id)] = entry
    for entry in result.tools: canonical_options.tools[String(entry.id)] = entry
    for entry in result.passive_options: canonical_options.passives[String(entry.id)] = entry
    for family in FAMILY_KEYS:
        var table := String(FAMILY_TABLES[family])
        var slots: Array = []
        var options: Array = []
        var equipped: Array = state.equipped_families[family]
        for slot in range(int(FAMILY_CAPACITIES[family])):
            var spec := _slot_spec(family, slot)
            if spec.is_empty(): continue
            var compatibility: Array = spec.get("compatible", []).duplicate()
            slots.append({"id": "%s:%d" % [family, slot], "family": family, "index": slot,
                "compatible": compatibility, "unlocked": _slot_unlocked(family, slot),
                "requires_mechanism": String(spec.get("requires_mechanism", "")), "equipped_id": String(equipped[slot]),
                "requires_part": String(spec.get("requires_part", "")), "part_ready": String(spec.get("requires_part", "")).is_empty() or has_part(String(spec.get("requires_part", ""))),
                "part_recipe": part_recipe(String(spec.get("requires_part", "")))})
        for id in catalog[table]:
            if table == "passives" and String(catalog[table][id].get("family", "")) != family: continue
            var compatible_slots: Array[int] = []
            for slot in range(int(FAMILY_CAPACITIES[family])):
                if _slot_spec(family, slot).get("compatible", []).has(String(id)):
                    compatible_slots.append(slot)
            var entry: Dictionary = canonical_options[table][String(id)].duplicate(true)
            entry.merge({"id": String(id), "slot_family": family,
                "unlocked": state["unlocked_" + table].has(id), "equipped_slots": _equipped_slots(equipped, String(id)),
                "compatible_slots": compatible_slots}, true)
            options.append(entry)
        result.slot_layout[family] = slots
        result.slot_families.append({"id": family, "name": String(FAMILY_NAMES[family]), "slots": slots, "options": options})
    for id in catalog.tools:
        result.tool_deficits[id] = maxi(0, tool_capacity(String(id)) - int(state.tool_counts.get(id, 0)))
        result.can_refill_tools = bool(result.can_refill_tools) or int(result.tool_deficits[id]) > 0
    if wallet is Dictionary: result.resupply_quote = quote_resupply(wallet)
    result.can_resupply_tools = bool(result.resupply_quote.get("ok", false))
    for id in catalog.recipes:
        var entry: Dictionary = catalog.recipes[id].duplicate(true)
        entry.id = id
        if entry.kind == "skill_branch":
            entry.current = int(state.skill_levels.get(entry.target, 0)) == int(entry.branch)
        elif entry.kind in ["tool_capacity", "slot_part", "passive"]:
            entry.crafted = state.unlocked_passives.has(String(entry.target)) if entry.kind == "passive" else state.get("crafted", []).has(id)
            if entry.kind == "tool_capacity":
                entry.capacity_now = tool_capacity(String(entry.target))
                entry.target_unlocked = state.unlocked_tools.has(String(entry.target))
        result.recipes.append(entry)
    return result

func _equipped_slots(ids: Array, id: String) -> Array:
    var slots := []
    for index in range(ids.size()):
        if ids[index] == id:
            slots.append(index)
    return slots
