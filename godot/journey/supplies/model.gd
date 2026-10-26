extends RefCounted
const V := preload("res://journey/core/values.gd")
const MAX_PACKS := 8
const MAX_LINES := 24
const PRIORITIES := ["急需", "备用", "长期"]

static func fresh() -> Dictionary:
    return {"version":1, "sequence":0, "packs":[], "seen":{}, "reserve":{}, "selected":""}

static func valid(data: Dictionary) -> bool:
    if data.get("version") != 1 or not V.count(data.get("sequence")):
        return false
    if not data.get("packs") is Array or data.packs.size() > MAX_PACKS:
        return false
    if not data.get("seen") is Dictionary or data.seen.size() > 512:
        return false
    if not data.get("reserve") is Dictionary or data.reserve.size() > 512:
        return false
    var identities := {}
    for pack in data.packs:
        if not pack is Dictionary or not pack.get("id") is String:
            return false
        if identities.has(pack.id) or V.text(pack.get("name"), 40).is_empty():
            return false
        if not pack.get("lines") is Array or pack.lines.size() > MAX_LINES:
            return false
        if not pack.get("note") is String or pack.note.length() > 500:
            return false
        identities[pack.id] = true
        var items := {}
        for line in pack.lines:
            if not line is Dictionary or not line.get("item") is String or items.has(line.item):
                return false
            if not V.count(line.get("target"), 9999) or int(line.target) < 1:
                return false
            if not V.count(line.get("priority"), 2) or not line.get("done") is bool:
                return false
            items[line.item] = true
    for key in data.seen:
        if not key is String or not data.seen[key] is String or data.seen[key].length() > 100:
            return false
    for key in data.reserve:
        if not key is String or not V.count(data.reserve[key], 9999):
            return false
    return V.json_safe(data, 0, [V.MAX_ITEMS])

