extends Node2D
## First physical connector content block. World-coordinate endpoints remain
## fixed; destination gameplay is still loaded at the terminal, not seamless.
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const ROCK := preload("res://scripts/world_rock_material.gd")
const SUPPORT_SHADER := preload("res://shaders/passage_support.gdshader")
const DECOR_ATLAS := "res://assets/sprites/flat_maps/moss_cavern/decor_atlas.png"
# Whole authored ornaments from the existing moss atlas, not generated outlines.
const SUPPORT_REGION := Rect2(96, 652, 249, 566)
const LANTERN_REGION := Rect2(984, 627, 144, 576)
const PATH := "res://data/world_passages.json"
const TRANSIT_LAYER := 64
static var definitions: Array = []
static var connections: Dictionary = {}
var active := false
var settling := false
var retry_blocked := false
var host: Node
var source_id := ""
var source_point := Vector2.ZERO
var destination_point := Vector2.ZERO
var destination_id := ""
var route: Dictionary = {}
var frozen: Array[Dictionary] = []
var original_mask := 0
var original_layer := 0
var sync_until := 0
var support_material: ShaderMaterial
var rear_wall: Node2D
var ornament_texture: Texture2D
var notice: Label
var terminal_world_point := Vector2.ZERO
var previous_position := Vector2.ZERO
var travelled := 0.0
var last_result: Dictionary = {}

static func routes() -> Array:
    if definitions.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        definitions = parsed.get("passages", []) if parsed is Dictionary else []
    return definitions.duplicate(true)

static func endpoint(region: String, portal: String) -> Dictionary:
    if connections.is_empty():
        for passage in routes():
            for side in ["a", "b"]:
                var data: Dictionary = passage[side]
                var other: Dictionary = passage["b" if side == "a" else "a"]
                connections[String(data.region) + ":" + String(data.portal)] = {
                    "passage": passage, "source": data, "target": other,
                    "source_portal": ROUTES.portal(String(data.region), String(data.portal)),
                    "target_portal": ROUTES.portal(String(other.region), String(other.portal))}
    return connections.get(region + ":" + portal, {}).duplicate(true)

static func glyph(region: String, portal: String) -> String:
    var link := endpoint(region, portal)
    return "F" if link.is_empty() else "→" if String(link.source.region) == String(link.passage.a.region) else "←"

func bind(owner_host: Node) -> void:
    host = owner_host
    name = "WorldPassage"
    z_index = 0

func try_walk_entry() -> void:
    if active or settling or host.world_loading or host.chapter_transitioning or not host.active_overlay.is_empty() or host.player.hp <= 0:
        return
    for passage in routes():
        for side in ["a", "b"]:
            var data: Dictionary = passage[side]
            if String(data.region) != String(host.config.id):
                continue
            var link := endpoint(String(data.region), String(data.portal))
            var portal: Dictionary = link.source_portal
            var start := Vector2(portal.position[0], portal.position[1])
            var other: Dictionary = passage["b" if side == "a" else "a"]
            var target_portal: Dictionary = link.target_portal
            var target := COORDINATES.to_local(String(data.region), COORDINATES.to_world(String(other.region), Vector2(target_portal.position[0], target_portal.position[1])))
            var direction := signf(target.x - start.x)
            var key: String = "move_right" if direction > 0 else "move_left"
            # A deliberate step through the mouth; standing at it does not travel.
            if host.player.global_position.distance_to(start) < 52 and Input.is_action_pressed(key) and host.player.is_on_floor():
                begin(String(data.portal))
                return

