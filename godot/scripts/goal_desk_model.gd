extends RefCounted
const LIMIT := 3
var state := {"pins":[], "notes":{}, "hud":true}
var store := preload("res://scripts/journey_desk_store.gd").new()

static func valid_key(value: Variant) -> bool:
    return value is String and value.length() <= 128 and (value.begins_with("quest:") or value.begins_with("main:")) and value.get_slice(":",1) != ""

func configure(journey: String) -> void:
    store.configure("goals", journey)
    restore(store.read())

func restore(raw: Dictionary) -> void:
    state = {"pins":[], "notes":{}, "hud":true}
    if raw.get("pins") is Array:
        for key in raw.pins.slice(0,32):
            if valid_key(key) and not state.pins.has(key) and state.pins.size() < LIMIT:state.pins.append(key)
    if raw.get("notes") is Dictionary:
        for key in state.pins:
            if raw.notes.get(key) is String:state.notes[key] = String(raw.notes[key]).left(160)
    if raw.get("hud") is bool:state.hud = raw.hud

func change(command: String, key: String, known: Array, value: Variant = null) -> Dictionary:
    var candidate := state.duplicate(true)
    var public_keys: Array = known.map(func(row):return String(row.key))
    match command:
        "pin":
            if not public_keys.has(key) or not valid_key(key):return {"ok":false,"reason":"只能追踪当前已知的主线或委托。"}
            if candidate.pins.has(key):return {"ok":true}
            if candidate.pins.size() >= LIMIT:return {"ok":false,"reason":"最多追踪三项目标，请先取消一项。"}
            candidate.pins.append(key)
        "remove":candidate.pins.erase(key);candidate.notes.erase(key)
        "first":
            if not candidate.pins.has(key):return {"ok":false,"reason":"请先追踪此目标。"}
            candidate.pins.erase(key);candidate.pins.push_front(key)
        "note":
            if not candidate.pins.has(key) or not value is String:return {"ok":false,"reason":"先追踪目标，再保存备注。"}
            candidate.notes[key] = String(value).strip_edges().left(160)
        "hud":
            if not value is bool:return {"ok":false,"reason":"显示选项无效。"}
            candidate.hud = value
        _:return {"ok":false,"reason":"操作无效。"}
    if not store.write(candidate):return {"ok":false,"reason":store.error}
    state = candidate
    return {"ok":true,"reason":"追踪记录已保存；剧情进度不变。"}

static func filter_rows(rows: Array, query: String, mode: int) -> Array:
    var result: Array = []
    var tokens := query.left(80).to_lower().split(" ",false)
    for row in rows:
        if mode == 1 and bool(row.complete):continue
        if mode == 2 and not bool(row.complete):continue
        var public_text := (String(row.title)+"\n"+String(row.text)).to_lower()
        var matches := true
        for token in tokens:
            if not public_text.contains(token):matches = false;break
        if matches:result.append(row)
    return result
