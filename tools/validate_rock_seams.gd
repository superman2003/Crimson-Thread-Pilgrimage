extends SceneTree
## GPU probe: opposing source edges deliberately disagree. Requires real GL.
const SHADER = preload("res://shaders/world_rock.gdshader")
const ROCK_ATLAS := "res://assets/sprites/flat_maps/shared_ink/rock_mass_ink_v1.webp"
var results: Array = []
var failures := 0
func _initialize() -> void: call_deferred("run")
func panel(parent: Node, material: Material, rect: Rect2) -> void:
    var face := Polygon2D.new()
    face.position = rect.position
    face.polygon = PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x,0),rect.size,Vector2(0,rect.size.y)])
    face.material = material
    parent.add_child(face)
func render_probe(material: ShaderMaterial, center: Vector2, split: bool, extent: int = 64) -> Image:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(extent,extent)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var world := Node2D.new()
    viewport.add_child(world)
    var half := float(extent)*0.5
    if split:
        panel(world,material,Rect2(center-Vector2(half,half),Vector2(half,extent)))
        panel(world,material,Rect2(center-Vector2(0,half),Vector2(half,extent)))
    else: panel(world,material,Rect2(center-Vector2(half,half),Vector2(extent,extent)))
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
    # Modes: plain repeat (seams expected), plain mirror fold, and the V03
    # repetition-breaking blend, which must stay as seam-free as the fold.
    for center in [Vector2(64,32),Vector2(-64,32),Vector2(128,32),Vector2(32,64),Vector2(32,-64),Vector2(64,-64)]:
        for mode in ["repeat","mirror","blend"]:
            var mirrored: bool = mode!="repeat"
            material.set_shader_parameter("mirror_repeat",mirrored)
            material.set_shader_parameter("break_repetition",mode=="blend")
            var whole: Image = await render_probe(material,center,false)
            var split: Image = await render_probe(material,center,true)
            if whole.is_empty() or split.is_empty():
                push_error("Real renderer required")
                quit(1)
                return
            var edge := 0.0
            var partition := 0.0
            var interior := 0.0
            for i in 64:
                if int(center.x)%64==0: edge=maxf(edge,delta(whole.get_pixel(31,i),whole.get_pixel(32,i)))
                if int(center.y)%64==0: edge=maxf(edge,delta(whole.get_pixel(i,31),whole.get_pixel(i,32)))
                for j in 64: partition=maxf(partition,delta(whole.get_pixel(i,j),split.get_pixel(i,j)))
                for j in 63:
                    if j!=31:
                        interior=maxf(interior,delta(whole.get_pixel(j,i),whole.get_pixel(j+1,i)))
                        interior=maxf(interior,delta(whole.get_pixel(i,j),whole.get_pixel(i,j+1)))
            # The fold reverses the gradient at the edge (neighbours equal). The
            # blend's own layer transitions are continuous but can be steep at
            # this 64px probe scale, so its tile edge must simply be no sharper
            # than its steepest step elsewhere; a real atlas seam jumps alone.
            var edge_ok: bool = edge>0.5 if mode=="repeat" else (edge<0.01 if mode=="mirror" else edge<=interior*1.05+0.01)
            var passed: bool = edge_ok and partition<0.01
            if not passed: failures+=1
            results.append({"center":[center.x,center.y],"mode":mode,"edge_delta":edge,"interior_max_delta":interior,"partition_delta":partition,"pass":passed})
    # V03 symmetry probe on the real ink rock: around a corner where both fold
    # axes cross, the plain mirror is an exact four-way kaleidoscope; the blend
    # must break it. Score = mean |left - mirrored right| over a 96px band.
    var rock: Texture2D = load(ROCK_ATLAS)
    var real := ShaderMaterial.new()
    real.shader = SHADER
    real.set_shader_parameter("stone_atlas",rock)
    real.set_shader_parameter("tile_size",Vector2(rock.get_size()))
    var corner := Vector2(rock.get_size())
    for mode in ["mirror","blend"]:
        real.set_shader_parameter("break_repetition",mode=="blend")
        var patch: Image = await render_probe(real,corner,false,256)
        var total := 0.0
        var samples := 0
        for y in range(0,256,2):
            for k in range(1,97):
                total += delta(patch.get_pixel(128-k,y),patch.get_pixel(127+k,y))
                samples += 1
        var score := total/float(samples)
        var symmetric_ok: bool = score<0.01 if mode=="mirror" else score>0.03
        if not symmetric_ok: failures+=1
        results.append({"symmetry_probe":mode,"mirror_difference":score,"pass":symmetric_ok})
        print("ROCK_SYMMETRY %s mirror_difference=%.4f" % [mode,score])
    var output := ProjectSettings.globalize_path("res://../artifacts/hero_rock_upgrade/checkpoint4")
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output+"/gpu_seams.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"probes":results,"failures":failures},"  "))
    file.close()
    print("ROCK_SEAMS probes=20 failures=",failures)
    quit(1 if failures else 0)