func begin(portal_id: String) -> bool:
    if active or settling or host.world_loading or host.chapter_transitioning or host.world_loader.phase != "idle" or host.player.hp <= 0 or host.player.death_timer > 0:
        return false
    var connection := endpoint(String(host.config.id), portal_id)
    if connection.is_empty():
        return false
    var portal: Dictionary = connection.source_portal
    for candidate in host.config.get("interactives", []):
        if String(candidate.get("id", "")) == portal_id:
            portal = candidate
            break
    if host.player.global_position.distance_to(Vector2(portal.position[0], portal.position[1])) > 100:
        return false
    var status := ROUTES.access(portal, host.inventory_counts, host.story_flags)
    if not status.open:
        host._toast(String(status.hint))
        return false
    destination_id = String(connection.target.region)
    var target: Dictionary = connection.target_portal
    var entry := Vector2(target.position[0], target.position[1])
    if host.world_loader.preflight(ROUTES.config_path(destination_id), entry, host.world_prefetch).is_empty():
        host._toast(host.world_loader.last_error)
        return false
    route = connection.passage.duplicate(true)
    source_id = String(host.config.id)
    source_point = Vector2(portal.position[0], portal.position[1])
    destination_point = COORDINATES.to_local(source_id, COORDINATES.to_world(destination_id, entry))
    # Cancel geometry-bound actions and settle heal refunds before checkpointing.
    var speed: Vector2 = host.player.velocity
    host.player.prepare_region_handoff()
    host._close_overlays()
    host._save_world()
    original_layer = host.player.collision_layer
    original_mask = host.player.collision_mask
    host.player.collision_layer = TRANSIT_LAYER
    host.player.collision_mask = TRANSIT_LAYER
    host.player.velocity = speed
    frozen.clear()
    for node in host.get_children():
        if node == host.player or node == self:
            continue
        var record := {"node": node, "mode": node.process_mode}
        node.process_mode = Node.PROCESS_MODE_DISABLED
        if node is CanvasItem or node is CanvasLayer:
            record["visible"] = node.visible
            node.visible = false
        frozen.append(record)
    _build_tube()
    retry_blocked = false
    active = true
    host.world_loading = true # source Area signals and saves remain inert
    sync_until = Engine.get_physics_frames() + 1
    previous_position = host.player.global_position
    travelled = 0
    last_result = {}
    _camera_bounds()
    host.player.reset_camera_after_arrival()
    return true

func _build_tube() -> void:
    var a := source_point if source_point.x < destination_point.x else destination_point
    var b := destination_point if source_point.x < destination_point.x else source_point
    var floor_a := a + Vector2(0, 40)
    var floor_b := b + Vector2(0, 40)
    var length := b.x - a.x
    var theme := String(route.get("material", "moss_cavern"))
    var stone_material := ROCK.for_theme(theme)
    support_material = ShaderMaterial.new()
    support_material.shader = SUPPORT_SHADER
    support_material.set_shader_parameter("stone_atlas", stone_material.get_shader_parameter("stone_atlas"))
    support_material.set_shader_parameter("tile_size", stone_material.get_shader_parameter("tile_size"))
    rear_wall = Node2D.new()
    rear_wall.name = "PassageRearWall"
    rear_wall.z_index = -20
    add_child(rear_wall)
    var backdrop := ROCK.face(rear_wall, PackedVector2Array([a + Vector2(-640, -600), b + Vector2(640, -600), b + Vector2(640, 500), a + Vector2(-640, 500)]), theme)
    backdrop.color = Color(0.24, 0.32, 0.30)
    backdrop.z_index = -5
    var body := StaticBody2D.new()
    body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
    body.collision_layer = TRANSIT_LAYER
    body.collision_mask = 0
    add_child(body)
    # Two continuous polygon faces, one material throughout each structure.
    for points in [PackedVector2Array([floor_a + Vector2(-96, 0), floor_b + Vector2(96, 0), floor_b + Vector2(96, 400), floor_a + Vector2(-96, 400)]),
        PackedVector2Array([floor_a + Vector2(-96, -580), floor_b + Vector2(96, -580), floor_b + Vector2(96, -260), floor_a + Vector2(-96, -260)])]:
        var collision := CollisionPolygon2D.new()
        collision.polygon = points
        body.add_child(collision)
        var face := ROCK.face(self, points, theme)
        face.z_index = -5
    for point in [floor_a + Vector2(-96, -130), floor_b + Vector2(96, -130)]:
        var cap := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = Vector2(16, 260)
        cap.shape = shape
        cap.position = point
        body.add_child(cap)
    for index in range(int(length / 640) + 1):
        var x := a.x + index * 640
        var y := floor_a.y + (floor_b.y - floor_a.y) * (x - a.x) / length
        # Raised rear-wall foot, separated from the playable foreground lane.
        _painted_ornament("MossWallPilaster_%d" % index, SUPPORT_REGION,
            Vector2(x, y - 52), 208.0, "support", true)
        if x + 320 < b.x:
            var lamp_y := floor_a.y + (floor_b.y - floor_a.y) * (x + 320 - a.x) / length
            _painted_ornament("DrainpipeLantern_%d" % index, LANTERN_REGION,
                Vector2(x + 320, lamp_y - 246), 98.0, "lantern", false)
    # Continuous rear-wall plinth covers the pilaster feet 56px above the lane.
    var plinth := ROCK.face(rear_wall, PackedVector2Array([
        floor_a + Vector2(-640, -56), floor_b + Vector2(640, -56),
        floor_b + Vector2(640, 0), floor_a + Vector2(-640, 0)]), theme)
    plinth.name = "RearWallPlinth"
    plinth.color = Color(0.19, 0.25, 0.23)
    plinth.z_index = 2
    # Sideways travel ends here; rear-wall ornaments are never entrances.
    var direction := signf(destination_point.x - source_point.x)
    _endpoint_marker(source_point, source_id, -direction)
    _endpoint_marker(destination_point, destination_id, direction)
    var canvas := CanvasLayer.new()
    add_child(canvas)
    notice = Label.new()
    notice.position = Vector2(36, 30)
    notice.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC.ttf"))
    notice.add_theme_font_size_override("font_size", 20)
    canvas.add_child(notice)

