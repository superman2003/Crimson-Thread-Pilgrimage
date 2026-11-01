extends SceneTree
## Exact earned camp restore, actual air jump/contact/rebound; no state/HP/position grants.
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const SAVE := "user://test_v04_movement_world_20261023.json"
const SEED := "res://../artifacts/t04_obsidian_route/earned_camp_seed.json"
var failures := 0
var scene: Node2D
var output := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if not ok: failures += 1; push_error("MOVEMENT_WORLD: " + label)
func frames(count: int) -> void:
    for i in count: await physics_frame; await process_frame
func capture(label: String) -> void:
    if output.is_empty(): return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(label+".png"))
func finish() -> void:
    for action in ["move_right","move_left","jump","heal"]: Input.action_release(action)
    RETIREMENT.retire_tree(scene); scene.queue_free(); await frames(5)
    AUDIO._stream_cache.clear(); AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"observed world audio retirement")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(SAVE+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("PLAYER_MOVEMENT_WORLD failures="+str(failures))
    quit(1 if failures else 0)
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    var bytes := FileAccess.get_file_as_bytes(SEED)
    var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
    check(hash.finish().hex_encode()=="91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b","published exact earned camp")
    var file := FileAccess.open(SAVE,FileAccess.WRITE); file.store_buffer(bytes); file.close()
    scene = load("res://scenes/World.tscn").instantiate(); scene.world_resume=true; scene.world_save_path=SAVE; root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene; await frames(15)
    check(scene.player.hp==5 and scene.player.energy==100 and scene.currency_count==287 and not scene.player.debug_invulnerable,"unmodified earned resources and enabled injury")
    check(scene.player.double_jump_unlocked and scene.player.wall_grip_unlocked and not scene.player.dash_unlocked,"only normally earned air jump/grip; camp still has no dash")
    print("MOVEMENT_WORLD start=",scene.player.position," hp=",scene.player.hp," energy=",scene.player.energy)
    # Walk normally across the earned camp floor to clear the shrine sign's UI overlay.
    Input.action_press("move_right");await frames(45);Input.action_release("move_right");await frames(4)
    print("MOVEMENT_WORLD visible jump start=",scene.player.position)
    Input.action_press("jump");await frames(3);Input.action_release("jump");await frames(3)
    check(artwork("double_jump").is_empty(),"ordinary first World jump has no air fan")
    Input.action_press("jump");await frames(2);Input.action_release("jump")
    check(not scene.player.air_jump_available and artwork("double_jump").size()==1,"actual earned World double jump consumes once")
    await frames(3);await capture("world_double_jump")
    for frame in 150:
        if scene.player.is_on_floor():break
        await frames(1)
    check(scene.player.is_on_floor() and artwork("land").size()==1,"actual World landing edge produces dust")
    await capture("world_land")
    await frames(20)
    Input.action_press("move_left")
    for frame in 180:
        if scene.player.is_on_wall() and scene.player.position.x<125:break
        await frames(1)
    print("MOVEMENT_WORLD west contact=",scene.player.position," normal=",scene.player.get_wall_normal())
    check(scene.player.is_on_wall(),"normal west walk reaches actual camp rock wall")
    Input.action_press("jump");await frames(3);Input.action_release("jump")
    for frame in 90:
        if scene.player.wall_sliding and artwork("wall_grip").size()==1:break
        await frames(1)
    check(scene.player.wall_sliding and artwork("wall_grip").size()==1,"actual earned World wall grip follows falling contact")
    await capture("world_wall_grip")
    var id:int=artwork("wall_grip")[0].get_instance_id() if artwork("wall_grip").size()==1 else 0
    await frames(5)
    check(artwork("wall_grip").size()==1 and artwork("wall_grip")[0].get_instance_id()==id,"World contact persists without per-frame spawning")
    Input.action_press("jump");await frames(2);Input.action_release("jump");Input.action_release("move_left")
    check(scene.player.velocity.x>0 and scene.player.velocity.y<0,"actual World wall rebound preserves positive away impulse")
    await capture("world_wall_jump")
    check(scene.player.hp==5 and scene.player.energy==100 and scene.currency_count==287,"only normal movement; no HP/resource grants or costs")
    print("MOVEMENT_WORLD result=",scene.player.position," hp=",scene.player.hp," energy=",scene.player.energy," wallet=",scene.currency_count)
    await finish()
func artwork(family:String) -> Array:
    return scene.player.get_children().filter(func(n):return n.has_meta("player_movement_art") and not n.is_queued_for_deletion() and n.family==family)
