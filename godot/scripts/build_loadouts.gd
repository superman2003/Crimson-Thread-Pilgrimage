extends RefCounted
## Named loadouts: previewing, renaming, copying, saving, deleting and restoring them, and validating slots.
## Moved out of build_system.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func loadout_name_error(system: RefCounted, value: Variant) -> String:
    if not value is String:return "方案名称无效"
    var name: String=value.strip_edges()
    if name.is_empty():return "方案名称不能为空"
    if name.length()>24:return "方案名称最多24个字"
    for index in name.length():
        if name.unicode_at(index)<32 or name.unicode_at(index)==127:return "方案名称不能含控制字符"
    return ""


static func preview_loadout_management(system: RefCounted, source: String, target: Variant, copy: bool, at_bell: bool) -> Dictionary:
    if not system.state.loadouts.has(source):return system._fail("原方案不存在")
    var error: String = system._loadout_name_error(target)
    if not error.is_empty():return system._fail(error)
    var name: String=target.strip_edges()
    if name==source:return system._fail("请输入不同的新名称")
    if system.state.loadouts.has(name):return system._fail("新名称已存在，不会覆盖其它方案")
    if copy and system.state.loadouts.size()>=8:return system._fail("最多保存8个构筑方案")
    if not system.state.loadouts[source] is Dictionary:return system._fail("原方案数据损坏")
    var source_error: String = system._validate_loadout(system.state.loadouts[source])
    if not source_error.is_empty():return system._fail(source_error)
    return system._ok({"target":name,"copy":copy,"can_apply":at_bell,"source_snapshot":system.state.loadouts[source].duplicate(true),
        "reason":"" if at_bell else "请在钟龛管理构筑方案"})


static func rename_loadout(system: RefCounted, source: String, target: Variant, at_bell: bool) -> Dictionary:
    var quote: Dictionary = system.preview_loadout_management(source,target,false,at_bell)
    if not quote.get("ok",false):return quote
    if not at_bell:return system._fail(quote.reason)
    var renamed:={}
    for name in system.state.loadouts:
        renamed[quote.target if name==source else name]=system.state.loadouts[name].duplicate(true)
    system.state.loadouts=renamed
    return system._ok({"reason":"方案已重命名；当前装备与资源不变。","name":quote.target})


static func copy_loadout(system: RefCounted, source: String, target: Variant, at_bell: bool) -> Dictionary:
    var quote: Dictionary = system.preview_loadout_management(source,target,true,at_bell)
    if not quote.get("ok",false):return quote
    if not at_bell:return system._fail(quote.reason)
    system.state.loadouts[quote.target]=quote.source_snapshot.duplicate(true)
    return system._ok({"reason":"已复制保存方案；当前装备与资源不变。","name":quote.target})


static func save_loadout(system: RefCounted, name: String, at_bell: bool) -> Dictionary:
    if not at_bell: return system._fail("请在钟龛保存构筑方案")
    var error: String = system._loadout_name_error(name)
    if not error.is_empty():return system._fail(error)
    name = name.strip_edges()
    if system.state.loadouts.size() >= 8 and not system.state.loadouts.has(name): return system._fail("最多保存8个构筑方案")
    system.state.loadouts[name] = {"crest": system.state.crest, "skills": system.state.skills.duplicate(), "tools": system.state.tools.duplicate(),
        "passives": system.state.passives.duplicate(), "active_skill_slot": system.state.active_skill_slot,
        "active_tool_slot": system.state.active_tool_slot, "equipped_families": system.state.equipped_families.duplicate(true)}
    return system._ok()


static func delete_loadout(system: RefCounted, name: String, at_bell: bool) -> Dictionary:
    if not at_bell:return system._fail("请在钟龛管理构筑方案")
    if not system.state.loadouts.has(name):return system._fail("方案不存在")
    system.state.loadouts.erase(name)
    return system._ok({"reason":"已删除构筑方案；当前装备不变。"})


