extends SceneTree
const COORD := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
var probes: Array = []
var failures := 0
func _initialize() -> void: call_deferred("run")
func capture() -> Image:
    for unused in 3: await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func changed(a: Image,b: Image) -> int:
    var result := 0
    for y in range(0,a.get_height(),2):
        for x in range(0,a.get_width(),2):
            if a.get_pixel(x,y)!=b.get_pixel(x,y): result += 1
    return result
func run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Real GL required")
        quit(1)
        return
    root.size = Vector2i(1280,720)
    var output := ProjectSettings.globalize_path("res://../artifacts/world_rims")
    DirAccess.make_dir_recursive_absolute(output)
    for id in COORD.manifest().regions:
        var scene: Node = load("res://scenes/Main.tscn").instantiate()
        scene.config_path = ROUTES.config_path(id)
        root.add_child(scene)
        current_scene = scene
        await process_frame
        # Retire audio before the accelerated graphics-only fixture freezes AI.
        for voice in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer2D",true,false):
            voice.stop()
            voice.stream = null
        scene.process_mode = Node.PROCESS_MODE_DISABLED
        scene.ui_canvas.visible = false
        scene.player.get_node("Camera2D").enabled = false
        var forms: Array = scene.config.terrain
        for index in [0,forms.size()/2]:
            var surface: Array = forms[index].surface
            var a: Array = surface[0]
            var b: Array = surface[1]
            var point := Vector2((float(a[0])+float(b[0]))*0.5,(float(a[1])+float(b[1]))*0.5)
            scene.player.position = point
            var center := (point-Vector2(0,110)).clamp(Vector2(640,360),Vector2(scene.world_width-640,scene.world_height-360))
            root.canvas_transform = Transform2D(0,Vector2(640,360)-center)
            var mass: Node = scene.cave_world.get_node("PaintedRockMass")
            mass._refresh_view()
            var image := await capture()
            var rims: Array = []
            for node in scene.find_children("*","Polygon2D",true,false):
                if node.has_meta("independent_edge_art"):
                    rims.append(node)
                    node.visible = false
            var without := await capture()
            for rim in rims: rim.visible = true
            var pixels := changed(image,without)
            var passed := pixels>100
            if not passed:
                failures += 1
                push_error("Room rims invisible: "+id)
            var name := "%s_%d.jpg" % [String(id),index]
            if image.save_jpg(output.path_join(name),0.91)!=OK:
                failures += 1
                push_error("Cannot save room image")
            probes.append({"region":id,"terrain_index":index,"rim_pixels":pixels,"passed":passed,"file":name,"fixture_positioning":true})
        scene.free()
        current_scene = null
        await process_frame
        root.canvas_transform = Transform2D.IDENTITY
    var file := FileAccess.open(output.path_join("gpu_rims.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer":"real_gl","probes":probes,"failures":failures},"  "))
    file.close()
    print("ROOM_RIM_PIXELS probes=%d failures=%d" % [probes.size(),failures])
    quit(1 if failures else 0)
