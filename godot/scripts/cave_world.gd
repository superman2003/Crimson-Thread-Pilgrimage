extends Node2D
## Opaque rock mass; ordinary rooms stay visible, authored dark rooms use local sight.

const ROCK := preload("res://scripts/world_rock_material.gd")
const VISIBLE_ROCK := preload("res://scripts/visible_rock_mass.gd")
const INKS := {"moss_cavern":"172d26", "rain_foundry":"142b37", "salt_archive":"322c3b", "string_greenhouse":"203325", "obsidian_pilgrim":"2e2634", "silent_crown":"232b3c"}
var solid_rects: Array[Rect2] = []
var outlines: Array = []
var rock_ink := Color("172d26")
var scene: Node2D
var fog: ColorRect
var shader_material: ShaderMaterial
var ray_lengths := PackedFloat32Array()
var scan_timer := 0.0
var vision_radius := 540.0
var dark_vision_radius := 360.0
var default_visibility := "normal"
var ray_count := 96
var lights: Array[Vector2] = []

## Descriptors stay resident for maps, spawn checks and authored geometry.
## Only physical rock bodies are distance resident in the World host.
const COLLISION_CHUNK_SIZE := 1024.0
const CRITICAL_HALF_SIZE := Vector2(960, 768)
const PREFETCH_MARGIN := 640.0
const KEEP_MARGIN := 1280.0
const COLLISION_BUDGET_USEC := 2000
var collision_streaming := false
var collision_chunks: Dictionary = {}
var resident_collision_chunks: Dictionary = {}
var collision_root: Node2D
var collision_loads := 0
var collision_releases := 0
var critical_loads := 0
var critical_bounds := Rect2()
var collision_shutdown := false
var collision_pins: Dictionary = {}
var critical_sync_until := 0

func configure(chapter: Dictionary, theme: String, owner_scene: Node2D, stream_collisions: bool = false, initial_focus: Vector2 = Vector2.ZERO) -> void:
    name = "CaveWorld"
    scene = owner_scene
    rock_ink = Color(INKS.get(theme,"172d26"))
    var data: Dictionary = chapter.get("cave_world", {})
    if data.is_empty(): return
    vision_radius = float(data.get("vision_radius",540))
    dark_vision_radius = float(data.get("dark_vision_radius",360))
    default_visibility = String(data.get("visibility","normal"))
    outlines = data.get("outlines",[])
    collision_streaming = stream_collisions
    if collision_streaming:
        collision_root = Node2D.new()
        collision_root.name = "SolidCaveMass"
    else:
        var body := StaticBody2D.new()
        body.name = "SolidCaveMass"
        body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
        body.collision_layer = 17
        body.collision_mask = 0
        collision_root = body
    add_child(collision_root)
    for value in data.get("solid_rects", []):
        var rect := Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
        var index := solid_rects.size()
        solid_rects.append(rect)
        if collision_streaming:
            var center := rect.get_center()
            var key := "%d:%d" % [floori(center.x / COLLISION_CHUNK_SIZE), floori(center.y / COLLISION_CHUNK_SIZE)]
            if not collision_chunks.has(key):
                collision_chunks[key] = {"bounds": rect, "indices": []}
            collision_chunks[key].bounds = collision_chunks[key].bounds.merge(rect)
            collision_chunks[key].indices.append(index)
        else:
            _add_collision_shape(collision_root, rect, index)
    if collision_streaming:
        warm_collision_focus(initial_focus)
    var surface := VISIBLE_ROCK.new()
    surface.name = "PaintedRockMass"
    surface.show_behind_parent = true
    add_child(surface)
    surface.configure(solid_rects, ROCK.for_theme(theme))
    z_index = 12 # Opaque painted rock covers distant backdrops and wall ornaments.
    queue_redraw()
    for point in chapter.get("save_points",[]):
        lights.append(Vector2(float(point.position[0]),float(point.position[1])-65))
    _create_vision()

func _draw() -> void:
    for value in outlines:
        var points := PackedVector2Array()
        for p in value:points.append(Vector2(float(p[0]),float(p[1])))
        if points.size()<2:continue
        draw_polyline(points,rock_ink.darkened(.25),4.0,true)
        draw_polyline(points,rock_ink.lightened(.25),1.2,true)
    for p in lights:
        for radius in [54,36,20]:
            draw_circle(p,float(radius),Color(.68,.89,.65,.035))
        draw_circle(p,3,Color(.81,.97,.73,.9))

func intersects_rect(rect: Rect2) -> bool:
    for solid in solid_rects:
        if solid.intersects(rect):return true
    return false

