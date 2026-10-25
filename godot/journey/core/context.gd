extends RefCounted
signal refresh_requested
signal message_requested(message: String)
signal close_requested
const VALUES := preload("res://journey/core/values.gd")
var owner_ref: WeakRef
var store := preload("res://journey/core/store.gd").new()
var latest: Dictionary = {}
var cached_region := ""
var cached_config: Dictionary = {}
var cached_catalog: Dictionary = {}
var catalog_owner := 0

func bind(level: Node) -> void:
    owner_ref = weakref(level)
    store.configure(String(level.get("world_save_path")))
    update()

func level() -> Node:
    var node: Node = owner_ref.get_ref() if owner_ref != null else null
    if not is_instance_valid(node) or node.is_queued_for_deletion():
        return null
    return node

func update() -> Dictionary:
    var node := level()
    if node == null or not bool(node.get("initial_region_ready")) or not is_instance_valid(node.get("player")):
        latest = {}
        return latest
    var player: Node = node.player
    var regions: Dictionary = node.world_state.data.regions.duplicate(true)
    var region_id := String(node.config.get("id", ""))
    if cached_region != region_id or cached_config.is_empty():
        cached_region = region_id
        cached_config = node.config.duplicate(true)
    var build_id: int = node.build_system.get_instance_id()
    if catalog_owner != build_id or cached_catalog.is_empty():
        catalog_owner = build_id
        cached_catalog = node.build_system.catalog.duplicate(true)
    var current: Dictionary = regions.get(region_id, {})
    current["visited_rooms"] = node.visited_rooms.duplicate(true)
    current["opened_shortcuts"] = node.opened_shortcuts.duplicate(true)
    regions[region_id] = current
    latest = {
        "slot":store.scope,
        "save_path":String(node.world_save_path),
        "region":region_id,
        "region_name":String(node.config.get("chapter_name", region_id)),
        "room":String(node.current_room_id),
        "inventory":node.inventory_counts.duplicate(true),
        "flags":node.story_flags.duplicate(true),
        "regions":regions,
        "wallet":int(node.currency_count),
        "config":cached_config,
        "catalog":cached_catalog,
        "build_state":node.build_system.state.duplicate(true),
        "build":node.build_system.get_snapshot(),
        "player":{
            "hp":int(player.hp),
            "energy":int(player.energy),
            "position":VALUES.pair(player.global_position),
            "velocity":VALUES.pair(player.velocity),
            "grounded":player.is_on_floor(),
            "alive":int(player.hp) > 0
        },
        "exploring":String(node.active_overlay).is_empty() and not bool(node.world_loading) and not bool(node.chapter_transitioning),
        "at_shrine":node.is_near_shrine(),
        "timestamp":int(Time.get_unix_time_from_system())
    }
    return latest

func snapshot() -> Dictionary:
    return latest.duplicate(true)

func refresh() -> void:
    refresh_requested.emit()

func tell(message: String) -> void:
    message_requested.emit(message)

func finish() -> void:
    close_requested.emit()

func item_name(id: String) -> String:
    var node := level()
    if node != null and node.has_method("_item_display_name"):
        return String(node.call("_item_display_name", id))
    return id

func room_name(id: String) -> String:
    for room in latest.get("config", {}).get("map_rooms", []):
        if String(room.get("id", "")) == id:
            return String(room.get("name", id))
    return id

func editable() -> bool:
    var node := level()
    return node != null and not bool(node.get("world_loading")) and not bool(node.get("chapter_transitioning"))
