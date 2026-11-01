extends RefCounted
const V := preload("res://journey/core/values.gd")
const PATH := "res://data/original_creature_combat.json"
const JOURNAL := "res://data/enemy_journal.json"
const TYPES := {"melee":"近身", "lunge":"突进", "fan":"扇射", "pool":"落池", "dive":"俯冲", "guard":"架势", "wave":"低波", "vault":"跃刺", "mortar":"抛弹", "beam":"光束", "projectile":"直射", "feint":"虚晃", "combo":"连段", "nova":"环射", "rootline":"根刺", "blink":"闪位", "retreat":"退刺"}
const FIELDS := {"range":"参考距离", "windup":"前摇秒数", "active":"判定秒数", "recover":"收势秒数", "cooldown":"目录冷却秒数", "damage":"基础伤害", "hit_width":"判定宽", "hit_height":"判定高", "offset":"前方偏移", "projectile_speed":"弹速", "lunge_speed":"突进速度", "shot_count":"弹体/落点数", "warning":"地面预警秒数", "hazard_life":"地面危险秒数", "radius":"危险半径"}

static func fresh() -> Dictionary:
    return {"version":1, "notes":{}, "favorites":[], "checks":{}, "sequences":[], "sequence_counter":0}

static func valid(data: Dictionary) -> bool:
    if data.get("version") != 1 or not data.get("notes") is Dictionary or data.notes.size() > 150:
        return false
    if not data.get("favorites") is Array or data.favorites.size() > 46:
        return false
    if not data.get("checks") is Dictionary or data.checks.size() > 150:
        return false
    for id in data.notes:
        if not id is String or not data.notes[id] is String or data.notes[id].length() > 1000:
            return false
    for id in data.checks:
        if not data.checks[id] is Dictionary:
            return false
        for key in data.checks[id]:
            if key not in ["windup", "active", "recover"] or not data.checks[id][key] is bool:
                return false
    return valid_sequences(data) and V.json_safe(data, 0, [V.MAX_ITEMS])

