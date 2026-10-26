extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const BUILD := preload("res://scripts/build_system.gd")
const VIEW := preload("res://journey/fieldwork/recipes/view.gd")


static func introduction() -> String:
    return "整理已获动作与已持图样可公开的改制方案，分析共享材料与图样门槛；当前报价通过独立构筑实例复核，不执行制作。"


static func known_recipes(snapshot: Dictionary) -> Array:
    var equipment := {}
    for row in K.equipment(snapshot):
        equipment[row.id] = true
    var result := []
    var inventory: Dictionary = snapshot.get("inventory", {})
    var flags: Dictionary = snapshot.get("flags", {})
    for id in snapshot.get("catalog", {}).get("recipes", {}):
        var source: Dictionary = snapshot.catalog.recipes[id]
        var kind := String(source.get("kind", ""))
        var target := String(source.get("target", ""))
        var allowed := equipment.has(target)
        if kind in ["passive", "slot_part"]:
            allowed = not source.get("requires_items", []).is_empty()
        for item in source.get("requires_items", []):
            allowed = allowed and K.positive(inventory.get(item))
        var required := String(source.get("requires_flag", ""))
        if not required.is_empty():
            allowed = allowed and K.flag(flags.get(required))
        var artisan := String(source.get("artisan", ""))
        if not artisan.is_empty():
            allowed = allowed and K.flag(flags.get("npc_met_" + artisan))
        if not allowed:
            continue
        var materials := {}
        for material in source.get("materials", {}):
            if V.count(source.materials[material], 100000):
                materials[material] = int(source.materials[material])
        result.append(
            {
                "id": id,
                "name": String(source.get("name", id)),
                "kind": kind,
                "target": target,
                "currency": int(source.get("currency", 0)),
                "materials": materials,
                "proofs": source.get("requires_items", []).duplicate(),
                "crafted": snapshot.get("build_state", {}).get("crafted", []).has(id)
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            return String(a.name).naturalnocasecmp_to(String(b.name)) < 0
    )
    return result.slice(0, 100)


static func capture(snapshot: Dictionary) -> Dictionary:
    var recipes := known_recipes(snapshot)
    var chosen := []
    if not recipes.is_empty():
        chosen.append(recipes[0].id)
    var inventory := {}
    for row in K.inventory(snapshot):
        inventory[row.id] = row.count
    var labels := {}
    for recipe in recipes:
        for id in recipe.materials:
            labels[id] = K.item_name(snapshot, id)
        for id in recipe.proofs:
            labels[id] = K.item_name(snapshot, id)
    return {
        "recipes": recipes,
        "selected": chosen,
        "inventory": inventory,
        "labels": labels,
        "wallet": int(snapshot.get("wallet", 0)),
        "multiplier": 1.0,
        "buffer": 0.0,
        "include_crafted": false
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("recipes") is Array
        or payload.recipes.size() > 100
        or not payload.get("selected") is Array
        or payload.selected.size() > 8
    ):
        return false
    if (
        not payload.get("inventory") is Dictionary
        or payload.inventory.size() > 500
        or not payload.get("labels") is Dictionary
        or payload.labels.size() > 300
    ):
        return false
    if (
        not V.count(payload.get("wallet"))
        or not V.count(payload.get("multiplier"), 20)
        or payload.multiplier < 1
    ):
        return false
    if (
        not V.number(payload.get("buffer"))
        or payload.buffer < 0
        or payload.buffer > 100
        or not payload.get("include_crafted") is bool
    ):
        return false
    var ids := {}
    for recipe in payload.recipes:
        if not recipe is Dictionary or not recipe.get("id") is String or ids.has(recipe.id):
            return false
        if (
            not recipe.get("name") is String
            or recipe.name.length() > 200
            or not recipe.get("kind") is String
            or not recipe.get("target") is String
        ):
            return false
        if (
            not V.count(recipe.get("currency"))
            or not recipe.get("materials") is Dictionary
            or recipe.materials.size() > 30
        ):
            return false
        if (
            not recipe.get("proofs") is Array
            or recipe.proofs.size() > 20
            or not recipe.get("crafted") is bool
        ):
            return false
        for material in recipe.materials:
            if not material is String or not V.count(recipe.materials[material], 100000):
                return false
        for proof in recipe.proofs:
            if not proof is String or proof.length() > 120:
                return false
        ids[recipe.id] = true
    var selected := {}
    for id in payload.selected:
        if not id is String or not ids.has(id) or selected.has(id):
            return false
        selected[id] = true
    for id in payload.inventory:
        if not id is String or not V.count(payload.inventory[id]):
            return false
    for id in payload.labels:
        if (
            not id is String
            or not payload.labels[id] is String
            or payload.labels[id].length() > 200
        ):
            return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for recipe in payload.recipes:
        if not recipe.crafted or payload.include_crafted:
            choices.append({"id": recipe.id, "name": recipe.name})
    return [
        {"id": "selected", "name": "计划方案（最多8项）", "kind": "checklist", "choices": choices},
        {"id": "multiplier", "name": "纯资源假设倍率", "kind": "number", "min": 1, "max": 20},
        {"id": "buffer", "name": "材料安全余量百分比", "kind": "number", "min": 0, "max": 100, "step": 5},
        {"id": "include_crafted", "name": "列出已制作方案", "kind": "toggle"}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d 个已公开配方 · 已选%d项 · 资金%d"
        % [payload.recipes.size(), payload.selected.size(), payload.wallet]
    )


static func index(payload: Dictionary) -> Dictionary:
    var result := {}
    for recipe in payload.recipes:
        result[recipe.id] = recipe
    return result


static func selected(payload: Dictionary) -> Array:
    var all := index(payload)
    var result := []
    for id in payload.selected:
        if all.has(id):
            result.append(all[id])
    return result


static func requirements(payload: Dictionary) -> Dictionary:
    var materials := {}
    var currency := 0
    var proofs := {}
    for recipe in selected(payload):
        currency += int(recipe.currency) * int(payload.multiplier)
        for id in recipe.materials:
            materials[id] = (
                int(materials.get(id, 0)) + int(recipe.materials[id]) * int(payload.multiplier)
            )
        for id in recipe.proofs:
            proofs[id] = true
    var base := materials.duplicate()
    for id in materials:
        materials[id] = int(ceil(float(materials[id]) * (1 + float(payload.buffer) / 100.0)))
    return {"currency": currency, "materials": materials, "base": base, "proofs": proofs.keys()}


static func material_rows(payload: Dictionary) -> Array:
    var need := requirements(payload)
    var result := []
    for id in need.materials:
        var held := int(payload.inventory.get(id, 0))
        var count := int(need.materials[id])
        result.append(
            {
                "材料": String(payload.labels.get(id, id)),
                "基础需求": need.base[id],
                "含余量需求": count,
                "现有": held,
                "缺口": maxi(0, count - held),
                "余量后余额": held - count,
                "id": id
            }
        )
    result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["缺口"]) > int(b["缺口"]))
    return result


