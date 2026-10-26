extends RefCounted
## Per-challenge persistent settings and bounded attempt history.
const ENGINE := preload("res://journey/k_trials/engine.gd")
const V := preload("res://journey/core/values.gd")
const MODE := "turnaround"
const TITLE := "远行折返"
const DESCRIPTION := "先离起点至少一千像素，再回到起点八十像素内。"
const DEFAULT := 1.0
const MINIMUM := 1.0
const MAXIMUM := 1.0
const UNIT := "次"
const HISTORY_LIMIT := 40

static func fresh() -> Dictionary:
    return {
        "version":1,
        "target":DEFAULT,
        "records":[],
    }

static func target_valid(value: Variant) -> bool:
    return V.number(value) and float(value) >= MINIMUM and float(value) <= MAXIMUM and floor(float(value)) == float(value)

static func valid(candidate: Dictionary) -> bool:
    if not V.count(candidate.get("version"), 1) or candidate.get("version") != 1 or not target_valid(candidate.get("target")):
        return false
    if not candidate.get("records") is Array or candidate.records.size() > HISTORY_LIMIT:
        return false
    for r in candidate.records:
        if not r is Dictionary or not ENGINE.record_valid(r, MODE):
            return false
    return V.json_safe(candidate, 0, [10000])

static func configure(data: Dictionary, target: Variant) -> Dictionary:
    if not valid(data) or not target_valid(target):
        return data.duplicate(true)
    var out := data.duplicate(true)
    out.target = float(target)
    return out

static func start(data: Dictionary, snapshot: Dictionary) -> Dictionary:
    if not valid(data):
        return {}
    return ENGINE.begin(MODE, snapshot, float(data.target))

static func append(data: Dictionary, run: Dictionary, timestamp: int) -> Dictionary:
    if not valid(data):
        return data.duplicate(true)
    var record := ENGINE.record(run, timestamp)
    if not ENGINE.record_valid(record, MODE):
        return data.duplicate(true)
    var out := data.duplicate(true)
    out.records.append(record)
    while out.records.size() > HISTORY_LIMIT:
        out.records.pop_front()
    return out

static func records(data: Dictionary, query: String = "", state: String = "all") -> Array:
    if not valid(data):
        return []
    var rows: Array = []
    for r in data.records:
        if state != "all" and r.state != state:
            continue
        if V.matches(query, [r.region, r.room, r.reason]):
            rows.push_front(r.duplicate(true))
    return rows

static func document(data: Dictionary, query: String = "", state: String = "all") -> String:
    var lines := PackedStringArray([TITLE, DESCRIPTION, "仅为本次工具启用后的离散观察，不作完整战斗或自然通关证明。"])
    for r in records(data, query, state):
        lines.append("%s | %s | %.2f / %.2f %s | %.2f 秒 | %s/%s | %s" % [
            V.date(int(r.time)), r.state, r.progress, r.target, UNIT,
            r.elapsed, r.region, r.room, r.reason])
    return "\n".join(lines) + "\n"
