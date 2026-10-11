extends RefCounted
## One shared instance is retained by Main's parent between region scenes.
## Positions are JSON arrays; scene objects and Vector2 never enter disk data.

const VERSION := 2
const DEFAULT_PATH := "user://pilgrimage_world.json"
const MAX_BYTES := 4 * 1024 * 1024
var last_error := ""
var data: Dictionary = fresh_data()

static func fresh_data() -> Dictionary:
    return {"version": VERSION, "inventory_counts": {}, "currency": 0,
        "story_flags": {}, "regions": {}, "current_region": "", "entry": [0, 0],
        "hp": 5, "energy": 100, "build_state": {}, "death_cache": {}}

static func fresh_region() -> Dictionary:
    return {"collected_ids": {}, "opened_shortcuts": {}, "visited_rooms": {},
        "boss_defeated": false, "boss_unlocked": false, "shortcut_open": false,
        "bell_count": 0, "checkpoint": [0, 0], "checkpoint_id": ""}

func reset() -> void:
    data = fresh_data()
    last_error = ""

func get_region(region_id: String) -> Dictionary:
    return data.get("regions", {}).get(region_id, fresh_region()).duplicate(true)

func capture_region(region_id: String, snapshot: Dictionary) -> bool:
    if region_id.is_empty():
        return _fail("empty region id")
    var region := get_region(region_id)
    for key in snapshot:
        if not region.has(key):
            return _fail("unknown region field: %s" % key)
        region[key] = _position(snapshot[key]) if key == "checkpoint" else snapshot[key]
    if not _valid_region(region):
        return _fail("invalid region snapshot")
    data.regions[region_id] = region.duplicate(true)
    last_error = ""
    return true

func capture_global(snapshot: Dictionary) -> bool:
    var candidate := data.duplicate(true)
    for key in snapshot:
        if key == "version" or key == "regions" or not candidate.has(key):
            return _fail("unknown or reserved global field: %s" % key)
        candidate[key] = _position(snapshot[key]) if key == "entry" else snapshot[key]
    if not _valid_data(candidate):
        return _fail("invalid global snapshot")
    data = candidate
    last_error = ""
    return true

func read(path: String = DEFAULT_PATH) -> bool:
    last_error = ""
    if not FileAccess.file_exists(path):
        return _fail("missing")
    var candidate: Variant = _read_valid_file(path)
    if candidate == null:
        return false
    data = candidate.duplicate(true)
    # Godot's JSON parser represents every number as float. Keep counters
    # integral so dictionary comparisons and inventory consumers remain stable.
    data.version = int(data.version)
    data.currency = int(data.currency)
    for item_id in data.inventory_counts:
        data.inventory_counts[item_id] = int(data.inventory_counts[item_id])
    for region_id in data.regions:
        data.regions[region_id].bell_count = int(data.regions[region_id].bell_count)
    return true

func write(path: String = DEFAULT_PATH) -> bool:
    last_error = ""
    if not _valid_data(data):
        return _fail("invalid in-memory world state")
    # Never replace a damaged save or discard its evidence after a failed load.
    if FileAccess.file_exists(path) and _read_valid_file(path) == null:
        return _fail("existing save is damaged; left untouched")
    var temporary := path + ".tmp"
    var handle := FileAccess.open(temporary, FileAccess.WRITE)
    if handle == null:
        return _fail("cannot open temporary save: %s" % FileAccess.get_open_error())
    handle.store_string(JSON.stringify(data))
    handle.flush()
    var status := handle.get_error()
    handle.close()
    if status != OK or _read_valid_file(temporary) == null:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return _fail("temporary save failed validation")
    var absolute := ProjectSettings.globalize_path(path)
    if FileAccess.file_exists(path):
        var backup_status := DirAccess.copy_absolute(absolute, absolute + ".bak")
        if backup_status != OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
            return _fail("cannot preserve previous save: %s" % backup_status)
    var rename_status := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
    if rename_status != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return _fail("cannot install save: %s" % rename_status)
    last_error = ""
    return true

func _read_valid_file(path: String) -> Variant:
    var handle := FileAccess.open(path, FileAccess.READ)
    if handle == null:
        _fail("cannot read save")
        return null
    if handle.get_length() > MAX_BYTES:
        handle.close()
        _fail("save exceeds size limit")
        return null
    var contents := handle.get_as_text()
    handle.close()
    var parser := JSON.new()
    if parser.parse(contents) != OK:
        _fail("invalid JSON")
        return null
    parser.data = _migrate(parser.data)
    if not _valid_data(parser.data):
        _fail("unsupported version or invalid save fields")
        return null
    return parser.data

static func _position(value: Variant) -> Variant:
    return [value.x, value.y] if value is Vector2 else value

