extends RefCounted
## Reachability expands only physically walked/jumped edges. Restoring a search
## node is allowed only at a previously reached landing; every successful route
## is then replayed continuously from the shrine before it can be reported.
const HIDDEN_KINDS := ["secret", "treasure", "reward"]
const ABILITY_FLAGS := ["dash_unlocked", "wall_grip_unlocked", "double_jump_unlocked", "thread_grapple_unlocked", "bell_guard_unlocked", "thorn_downstrike_unlocked", "lantern_phase_unlocked", "crown_resonance_unlocked"]
const ABILITY_ITEMS := ["thread_dash", "silk_wall_grip", "double_thread_jump", "echo_hook", "bell_guard", "thorn_downstrike", "lantern_phase", "crown_resonance"]

static func disable_ability_pickups(world: Node) -> void:
    # Install before World enters the tree, so even a pickup at the arrival
    # point cannot grant an ability or silently open its possession gate.
    if not world.child_entered_tree.is_connected(_discard_ability_pickup):
        world.child_entered_tree.connect(_discard_ability_pickup)
    for child in world.get_children(): _discard_ability_pickup(child)

static func _discard_ability_pickup(node: Node) -> void:
    if node is Area2D and String(node.get_meta("item_id", "")) in ABILITY_ITEMS:
        node.queue_free()

var host: Node
var player: CharacterBody2D
var invalid_motion := false
var goals: Array[Rect2] = []
var warmed_point := Vector2.INF

static func room_at(config: Dictionary, point: Vector2) -> Dictionary:
    var best: Dictionary = {}
    var area := INF
    for room in config.get("map_rooms", []):
        var r := rect_of(room)
        if r.has_point(point) and r.get_area() < area:
            best = room
            area = r.get_area()
    return best

static func rect_of(room: Dictionary) -> Rect2:
    var v: Array = room.layout_rect
    return Rect2(v[0], v[1], v[2], v[3])

func _release() -> void:
    for action in ["jump", "move_left", "move_right"]: Input.action_release(action)

func _direction(direction: int) -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    if direction < 0: Input.action_press("move_left")
    elif direction > 0: Input.action_press("move_right")

func _tick() -> bool:
    var before := player.global_position
    await host.get_tree().physics_frame
    await host.get_tree().process_frame
    # Reject respawn, travel, or any other teleport. Normal movement is far
    # below 64 px per fixed 60 Hz step, including the jump's vertical speed.
    if player.global_position.distance_to(before) > 64.0 or player.global_position.y > 9000.0:
        invalid_motion = true
    for flag in ABILITY_FLAGS:
        if bool(player.get(flag)): invalid_motion = true
    return not invalid_motion

func _restore(point: Vector2) -> bool:
    _release()
    player._reset_traversal_state()
    player.debug_invulnerable = true
    for flag in ABILITY_FLAGS: player.set(flag, false)
    player.global_position = point
    player.velocity = Vector2.ZERO
    invalid_motion = false
    if warmed_point.distance_to(point) > 64.0:
        for method in ["_warm_arrival_cave", "_warm_arrival_terrain", "_warm_arrival_platforms"]:
            if host.has_method(method): host.call(method)
        warmed_point = point
    for settle in 60:
        if not await _tick(): return false
        if settle >= 3 and player.is_on_floor(): return true
    return false

func _move(action: Dictionary) -> bool:
    _direction(int(action.walk_direction))
    for frame in int(action.walk_frames):
        if not await _tick():
            _release()
            return false
    _direction(0)
    if bool(action.jump):
        _direction(int(action.jump_direction))
        Input.action_press("jump")
        for frame in 112:
            if frame > 24: Input.action_release("jump")
            if not await _tick():
                _release()
                return false
            if frame > 6 and player.is_on_floor(): break
    _release()
    # Walking off a step is also a legitimate continuous edge.
    for settle in 110:
        if not await _tick(): return false
        if settle >= 2 and player.is_on_floor() and absf(player.velocity.x) < 0.1: return true
    return false

func _exit_room(config: Dictionary, room: Dictionary) -> Dictionary:
    if invalid_motion or not player.is_on_floor() or rect_of(room).has_point(player.global_position): return {}
    var other := room_at(config, player.global_position)
    if other.is_empty() or String(other.id) == String(room.id) or bool(other.get("hidden", false)) or String(other.get("kind", "")) in HIDDEN_KINDS: return {}
    return other

