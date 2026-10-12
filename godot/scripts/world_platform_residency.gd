extends RefCounted
## Ordinary authored platforms only. Gates and stateful blockers stay outside.
const HALF_SIZE := Vector2(960, 768)
const PRELOAD_MARGIN := 640.0
const KEEP_MARGIN := 1280.0
const BUDGET_USEC := 2000
var records: Dictionary = {}
var resident: Dictionary = {}
var pins: Dictionary = {}
# Actors are still fully resident, so their support remains until region teardown.
var held: Dictionary = {}
var critical_bounds := Rect2()
var load_bounds := Rect2()
var sync_until := 0
var loads := 0
var releases := 0
var closed := false

func _window(host: Node2D, focus: Vector2, velocity: Vector2, delta: float) -> void:
    var local_focus := host.to_local(focus)
    var sweep := velocity * clampf(delta, 0.0, 0.25)
    critical_bounds = Rect2(local_focus - HALF_SIZE, HALF_SIZE * 2).expand(local_focus + sweep - HALF_SIZE).expand(local_focus + sweep + HALF_SIZE)
    var viewport := host.get_viewport_rect().size
    var zoom := Vector2.ONE
    if is_instance_valid(host.player):
        var camera: Camera2D = host.player.get_node_or_null("Camera2D")
        if camera != null:
            zoom = camera.zoom
    # Cover a clamped/look-ahead camera as well as physics. At a world border
    # the visible rectangle can be a full viewport width away from the player.
    var half_view := Vector2(maxf(HALF_SIZE.x, viewport.x / maxf(0.25, zoom.x) + 256), maxf(HALF_SIZE.y, viewport.y / maxf(0.25, zoom.y) + 256))
    load_bounds = critical_bounds.merge(Rect2(local_focus - half_view, half_view * 2))

func register(host: Node2D, data: Dictionary, focus: Vector2) -> void:
    if closed:
        return
    var id := String(data.id)
    var value: Array = data.rect
    var rect := Rect2(value[0], value[1], value[2], value[3])
    records[id] = {"data": data.duplicate(true), "bounds": rect}
    _window(host, focus, Vector2.ZERO, 0)
    if load_bounds.intersects(rect):
        _create(host, id)
        if critical_bounds.intersects(rect):
            sync_until = Engine.get_physics_frames() + 1

func _create(host: Node2D, id: String) -> void:
    if resident.has(id) and is_instance_valid(resident[id]):
        return
    var body: StaticBody2D = host._make_region_platform(records[id].data)
    body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
    body.set_meta("spatial_platform_id", id)
    resident[id] = body
    loads += 1

func hold(host: Node2D, id: String) -> void:
    if closed or not records.has(id):
        return
    held[id] = true
    _create(host, id)

func warm(host: Node2D, focus: Vector2) -> void:
    update(host, focus, Vector2.ZERO, 0, true)

func update(host: Node2D, focus: Vector2, velocity: Vector2, delta: float, eager: bool = false) -> void:
    if closed or not focus.is_finite() or not velocity.is_finite():
        return
    _window(host, focus, velocity, delta)
    var frame := Engine.get_physics_frames()
    for id in pins.keys():
        if int(pins[id]) < frame:
            pins.erase(id)
    for id in records:
        if load_bounds.intersects(records[id].bounds) and (not resident.has(id) or not is_instance_valid(resident[id])):
            _create(host, id)
            if critical_bounds.intersects(records[id].bounds):
                sync_until = frame + 1
    var keep := load_bounds.grow(KEEP_MARGIN)
    var started := Time.get_ticks_usec()
    var removed := 0
    for id in resident.keys():
        if not held.has(id) and not pins.has(id) and not keep.intersects(records[id].bounds):
            if not eager and (removed >= 2 or (removed > 0 and Time.get_ticks_usec() - started >= BUDGET_USEC)):
                break
            var body: Variant = resident[id]
            if is_instance_valid(body):
                host.remove_child(body)
                body.free()
            resident.erase(id)
            releases += 1
            removed += 1
    var upcoming := load_bounds.grow(PRELOAD_MARGIN)
    var pending: Array = []
    for id in records:
        if upcoming.intersects(records[id].bounds) and not resident.has(id):
            pending.append(id)
    pending.sort_custom(func(a, b): return records[a].bounds.get_center().distance_squared_to(host.to_local(focus)) < records[b].bounds.get_center().distance_squared_to(host.to_local(focus)))
    started = Time.get_ticks_usec()
    var created := 0
    for id in pending:
        if not eager and (created >= 2 or (created > 0 and Time.get_ticks_usec() - started >= BUDGET_USEC)):
            break
        _create(host, id)
        created += 1

func ensure_segment(host: Node2D, from: Vector2, to: Vector2) -> void:
    if closed or not from.is_finite() or not to.is_finite():
        return
    var bounds := Rect2(host.to_local(from), Vector2.ZERO).expand(host.to_local(to)).grow(16)
    for id in records:
        if bounds.intersects(records[id].bounds):
            _create(host, id)
            pins[id] = Engine.get_physics_frames() + 2

func ray_hit(host: Node2D, from: Vector2, to: Vector2) -> Dictionary:
    if closed or not from.is_finite() or not to.is_finite():
        return {}
    var start := host.to_local(from)
    var direction := host.to_local(to) - start
    var nearest := INF
    for id in records:
        var role := String(records[id].data.get("collision_role", "")).to_lower()
        if role in ["decorative", "no_collision"]:
            continue
        var rect: Rect2 = records[id].bounds
        var low := 0.0
        var high := 1.0
        var intersects := true
        for axis in range(2):
            if is_zero_approx(direction[axis]):
                if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]:
                    intersects = false
                    break
            else:
                var first := (rect.position[axis] - start[axis]) / direction[axis]
                var last := (rect.end[axis] - start[axis]) / direction[axis]
                low = maxf(low, minf(first, last))
                high = minf(high, maxf(first, last))
                if low > high:
                    intersects = false
                    break
        if intersects and low <= high and low <= 1 and high >= 0:
            nearest = minf(nearest, maxf(0, low))
    return {} if not is_finite(nearest) else {"position": from.lerp(to, nearest), "authored_static": true}

func ready() -> bool:
    return Engine.get_physics_frames() >= sync_until

func snapshot() -> Dictionary:
    var count := 0
    for body in resident.values():
        if is_instance_valid(body):
            count += 1
    return {"authored": records.size(), "resident": count, "loads": loads, "releases": releases, "pins": pins.size(), "held": held.size()}

func shutdown() -> void:
    closed = true
    resident.clear()
    pins.clear()
    held.clear()
    records.clear()