static func _number(value: Variant, nonnegative: bool = false) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    return is_finite(float(value)) and (not nonnegative or float(value) >= 0)

static func _whole(value: Variant) -> bool:
    return _number(value, true) and float(value) == floor(float(value)) and float(value) <= 2147483647

static func _point(value: Variant) -> bool:
    return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])

static func _boolean_map(value: Variant) -> bool:
    if not value is Dictionary:
        return false
    for key in value:
        if not key is String or key.is_empty() or not value[key] is bool:
            return false
    return true

static func _json_value(value: Variant, depth: int = 0) -> bool:
    if depth > 16:
        return false
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_STRING:
            return true
        TYPE_INT, TYPE_FLOAT:
            return _number(value)
        TYPE_ARRAY:
            for child in value:
                if not _json_value(child, depth + 1):
                    return false
            return true
        TYPE_DICTIONARY:
            for key in value:
                if not key is String or not _json_value(value[key], depth + 1):
                    return false
            return true
    return false

static func _valid_region(value: Variant) -> bool:
    if not value is Dictionary:
        return false
    for field in ["collected_ids", "opened_shortcuts", "visited_rooms"]:
        if not _boolean_map(value.get(field)):
            return false
    for field in ["boss_defeated", "boss_unlocked", "shortcut_open"]:
        if not value.get(field) is bool:
            return false
    return _whole(value.get("bell_count")) and int(value.bell_count) <= 1000000 and _point(value.get("checkpoint")) and value.get("checkpoint_id") is String

static func _valid_data(value: Variant) -> bool:
    if not value is Dictionary or not _whole(value.get("version")) or int(value.version) != VERSION:
        return false
    if not value.get("build_state") is Dictionary or not _valid_death_cache(value.get("death_cache")):
        return false
    if not value.get("inventory_counts") is Dictionary or not value.get("story_flags") is Dictionary or not value.get("regions") is Dictionary:
        return false
    for key in value.inventory_counts:
        if not key is String or key.is_empty() or not _whole(value.inventory_counts[key]):
            return false
    for key in value.regions:
        if not key is String or key.is_empty() or not _valid_region(value.regions[key]):
            return false
    return _whole(value.get("currency")) and _number(value.get("hp"), true) and _number(value.get("energy"), true) and value.get("current_region") is String and _point(value.get("entry")) and _json_value(value)

func _fail(message: String) -> bool:
    last_error = message
    return false


static func _migrate(value: Variant) -> Variant:
    if not value is Dictionary or not _whole(value.get("version")):
        return value
    var migrated: Dictionary = value.duplicate(true)
    if int(migrated.version) == 1:
        migrated.version = VERSION
        migrated["build_state"] = {}
        migrated["death_cache"] = {}
    return migrated

static func _valid_death_cache(value: Variant) -> bool:
    if not value is Dictionary:
        return false
    if value.is_empty():
        return true
    return value.get("region_id") is String and not String(value.region_id).is_empty() and _point(value.get("position")) and _whole(value.get("currency"))

static func slot_path(index: int) -> String:
    return DEFAULT_PATH if index == 1 else "user://pilgrimage_world_slot_%d.json" % clampi(index, 1, 3)

static func slot_summaries() -> Array:
    var summaries: Array = []
    for index in range(1, 4):
        var world = load("res://scripts/world_state.gd").new()
        var path := slot_path(index)
        var exists := FileAccess.file_exists(path)
        var valid: bool = world.read(path) if exists else false
        summaries.append({"slot": index, "exists": exists, "valid": valid,
            "region_id": String(world.data.current_region) if valid else "",
            "regions": world.data.regions.size() if valid else 0,
            "currency": int(world.data.currency) if valid else 0,
            "error": world.last_error if exists and not valid else ""})
    return summaries

## A damaged primary is retained verbatim before installing a validated backup.
func restore_backup(path: String = DEFAULT_PATH) -> bool:
    var backup := path + ".bak"
    var candidate: Variant = _read_valid_file(backup)
    if candidate == null:
        return _fail("backup missing or damaged")
    var temporary := path + ".restore"
    var absolute := ProjectSettings.globalize_path(path)
    if DirAccess.copy_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(temporary)) != OK:
        return _fail("cannot prepare backup recovery")
    if FileAccess.file_exists(path):
        var preserved := absolute + ".before_restore_" + str(Time.get_unix_time_from_system()).replace(".", "_")
        if DirAccess.rename_absolute(absolute, preserved) != OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
            return _fail("cannot preserve original save")
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute) != OK:
        return _fail("cannot install recovered save; original was preserved")
    data = candidate.duplicate(true)
    last_error = ""
    return read(path)
