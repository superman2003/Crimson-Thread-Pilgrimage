extends RefCounted
## Stable campaign coordinates. Chapter physics remain in their local frame
## until the physical connectors and streaming host are installed.
const PATH := "res://data/world_layout.json"
static var _manifest: Dictionary = {}

static func manifest() -> Dictionary:
    if _manifest.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if parsed is Dictionary:
            _manifest = parsed
    return _manifest.duplicate(true)

static func layout_version() -> int:
    return int(manifest().get("version", 0))

static func has_region(region_id: String) -> bool:
    return manifest().get("regions", {}).has(region_id)

static func to_world(region_id: String, local_position: Vector2) -> Vector2:
    var region: Dictionary = manifest().get("regions", {}).get(region_id, {})
    if region.is_empty():
        return Vector2.INF
    var origin: Array = region.origin
    return Vector2(origin[0], origin[1]) + local_position

static func to_local(region_id: String, world_position: Vector2) -> Vector2:
    var origin := to_world(region_id, Vector2.ZERO)
    return world_position - origin if origin.is_finite() else Vector2.INF

static func region_bounds(region_id: String) -> Rect2:
    var region: Dictionary = manifest().get("regions", {}).get(region_id, {})
    if region.is_empty():
        return Rect2()
    return Rect2(to_world(region_id, Vector2.ZERO), Vector2(region.size[0], region.size[1]))

static func location(region_id: String, local_position: Vector2) -> Dictionary:
    if not has_region(region_id) or not local_position.is_finite():
        return {}
    var point := to_world(region_id, local_position)
    return {"layout_version": layout_version(), "region_id": region_id,
        "position": [point.x, point.y]}

static func valid_location(value: Variant, region_id: String, local_position: Vector2) -> bool:
    if not value is Dictionary:
        return false
    if not has_region(region_id):
        return value.is_empty()
    var version: Variant = value.get("layout_version")
    if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version != layout_version() or value.get("region_id") != region_id:
        return false
    var position: Variant = value.get("position")
    if not position is Array or position.size() != 2:
        return false
    for number in position:
        if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)):
            return false
    return Vector2(position[0], position[1]).distance_to(to_world(region_id, local_position)) <= 0.001
