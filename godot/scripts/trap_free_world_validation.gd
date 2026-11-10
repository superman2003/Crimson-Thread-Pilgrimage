extends SceneTree
const RETIRE := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const PROBE := preload("res://scripts/trap_free_validation_helper.gd")
const CHAPTERS := ["moss_bell_court","rain_foundry_canal","saltwhite_archive","broken_string_greenhouse","obsidian_pilgrim_road","silent_crown_core"]
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;push_error("TRAP_FREE_WORLD "+label)
func frames(n: int) -> void:
    for i in n:
        await physics_frame
        await process_frame
func visible_player(scene: Node2D) -> bool:
    return scene.player.is_visible_in_tree() and root.get_visible_rect().has_point(scene.player.get_global_transform_with_canvas().origin)
func retired_nodes(node: Node) -> int:
    var total := int(node.has_meta("hazard_authored_size") or String(node.name).begins_with("HazardMotif"))
    for child in node.get_children(): total+=retired_nodes(child)
    return total
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var output:=ProjectSettings.globalize_path("res://../artifacts/trap_free_world_v1/native")
    DirAccess.make_dir_recursive_absolute(output)
    for index in CHAPTERS.size():
        var path: String="res://data/demo_ch%02d_%s.json"%[index+1,CHAPTERS[index]]
        var scene=load("res://scenes/Main.tscn").instantiate()
        scene.config_path=path;root.add_child(scene)
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
        await frames(30)
        check(scene.config.get("hazards",[]).is_empty(),path+" contains no level traps")
        check(scene.hazard_total==0,path+" reports zero trap instances")
        check(retired_nodes(scene)==0,path+" has no trap art, collision owners or invisible triggers")
        check(get_nodes_in_group("pogo_surface").is_empty(),path+" has no environmental pogo surfaces")
        for result in PROBE.probe(scene,scene.player): check(bool(result[0]),path+" "+String(result[1]))
        if DisplayServer.get_name()!="headless":
            check(visible_player(scene),path+" camera has settled on the visible Player before capture")
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_jpg(output.path_join("ch%02d-clear.jpg"%[index+1]),.88)==OK,"save actual chapter capture")
        RETIRE.retire_tree(scene);scene.queue_free();await frames(4)
        AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
        check(await RETIRE.drain(self),path+" audio ownership retires")
    var world=load("res://scenes/World.tscn").instantiate()
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    await frames(30)
    check(world.initial_region_ready and world.world_mode,"actual World entry finishes loading")
    check(world.hazard_total==0 and retired_nodes(world)==0,"actual World entry has no trap graphics or triggers")
    for result in PROBE.probe(world,world.player):check(bool(result[0]),"actual World "+String(result[1]))
    if DisplayServer.get_name()!="headless":
        check(visible_player(world),"actual World camera has settled on the visible Player before capture")
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_jpg(output.path_join("world-clear.jpg"),.88)==OK,"save actual World entry capture")
    RETIRE.retire_tree(world);world.queue_free();await frames(4)
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"actual World audio ownership retires")
    print("TRAP_FREE_WORLD checks=%d failures=%d chapters=6"%[checks,failures])
    quit(0 if failures==0 else 1)