static func preview_loadout(system: RefCounted, name: String, at_bell: bool) -> Dictionary:
    if not system.state.loadouts.has(name): return system._fail("方案尚未保存")
    var saved: Variant = system.state.loadouts[name]
    if not saved is Dictionary: return system._fail("方案数据损坏")
    var reason: String = system._validate_loadout(saved)
    if not reason.is_empty(): return system._fail(reason)
    var candidate = system.get_script().new()
    candidate.state = system.state.duplicate(true)
    candidate.cooldowns = system.cooldowns.duplicate(true)
    candidate.permanent_stats = system.permanent_stats.duplicate()
    var result: Dictionary = candidate.restore_loadout(name, true)
    if not bool(result.get("ok", false)): return result
    return system._ok({"can_restore": at_bell, "reason": "" if at_bell else "请在钟龛恢复构筑",
        "profile": candidate.profile(), "current_profile": system.profile(), "changes": system._loadout_changes(candidate), "equipped_families": candidate.state.equipped_families.duplicate(true),
        "currency_cost": 0, "refills_resources": false})


static func loadout_changes(system: RefCounted, candidate: RefCounted) -> Array:
    var changes: Array=[]
    if system.state.crest!=candidate.state.crest:changes.append({"kind":"crest","from":system.state.crest,"to":candidate.state.crest})
    for family in system.state.equipped_families:
        var before: Array=system.state.equipped_families[family]
        var after: Array=candidate.state.equipped_families[family]
        for index in before.size():
            if before[index]!=after[index]:changes.append({"kind":"slot","family":family,"slot":index,"from":before[index],"to":after[index]})
    for key in ["active_skill_slot","active_tool_slot"]:
        if system.state[key]!=candidate.state[key]:changes.append({"kind":"active","field":key,"from":system.state[key],"to":candidate.state[key]})
    return changes


static func restore_loadout(system: RefCounted, name: String, at_bell: bool) -> Dictionary:
    if not at_bell: return system._fail("请在钟龛恢复构筑")
    if not system.state.loadouts.has(name): return system._fail("方案不存在")
    var build: Dictionary = system.state.loadouts[name]
    var reason: String = system._validate_loadout(build)
    if not reason.is_empty(): return system._fail(reason)
    system.state.crest = String(build.crest)
    system.state.equipped_families = build.equipped_families.duplicate(true)
    system.state.active_skill_slot = int(build.active_skill_slot)
    system.state.active_tool_slot = int(build.active_tool_slot)
    system._sync_aliases()
    return system._ok()


static func validate_slots(system: RefCounted, ids: Variant, table: String) -> bool:
    if not ids is Array or ids.size() != 2: return false
    var seen := {}
    for id in ids:
        if not id is String: return false
        if id.is_empty(): continue
        if not system.catalog[table].has(id) or not system.state["unlocked_" + table].has(id) or seen.has(id): return false
        seen[id] = true
    return true


static func validate_loadout(system: RefCounted, build: Dictionary) -> String:
    if not build.get("crest") is String or not system.state.unlocked_crests.has(build.get("crest")):
        return "方案引用未获得的契印"
    if not build.get("equipped_families") is Dictionary:
        return "方案家族槽位数据无效"
    var families: Dictionary = build.equipped_families
    # Unselected slots may retain a dormant item across crest layouts. The
    # active slots below must always be compatible with the saved crest.
    var reason: String = system._validate_family_arrays(families, String(build.crest), false)
    if not reason.is_empty(): return reason
    for key in ["active_skill_slot", "active_tool_slot"]:
        if not system._counter(build.get(key), 1): return "活动槽位无效"
    var skills: Array = families.thread_skill
    var tools: Array = families.tool
    var active_skill := int(build.active_skill_slot)
    var active_tool := int(build.active_tool_slot)
    if not system._active_slot_valid("thread_skill", active_skill, skills, String(build.crest)):
        return "活动线技槽位无效"
    if not system._active_slot_valid("tool", active_tool, tools, String(build.crest)):
        return "活动战具槽位无效"
    var expected_passives: Array = system._active_accessories(families, String(build.crest))
    if build.get("skills") != skills or build.get("tools") != tools or build.get("passives") != expected_passives:
        return "方案兼容装备别名不一致"
    return ""


static func active_slot_valid(system: RefCounted, family: String, active: int, values: Array, crest: String) -> bool:
    if system._slot_unlocked(family, active, crest) and system._slot_accepts(family, active, String(values[active]), crest):
        return true
    if active != 0:
        return false
    for slot in range(values.size()):
        if system._slot_unlocked(family, slot, crest) and not String(values[slot]).is_empty() and system._slot_accepts(family, slot, String(values[slot]), crest):
            return false
    return true
