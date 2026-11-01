extends RefCounted
## Internal catalogue only. Callers must gate output by acquired items/met NPCs.
const V := preload("res://journey/core/values.gd")
static var cached: Array = []

static func configurations(snapshot: Dictionary) -> Array:
    if cached.is_empty():
        for file in DirAccess.get_files_at("res://data"):
            if file.begins_with("demo_ch") and file.ends_with(".json"):
                var config := V.read_json("res://data/" + file, 4194304)
                if not config.is_empty():
                    cached.append(config)
    var result: Array = cached.duplicate()
    result.append(snapshot.get("config", {}))
    return result

static func items(snapshot: Dictionary) -> Dictionary:
    var result := {}
    for config in configurations(snapshot):
        result.merge(config.get("inventory", {}).get("catalog", {}), true)
    return result

static func npcs(snapshot: Dictionary) -> Dictionary:
    var result := {}
    for config in configurations(snapshot):
        for npc in config.get("npcs", []):
            var record: Dictionary = npc.duplicate(true)
            record["region_name"] = String(config.get("chapter_name", ""))
            result[String(npc.get("id", ""))] = record
    return result
