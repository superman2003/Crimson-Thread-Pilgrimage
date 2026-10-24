extends SceneTree
## Exact earned camp save, normal Input only. No direct damage, position, HP or ability writes.
const SAVE := "user://test_v04_dash_world_20261024.json"
const SEED := "res://../artifacts/w03_earned_dash/final_native_02/earned_dash_return_seed.json"
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
var scene: Node2D
var failures := 0
var output := ""
var observed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if not ok: failures += 1; push_error("DASH_WORLD: "+label)
func frames(count: int) -> void:
    for i in count: await physics_frame; await process_frame
func artwork() -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("player_dash_art") and not n.is_queued_for_deletion())
func capture(label:String) -> void:
    if output.is_empty():return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native capture")
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    var bytes:=FileAccess.get_file_as_bytes(SEED)
    var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
    check(hash.finish().hex_encode()=="3de61acca3f0263c2ebe1647ab452533313cc2ace4caa22335513e69071be137","exact published camp seed")
    var file:=FileAccess.open(SAVE,FileAccess.WRITE);file.store_buffer(bytes);file.close()
    scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=true;scene.world_save_path=SAVE;root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene;await frames(15)
    check(scene.player.hp==5 and scene.player.max_hp==7 and scene.player.energy==100 and scene.currency_count==329 and not scene.player.debug_invulnerable and scene.player.dash_unlocked,"unchanged earned resources, real injury enabled")
    print("DASH_WORLD_START ",scene.player.position," hp=",scene.player.hp)
    var hp_before:int=scene.player.hp;var start:Vector2=scene.player.position
    Input.action_press("dash");await frames(1);Input.action_release("dash")
    check(scene.player.dash_timer>0 and artwork().is_empty(),"normally earned World dash starts; end material waits for real expiry")
    for i in 40:
        if scene.player.dash_timer<=0:break
        await frames(1)
    check(artwork().size()==1,"actual World dash expiry owns one authored ribbon")
    if artwork().size()==1:
        check(artwork()[0].from==start+Vector2(0,-34) and artwork()[0].length>24,"World ribbon uses actual traveled endpoint")
    print("DASH_WORLD_ACCEPTED start=",start," end=",scene.player.position," hp=",scene.player.hp," max_hp=",scene.player.max_hp," wallet=",scene.currency_count," ribbon_count=",artwork().size())
    await capture("world_dash_end")
    await frames(24)
    check(scene.player.hp==hp_before and scene.currency_count==329 and artwork().is_empty(),"World dash preserves actual resources and retires material")
    RETIREMENT.retire_tree(scene);scene.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"observable World audio retirement")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("PLAYER_DASH_WORLD failures="+str(failures)+" input_only=true direct_damage=false")
    quit(1 if failures else 0)
