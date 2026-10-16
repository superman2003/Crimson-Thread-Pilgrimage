extends SceneTree
## Real GL at fixture positions, separate from full-length physics acceptance.
const PASSAGE := preload("res://scripts/world_passage.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
var scene: Node
var failures := 0
var probes: Array = []
func _initialize() -> void: call_deferred("run")
func draw_frames(count: int = 3) -> void:
    for tick in count:
        await process_frame
        await RenderingServer.frame_post_draw
func run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Network visual checks require real GL")
        quit(1)
        return
    root.size=Vector2i(1280,720)
    var output := ProjectSettings.globalize_path("res://../artifacts/passage_network")
    DirAccess.make_dir_recursive_absolute(output)
    for route in PASSAGE.routes():
        var portal: Dictionary=ROUTES.portal(String(route.a.region),String(route.a.portal))
        scene=load("res://scenes/World.tscn").instantiate()
        scene.world_resume=false
        scene.world_save_path="user://passage_network_pixels.json"
        scene.config_path=ROUTES.config_path(String(route.a.region))
        root.add_child(scene)
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
        current_scene=scene
        scene.process_mode=Node.PROCESS_MODE_DISABLED
        for ability in ["silk_wall_grip","double_thread_jump","lantern_phase"]: scene._add_inventory_item(ability,1,false)
        scene._sync_player_abilities()
        scene.player.global_position=Vector2(portal.position[0],portal.position[1])
        if not scene.world_passage.begin(String(portal.id)):
            push_error("Cannot enter visual fixture "+String(route.id))
            quit(1)
            return
        for fraction in [0.005,0.5,0.995]:
            scene.player.global_position=scene.world_passage.source_point.lerp(scene.world_passage.destination_point,fraction)+Vector2(0,40)
            scene.player.reset_camera_after_arrival()
            var camera: Camera2D=scene.player.get_node("Camera2D")
            camera.reset_smoothing()
            camera.force_update_scroll()
            await draw_frames()
            var visible: Image=root.get_texture().get_image()
            scene.player.hide()
            await draw_frames()
            var hidden: Image=root.get_texture().get_image()
            scene.player.show()
            var hero_pixels := 0
            var colors := {}
            var lit := 0
            for y in range(0,720,2):
                for x in range(0,1280,2):
                    if visible.get_pixel(x,y)!=hidden.get_pixel(x,y): hero_pixels+=1
                    if x%12==0 and y%12==0:
                        var color := visible.get_pixel(x,y)
                        colors[color.to_html()]=true
                        if color.get_luminance()>0.025: lit+=1
            var ok := hero_pixels>40 and colors.size()>64 and lit>500
            if not ok:
                failures+=1
                push_error("Network render lacks visible hero or textured lane: "+String(route.id)+" "+str(fraction))
            var file := "%s_%03d.webp" % [route.id,int(fraction*1000)]
            if visible.save_webp(output.path_join(file))!=OK:
                failures+=1
                push_error("Cannot save network capture")
            probes.append({"route":route.id,"fraction":fraction,"hero_pixels":hero_pixels,"colors":colors.size(),"lit_samples":lit,"passed":ok,"file":file})
        scene.free()
        current_scene=null
        await process_frame
    var file := FileAccess.open(output.path_join("gpu_network.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer":"real_gl","fixture_positioning":true,"probes":probes,"failures":failures},"  "))
    file.close()
    for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://passage_network_pixels.json"+suffix))
    print("PASSAGE_NETWORK_PIXELS probes=%d failures=%d" % [probes.size(),failures])
    quit(0 if failures==0 else 1)
