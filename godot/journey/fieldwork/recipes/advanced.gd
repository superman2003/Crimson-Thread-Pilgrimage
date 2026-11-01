extends RefCounted
## Exhaustive feasible subsets of the user's at-most-eight selected recipes.
## Resource feasibility is distinct from the independent production quote.
const K := preload("res://journey/fieldwork/knowledge.gd")
const MAX_SELECTED := 8


static func evaluate(payload: Dictionary, recipes: Array, mask: int) -> Dictionary:
    var required := {}
    var money := 0
    var branches := {}
    var chosen := []
    var conflicts := []
    var already := []
    var multiplier := int(payload.multiplier)
    for i in recipes.size():
        if mask & (1 << i) == 0:
            continue
        var recipe: Dictionary = recipes[i]
        chosen.append(recipe.id)
        if recipe.crafted and not payload.include_crafted:
            already.append(recipe.id)
        if recipe.kind == "skill_branch":
            if branches.has(recipe.target):
                conflicts.append(recipe.target)
            branches[recipe.target] = recipe.id
        money += int(recipe.currency) * multiplier
        for id in recipe.materials:
            required[id] = int(required.get(id, 0)) + int(recipe.materials[id]) * multiplier
    for id in required:
        required[id] = int(ceil(float(required[id]) * (1.0 + float(payload.buffer) / 100.0)))
    var deficits := {}
    for id in required:
        var shortfall := int(required[id]) - int(payload.inventory.get(id, 0))
        if shortfall > 0:
            deficits[id] = shortfall
    var wallet_gap := maxi(0, money - int(payload.wallet))
    return {
        "ids": chosen, "mask": mask, "count": chosen.size(), "currency": money,
        "materials": required, "deficits": deficits, "wallet_gap": wallet_gap,
        "conflicts": conflicts, "already": already,
        "feasible": deficits.is_empty() and wallet_gap == 0 and conflicts.is_empty() and already.is_empty()
    }


static func enumerate(payload: Dictionary) -> Dictionary:
    if not payload.get("selected") is Array or payload.selected.size() > MAX_SELECTED:
        return {"ok": false, "reason": "最多精确比较八个已选配方"}
    var index := {}
    for row in payload.get("recipes", []):
        index[row.id] = row
    var recipes := []
    var seen := {}
    for id in payload.selected:
        if not index.has(id) or seen.has(id):
            return {"ok": false, "reason": "配方不存在或重复"}
        seen[id] = true
        recipes.append(index[id])
    var all := []
    var best := 0
    for mask in (1 << recipes.size()):
        var result := evaluate(payload, recipes, mask)
        all.append(result)
        if result.feasible:
            best = maxi(best, result.count)
    var maximal := []
    for result in all:
        if not result.feasible:
            continue
        var extendable := false
        for i in recipes.size():
            if result.mask & (1 << i) == 0 and all[result.mask | (1 << i)].feasible:
                extendable = true
                break
        if not extendable:
            maximal.append(result)
    maximal.sort_custom(func(a: Dictionary, b: Dictionary):
        if a.count != b.count:
            return a.count > b.count
        if a.currency != b.currency:
            return a.currency < b.currency
        return int(a.mask) < int(b.mask))
    var essential := []
    for id in payload.selected:
        var appears := false
        var every := true
        for result in all:
            if result.feasible and result.count == best:
                appears = true
                every = every and result.ids.has(id)
        if appears and every:
            essential.append(id)
    return {
        "ok": true, "all": all, "maximal": maximal, "best": best,
        "essential": essential, "tested": all.size(), "recipes": recipes
    }


static func opportunity(result: Dictionary) -> Array:
    if not result.get("ok", false):
        return []
    var rows := []
    for recipe in result.recipes:
        var with_recipe := -1
        var without_recipe := -1
        for subset in result.all:
            if not subset.feasible:
                continue
            if subset.ids.has(recipe.id):
                with_recipe = maxi(with_recipe, subset.count)
            else:
                without_recipe = maxi(without_recipe, subset.count)
        rows.append({
            "配方": recipe.name,
            "包含时最多项": with_recipe if with_recipe >= 0 else "不可行",
            "不包含时最多项": without_recipe,
            "全部最多项组合必含": "是" if result.essential.has(recipe.id) else "否"
        })
    return rows


static func certify(payload: Dictionary, result: Dictionary) -> bool:
    if not result.get("ok", false) or result.tested != 1 << result.recipes.size():
        return false
    for row in result.maximal:
        var replay := evaluate(payload, result.recipes, int(row.mask))
        if replay != row or not replay.feasible:
            return false
    return true


static func sections(payload: Dictionary) -> Array:
    var result := enumerate(payload)
    if not result.ok:
        return [K.notice("配方精确取舍", result.reason)]
    var labels := {}
    for recipe in result.recipes:
        labels[recipe.id] = recipe.name
    var rows := []
    for subset in result.maximal.slice(0, 20):
        var names := []
        for id in subset.ids:
            names.append(labels.get(id, id))
        rows.append({
            "互不扩展组合": "、".join(names) if not names.is_empty() else "暂不制作",
            "项数": subset.count, "货币": subset.currency,
            "材料种类": subset.materials.size()
        })
    var full: Dictionary = result.all[-1]
    var gaps := []
    for id in full.deficits:
        gaps.append({"材料": payload.labels.get(id, id), "全选缺口": full.deficits[id]})
    return [
        K.notice("八项以内精确组合", "枚举%d个子集，最多同时满足%d项；复演证书%s。只做当前物资约束试算，不执行制作或解锁。"
            % [result.tested, result.best, "通过" if certify(payload, result) else "未通过"]),
        K.table("不可再扩展的可行组合（前20项）", ["互不扩展组合", "项数", "货币", "材料种类"], rows),
        K.table("单项机会成本", ["配方", "包含时最多项", "不包含时最多项", "全部最多项组合必含"], opportunity(result)),
        K.table("全部目标的共同缺口", ["材料", "全选缺口"], gaps,
            "安全余量按合计需求向上取整。同一技能的分支互斥、已制成过滤与资金同时参与。正式制作仍须原有独立构筑报价通过。")
    ]