static func branch_conflicts(payload: Dictionary) -> Array:
    var groups := {}
    for recipe in selected(payload):
        if recipe.kind == "skill_branch":
            if not groups.has(recipe.target):
                groups[recipe.target] = []
            groups[recipe.target].append(recipe.name)
    var result := []
    for id in groups:
        if groups[id].size() > 1:
            result.append(
                {"动作": id, "冲突方向": " / ".join(groups[id]), "说明": "同一技能不能在一份生产批次中选择两个校习方向"}
            )
    return result


static func sharing(payload: Dictionary) -> Array:
    var consumers := {}
    for recipe in payload.recipes:
        for id in recipe.materials:
            if not consumers.has(id):
                consumers[id] = []
            consumers[id].append(recipe.name)
    var result := []
    for id in consumers:
        result.append(
            {
                "材料": String(payload.labels.get(id, id)),
                "关联配方数": consumers[id].size(),
                "关联配方": " / ".join(consumers[id])
            }
        )
    result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["关联配方数"]) > int(b["关联配方数"]))
    return result


static func recipe_affordability(payload: Dictionary) -> Array:
    var result := []
    for recipe in payload.recipes:
        var shortages := []
        if int(recipe.currency) > int(payload.wallet):
            shortages.append("资金" + str(int(recipe.currency) - int(payload.wallet)))
        for id in recipe.materials:
            var missing := int(recipe.materials[id]) - int(payload.inventory.get(id, 0))
            if missing > 0:
                shortages.append(String(payload.labels.get(id, id)) + str(missing))
        var status := "资源足够"
        if not shortages.is_empty():
            status = "缺少 " + "、".join(shortages)
        if recipe.crafted:
            status = "记录中已经制作"
        result.append(
            {"配方": recipe.name, "资金成本": recipe.currency, "资源检查": status, "类型": recipe.kind}
        )
    return result


static func proof_rows(payload: Dictionary) -> Array:
    var result := []
    for id in requirements(payload).proofs:
        result.append(
            {
                "图样": String(payload.labels.get(id, id)),
                "记录中持有": int(payload.inventory.get(id, 0)),
                "是否消耗": "不消耗；按原配方规则核对"
            }
        )
    return result


static func cost_contributions(payload: Dictionary) -> Array:
    var total := maxi(1, int(requirements(payload).currency))
    var result := []
    for recipe in selected(payload):
        var cost := int(recipe.currency) * int(payload.multiplier)
        result.append(
            {
                "配方": recipe.name,
                "资金成本": cost,
                "资金占比": float(cost) / total,
                "材料种类": recipe.materials.size(),
                "图样种类": recipe.proofs.size()
            }
        )
    return result