static func observe(data: Dictionary, snapshot: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    var catalog: Dictionary = preload("res://journey/core/public_catalog.gd").items(snapshot)
    for id in snapshot.get("inventory", {}):
        if not V.held(snapshot.inventory[id]) or not catalog.get(id) is Dictionary:
            continue
        if result.seen.has(id):
            continue
        if result.seen.size() >= 512:
            break
        result.seen[id] = V.text(String(catalog[id].get("name", id)), 100)
    return result

static func pack(data: Dictionary, id: String) -> Dictionary:
    for record in data.packs:
        if record.id == id:
            return record.duplicate(true)
    return {}

static func create(data: Dictionary, title: String) -> Dictionary:
    var result := data.duplicate(true)
    var name := V.text(title, 40)
    if name.is_empty() or result.packs.size() >= MAX_PACKS:
        return result
    for record in result.packs:
        if String(record.name).nocasecmp_to(name) == 0:
            return result
    result.sequence = int(result.sequence) + 1
    var id := "pack_" + str(int(result.sequence))
    result.packs.append({"id":id, "name":name, "note":"", "lines":[], "created":int(Time.get_unix_time_from_system())})
    result.selected = id
    return result

static func duplicate_pack(data: Dictionary, id: String, title: String) -> Dictionary:
    var source := pack(data, id)
    var result := create(data, title)
    if source.is_empty() or result.packs.size() == data.packs.size():
        return data.duplicate(true)
    var copy: Dictionary = result.packs[-1]
    copy.lines = source.lines.duplicate(true)
    copy.note = source.note
    for line in copy.lines:
        line.done = false
    return result

static func rename(data: Dictionary, id: String, title: String) -> Dictionary:
    var result := data.duplicate(true)
    var name := V.text(title, 40)
    if name.is_empty():
        return result
    for record in result.packs:
        if record.id != id and String(record.name).nocasecmp_to(name) == 0:
            return result
    for record in result.packs:
        if record.id == id:
            record.name = name
    return result

static func remove(data: Dictionary, id: String) -> Dictionary:
    var result := data.duplicate(true)
    for index in range(result.packs.size() - 1, -1, -1):
        if result.packs[index].id == id:
            result.packs.remove_at(index)
    if result.selected == id:
        result.selected = String(result.packs[0].id) if not result.packs.is_empty() else ""
    return result

static func reorder(data: Dictionary, id: String, direction: int) -> Dictionary:
    var result := data.duplicate(true)
    for index in result.packs.size():
        if result.packs[index].id != id:
            continue
        var target := clampi(index + signi(direction), 0, result.packs.size() - 1)
        var temporary: Dictionary = result.packs[index]
        result.packs[index] = result.packs[target]
        result.packs[target] = temporary
        break
    return result

static func note(data: Dictionary, id: String, value: String) -> Dictionary:
    var result := data.duplicate(true)
    for record in result.packs:
        if record.id == id:
            record.note = V.text(value, 500)
    return result

static func line(data: Dictionary, pack_id: String, item: String, target: int, priority: int) -> Dictionary:
    var result := data.duplicate(true)
    if not result.seen.has(item) or target < 1 or target > 9999 or priority < 0 or priority > 2:
        return result
    for record in result.packs:
        if record.id != pack_id:
            continue
        for entry in record.lines:
            if entry.item == item:
                entry.target = target
                entry.priority = priority
                return result
        if record.lines.size() < MAX_LINES:
            record.lines.append({"item":item, "target":target, "priority":priority, "done":false})
    return result

static func remove_line(data: Dictionary, pack_id: String, item: String) -> Dictionary:
    var result := data.duplicate(true)
    for record in result.packs:
        if record.id != pack_id:
            continue
        for index in range(record.lines.size() - 1, -1, -1):
            if record.lines[index].item == item:
                record.lines.remove_at(index)
    return result

static func set_done(data: Dictionary, pack_id: String, item: String, value: bool) -> Dictionary:
    var result := data.duplicate(true)
    for record in result.packs:
        if record.id == pack_id:
            for entry in record.lines:
                if entry.item == item:
                    entry.done = value
    return result

static func reserve(data: Dictionary, item: String, value: int) -> Dictionary:
    var result := data.duplicate(true)
    if not result.seen.has(item) or value < 0 or value > 9999:
        return result
    if value == 0:
        result.reserve.erase(item)
    else:
        result.reserve[item] = value
    return result

static func items(data: Dictionary, inventory: Dictionary, query: String = "") -> Array:
    var result := []
    for id in data.seen:
        var title := String(data.seen[id])
        if not V.matches(query, [title, String(id)]):
            continue
        var count := int(inventory.get(id, 0)) if V.count(inventory.get(id, 0)) else 0
        result.append({"id":id, "name":title, "held":count, "reserve":int(data.reserve.get(id, 0))})
    result.sort_custom(func(a: Dictionary, b: Dictionary):return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
    return result

static func allocate(data: Dictionary, inventory: Dictionary) -> Dictionary:
    var available := {}
    var totals := {}
    for id in data.seen:
        var held := int(inventory.get(id, 0)) if V.count(inventory.get(id, 0)) else 0
        available[id] = maxi(0, held - int(data.reserve.get(id, 0)))
        totals[id] = {"held":held, "reserve":int(data.reserve.get(id, 0)), "requested":0, "allocated":0, "missing":0}
    var rows := []
    # Priority first, then the visible pack order. A material unit is allocated
    # at most once across every plan; the real inventory remains untouched.
    for priority in 3:
        for record in data.packs:
            for entry in record.lines:
                if entry.done or int(entry.priority) != priority or not data.seen.has(entry.item):
                    continue
                var id := String(entry.item)
                var desired := int(entry.target)
                var granted := mini(desired, int(available.get(id, 0)))
                available[id] = int(available.get(id, 0)) - granted
                totals[id].requested += desired
                totals[id].allocated += granted
                totals[id].missing += desired - granted
                rows.append({"pack":record.id, "pack_name":record.name, "item":id, "name":data.seen[id], "target":desired, "allocated":granted, "missing":desired - granted, "priority":priority})
    return {"rows":rows, "totals":totals, "remaining":available}

static func summary(data: Dictionary, inventory: Dictionary, pack_id: String) -> Dictionary:
    var allocation := allocate(data, inventory)
    var requested := 0
    var allocated := 0
    var complete := 0
    var rows := []
    for row in allocation.rows:
        if row.pack != pack_id:
            continue
        requested += int(row.target)
        allocated += int(row.allocated)
        if int(row.missing) == 0:
            complete += 1
        rows.append(row)
    return {"rows":rows, "requested":requested, "allocated":allocated, "complete":complete, "missing":requested - allocated}

static func compare(data: Dictionary, left: String, right: String) -> Array:
    var a := pack(data, left)
    var b := pack(data, right)
    var values := {}
    for entry in a.get("lines", []):
        if entry.done:
            continue
        values[entry.item] = {"left":int(entry.target), "right":0}
    for entry in b.get("lines", []):
        if entry.done:
            continue
        if not values.has(entry.item):
            values[entry.item] = {"left":0, "right":0}
        values[entry.item].right = int(entry.target)
    var result := []
    for id in values:
        if not data.seen.has(id):
            continue
        result.append({"id":id, "name":data.seen[id], "left":values[id].left, "right":values[id].right, "difference":int(values[id].right) - int(values[id].left)})
    result.sort_custom(func(x: Dictionary, y: Dictionary):return String(x.name).naturalnocasecmp_to(String(y.name)) < 0)
    return result

static func document(data: Dictionary, inventory: Dictionary) -> String:
    var lines: Array[String] = ["物资储备计划", "仅供规划；未移动、购买或消耗任何游戏物资。", ""]
    var allocation := allocate(data, inventory)
    for record in data.packs:
        lines.append("【" + String(record.name) + "】")
        if not String(record.note).is_empty():
            lines.append(String(record.note))
        for row in allocation.rows:
            if row.pack == record.id:
                lines.append("%s：目标%d / 可分配%d / 缺%d · %s" % [row.name, row.target, row.allocated, row.missing, PRIORITIES[int(row.priority)]])
        lines.append("")
    return "\n".join(lines)

static func import_pack(data: Dictionary, raw: String, title: String) -> Dictionary:
    if raw.to_utf8_buffer().size() > 65536:
        return {"ok":false, "reason":"清单内容过大。"}
    var parsed: Variant = V.parse_json(raw)
    if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("lines") is Array:
        return {"ok":false, "reason":"清单格式无法识别。"}
    if parsed.lines.size() > MAX_LINES:
        return {"ok":false, "reason":"单份清单最多24种物资。"}
    var candidate := create(data, title)
    if candidate.packs.size() == data.packs.size():
        return {"ok":false, "reason":"名称重复、为空或清单数量已满。"}
    var id := String(candidate.selected)
    for entry in parsed.lines:
        if not entry is Dictionary or not entry.get("item") is String:
            return {"ok":false, "reason":"物资字段无效。"}
        if not candidate.seen.has(entry.item) or not V.count(entry.get("target"), 9999) or int(entry.target) < 1:
            return {"ok":false, "reason":"清单包含未见物资或无效数量。"}
        if not V.count(entry.get("priority", 1), 2):
            return {"ok":false, "reason":"物资优先级无效。"}
        candidate = line(candidate, id, String(entry.item), int(entry.target), int(entry.get("priority", 1)))
    if not valid(candidate):
        return {"ok":false, "reason":"清单未通过检查。"}
    return {"ok":true, "data":candidate, "reason":"已导入规划清单；库存没有变化。"}

static func audit(data: Dictionary, inventory: Dictionary, allocation: Dictionary) -> Dictionary:
    var errors := []
    var allocated := {}
    var requested := {}
    for row in allocation.get("rows", []):
        if not V.count(row.get("target"), 9999) or not V.count(row.get("allocated"), 9999) or not V.count(row.get("missing"), 9999):
            errors.append("分配行包含无效数量。")
            continue
        if int(row.allocated) + int(row.missing) != int(row.target):
            errors.append("目标数量没有完整分解为可分配与缺口。")
        var id := String(row.get("item", ""))
        if not data.seen.has(id):
            errors.append("分配包含未见物资。")
        allocated[id] = int(allocated.get(id, 0)) + int(row.allocated)
        requested[id] = int(requested.get(id, 0)) + int(row.target)
    for id in allocated:
        var held := int(inventory.get(id, 0)) if V.count(inventory.get(id, 0)) else 0
        var reserve := int(data.reserve.get(id, 0))
        if int(allocated[id]) > maxi(0, held - reserve):
            errors.append("同一份库存被重复分配或侵占了预留量。")
        var total: Dictionary = allocation.get("totals", {}).get(id, {})
        if int(total.get("allocated", -1)) != int(allocated[id]) or int(total.get("requested", -1)) != int(requested[id]):
            errors.append("合计与逐项分配不一致。")
    return {"ok":errors.is_empty(), "errors":errors, "items":allocated.size()}