func _endpoint_marker(point: Vector2, region_id: String, direction: float) -> void:
    var names := {"demo_ch01_moss_bell_court": "苔钟庭", "demo_ch02_rain_foundry_canal": "铸雨渠"}
    var marker := Label.new()
    marker.name = "Endpoint_" + region_id
    marker.text = "%s出口 →" % names[region_id] if direction > 0 else "← %s出口" % names[region_id]
    marker.position = point + Vector2(-140 * direction - 130, -100)
    marker.size = Vector2(260, 40)
    marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    marker.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC.ttf"))
    marker.add_theme_font_size_override("font_size", 22)
    marker.add_theme_color_override("font_color", Color(0.78, 0.80, 0.57))
    marker.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.04))
    marker.add_theme_constant_override("outline_size", 4)
    marker.z_index = -3
    add_child(marker)

func _painted_ornament(node_name: String, region: Rect2, anchor: Vector2,
        height: float, kind: String, bottom_anchor: bool) -> void:
    if ornament_texture == null:
        ornament_texture = load(DECOR_ATLAS) as Texture2D
    if ornament_texture == null:
        push_error("Missing painted drainpipe ornaments")
        return
    var frame := AtlasTexture.new()
    frame.atlas = ornament_texture
    frame.region = region
    frame.filter_clip = true
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = frame
    sprite.centered = false
    # Recessed wall ornament; preserve the authored aspect ratio.
    sprite.scale = Vector2.ONE * height / region.size.y
    sprite.position = anchor - Vector2(region.size.x * sprite.scale.x * 0.5,
        height if bottom_anchor else 0.0)
    # Child of the rear wall, behind its plinth and the entire gameplay plane.
    sprite.z_index = 1
    if kind == "support":
        sprite.material = support_material
    else:
        sprite.modulate = Color(0.42, 0.50, 0.37)
    sprite.set_meta("passage_ornament", kind)
    sprite.set_meta("original_map_asset", DECOR_ATLAS)
    rear_wall.add_child(sprite)

func _camera_bounds() -> void:
    var camera: Camera2D = host.player.get_node("Camera2D")
    camera.limit_left = floori(minf(source_point.x, destination_point.x) - 640)
    camera.limit_right = ceili(maxf(source_point.x, destination_point.x) + 640)
    camera.limit_top = floori(minf(source_point.y, destination_point.y) - 560)
    camera.limit_bottom = ceili(maxf(source_point.y, destination_point.y) + 440)