static func similarity(payload: Dictionary) -> Array:
    var result := []
    for i in payload.recipes.size():
        for j in range(i + 1, payload.recipes.size()):
            var a: Dictionary = payload.recipes[i]
            var b: Dictionary = payload.recipes[j]
            var union := {}
            var common := 0
            for id in a.materials:
                union[id] = true
                if b.materials.has(id):
                    common += 1
            for id in b.materials:
                union[id] = true
            if common > 0:
                result.append(
                    {
                        "方案甲": a.name,
                        "方案乙": b.name,
                        "共享材料种类": common,
                        "材料集合相似度": float(common) / maxf(1, union.size())
                    }
                )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary): return float(a["材料集合相似度"]) > float(b["材料集合相似度"])
    )
    return result.slice(0, 40)


static func production_quote(payload: Dictionary, snapshot: Dictionary) -> Dictionary:
    if payload.selected.is_empty():
        return {"ok": false, "reason": "先选择至少一项方案。"}
    var clone := BUILD.new()
    var restored: Dictionary = clone.restore(snapshot.get("build_state", {}))
    if not restored.ok:
        return {"ok": false, "reason": "当前构筑不能建立独立报价实例。"}
    clone.sync_progress(
        snapshot.get("inventory", {}), String(snapshot.get("region", "")), snapshot.get("flags", {})
    )
    var result: Dictionary = clone.quote_craft_batch(
        payload.selected,
        {
            "currency": int(snapshot.get("wallet", 0)),
            "inventory_counts": snapshot.get("inventory", {}).duplicate(true)
        }
    )
    return result


static func portfolio_pressure(payload: Dictionary) -> Array:
    var result := []
    for row in material_rows(payload):
        var need := int(row["含余量需求"])
        var held := int(row["现有"])
        var pressure := float(need) / maxf(1, held)
        result.append(
            {
                "材料": row["材料"],
                "需求与持有比": pressure,
                "需求": need,
                "现有": held,
                "状态": "需要补足" if need > held else "库存覆盖"
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary): return float(a["需求与持有比"]) > float(b["需求与持有比"])
    )
    return result


static func buffer_sensitivity(payload: Dictionary) -> Array:
    var result := []
    for value in [0, 10, 25, 50, 100]:
        var sample := payload.duplicate(true)
        sample.buffer = float(value)
        var missing := 0
        var amount := 0
        for row in material_rows(sample):
            missing += int(row["缺口"])
            amount += int(row["含余量需求"])
        result.append(
            {
                "余量百分比": value,
                "材料合计": amount,
                "材料缺口合计": missing,
                "资金成本": requirements(sample).currency
            }
        )
    return result


static func dependency_data(payload: Dictionary) -> Dictionary:
    var resources := []
    var recipes := []
    var links := []
    var known := {}
    for recipe in selected(payload):
        recipes.append(
            {
                "id": recipe.id,
                "name": recipe.name,
                "currency": recipe.currency,
                "crafted": recipe.crafted
            }
        )
        for id in recipe.materials:
            if not known.has(id):
                known[id] = true
                resources.append(
                    {
                        "id": id,
                        "name": String(payload.labels.get(id, id)),
                        "held": int(payload.inventory.get(id, 0)),
                        "proof": false
                    }
                )
            links.append(
                {"from": id, "to": recipe.id, "amount": int(recipe.materials[id]), "proof": false}
            )
        for id in recipe.proofs:
            var key := "proof:" + String(id)
            if not known.has(key):
                known[key] = true
                resources.append(
                    {
                        "id": key,
                        "name": String(payload.labels.get(id, id)),
                        "held": int(payload.inventory.get(id, 0)),
                        "proof": true
                    }
                )
            links.append({"from": key, "to": recipe.id, "amount": 1, "proof": true})
    return {"resources": resources, "recipes": recipes, "links": links}