func _replay(config: Dictionary, start: Vector2, room: Dictionary, route: Array) -> Dictionary:
    warmed_point = Vector2.INF
    if not await _restore(start): return {}
    var trace: Array = [[player.global_position.x, player.global_position.y]]
    for action in route:
        if not await _move(action): return {}
        trace.append([player.global_position.x, player.global_position.y])
    var other := _exit_room(config, room)
    if other.is_empty(): return {}
    return {"escaped": true, "replay_verified": true, "via": String(other.id), "from": [start.x, start.y], "to": [player.global_position.x, player.global_position.y], "inputs": route, "trajectory": trace}

func replay(world: Node, config: Dictionary, start: Vector2, room: Dictionary, route: Array) -> Dictionary:
    host = world
    player = world.player
    return await _replay(config, start, room, route)

func _goals(config: Dictionary, hidden: Dictionary) -> void:
    goals.clear()
    var excluded := rect_of(hidden)
    for other in config.get("map_rooms", []):
        if bool(other.get("hidden", false)) or String(other.get("kind", "")) in HIDDEN_KINDS: continue
        var rect := rect_of(other)
        var overlap := rect.intersection(excluded)
        if not overlap.has_area():
            goals.append(rect)
            continue
        for part in [Rect2(rect.position, Vector2(rect.size.x, overlap.position.y - rect.position.y)), Rect2(Vector2(rect.position.x, overlap.end.y), Vector2(rect.size.x, rect.end.y - overlap.end.y)), Rect2(Vector2(rect.position.x, overlap.position.y), Vector2(overlap.position.x - rect.position.x, overlap.size.y)), Rect2(Vector2(overlap.end.x, overlap.position.y), Vector2(rect.end.x - overlap.end.x, overlap.size.y))]:
            if part.has_area(): goals.append(part)

func _goal_distance(point: Vector2) -> float:
    var distance := INF
    for goal in goals:
        var gap := Vector2(maxf(0.0, maxf(goal.position.x - point.x, point.x - goal.end.x)), maxf(0.0, maxf(goal.position.y - point.y, point.y - goal.end.y)))
        distance = minf(distance, gap.length())
    return distance

func search(world: Node, config: Dictionary, start: Vector2, room: Dictionary, max_nodes: int = 100) -> Dictionary:
    host = world
    player = world.player
    _goals(config, room)
    var queue: Array = [{"point": start, "route": []}]
    var seen := {}
    var expanded := 0
    var actions: Array = []
    # Walking and jumping are separate graph edges: a walked landing can be
    # followed by any jump without rerunning the same approach three times.
    for direction in [-1, 1]:
        for duration in [12, 24, 48]:
            actions.append({"walk_direction": direction, "walk_frames": duration, "jump": false, "jump_direction": 0})
    for direction in [-1, 0, 1]:
        actions.append({"walk_direction": 0, "walk_frames": 0, "jump": true, "jump_direction": direction})
    while not queue.is_empty() and expanded < max_nodes:
        # Prefer landings near an actual non-secret room outside the shrine
        # rectangle. Pure height ordering can wander up unmapped cave ledges.
        queue.sort_custom(func(a, b): return _goal_distance(a.point) + a.route.size() * 0.1 < _goal_distance(b.point) + b.route.size() * 0.1)
        var state: Dictionary = queue.pop_front()
        expanded += 1
        if expanded % 10 == 0: print("SHRINE_EXIT_SEARCH room=%s expanded=%d queued=%d y=%.1f" % [String(room.id), expanded, queue.size(), state.point.y])
        for action in actions:
            # No offset: this is exactly the shrine or a certified landing.
            if not await _restore(state.point) or not await _move(action): continue
            var land := player.global_position
            var route: Array = state.route.duplicate(true)
            route.append(action.duplicate(true))
            if not _exit_room(config, room).is_empty():
                var result := await _replay(config, start, room, route)
                if not result.is_empty():
                    _release()
                    result.landings = seen.size()
                    result.expanded = expanded
                    return result
            var key := Vector2i(roundi(land.x / 30.0), roundi(land.y / 15.0))
            if not seen.has(key):
                seen[key] = true
                queue.append({"point": land, "route": route})
    _release()
    return {"escaped": false, "replay_verified": false, "landings": seen.size(), "expanded": expanded, "reason": "search_budget_exhausted" if not queue.is_empty() else "no_route_found"}
