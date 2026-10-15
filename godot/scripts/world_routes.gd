class_name PilgrimageWorldRoutes
extends RefCounted

const ROUTES_PATH := "res://data/world_routes.json"
static var _cached_stamp := -1
static var _cached_data: Dictionary = {}
static var _cache_generation := 0
static var sync_manifest_parses := 0

static func _ensure_manifest_cache() -> void:
    var stamp := FileAccess.get_modified_time(ROUTES_PATH)
    if stamp == _cached_stamp:
        return
    var file := FileAccess.open(ROUTES_PATH, FileAccess.READ)
    if file == null:
        _cached_stamp = stamp
        _cached_data = {}
        return
    var parsed = JSON.parse_string(file.get_as_text())
    sync_manifest_parses += 1
    _cached_data = parsed if parsed is Dictionary else {}
    _cached_stamp = stamp
    _cache_generation += 1

## Callers receive a snapshot; nested mutable cache data never escapes.
static func _data() -> Dictionary:
    _ensure_manifest_cache()
    return _cached_data.duplicate(true)

static func manifest_stamp() -> int:
    _ensure_manifest_cache()
    return _cached_stamp

static func manifest_generation() -> int:
    _ensure_manifest_cache()
    return _cache_generation

## Production World code uses these cache-only calls after the shared loader has
## published a complete worker result. They never parse or repair the cache.
static func cache_is_current() -> bool:
    return _cached_stamp >= 0 and _cached_stamp == FileAccess.get_modified_time(ROUTES_PATH)

static func cached_generation() -> int:
    return _cache_generation if cache_is_current() else -1

static func cached_config_path(region_id: String) -> String:
    if not cache_is_current():
        return ""
    return "res://data/%s.json" % region_id if _cached_data.get("chapters", {}).has(region_id) else ""

static func cached_overlay_bundle(region_id: String) -> Dictionary:
    if not cache_is_current():
        return {}
    return {"generation": _cache_generation, "stamp": _cached_stamp,
        "version": _cached_data.get("version", 1),
        "overlay": _cached_data.get("chapters", {}).get(region_id, {})}

static func cached_chapters() -> Dictionary:
    if not cache_is_current():
        return {}
    return _cached_data.get("chapters", {})

static func cached_portal(region_id: String, portal_id: String) -> Dictionary:
    if not cache_is_current():
        return {}
    for candidate in _cached_data.get("chapters", {}).get(region_id, {}).get("portals", []):
        if str(candidate.get("id", "")) == portal_id:
            return candidate.duplicate(true)
    return {}

static func cached_data() -> Dictionary:
    return _cached_data.duplicate(true) if cache_is_current() else {}

static func overlay_bundle(region_id: String) -> Dictionary:
    _ensure_manifest_cache()
    return {"generation": _cache_generation, "stamp": _cached_stamp,
        "version": _cached_data.get("version", 1),
        "overlay": _cached_data.get("chapters", {}).get(region_id, {})}

## Worker-friendly ticket payload. The shared CONFIG_READ_JOB owns the actual
## file/JSON operation; callers validate its ticket and stamp before commit.
static func manifest_ticket(read_result: Dictionary, generation: int) -> Dictionary:
    if str(read_result.get("error", "")) != "" or not read_result.get("raw") is Dictionary:
        return {}
    return {"generation": generation, "stamp": int(read_result.get("stamp", -1)),
        # Ownership transfers from the completed worker ticket. The loader
        # incrementally clones this private tree before publishing the cache.
        "manifest": read_result.raw}

static func accept_manifest_ticket(ticket: Dictionary, generation: int) -> bool:
    if int(ticket.get("generation", -1)) != generation or int(ticket.get("stamp", -1)) != FileAccess.get_modified_time(ROUTES_PATH):
        return false
    var manifest: Variant = ticket.get("manifest")
    if not manifest is Dictionary:
        return false
    # `manifest` must be a fully detached loader-owned copy. Never expose the
    # worker's mutable result as the shared cache.
    _cached_data = manifest
    _cached_stamp = int(ticket.stamp)
    _cache_generation += 1
    return true

static func config_path(region_id: String) -> String:
    _ensure_manifest_cache()
    return "res://data/%s.json" % region_id if _cached_data.get("chapters", {}).has(region_id) else ""

static func portal(region_id: String, portal_id: String) -> Dictionary:
    _ensure_manifest_cache()
    for candidate in _cached_data.get("chapters", {}).get(region_id, {}).get("portals", []):
        if str(candidate.get("id", "")) == portal_id:
            return candidate.duplicate(true)
    return {}

## A permanent latch only removes its latch condition, never an ability condition.
## Used for entry, nearby feedback and both directions of the atlas.
static func access(data: Dictionary, inventory: Dictionary, flags: Dictionary) -> Dictionary:
    var latch := str(data.get("requires_shortcut", ""))
    if not latch.is_empty() and not bool(flags.get("world_shortcut_" + latch, false)):
        return {"open": false, "kind": "far_side", "requirement": latch,
            "label": "另一侧门闩", "hint": str(data.get("hint", "门闩在另一侧。请先寻找别的通路。"))}
    var ability := str(data.get("required_ability", ""))
    if not ability.is_empty() and int(inventory.get(ability, 0)) <= 0:
        var title := str(data.get("required_ability_name", ability))
        return {"open": false, "kind": "ability", "requirement": ability,
            "label": title, "hint": "需要%s。%s" % [title, str(data.get("hint", "暂时可以探索别处。"))]}
    return {"open": true, "kind": "open", "requirement": "", "label": "已通", "hint": ""}

## Apply ONLY in world mode. Standalone chapter demos retain their original data.
static func apply_to(source: Dictionary) -> Dictionary:
    var config := source.duplicate(true)
    _apply_owned(config)
    return config

## Only use when source is freshly loaded or otherwise uniquely owned. This
## avoids duplicating the entire chapter snapshot before applying its overlay.
static func apply_to_owned(source: Dictionary) -> Dictionary:
    _apply_owned(source)
    return source

static func apply_to_owned_cached(source: Dictionary) -> Dictionary:
    if not cache_is_current():
        return {}
    _apply_owned_cached(source)
    return source

static func _apply_owned_cached(config: Dictionary) -> void:
    if not cache_is_current():
        return
    _apply_overlay(config, _cached_data)

static func _apply_owned(config: Dictionary) -> void:
    _ensure_manifest_cache()
    _apply_overlay(config, _cached_data)

static func _apply_overlay(config: Dictionary, manifest: Dictionary) -> void:
    var overlay: Dictionary = manifest.get("chapters", {}).get(str(config.get("id", "")), {})
    if overlay.is_empty():
        return
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
    config["world_routes_version"] = manifest.get("version", 1)
