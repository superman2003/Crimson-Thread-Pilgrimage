extends "res://scripts/world_waterwheel_route_playback.gd"
## Exact earned dash-return seed; normal Input travel to the authored moss viaduct ring.
const HOOK_SAVE:="user://test_v04_hook_world_20261024.json"
const HOOK_SEED:="res://../artifacts/w03_earned_dash/final_native_02/earned_dash_return_seed.json"
const RETIREMENT:=preload("res://scripts/audio_retirement.gd")
const AUDIO:=preload("res://scripts/audio_director.gd")
const POLICY:=preload("res://scripts/combat_visual_policy.gd")
var output:=""
func hookwork(kind:String="") -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("player_hook_art") and not n.is_queued_for_deletion() and (kind.is_empty() or n.kind==kind))
func capture(label:String) -> void:
    if output.is_empty():return
    await RenderingServer.frame_post_draw
    _check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native capture")
func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    var bytes:=FileAccess.get_file_as_bytes(HOOK_SEED);var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
    _check(hash.finish().hex_encode()=="3de61acca3f0263c2ebe1647ab452533313cc2ace4caa22335513e69071be137","exact published original seed bytes")
    var file:=FileAccess.open(HOOK_SAVE,FileAccess.WRITE);file.store_buffer(bytes);file.close();scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=true;scene.world_save_path=HOOK_SAVE;root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene);current_scene=scene;await _tick(15)
    _check(scene.player.hp==5 and scene.player.max_hp==7 and scene.player.thread_grapple_unlocked and scene.currency_count==329 and not scene.player.debug_invulnerable,"original stock HP remains5/max7 and earned hook/dash retained")
    print("HOOK_WORLD_START ",scene.player.position)
    for platform in scene.config.platforms:
        var rect:Variant=platform.get("rect",[])
        if rect.size()==4 and rect[0]>=2400 and rect[0]<=4400 and rect[1]>2400 and rect[1]<3800:print("HOOK_WORLD_PLATFORM ",platform.id," ",rect)
    for anchor in get_nodes_in_group("grapple_anchor"):print("HOOK_WORLD_RING ",anchor.name," ",anchor.global_position)
    for point in [Vector2(1420,3692),Vector2(1130,3612),Vector2(870,3532),Vector2(640,3452),Vector2(410,3400)]:
        if not await _leap(point,20,"normal old court west lift return"):await finish_hook();return
    await _interact("moss_salt_lift_lower","demo_ch01_moss_bell_court",Vector2(4850,610))
    if failures>0:await finish_hook();return
    if not await _leap(Vector2(4430,716),20,"normal salt attic lip crossing"):await finish_hook();return
    Input.action_press("move_left")
    for i in 800:
        await _tick(1)
        if i%60==0:print("HOOK_WORLD_DESCENT ",scene.player.position)
        if scene.player.position.x<4280:Input.action_release("move_left")
        if scene.player.position.y>1500 and scene.player.is_on_floor():Input.action_press("move_right")
        elif scene.player.position.y>1500:Input.action_release("move_right")
        if scene.player.position.y>2470:break
    Input.action_release("move_left");Input.action_release("move_right")
    _release()
    Input.action_press("move_left");await _tick(3);Input.action_release("move_left")
    print("HOOK_WORLD_READINESS unlocked=",scene.player.thread_grapple_unlocked," can=",scene.player._can_start_action()," ui=",scene.player.ui_input_locked," attack=",scene.player.attack_timer)
    for anchor in get_nodes_in_group("grapple_anchor"):print("HOOK_WORLD_ENABLED ",anchor.name," ",anchor.get_meta("grapple_enabled")," visible=",anchor.is_visible_in_tree())
    Input.action_press("aim_up");Input.action_press("hook");await process_frame;await _tick(3);Input.action_release("hook");Input.action_release("aim_up")
    var query:=PhysicsRayQueryParameters2D.create(scene.player.global_position+Vector2(0,-42),Vector2(4300,2480),scene.player.collision_mask,[scene.player.get_rid()])
    print("HOOK_WORLD_GATE facing=",scene.player.facing," origin=",scene.player.global_position+Vector2(0,-42)," obstruction=",scene.player.get_world_2d().direct_space_state.intersect_ray(query))
    _check(scene.player.grapple_timer>0 and is_instance_valid(scene.player.grapple_anchor) and String(scene.player.grapple_anchor.name)=="moss_viaduct_ring","normal Input acquired actual authored viaduct anchor")
    _check(hookwork("traversal").size()==1 and not hookwork("latch").is_empty(),"real World anchor owns head/cord and actual latch")
    print("HOOK_WORLD_ATTACHED hp=",scene.player.hp," death_count=",deaths," ",scene.player.position," anchor=",scene.player.grapple_anchor.global_position if is_instance_valid(scene.player.grapple_anchor) else Vector2.ZERO)
    await capture("world_hook_attached")
    for i in 70:
        if scene.player.grapple_timer<=0:break
        await _tick(1)
    _check(scene.player.grapple_timer<=0 and hookwork("traversal").is_empty(),"normal World pull retires active head/cord")
    await capture("world_hook_recovery");await _tick(25)
    _check(hookwork().is_empty() and deaths==0,"normal World route survives and cleans material")
    await finish_hook()
func finish_hook() -> void:
    _release();Input.action_release("hook");Input.action_release("aim_up");RETIREMENT.retire_tree(scene);scene.queue_free();scene=null
    for i in 5:await process_frame
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear();_check(await RETIREMENT.drain(self),"observable World audio retirement")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(HOOK_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(HOOK_SAVE+suffix))
    print("PLAYER_HOOK_WORLD failures=%d input_only=true direct_damage=false"%failures);quit(1 if failures else 0)
