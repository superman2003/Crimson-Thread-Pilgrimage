extends RefCounted
## Describe the exact detached transaction candidate; no optimistic effects are
## inferred for rejected quotes, and new equipment is never treated as equipped.
const FAMILIES:={"tool":"战具","combat_accessory":"战斗铭饰","travel_accessory":"行旅铭饰","thread_skill":"线术"}
static func compare(build: RefCounted, quote: Dictionary) -> Dictionary:
    var result:={"available":false,"tools":[],"slots":[],"skills":[],"equipment":[],"parts":[]}
    if not quote.get("ok",false) or not quote.get("build") is Dictionary:return result
    var candidate: RefCounted=build.get_script().new()
    candidate.catalog=build.catalog.duplicate(true)
    if not candidate.restore(quote.build).ok:return result
    for id in build.catalog.tools:
        var old_capacity: int=build.tool_capacity(String(id))
        var new_capacity: int=candidate.tool_capacity(String(id))
        if old_capacity!=new_capacity:
            result.tools.append({"id":String(id),"name":String(build.catalog.tools[id].name),"before":old_capacity,"after":new_capacity,
                "stock_before":int(build.state.tool_counts.get(id,0)),"stock_after":int(candidate.state.tool_counts.get(id,0))})
    for crest in build.state.unlocked_crests:
        var layout: Dictionary=build.catalog.crests[crest].slot_layout
        for family in layout:
            for index in layout[family].size():
                if not build._slot_unlocked(family,index,crest) and candidate._slot_unlocked(family,index,crest):
                    result.slots.append({"crest":String(crest),"name":String(build.catalog.crests[crest].name),"family":String(family),"index":index})
    for id in candidate.state.unlocked_passives:
        if not build.state.unlocked_passives.has(id):result.equipment.append({"id":String(id),"name":String(build.catalog.passives[id].name)})
    for id in build.catalog.skills:
        if build.skill_branch(String(id))==candidate.skill_branch(String(id)):continue
        var skill: Dictionary=build.catalog.skills[id]
        result.skills.append({"id":String(id),"name":String(skill.name),"before":String(skill.get("branches",{}).get(build.skill_branch(String(id)),{}).get("name","未校习")),
            "after":String(skill.get("branches",{}).get(candidate.skill_branch(String(id)),{}).get("name","未校习"))})
    for id in candidate.state.crafted:
        if build.state.crafted.has(id):continue
        var recipe: Dictionary=build.catalog.recipes[id]
        if String(recipe.kind)=="slot_part":result.parts.append(String(recipe.name))
    result.available=true
    return result

static func text(effects: Dictionary) -> String:
    if not effects.available:return "整单条件不足，暂不展示可提交的构筑结果。"
    var lines: Array[String]=["整单制作后的实际变化（不会自动装备）"]
    for tool in effects.tools:
        lines.append("%s容量：%d → %d；现有次数：%d → %d" % [tool.name,tool.before,tool.after,tool.stock_before,tool.stock_after])
    for name in effects.parts:lines.append("取得部件："+String(name)+"；仍需对应契印的机制修复条件。")
    for slot in effects.slots:lines.append("%s · %s第%d槽：锁定 → 可用" % [slot.name,String(FAMILIES.get(slot.family,slot.family)),int(slot.index)+1])
    for item in effects.equipment:lines.append("新增可装备："+String(item.name)+"；装备后的取舍请另在装备页核对。")
    for skill in effects.skills:lines.append("%s校习：%s → %s" % [skill.name,skill.before,skill.after])
    if lines.size()==1:lines.append("此清单没有新增容量、槽位、可装备物或校习方向。")
    lines.append("预览来自整单事务候选；不补满生命、绯线或战具，不移动现有装备。")
    return "\n".join(lines)
