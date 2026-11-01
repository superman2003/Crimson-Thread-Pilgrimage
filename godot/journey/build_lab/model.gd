extends RefCounted
const V := preload("res://journey/core/values.gd")
const BUILD := preload("res://scripts/build_system.gd")
const MAX_SCENARIOS := 12
const OWNERSHIP := ["unlocked_crests", "unlocked_skills", "unlocked_tools", "unlocked_passives", "mechanisms", "crafted", "skill_levels"]
const FAMILIES := {"tool":"战具", "thread_skill":"线术", "combat_accessory":"战斗铭饰", "travel_accessory":"行旅铭饰"}
const METRICS := {
    "attack_speed_mult":"针击速度倍率", "damage_taken_mult":"承伤倍率",
    "pogo_bounce_mult":"下击弹跳倍率", "melee_energy_mult":"近战回线倍率",
    "knockback_mult":"击退倍率", "status_buildup_mult":"状态积累倍率",
    "hazard_trigger_mult":"危险触发倍率", "attack_reach_mult":"针击范围倍率",
    "max_hp":"生命上限", "max_energy":"绯线上限",
    "heal_interrupt_loss_ratio":"疗伤中断损耗比例",
    "move_mult":"移动倍率", "attack_damage_mult":"针击伤害倍率",
    "energy_gain_mult":"回线倍率", "skill_damage_mult":"线术伤害倍率",
    "skill_cost_mult":"线术费用倍率", "heal_cost":"疗伤费用",
    "heal_amount":"疗伤恢复", "heal_duration":"疗伤引导",
    "max_hp_bonus":"生命容量加成", "max_energy_bonus":"绯线容量加成",
    "ranged_range_mult":"远程范围倍率", "tool_capacity_bonus":"战具容量加成"
}

static func fresh() -> Dictionary:
    return {"version":1, "sequence":0, "scenarios":[], "draft":{}, "source":"", "selected":""}

static func valid(data: Dictionary) -> bool:
    if data.get("version") != 1 or not V.count(data.get("sequence")):
        return false
    if not data.get("draft") is Dictionary or not data.get("scenarios") is Array or data.scenarios.size() > MAX_SCENARIOS:
        return false
    var names := {}
    var ids := {}
    for row in data.scenarios:
        if not row is Dictionary or not row.get("state") is Dictionary:
            return false
        if not row.get("id") is String or ids.has(row.id):
            return false
        var name := V.text(row.get("name"), 40)
        if name.is_empty() or names.has(name.to_lower()):
            return false
        if not row.get("note") is String or row.note.length() > 600:
            return false
        ids[row.id] = true
        names[name.to_lower()] = true
    return V.json_safe(data, 0, [V.MAX_ITEMS])

static func machine(snapshot: Dictionary, state: Dictionary = {}) -> Dictionary:
    var system := BUILD.new()
    var live: Dictionary = snapshot.get("build_state", {})
    if live.is_empty():
        return {"ok":false, "reason":"当前构筑尚未准备好。"}
    var candidate: Dictionary = state.duplicate(true) if not state.is_empty() else live.duplicate(true)
    # Saved drafts can rearrange equipment, but current live ownership is the
    # authority. No imported draft may grant a crest, recipe or training branch.
    for field in OWNERSHIP:
        candidate[field] = live.get(field, system.state.get(field)).duplicate(true) if live.get(field, system.state.get(field)) is Array or live.get(field, system.state.get(field)) is Dictionary else live.get(field)
    candidate.tool_counts = live.get("tool_counts", {}).duplicate(true)
    candidate.loadouts = {}
    var restored: Dictionary = system.restore(candidate)
    if not restored.get("ok", false):
        return {"ok":false, "reason":String(restored.get("reason", "试算构筑无效。"))}
    system.sync_progress(snapshot.get("inventory", {}), String(snapshot.get("region", "")), snapshot.get("flags", {}))
    return {"ok":true, "system":system, "state":system.state.duplicate(true), "stats":system.stats(), "snapshot":system.get_snapshot()}

