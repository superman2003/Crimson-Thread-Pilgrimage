class_name PilgrimageWorldRoutes
extends RefCounted

const ROUTES_PATH := "res://data/world_routes.json"

static func _data() -> Dictionary:
    var file := FileAccess.open(ROUTES_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

static func config_path(region_id: String) -> String:
    return "res://data/%s.json" % region_id if _data().get("chapters", {}).has(region_id) else ""

static func portal(region_id: String, portal_id: String) -> Dictionary:
    for candidate in _data().get("chapters", {}).get(region_id, {}).get("portals", []):
        if str(candidate.get("id", "")) == portal_id:
            return candidate.duplicate(true)
    return {}

## Apply ONLY in world mode. Standalone chapter demos retain their original data.
static func apply_to(source: Dictionary) -> Dictionary:
    var config := source.duplicate(true)
    var overlay: Dictionary = _data().get("chapters", {}).get(str(config.get("id", "")), {})
    if overlay.is_empty():
        return config
    # Optional return workshops extend the authored region instead of placing
    # solid gates across its mandatory route. Camera/fall bounds use this too.
    if not overlay.get("world_overrides", {}).is_empty():
        config["world"].merge(overlay["world_overrides"].duplicate(true), true)
    for room_override in overlay.get("map_room_overrides", []):
        for room in config.get("map_rooms", []):
            if str(room.get("id", "")) == str(room_override.get("id", "")):
                room.merge(room_override.duplicate(true), true)
    for terrain_override in overlay.get("terrain_overrides", []):
        for terrain in config.get("terrain", []):
            if str(terrain.get("id", "")) == str(terrain_override.get("id", "")):
                terrain.merge(terrain_override.duplicate(true), true)
    for platform_override in overlay.get("platform_overrides", []):
        for platform in config.get("platforms", []):
            if str(platform.get("id", "")) == str(platform_override.get("id", "")):
                platform.merge(platform_override.duplicate(true), true)
    for gate_override in overlay.get("locked_gate_overrides", []):
        for gate in config.get("locked_gates", []):
            if str(gate.get("id", "")) == str(gate_override.get("id", "")):
                gate.merge(gate_override.duplicate(true), true)
    for override in overlay.get("collectible_overrides", []):
        for collectible in config.get("collectibles", []):
            if str(collectible.get("id", "")) == str(override.get("id", "")):
                collectible.merge(override.duplicate(true), true)
    for key in ["collectibles", "platforms", "locked_gates", "map_rooms", "terrain", "grapple_anchors", "save_points"]:
        if not overlay.get(key, []).is_empty():
            if not config.has(key):
                config[key] = []
            config[key].append_array(overlay[key].duplicate(true))
    var interactives: Array = []
    for interactive in config.get("interactives", []):
        if str(interactive.get("id", "")) not in overlay.get("remove_interactives", []):
            interactives.append(interactive)
    interactives.append_array(overlay.get("portals", []).duplicate(true))
    config["interactives"] = interactives
    if not overlay.get("inventory_catalog", {}).is_empty():
        if not config.has("inventory"):
            config["inventory"] = {}
        if not config["inventory"].has("catalog"):
            config["inventory"]["catalog"] = {}
        config["inventory"]["catalog"].merge(overlay["inventory_catalog"].duplicate(true), true)
    config["world_routes_version"] = _data().get("version", 1)
    return config
