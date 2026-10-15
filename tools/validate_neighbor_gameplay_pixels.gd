extends SceneTree
## Paused canonical arrival art parity, not natural gameplay acceptance.
const COORD := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
var scene: Node
var failures := 0
var probes: Array = []
var output: String
func _initialize() -> void: call_deferred("run")
func capture() -> Image:
    for unused in 3: await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func live(key: String, data: Dictionary) -> Area2D:
    if not key.begins_with("enemy:"): return scene.get_node_or_null(NodePath(String(data.id)))
    for child in scene.get_children():
        if child.get_script() == scene.ENEMY_ACTOR_SCRIPT and child.spawn_id == String(data.id): return child
    return null
func stage(records: Dictionary) -> int:
    for child in scene.get_children():
        if child is CanvasItem or child is CanvasLayer: child.visible = false
    scene.player.get_node("Camera2D").enabled = false
    root.canvas_transform = Transform2D.IDENTITY
    var count := 0
    for key in records:
        if count >= 5: break
        var area := live(key,records[key].data)
        if area == null: continue
        area.position = Vector2(150 + count * 240,480)
        area.visible = true
        count += 1
    return count
func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real OpenGL required")
        quit(1)
        return
    root.size = Vector2i(1280,720)
    root.process_mode = Node.PROCESS_MODE_DISABLED
    output = ProjectSettings.globalize_path("res://../artifacts/neighbor_gameplay")
    DirAccess.make_dir_recursive_absolute(output)
    var background := ColorRect.new()
    background.size = Vector2(1280,720)
    background.color = Color("172321")
    background.z_index = -100
    root.add_child(background)
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://neighbor_gameplay_pixels.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    var title := Label.new()
    title.position = Vector2(48,48)
    title.add_theme_font_override("font",load("res://assets/fonts/NotoSansSC.ttf"))
    title.add_theme_font_size_override("font_size",24)
    title.add_theme_color_override("font_color",Color("c7cbb5"))
    root.add_child(title)
    for id in COORD.manifest().regions:
        var pref: RefCounted = scene.world_prefetch
        pref.shutdown()
        pref.generation = scene.world_loader.generation
        pref.selection_elapsed = -1000
        var path := ROUTES.config_path(id)
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var entry := Vector2(raw.player_start[0],raw.player_start[1])
        var prepared: Dictionary = scene.world_loader.validate_config(raw,path,entry)
        pref.desired = {id:{"path":path,"entry":entry,"distance":0}}
        pref.configs = {id:{"raw":raw,"prepared":prepared,"stamp":FileAccess.get_modified_time(path)}}
        for unused in 500:
            pref.step(scene,0)
            if pref.gameplay.regions.has(id) and pref.gameplay.regions[id].pending.is_empty(): break
            await process_frame
        var records: Dictionary = pref.gameplay.regions[id].actors.duplicate()
        title.text = String(prepared.get("chapter_name",id))
        scene._travel_world(path,entry)
        var visible := stage(records)
        var warm: Image = await capture()
        pref.shutdown()
        scene._travel_world(path,entry)
        stage(records)
        var cold: Image = await capture()
        var changed := 0
        if warm.is_empty() or cold.is_empty() or warm.get_size() != cold.get_size():
            changed = 1000000
        else:
            warm.convert(Image.FORMAT_RGBA8)
            cold.convert(Image.FORMAT_RGBA8)
            var a := warm.get_data()
            var b := cold.get_data()
            for offset in range(0,a.size(),4):
                if a[offset] != b[offset] or a[offset+1] != b[offset+1] or a[offset+2] != b[offset+2]: changed += 1
        var ok := visible > 0 and changed == 0
        if not ok:
            failures += 1
            push_error("Gameplay art parity failed %s: %d pixels" % [id,changed])
        probes.append({"region":id,"visible_actors":visible,"changed_pixels":changed,"passed":ok})
        cold.save_jpg(output.path_join(id+".jpg"),0.92)
    scene.free()
    await process_frame
    for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://neighbor_gameplay_pixels.json"+suffix))
    var file := FileAccess.open(output.path_join("gpu_gameplay.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer":"Mesa llvmpipe real GL","probes":probes,"failures":failures,"fixture_positioning":true,"combat_acceptance":false},"  ")+"\n")
    file.close()
    print("NEIGHBOR_GAMEPLAY_PIXELS probes=%d failures=%d" % [probes.size(),failures])
    quit(0 if failures == 0 else 1)