func _create_vision() -> void:
    fog = ColorRect.new()
    fog.name = "CaveSight"
    fog.visible = false
    fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fog.z_index = 40
    fog.color = Color.WHITE
    var shader := Shader.new()
    shader.code = """shader_type canvas_item;
uniform vec2 source_px;
uniform vec2 viewport_px;
uniform float zoom_value = 1.25;
uniform float radius = 540.0;
uniform float ray_lengths[96];
void fragment() {
    vec2 offset = (SCREEN_UV * viewport_px - source_px) / zoom_value;
    float distance_value = length(offset);
    float angle = mod(atan(offset.y,offset.x)+6.2831853,6.2831853);
    float index_value = angle / 6.2831853 * 96.0;
    int a = int(floor(index_value));
    int b = (a+1)%96;
    float limit_value = min(ray_lengths[a],ray_lengths[b]);
    float occlusion = smoothstep(limit_value-12.0,limit_value+6.0,distance_value);
    float falloff = smoothstep(radius*.48,radius,distance_value);
    COLOR = vec4(0.005,0.008,0.012,max(occlusion*.96,falloff*.88));
}"""
    shader_material = ShaderMaterial.new()
    shader_material.shader = shader
    fog.material = shader_material
    add_child(fog)
    for i in range(ray_count):ray_lengths.append(vision_radius)
    shader_material.set_shader_parameter("ray_lengths",ray_lengths)

func _process(delta: float) -> void:
    if fog==null or scene.player==null:return
    var room: Dictionary = scene._map_room_by_id(String(scene.current_room_id))
    var dark := String(room.get("visibility",default_visibility)) == "dark"
    fog.visible = dark
    if not dark:
        scan_timer = 0.0
        return
    var viewport := get_viewport()
    var camera := viewport.get_camera_2d()
    if camera==null:return
    # A world-space quad follows the camera; HUD lives in its separate CanvasLayer.
    var inverse := viewport.get_canvas_transform().affine_inverse()
    var size := viewport.get_visible_rect().size
    fog.global_position = inverse * Vector2.ZERO
    fog.size = size / camera.zoom
    var origin: Vector2 = scene.player.global_position + Vector2(0,-48)
    var radius := maxf(1.0,float(room.get("vision_radius",dark_vision_radius)))
    shader_material.set_shader_parameter("source_px",viewport.get_canvas_transform()*origin)
    shader_material.set_shader_parameter("viewport_px",size)
    shader_material.set_shader_parameter("zoom_value",camera.zoom.x)
    shader_material.set_shader_parameter("radius",radius)
    scan_timer -= delta
    if scan_timer>0:return
    scan_timer = .08
    var space := get_world_2d().direct_space_state
    for i in range(ray_count):
        var target := origin+Vector2.RIGHT.rotated(TAU*float(i)/ray_count)*radius
        var query := PhysicsRayQueryParameters2D.create(origin,target,16)
        var hit := space.intersect_ray(query)
        ray_lengths[i] = radius if hit.is_empty() else origin.distance_to(hit.position)
    shader_material.set_shader_parameter("ray_lengths",ray_lengths)


func _add_collision_shape(body: Node, rect: Rect2, index: int) -> void:
    var collision := CollisionShape2D.new()
    collision.name = "Rock_%d" % index
    collision.set_meta("authored_rock_index", index)
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    collision.position = rect.get_center()
    collision.shape = shape
    body.add_child(collision)


func _create_collision_chunk(key: String) -> void:
    if resident_collision_chunks.has(key):
        return
    var body := StaticBody2D.new()
    body.name = "RockChunk_" + key.replace(":", "_")
    body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
    body.collision_layer = 17 # preserve terrain/sight-blocker bits
    body.collision_mask = 0
    collision_root.add_child(body)
    for index in collision_chunks[key].indices:
        _add_collision_shape(body, solid_rects[index], index)
    resident_collision_chunks[key] = body
    collision_loads += 1


func warm_collision_focus(focus: Vector2) -> void:
    update_collision_window(focus, Vector2.ZERO, 0.0, true)


