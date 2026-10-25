extends RefCounted
const V := preload("res://journey/fieldwork/scalars.gd")
const STORY := preload("res://scripts/world_narrative.gd")


static func positive(value: Variant) -> bool:
    return V.count(value, 1000000) and float(value) > 0


static func flag(value: Variant) -> bool:
    return value is bool and value


static func rectangle(value: Variant) -> Rect2:
    if not value is Array or value.size() != 4:
        return Rect2()
    for item in value:
        if not V.number(item) or absf(float(item)) > 1000000:
            return Rect2()
    var rect := Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
    return rect if rect.size.x > 0 and rect.size.y > 0 else Rect2()


static func rooms(snapshot: Dictionary) -> Array:
    var result := []
    var region := String(snapshot.get("region", ""))
    var visits: Dictionary = snapshot.get("regions", {}).get(region, {}).get("visited_rooms", {})
    for source in snapshot.get("config", {}).get("map_rooms", []):
        if not source is Dictionary or not source.get("id") is String:
            continue
        if not flag(visits.get(source.id)) and source.id != snapshot.get("room"):
            continue
        var row: Dictionary = source.duplicate(true)
        row["key"] = region + ":" + String(source.id)
        row["region"] = region
        row["region_name"] = String(snapshot.get("region_name", ""))
        result.append(row)
    return result


static func room_index(snapshot: Dictionary) -> Dictionary:
    var result := {}
    for row in rooms(snapshot):
        result[String(row.id)] = row
    return result


static func inventory(snapshot: Dictionary) -> Array:
    var result := []
    for id in snapshot.get("inventory", {}):
        var amount: Variant = snapshot.inventory[id]
        if id is String and positive(amount):
            result.append({"id": id, "name": item_name(snapshot, id), "count": int(amount)})
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            return String(a.name).naturalnocasecmp_to(String(b.name)) < 0
    )
    return result


static func item_name(snapshot: Dictionary, id: String) -> String:
    var source: Variant = snapshot.get("config", {}).get("inventory", {}).get("catalog", {})
    if source is Dictionary and source.get(id) is Dictionary:
        return String(source[id].get("name", id))
    for group in ["skills", "tools", "passives", "crests"]:
        for key in snapshot.get("catalog", {}).get(group, {}):
            var record: Dictionary = snapshot.catalog[group][key]
            if record.get("unlock_item") == id:
                return String(record.get("name", id))
    return id


static func equipment(snapshot: Dictionary) -> Array:
    var result := []
    var state: Dictionary = snapshot.get("build_state", {})
    var owned: Dictionary = state.get("owned", {})
    for group in ["crests", "skills", "tools", "passives"]:
        for id in snapshot.get("catalog", {}).get(group, {}):
            var source: Dictionary = snapshot.catalog[group][id]
            var authorized: bool = id == "crimson" and group == "crests"
            authorized = authorized or (id == "cleave" and group == "skills")
            var ownership: Variant = state.get("unlocked_" + group, owned.get(group, []))
            if ownership is Array:
                authorized = authorized or ownership.has(id)
            elif ownership is Dictionary:
                authorized = authorized or flag(ownership.get(id)) or positive(ownership.get(id))
            if source.has("unlock_item"):
                authorized = (
                    authorized or positive(snapshot.get("inventory", {}).get(source.unlock_item))
                )
            if not authorized:
                continue
            var row: Dictionary = source.duplicate(true)
            row["id"] = id
            row["group"] = group
            result.append(row)
    return result


static func enemies(snapshot: Dictionary) -> Array:
    var combat := V.read_json("res://data/original_creature_combat.json")
    var journal: Dictionary = V.read_json("res://data/enemy_journal.json").get("entries", {})
    var result := []
    for id in combat:
        if not flag(snapshot.get("flags", {}).get("journal_enemy_" + String(id))):
            continue
        if not combat[id] is Dictionary:
            continue
        var row: Dictionary = combat[id].duplicate(true)
        row["id"] = id
        row["name"] = String(journal.get(id, {}).get("name", "已击败敌人"))
        result.append(row)
    return result


static func story(snapshot: Dictionary) -> Dictionary:
    return STORY.new().evaluate_progress(snapshot.get("inventory", {}), snapshot.get("flags", {}))


static func safe_number(value: Variant, fallback: float = 0.0) -> float:
    return float(value) if V.number(value) else fallback


static func describe(value: Variant) -> String:
    if value is Dictionary or value is Array:
        return JSON.stringify(value)
    if value is bool:
        return "是" if value else "否"
    return str(value)


static func csv_cell(value: Variant) -> String:
    var raw := describe(value)
    if not raw.is_empty() and raw[0] in ["=", "+", "-", "@", "\t", "\r"]:
        raw = "'" + raw
    return '"' + raw.replace('"', '""') + '"'


static func csv(headers: Array, rows: Array) -> String:
    var lines: Array[String] = []
    var title: Array[String] = []
    for header in headers:
        title.append(csv_cell(header))
    lines.append(",".join(title))
    for row in rows:
        var cells: Array[String] = []
        for header in headers:
            cells.append(csv_cell(row.get(header, "")))
        lines.append(",".join(cells))
    return "\r\n".join(lines) + "\r\n"


static func distribution(values: Array) -> Dictionary:
    var clean: Array[float] = []
    for value in values:
        if V.number(value):
            clean.append(float(value))
    clean.sort()
    if clean.is_empty():
        return {
            "count": 0,
            "sum": 0.0,
            "mean": 0.0,
            "median": 0.0,
            "min": 0.0,
            "max": 0.0,
            "deviation": 0.0
        }
    var total := 0.0
    for value in clean:
        total += value
    var mean := total / clean.size()
    var variance := 0.0
    for value in clean:
        variance += pow(value - mean, 2)
    var middle := clean.size() / 2
    var median := clean[middle] if clean.size() % 2 else (clean[middle - 1] + clean[middle]) / 2.0
    return {
        "count": clean.size(),
        "sum": total,
        "mean": mean,
        "median": median,
        "min": clean[0],
        "max": clean[-1],
        "deviation": sqrt(variance / clean.size())
    }


static func counts(rows: Array, key: String) -> Dictionary:
    var result := {}
    for row in rows:
        var value := String(row.get(key, "未分类"))
        result[value] = int(result.get(value, 0)) + 1
    return result


static func table(title: String, columns: Array, rows: Array, note: String = "") -> Dictionary:
    return {"kind": "table", "title": title, "columns": columns, "rows": rows, "note": note}


static func notice(title: String, text: String) -> Dictionary:
    return {"kind": "text", "title": title, "text": text}


static func bars(title: String, values: Dictionary, note: String = "") -> Dictionary:
    var rows := []
    for id in values:
        rows.append({"label": String(id), "value": safe_number(values[id])})
    return {"kind": "bars", "title": title, "rows": rows, "note": note}
