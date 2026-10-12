extends SceneTree
## GPU probe: opposing source edges deliberately disagree. Requires real GL.
const SHADER = preload("res://shaders/world_rock.gdshader")
var results: Array = []
var failures := 0
func _initialize() -> void: call_deferred("run")
func panel(parent: Node, material: Material, rect: Rect2) -> void:
    var face := Polygon2D.new()
    face.position = rect.position
    face.polygon = PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x,0),rect.size,Vector2(0,rect.size.y)])
    face.material = material
    parent.add_child(face)
func render_probe(material: ShaderMaterial, center: Vector2, split: bool) -> Image:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(64,64)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var world := Node2D.new()
    viewport.add_child(world)
    if split:
        panel(world,material,Rect2(center-Vector2(32,32),Vector2(32,64)))
        panel(world,material,Rect2(center-Vector2(0,32),Vector2(32,64)))
    else: panel(world,material,Rect2(center-Vector2(32,32),Vector2(64,64)))
    var camera := Camera2D.new()
    camera.position = center
    viewport.add_child(camera)
    for tick in 3: await process_frame
    await RenderingServer.frame_post_draw
    var image := viewport.get_texture().get_image()
    viewport.queue_free()
    await process_frame
    return image
func delta(a: Color,b: Color) -> float:
    return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func run() -> void:
    var source := Image.create(64,64,false,Image.FORMAT_RGBA8)
    for y in 64:
        for x in 64: source.set_pixel(x,y,Color(float(x)/63,float(y)/63,0.25,1))
    var material := ShaderMaterial.new()
    material.shader = SHADER
    material.set_shader_parameter("stone_atlas",ImageTexture.create_from_image(source))
    material.set_shader_parameter("tile_size",Vector2(64,64))
    for center in [Vector2(64,32),Vector2(-64,32),Vector2(128,32),Vector2(32,64),Vector2(32,-64),Vector2(64,-64)]:
        for mirrored in [false,true]:
            material.set_shader_parameter("mirror_repeat",mirrored)
            var whole: Image = await render_probe(material,center,false)
            var split: Image = await render_probe(material,center,true)
            if whole.is_empty() or split.is_empty():
                push_error("Real renderer required")
                quit(1)
                return
            var edge := 0.0
            var partition := 0.0
            for i in 64:
                if int(center.x)%64==0: edge=maxf(edge,delta(whole.get_pixel(31,i),whole.get_pixel(32,i)))
                if int(center.y)%64==0: edge=maxf(edge,delta(whole.get_pixel(i,31),whole.get_pixel(i,32)))
                for j in 64: partition=maxf(partition,delta(whole.get_pixel(i,j),split.get_pixel(i,j)))
            var passed: bool = (edge<0.01 if mirrored else edge>0.5) and partition<0.01
            if not passed: failures+=1
            results.append({"center":[center.x,center.y],"mirror_repeat":mirrored,"edge_delta":edge,"partition_delta":partition,"pass":passed})
    var output := ProjectSettings.globalize_path("res://../artifacts/hero_rock_upgrade/checkpoint4")
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output+"/gpu_seams.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"probes":results,"failures":failures},"  "))
    file.close()
    print("ROCK_SEAMS probes=12 failures=",failures)
    quit(1 if failures else 0)