## The host calls this before its Player physics step. Current/swept critical
## coverage is mandatory, even if a teleport exceeds the admission budget.
## Only speculative work is limited to two chunks/2ms; safety wins over timing.
func update_collision_window(focus: Vector2, velocity: Vector2, delta: float, eager: bool = false) -> void:
    if not collision_streaming or collision_shutdown or not focus.is_finite() or not velocity.is_finite():
        return
    var physics_frame := Engine.get_physics_frames()
    for key in collision_pins.keys():
        if int(collision_pins[key]) < physics_frame:
            collision_pins.erase(key)
    var local_focus := to_local(focus)
    var sweep := velocity * clampf(delta, 0.0, 0.25)
    var half_size := CRITICAL_HALF_SIZE
    if is_instance_valid(scene) and scene.has_method("_map_room_by_id"):
        var room: Dictionary = scene._map_room_by_id(String(scene.current_room_id))
        if String(room.get("visibility", default_visibility)) == "dark":
            var radius := maxf(1.0, float(room.get("vision_radius", dark_vision_radius))) + 128
            half_size = Vector2(maxf(half_size.x, radius), maxf(half_size.y, radius))
    critical_bounds = Rect2(local_focus - half_size, half_size * 2).expand(local_focus + sweep - half_size).expand(local_focus + sweep + half_size)
    var upcoming := critical_bounds.grow(PREFETCH_MARGIN)
    var keep := critical_bounds.grow(KEEP_MARGIN)
    var critical_added := false
    for key in collision_chunks:
        if critical_bounds.intersects(collision_chunks[key].bounds) and not resident_collision_chunks.has(key):
            _create_collision_chunk(key)
            critical_loads += 1
            critical_added = true
    if critical_added:
        critical_sync_until = Engine.get_physics_frames() + 1
    var started := Time.get_ticks_usec()
    var released := 0
    for key in resident_collision_chunks.keys():
        if not collision_pins.has(key) and not keep.intersects(collision_chunks[key].bounds):
            if not eager and (released >= 2 or (released > 0 and Time.get_ticks_usec() - started >= COLLISION_BUDGET_USEC)):
                break
            var body: Node = resident_collision_chunks[key]
            # Called from host _physics_process before movement, not from an
            # Area body signal; immediate retirement cannot leave stale shapes.
            collision_root.remove_child(body)
            body.free()
            resident_collision_chunks.erase(key)
            collision_releases += 1
            released += 1
    var pending: Array = []
    for key in collision_chunks:
        if upcoming.intersects(collision_chunks[key].bounds) and not resident_collision_chunks.has(key):
            pending.append(key)
    pending.sort_custom(func(a, b): return collision_chunks[a].bounds.get_center().distance_squared_to(local_focus) < collision_chunks[b].bounds.get_center().distance_squared_to(local_focus))
    started = Time.get_ticks_usec()
    var created := 0
    for key in pending:
        if not eager and (created >= 2 or (created > 0 and Time.get_ticks_usec() - started >= COLLISION_BUDGET_USEC)):
            break
        _create_collision_chunk(key)
        created += 1


func collision_snapshot() -> Dictionary:
    var shapes := 0
    for key in resident_collision_chunks:
        shapes += collision_chunks[key].indices.size()
    return {"streaming": collision_streaming, "chunks": collision_chunks.size(),
        "resident_chunks": resident_collision_chunks.size(), "authored_shapes": solid_rects.size(),
        "resident_shapes": shapes if collision_streaming else solid_rects.size(),
        "loads": collision_loads, "releases": collision_releases, "critical_loads": critical_loads,
        "critical_bounds": critical_bounds}


func _exit_tree() -> void:
    collision_shutdown = true
    resident_collision_chunks.clear()
    collision_pins.clear()
    # Shapes are tree-owned. No detached-body retention or deferred work queue.


## Short-lived pins preserve offscreen projectile sweeps, beams and AI sight.
## The descriptor query is conservative; authored rectangles are never split.
func ensure_collision_segment(from: Vector2, to: Vector2) -> void:
    if not collision_streaming or collision_shutdown or not from.is_finite() or not to.is_finite():
        return
    var bounds := Rect2(to_local(from), Vector2.ZERO).expand(to_local(to)).grow(16)
    for key in collision_chunks:
        if bounds.intersects(collision_chunks[key].bounds):
            _create_collision_chunk(key)
            collision_pins[key] = Engine.get_physics_frames() + 2


## Fresh bodies may not be visible to a physics ray until the server syncs.
## Query immutable rectangles as well, so a remote shot cannot exploit that gap.
func rock_ray_hit(from: Vector2, to: Vector2) -> Dictionary:
    if not collision_streaming or not from.is_finite() or not to.is_finite():
        return {}
    var start := to_local(from)
    var direction := to_local(to) - start
    var nearest := INF
    for rect in solid_rects:
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
        if intersects and low <= high and low <= 1.0 and high >= 0.0:
            nearest = minf(nearest, maxf(0.0, low))
    return {} if not is_finite(nearest) else {"position": from.lerp(to, nearest), "authored_rock": true}


func critical_collision_ready() -> bool:
    return not collision_streaming or Engine.get_physics_frames() >= critical_sync_until
