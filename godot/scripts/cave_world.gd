extends Node2D
## Opaque rock mass, real cave collision and local visibility limited by rock.

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
var ray_count := 96
var lights: Array[Vector2] = []

func configure(chapter: Dictionary, theme: String, owner_scene: Node2D) -> void:
    name = "CaveWorld"
    scene = owner_scene
    rock_ink = Color(INKS.get(theme,"172d26"))
    var data: Dictionary = chapter.get("cave_world", {})
    if data.is_empty(): return
    vision_radius = float(data.get("vision_radius",540))
    outlines = data.get("outlines",[])
    var body := StaticBody2D.new()
    body.name = "SolidCaveMass"
    body.collision_layer = 17 # Terrain + a dedicated sight-blocker bit.
    body.collision_mask = 0
    add_child(body)
    for value in data.get("solid_rects",[]):
        var rect := Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
        solid_rects.append(rect)
        var collision := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = rect.size
        collision.position = rect.get_center()
        collision.shape = shape
        body.add_child(collision)
    z_index = 12 # Opaque rock covers distant backdrops and wall ornaments.
    queue_redraw()
    for point in chapter.get("save_points",[]):
        lights.append(Vector2(float(point.position[0]),float(point.position[1])-65))
    _create_vision()

func _draw() -> void:
    for rect in solid_rects:
        draw_rect(rect,Color("030609"))
    for value in outlines:
        var points := PackedVector2Array()
        for p in value:points.append(Vector2(float(p[0]),float(p[1])))
        if points.size()<2:continue
        draw_polyline(points,rock_ink,22.0,true)
        draw_polyline(points,rock_ink.lightened(.15),3.0,true)
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
    var viewport := get_viewport()
    var camera := viewport.get_camera_2d()
    if camera==null:return
    # A world-space quad follows the camera; HUD lives in its separate CanvasLayer.
    var inverse := viewport.get_canvas_transform().affine_inverse()
    var size := viewport.get_visible_rect().size
    fog.global_position = inverse * Vector2.ZERO
    fog.size = size / camera.zoom
    var origin: Vector2 = scene.player.global_position + Vector2(0,-48)
    var radius := vision_radius
    var room_id := String(scene.current_room_id)
    if room_id.contains("vault") or room_id.contains("grotto"):
        radius = 360.0
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