static func known(flags: Dictionary) -> Array:
    var combat := V.read_json(PATH, 2097152)
    var journal: Dictionary = V.read_json(JOURNAL, 1048576).get("entries", {})
    var result := []
    for id in combat:
        var value: Variant = flags.get("journal_enemy_" + String(id), false)
        if not value is bool or not value or not combat[id] is Dictionary:
            continue
        var row: Dictionary = combat[id].duplicate(true)
        row["id"] = id
        row["name"] = String(journal.get(id, {}).get("name", "已击败敌人"))
        row["hint"] = String(journal.get(id, {}).get("warning", ""))
        row["response"] = String(journal.get(id, {}).get("response", ""))
        var attacks := []
        for attack in row.get("attacks", []):
            if valid_attack(attack):
                attacks.append(attack.duplicate(true))
        if elite_known(flags, String(id)):
            for attack in row.get("elite", {}).get("attacks", []):
                if valid_attack(attack):
                    attacks.append(attack.duplicate(true))
        row.attacks = attacks
        result.append(row)
    result.sort_custom(func(a: Dictionary, b: Dictionary):return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
    return result

static func valid_attack(value: Variant) -> bool:
    if not value is Dictionary or not value.get("id") is String or not value.get("name") is String:
        return false
    if not TYPES.has(value.get("type")):
        return false
    for key in ["windup", "active", "recover", "cooldown", "range"]:
        if not V.number(value.get(key)) or float(value[key]) < 0 or float(value[key]) > 10000:
            return false
    return true

static func duration(attack: Dictionary) -> float:
    return float(attack.get("windup", 0)) + float(attack.get("active", 0)) + float(attack.get("recover", 0))

static func phases(attack: Dictionary) -> Array:
    var windup := float(attack.get("windup", 0))
    var active := float(attack.get("active", 0))
    var recover := float(attack.get("recover", 0))
    return [
        {"id":"windup", "name":"前摇", "start":0.0, "finish":windup},
        {"id":"active", "name":"判定", "start":windup, "finish":windup + active},
        {"id":"recover", "name":"收势", "start":windup + active, "finish":windup + active + recover}
    ]

static func phase(attack: Dictionary, time: float) -> Dictionary:
    if not is_finite(time) or time < 0:
        return {"id":"idle", "name":"未开始", "progress":0.0}
    for row in phases(attack):
        if time < float(row.finish):
            row["progress"] = clampf((time - float(row.start)) / maxf(0.001, float(row.finish) - float(row.start)), 0, 1)
            return row
    return {"id":"finished", "name":"动作字段结束", "progress":1.0}

static func values(attack: Dictionary) -> Array:
    var result := []
    for key in FIELDS:
        if V.number(attack.get(key)):
            result.append({"id":key, "name":FIELDS[key], "value":float(attack[key])})
    return result

static func compare(a: Dictionary, b: Dictionary) -> Array:
    var result := []
    for key in FIELDS:
        if V.number(a.get(key)) and V.number(b.get(key)):
            result.append({"name":FIELDS[key], "left":float(a[key]), "right":float(b[key]), "difference":float(b[key]) - float(a[key])})
    return result

static func attacks(rows: Array, query: String, type: String, favorites: Array = [], favorites_only: bool = false) -> Array:
    var result := []
    for enemy in rows:
        if favorites_only and not favorites.has(enemy.id):
            continue
        for attack in enemy.attacks:
            if type != "all" and attack.type != type:
                continue
            if not V.matches(query, [String(enemy.name), String(attack.name), String(enemy.get("combat_identity", "")), String(attack.get("mechanic", ""))]):
                continue
            result.append({"key":String(enemy.id) + ":" + String(attack.id), "enemy":enemy, "attack":attack})
    return result

static func find(rows: Array, key: String) -> Dictionary:
    for row in attacks(rows, "", "all"):
        if row.key == key:
            return row
    return {}

static func annotate(data: Dictionary, rows: Array, key: String, note: String) -> Dictionary:
    var result := data.duplicate(true)
    if find(rows, key).is_empty():
        return result
    var clean := V.text(note, 1000)
    if clean.is_empty():
        result.notes.erase(key)
    else:
        result.notes[key] = clean
    return result

static func check_phase(data: Dictionary, rows: Array, key: String, phase_id: String, value: bool) -> Dictionary:
    var result := data.duplicate(true)
    if find(rows, key).is_empty() or phase_id not in ["windup", "active", "recover"]:
        return result
    var checks: Dictionary = result.checks.get(key, {})
    checks[phase_id] = value
    result.checks[key] = checks
    return result

static func favorite(data: Dictionary, rows: Array, enemy: String, value: bool) -> Dictionary:
    var result := data.duplicate(true)
    var known_enemy := false
    for row in rows:
        if row.id == enemy:
            known_enemy = true
    if not known_enemy:
        return result
    result.favorites.erase(enemy)
    if value:
        result.favorites.append(enemy)
    return result

static func report(rows: Array, data: Dictionary) -> String:
    var lines: Array[String] = ["已击败敌人动作目录", "动作字段图解，不代表实际AI选招、地形碰撞或自然战斗验收。", ""]
    for row in attacks(rows, "", "all"):
        lines.append(String(row.enemy.name) + " / " + String(row.attack.name))
        lines.append("类型：" + String(TYPES[row.attack.type]))
        for value in values(row.attack):
            lines.append("%s：%.3f" % [value.name, value.value])
        if data.notes.has(row.key):
            lines.append("手记：" + String(data.notes[row.key]))
        lines.append("")
    return "\n".join(lines)

static func compose(rows: Array, entries: Array) -> Dictionary:
    if entries.is_empty() or entries.size() > 8:
        return {"ok":false, "reason":"观察串联需要1至8个已公开动作。"}
    var timeline := []
    var cursor := 0.0
    for entry in entries:
        if not entry is Dictionary or not entry.get("key") is String or not V.number(entry.get("gap")):
            return {"ok":false, "reason":"串联步骤格式无效。"}
        var gap := float(entry.gap)
        if gap < 0 or gap > 5:
            return {"ok":false, "reason":"自定间隔必须在0至5秒之间。"}
        var known := find(rows, String(entry.key))
        if known.is_empty():
            return {"ok":false, "reason":"串联包含当前未公开的动作。"}
        cursor += gap
        var record := {"key":entry.key, "name":String(known.enemy.name) + " / " + String(known.attack.name), "begin":cursor, "finish":cursor + duration(known.attack), "phases":[]}
        for phase in phases(known.attack):
            record.phases.append({"id":phase.id, "name":phase.name, "start":cursor + float(phase.start), "finish":cursor + float(phase.finish)})
        timeline.append(record)
        cursor = float(record.finish)
        if cursor > 120:
            return {"ok":false, "reason":"观察串联超过120秒上限。"}
    return {"ok":true, "rows":timeline, "duration":cursor, "reason":"仅按目录周期和自定间隔排列；不是实际AI连续选招。"}

static func save_sequence(data: Dictionary, rows: Array, title: String, entries: Array) -> Dictionary:
    var result := data.duplicate(true)
    var name := V.text(title, 50)
    var composed := compose(rows, entries)
    if name.is_empty() or not composed.get("ok", false) or result.get("sequences", []).size() >= 8:
        return result
    for sequence in result.get("sequences", []):
        if String(sequence.name).nocasecmp_to(name) == 0:
            return result
    result["sequence_counter"] = int(result.get("sequence_counter", 0)) + 1
    var sequences: Array = result.get("sequences", [])
    sequences.append({"id":"study_" + str(int(result.sequence_counter)), "name":name, "entries":entries.duplicate(true)})
    result["sequences"] = sequences
    return result

static func valid_sequences(data: Dictionary) -> bool:
    var sequences: Variant = data.get("sequences", [])
    if not sequences is Array or sequences.size() > 8 or not V.count(data.get("sequence_counter", 0)):
        return false
    var ids := {}
    for record in sequences:
        if not record is Dictionary or not record.get("id") is String or ids.has(record.id):
            return false
        if V.text(record.get("name"), 50).is_empty() or not record.get("entries") is Array or record.entries.size() > 8:
            return false
        for entry in record.entries:
            if not entry is Dictionary or not entry.get("key") is String or not V.number(entry.get("gap")) or float(entry.gap) < 0 or float(entry.gap) > 5:
                return false
        ids[record.id] = true
    return true

static func elite_known(flags: Dictionary, kind: String) -> bool:
    for config in preload("res://journey/core/public_catalog.gd").configurations({}):
        for spawn in config.get("enemy_spawns", []):
            if spawn.get("kind") == kind and spawn.get("elite") == true and flags.get("elite_first_%s_%s" % [config.get("id", ""), spawn.get("id", "")]) == true:
                return true
    return false
