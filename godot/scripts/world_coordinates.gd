extends RefCounted
## Stable campaign coordinates. Public manifest snapshots are detached; hot
## transforms read prevalidated value-type bounds without copying the catalog.
const PATH := "res://data/world_layout.json"
const MAX_BYTES := 1048576
static var _manifest: Dictionary = {}
static var _bounds: Dictionary = {}
static var _version := 0
static var _loaded := false

static func _number(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func _pair(value: Variant, positive: bool = false) -> bool:
    if not value is Array or value.size() != 2:return false
    for number in value:
        if not _number(number) or (positive and float(number) <= 0.0):return false
    return true

static func _compile(data: Variant) -> void:
    _manifest = {};_bounds = {};_version = 0;_loaded = true
    if not data is Dictionary:return
    var version: Variant = data.get("version")
    if not _number(version) or float(version) != floor(float(version)) or float(version) <= 0 or float(version) > 1000000 or not data.get("regions") is Dictionary:return
    _manifest = data.duplicate(true)
    _version = int(version)
    for id in data.regions:
        var region: Variant = data.regions[id]
        if not id is String or id.is_empty() or not region is Dictionary:continue
        if not _pair(region.get("origin")) or not _pair(region.get("size"), true):continue
        var bounds := Rect2(Vector2(region.origin[0], region.origin[1]), Vector2(region.size[0], region.size[1]))
        if bounds.position.is_finite() and bounds.size.is_finite() and bounds.end.is_finite():_bounds[id] = bounds

static func _ensure_loaded() -> void:
    if _loaded:return
    var file := FileAccess.open(PATH, FileAccess.READ)
    if file == null or file.get_length() > MAX_BYTES:
        _compile(null)
        return
    _compile(JSON.parse_string(file.get_as_text()))

static func manifest() -> Dictionary:
    _ensure_loaded()
    return _manifest.duplicate(true)

static func layout_version() -> int:
    _ensure_loaded()
    return _version

static func has_region(region_id: String) -> bool:
    _ensure_loaded()
    return _bounds.has(region_id)

static func to_world(region_id: String, local_position: Vector2) -> Vector2:
    _ensure_loaded()
    if not local_position.is_finite() or not _bounds.has(region_id):return Vector2.INF
    var point: Vector2 = _bounds[region_id].position + local_position
    return point if point.is_finite() else Vector2.INF

static func to_local(region_id: String, world_position: Vector2) -> Vector2:
    _ensure_loaded()
    if not world_position.is_finite() or not _bounds.has(region_id):return Vector2.INF
    var point: Vector2 = world_position - _bounds[region_id].position
    return point if point.is_finite() else Vector2.INF

static func region_bounds(region_id: String) -> Rect2:
    _ensure_loaded()
    return _bounds.get(region_id, Rect2())

static func location(region_id: String, local_position: Vector2) -> Dictionary:
    var point := to_world(region_id, local_position)
    if not point.is_finite():return {}
    return {"layout_version": layout_version(), "region_id": region_id, "position": [point.x, point.y]}

static func valid_location(value: Variant, region_id: String, local_position: Vector2) -> bool:
    if not value is Dictionary or not local_position.is_finite():return false
    if not has_region(region_id):return value.is_empty()
    var version: Variant = value.get("layout_version")
    if not _number(version) or version != layout_version() or value.get("region_id") != region_id:return false
    var position: Variant = value.get("position")
    if not _pair(position):return false
    return Vector2(position[0], position[1]).distance_to(to_world(region_id, local_position)) <= 0.001