func step() -> void:
    if not active or settling:
        return
    var point: Vector2 = host.player.global_position
    travelled += point.distance_to(previous_position)
    previous_position = point
    var direction := signf(destination_point.x - source_point.x)
    notice.text = "%s · 距出口 %d 米\n继续步行；向来路折返 · Esc 返回入口" % [String(route.label), ceili(absf(destination_point.x - point.x) / 100)]
    if retry_blocked and (absf(point.x - destination_point.x) > 128 or Input.is_action_just_pressed("move_right" if direction > 0 else "move_left")):
        retry_blocked = false
    if Input.is_action_just_pressed("close_overlay") or host.player.hp <= 0 or point.y > maxf(source_point.y, destination_point.y) + 80:
        _return_to_source(true)
    elif direction * (point.x - source_point.x) < -30:
        _return_to_source(false)
    elif not retry_blocked and direction * (point.x - destination_point.x) >= 0:
        settling = true
        _arrive()

func _arrive() -> void:
    var world_point := COORDINATES.to_world(source_id, host.player.global_position)
    terminal_world_point = world_point
    var entry := COORDINATES.to_local(destination_id, world_point)
    # Keep the tube until target construction commits. The source remains the
    # saved checkpoint on cancellation/error; no half-built destination is saved.
    host.player.collision_layer = original_layer
    host.player.collision_mask = original_mask
    host.world_loading = false
    var ok: bool = await host.world_loader.replace_region_async(host, ROUTES.config_path(destination_id), entry, source_point)
    if not is_instance_valid(host) or not host.is_inside_tree():
        return
    if ok:
        last_result = {"arrived": true, "distance": travelled, "world_position": world_point}
        _clear()
        host._configure_player_camera()
        host.player.reset_camera_after_arrival()
    else:
        # Existing loader restores source state. Resume the physical terminal so
        # the player can walk back or retry without skipping the connector.
        var still_frozen := false
        for record in frozen:
            if is_instance_valid(record.node):
                still_frozen = true
        if not still_frozen:
            _freeze_current_region()
        host.player.global_position = COORDINATES.to_local(source_id, world_point)
        host.player.collision_layer = TRANSIT_LAYER
        host.player.collision_mask = TRANSIT_LAYER
        host.world_loading = true
        settling = false
        retry_blocked = true
        # Move only one step inward to avoid immediately retrying a cancelled load.
        host.player.global_position.x -= signf(destination_point.x - source_point.x) * 32
        sync_until = Engine.get_physics_frames() + 1
        _camera_bounds()
        host.player.reset_camera_after_arrival()

func _freeze_current_region() -> void:
    frozen.clear()
    for node in host.get_children():
        if node == self or node == host.player:
            continue
        var record := {"node": node, "mode": node.process_mode}
        node.process_mode = Node.PROCESS_MODE_DISABLED
        if node is CanvasItem or node is CanvasLayer:
            record["visible"] = node.visible
            node.visible = false
        frozen.append(record)

func _return_to_source(cancelled: bool) -> void:
    host.player.prepare_region_handoff()
    if cancelled:
        host.player.global_position = source_point
    for record in frozen:
        var node: Variant = record.node
        if is_instance_valid(node):
            node.process_mode = record.mode
            if node is CanvasItem or node is CanvasLayer:
                node.visible = bool(record.visible)
    host.player.collision_layer = original_layer
    host.player.collision_mask = original_mask
    host.world_loading = false
    last_result = {"arrived": false, "cancelled": cancelled, "distance": travelled}
    _clear()
    host._configure_player_camera()
    host.player.reset_camera_after_arrival()
    host.nearby_interactable = null
    host._save_world()

func _clear() -> void:
    active = false
    settling = false
    frozen.clear()
    notice = null
    ornament_texture = null
    support_material = null
    rear_wall = null
    for child in get_children():
        remove_child(child)
        child.queue_free()