static func start(data: Dictionary, snapshot: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    var evaluated := machine(snapshot)
    if not evaluated.ok:
        return result
    result.draft = evaluated.state
    result.source = V.fingerprint(snapshot.get("build_state", {}))
    return result

static func edit(data: Dictionary, snapshot: Dictionary, action: String, id: String, family: String = "", slot: int = 0) -> Dictionary:
    var current := machine(snapshot, data.draft)
    if not current.ok:
        return current
    var system: RefCounted = current.system
    var outcome: Dictionary
    if action == "crest":
        outcome = system.switch_crest(id, true)
    elif action == "equip" and FAMILIES.has(family):
        outcome = system.equip_family_slot(id, family, slot, true)
    elif action == "clear" and FAMILIES.has(family):
        outcome = system.equip_family_slot("", family, slot, true)
    else:
        return {"ok":false, "reason":"未知试算操作。"}
    if not outcome.get("ok", false):
        return outcome
    var candidate := data.duplicate(true)
    candidate.draft = system.state.duplicate(true)
    return {"ok":true, "data":candidate, "reason":"已更新沙盘；实际装备没有变化。"}

static func available(snapshot: Dictionary, state: Dictionary, family: String) -> Array:
    var result := []
    var evaluation := machine(snapshot, state)
    if not evaluation.ok:
        return result
    var view: Dictionary = evaluation.snapshot
    var source: Array = view.get({"tool":"tools", "thread_skill":"skills", "combat_accessory":"passive_options", "travel_accessory":"passive_options"}.get(family, ""), [])
    for item in source:
        if not item.get("unlocked", false):
            continue
        if family in ["combat_accessory", "travel_accessory"] and item.get("family") != family:
            continue
        result.append({"id":String(item.id), "name":String(item.get("name", item.id)), "description":String(item.get("description", ""))})
    return result

static func crest_choices(snapshot: Dictionary) -> Array:
    var result := []
    for item in snapshot.get("build", {}).get("crests", []):
        if item.get("unlocked", false):
            result.append({"id":String(item.id), "name":String(item.get("name", item.id))})
    return result

static func differences(snapshot: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
    var left := machine(snapshot, before)
    var right := machine(snapshot, after)
    if not left.ok:
        return left
    if not right.ok:
        return right
    var result := []
    for key in METRICS:
        var a: Variant = left.stats.get(key, 0)
        var b: Variant = right.stats.get(key, 0)
        if not V.number(a) or not V.number(b):
            continue
        result.append({"id":key, "name":METRICS[key], "before":float(a), "after":float(b), "difference":float(b) - float(a)})
    var skills := []
    for slot in 2:
        var a: Dictionary = left.system.selected_skill(slot)
        var b: Dictionary = right.system.selected_skill(slot)
        skills.append({"slot":slot, "before":_skill(a), "after":_skill(b)})
    var tools := []
    for slot in 2:
        tools.append({"slot":slot, "before":tool_slot(left, slot), "after":tool_slot(right, slot)})
    return {"ok":true, "metrics":result, "skills":skills, "tools":tools, "left":left, "right":right}

static func tool_slot(evaluation: Dictionary, slot: int) -> Dictionary:
    var id := String(evaluation.state.get("tools", ["", ""])[slot])
    for tool in evaluation.snapshot.get("tools", []):
        if tool.id == id:
            return {"name":String(tool.get("name", id)), "count":int(tool.get("count", 0)), "capacity":int(tool.get("capacity", 0)), "description":String(tool.get("description", ""))}
    return {"name":"空槽", "count":0, "capacity":0, "description":""}


static func _skill(value: Dictionary) -> Dictionary:
    if value.is_empty():
        return {"name":"空槽", "cost":0, "damage":0, "cycle":0.0, "range":0.0}
    return {
        "name":String(value.get("name", "线术")),
        "cost":int(value.get("energy_cost", 0)),
        "damage":int(value.get("damage", 0)),
        "cycle":float(value.get("windup", 0)) + float(value.get("active", 0)) + float(value.get("recovery", 0)),
        "range":float(value.get("range", 0))
    }

static func sustainability(evaluation: Dictionary, energy: int, health_missing: int, enemy_hp: int) -> Dictionary:
    if not evaluation.get("ok", false):
        return {"ok":false}
    var profile: Dictionary = evaluation.stats
    var heal_cost := maxi(1, int(profile.get("heal_cost", 60)))
    var heal_amount := maxi(1, int(profile.get("heal_amount", 1)))
    var heals := mini(maxi(0, energy) / heal_cost, ceili(float(maxi(0, health_missing)) / heal_amount))
    var heal_total := mini(health_missing, heals * heal_amount)
    var skills := []
    for slot in 2:
        var skill: Dictionary = evaluation.system.selected_skill(slot)
        if skill.is_empty():
            continue
        var cost := maxi(1, int(skill.get("energy_cost", 1)))
        var damage := maxi(0, int(skill.get("damage", 0)))
        var casts := maxi(0, energy) / cost
        var needed := ceili(float(maxi(0, enemy_hp)) / damage) if damage > 0 else -1
        skills.append({"name":String(skill.name), "casts":casts, "cost":cost, "damage":damage, "needed":needed, "affordable":damage > 0 and needed * cost <= energy})
    return {"ok":true, "heals":heals, "healed":heal_total, "remaining":maxi(0, energy) - heals * heal_cost, "skills":skills}

static func save_scenario(data: Dictionary, title: String, note: String, snapshot: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    var name := V.text(title, 40)
    if name.is_empty() or result.scenarios.size() >= MAX_SCENARIOS:
        return result
    for row in result.scenarios:
        if String(row.name).nocasecmp_to(name) == 0:
            return result
    var evaluated := machine(snapshot, data.draft)
    if not evaluated.ok:
        return result
    result.sequence = int(result.sequence) + 1
    var id := "scenario_" + str(int(result.sequence))
    result.scenarios.append({"id":id, "name":name, "note":V.text(note, 600), "state":evaluated.state, "created":int(Time.get_unix_time_from_system())})
    result.selected = id
    return result

static func scenario(data: Dictionary, id: String) -> Dictionary:
    for record in data.scenarios:
        if record.id == id:
            return record.duplicate(true)
    return {}

static func load_scenario(data: Dictionary, id: String, snapshot: Dictionary) -> Dictionary:
    var record := scenario(data, id)
    if record.is_empty():
        return {"ok":false, "reason":"试算方案不存在。"}
    var evaluation := machine(snapshot, record.state)
    if not evaluation.ok:
        return evaluation
    var result := data.duplicate(true)
    result.draft = evaluation.state
    result.selected = id
    return {"ok":true, "data":result, "reason":"方案已加载到沙盘；实际装备不变。"}

static func remove(data: Dictionary, id: String) -> Dictionary:
    var result := data.duplicate(true)
    for index in range(result.scenarios.size() - 1, -1, -1):
        if result.scenarios[index].id == id:
            result.scenarios.remove_at(index)
    if result.selected == id:
        result.selected = ""
    return result

static func import_draft(data: Dictionary, snapshot: Dictionary, raw: String) -> Dictionary:
    if raw.to_utf8_buffer().size() > 65536:
        return {"ok":false, "reason":"构筑文本过大。"}
    var parsed: Variant = V.parse_json(raw)
    if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("state") is Dictionary:
        return {"ok":false, "reason":"构筑文本格式无效。"}
    var evaluation := machine(snapshot, parsed.state)
    if not evaluation.ok:
        return evaluation
    var result := data.duplicate(true)
    result.draft = evaluation.state
    return {"ok":true, "data":result, "reason":"仅导入沙盘，未更改游戏装备、训练或物资。"}

static func describe(evaluation: Dictionary) -> String:
    if not evaluation.get("ok", false):
        return String(evaluation.get("reason", "试算失败。"))
    var lines: Array[String] = []
    var view: Dictionary = evaluation.snapshot
    for family in FAMILIES:
        var ids: Array = evaluation.state.get("equipped_families", {}).get(family, [])
        var names := []
        var options := available_from_view(view, family)
        for id in ids:
            names.append(String(options.get(id, "空槽")))
        lines.append(String(FAMILIES[family]) + "：" + " / ".join(names))
    return "\n".join(lines)

static func available_from_view(view: Dictionary, family: String) -> Dictionary:
    var result := {"":"空槽"}
    var table: String = {"tool":"tools", "thread_skill":"skills", "combat_accessory":"passive_options", "travel_accessory":"passive_options"}.get(family, "")
    for item in view.get(table, []):
        if item.get("unlocked", false):
            result[String(item.id)] = String(item.get("name", item.id))
    return result

static func contributions(snapshot: Dictionary, state: Dictionary) -> Array:
    var evaluation := machine(snapshot, state)
    if not evaluation.ok:
        return []
    var result := []
    var families: Dictionary = evaluation.state.get("equipped_families", {})
    for family in ["combat_accessory", "travel_accessory"]:
        var ids: Array = families.get(family, [])
        for slot in ids.size():
            var id := String(ids[slot])
            if id.is_empty():
                continue
            var isolated := machine(snapshot, state)
            var removed: Dictionary = isolated.system.equip_family_slot("", family, slot, true)
            if not removed.get("ok", false):
                continue
            var without: Dictionary = isolated.system.stats()
            var effects := []
            for key in METRICS:
                var before: Variant = without.get(key, 0)
                var after: Variant = evaluation.stats.get(key, 0)
                if V.number(before) and V.number(after) and not is_equal_approx(float(before), float(after)):
                    effects.append({"name":METRICS[key], "difference":float(after) - float(before)})
            var title := id
            for option in evaluation.snapshot.get("passive_options", []):
                if option.id == id:
                    title = String(option.get("name", id))
                    break
            result.append({"id":id, "name":title, "family":family, "slot":slot, "effects":effects})
    return result

static func report(snapshot: Dictionary, state: Dictionary) -> String:
    var evaluation := machine(snapshot, state)
    var comparison := differences(snapshot, snapshot.get("build_state", {}), state)
    if not evaluation.ok or not comparison.get("ok", false):
        return "当前构筑不能按现有获得条件复核。"
    var lines: Array[String] = ["构筑试算报告", "只读沙盘；未应用到真实角色。", "", describe(evaluation), "", "相对当前实际构筑："]
    for metric in comparison.metrics:
        lines.append("%s：%.3f → %.3f（%+.3f）" % [metric.name, metric.before, metric.after, metric.difference])
    lines.append("")
    lines.append("铭饰边际贡献（当前其余装备保持不变）：")
    for row in contributions(snapshot, state):
        lines.append(String(row.name))
        for effect in row.effects:
            lines.append("  %s %+.3f" % [effect.name, effect.difference])
    lines.append("区间估计不模拟敌人位移、无敌帧、碰撞与多段命中；自然战斗结果仍以实机为准。")
    return "\n".join(lines)

static func constraints(snapshot: Dictionary, state: Dictionary) -> Array:
    var evaluation := machine(snapshot, state)
    if not evaluation.get("ok", false):
        return [{"name":"构筑复核", "text":String(evaluation.get("reason", "无效"))}]
    var result := []
    var view: Dictionary = evaluation.snapshot
    result.append({"name":"铭饰容量", "text":"%d / %d" % [view.get("slots_used", 0), view.get("slots_total", 0)]})
    var layout: Dictionary = view.get("slot_layout", {})
    for family in FAMILIES:
        var slots: Array = layout.get(family, [])
        if slots.is_empty():
            result.append({"name":FAMILIES[family], "text":"此契印没有公开槽位资料。"})
            continue
        for index in slots.size():
            var spec: Dictionary = slots[index]
            var active: Variant = spec.get("unlocked", true)
            var label := "可使用" if active is bool and active else "尚未解锁"
            var compatibility: Variant = spec.get("compatible", [])
            if compatibility is Array and not compatibility.is_empty():
                label += " · 兼容 " + " / ".join(compatibility)
            result.append({"name":"%s槽位%d" % [FAMILIES[family], index + 1], "text":label})
    return result