static func analyze(payload: Dictionary, snapshot: Dictionary) -> Array:
    var need := requirements(payload)
    var quote := production_quote(payload, snapshot)
    var conflicts := branch_conflicts(payload)
    var result := [K.notice("已公开改制依赖", summary(payload))]
    result.append(
        {"kind": "custom", "title": "材料与图样依赖图", "view": VIEW, "data": dependency_data(payload)}
    )
    result.append(
        K.notice(
            "资源清单",
            (
                "倍率%d · 资金需求%d · 资金余额%d；材料余量%.0f%%。"
                % [
                    payload.multiplier,
                    need.currency,
                    int(payload.wallet) - int(need.currency),
                    payload.buffer
                ]
            )
        )
    )
    result.append(
        K.table("材料需求展开", ["材料", "基础需求", "含余量需求", "现有", "缺口", "余量后余额"], material_rows(payload))
    )
    result.append(K.table("图样检查", ["图样", "记录中持有", "是否消耗"], proof_rows(payload)))
    result.append(K.table("校习方向冲突", ["动作", "冲突方向", "说明"], conflicts))
    result.append(K.table("单项资源检查", ["配方", "类型", "资金成本", "资源检查"], recipe_affordability(payload)))
    result.append(
        K.table("方案资金贡献", ["配方", "资金成本", "资金占比", "材料种类", "图样种类"], cost_contributions(payload))
    )
    result.append(K.table("共享材料", ["材料", "关联配方数", "关联配方"], sharing(payload)))
    result.append(K.table("材料集合相似方案", ["方案甲", "方案乙", "共享材料种类", "材料集合相似度"], similarity(payload)))
    result.append(K.table("库存压力", ["材料", "需求与持有比", "需求", "现有", "状态"], portfolio_pressure(payload)))
    result.append(
        K.table("安全余量敏感性", ["余量百分比", "材料合计", "材料缺口合计", "资金成本"], buffer_sensitivity(payload))
    )
    result.append(
        K.notice(
            "当前生产报价复核",
            (
                "独立构筑与钱包报价通过；实际制作仍需原工匠、地点和门槛。未执行制作。"
                if quote.ok
                else String(quote.get("reason", "报价未通过"))
            )
        )
    )
    result.append(K.notice("倍率边界", "倍率只是材料计划假设。一次性改制与互斥校习仍由原生产规则限制，所有操作均未写入游戏构筑或钱包。"))
    return result


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var old := requirements(a)
    var current := requirements(b)
    var keys: Dictionary = old.materials.duplicate()
    keys.merge(current.materials, true)
    var result := []
    for id in keys:
        result.append(
            {
                "材料": String(b.labels.get(id, a.labels.get(id, id))),
                "旧需求": int(old.materials.get(id, 0)),
                "新需求": int(current.materials.get(id, 0)),
                "差额": int(current.materials.get(id, 0)) - int(old.materials.get(id, 0))
            }
        )
    return [
        K.notice("资金需求变化", "%d → %d" % [old.currency, current.currency]),
        K.table("材料计划变化", ["材料", "旧需求", "新需求", "差额"], result)
    ]


static func svg(payload: Dictionary) -> String:
    var report := preload("res://journey/fieldwork/vector.gd").new("已公开配方与资源依赖", 1100, 1200)
    report.paragraph(summary(payload))
    var data := dependency_data(payload)
    report.title("材料与图样到已选方案")
    var top := report.cursor
    var positions := {}
    var height := maxf(160, maxi(data.resources.size(), data.recipes.size()) * 32)
    for i in data.resources.size():
        var row: Dictionary = data.resources[i]
        var y: float = top + 25 + i * 32
        positions[row.id] = Vector2(350, y)
        report.rect(Rect2(28, y - 18, 320, 26), "#344336" if row.proof else "#1f3c37")
        report.text(35, y, String(row.name).left(22), 13)
        report.text(265, y, str(row.held), 12, report.MUTED)
    for i in data.recipes.size():
        var row: Dictionary = data.recipes[i]
        var y: float = top + 25 + i * 32
        positions[row.id] = Vector2(730, y)
        report.rect(Rect2(730, y - 18, 340, 26), "#334d3c")
        report.text(740, y, String(row.name).left(22), 13)
    for link in data.links:
        if not positions.has(link.from) or not positions.has(link.to):
            continue
        var a: Vector2 = positions[link.from]
        var b: Vector2 = positions[link.to]
        var color := report.GOLD if link.proof else report.GREEN
        report.line(a, b, color, 1.5)
        report.text(a.lerp(b, 0.5).x, a.lerp(b, 0.5).y - 4, str(link.amount), 12, color)
    report.cursor = top + height + 30
    report.paragraph("金色线表示只出示的图样；绿色线表示会按配方消耗的材料。此图没有执行制作。")
    report.table("材料展开与余量", ["材料", "基础需求", "含余量需求", "现有", "缺口"], material_rows(payload))
    report.table("个人计划资金贡献", ["配方", "资金成本", "资金占比", "材料种类"], cost_contributions(payload))
    report.table("方向冲突", ["动作", "冲突方向", "说明"], branch_conflicts(payload))
    report.table("安全余量敏感性", ["余量百分比", "材料合计", "材料缺口合计", "资金成本"], buffer_sensitivity(payload))
    return report.finish("倍率是纯资源假设。真实的一次性改制、图样与方向规则仍由原制作系统判断。")
