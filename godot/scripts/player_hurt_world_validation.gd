extends SceneTree
## Exact earned camp save, normal Input only. No direct damage, position, HP or ability writes.
const SAVE := "user://test_v04_hurt_world_20261024.json"
const SEED := "res://../artifacts/t04_obsidian_route/earned_camp_seed.json"
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
var scene: Node2D
var failures := 0
var output := ""
var observed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if not ok: failures += 1; push_error("HURT_WORLD: "+label)
func frames(count: int) -> void:
    for i in count: await physics_frame; await process_frame
func artwork() -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("player_hurt_art") and not n.is_queued_for_deletion())
func capture(label:String) -> void:
    if output.is_empty():return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native capture")
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    var bytes:=FileAccess.get_file_as_bytes(SEED)
    var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
    check(hash.finish().hex_encode()=="91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b","exact published camp seed")
    var file:=FileAccess.open(SAVE,FileAccess.WRITE);file.store_buffer(bytes);file.close()
    scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=true;scene.world_save_path=SAVE;root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene;await frames(15)
    check(scene.player.hp==5 and scene.player.max_hp==6 and scene.player.energy==100 and scene.currency_count==287 and not scene.player.debug_invulnerable and not scene.player.dash_unlocked,"unchanged earned resources, real injury enabled")
    print("HURT_WORLD_START ",scene.player.position," hp=",scene.player.hp)
    for enemy in get_nodes_in_group("enemy"):print("HURT_WORLD_ENEMY ",enemy.name," at=",enemy.global_position)
    var hp_before:int=scene.player.hp
    Input.action_press("move_right")
    for frame in 600:
        if frame==135 or frame==155:Input.action_press("jump")
        if frame==138 or frame==158:Input.action_release("jump")
        if scene.player.position.x>1000:Input.action_release("move_right");Input.action_press("move_left")
        if scene.player.position.x<910 and frame>150:Input.action_release("move_left");Input.action_press("move_right")
        await frames(1)
        if frame%60==0:print("HURT_WORLD_INPUT frame=",frame," position=",scene.player.position," hp=",scene.player.hp)
        if scene.player.hp<hp_before:
            observed=true
            print("HURT_WORLD_ACCEPTED frame=",frame," position=",scene.player.position," hp=",scene.player.hp," family=",artwork()[0].family if not artwork().is_empty() else "missing")
            check(scene.player.hp>0 and artwork().size()==1 and artwork()[0].family=="hurt_snap","real World accepted nonlethal injury owns authored snap")
            Input.action_release("move_right");Input.action_release("move_left");Input.action_release("jump")
            await capture("world_accepted_hurt")
            break
    Input.action_release("move_right");Input.action_release("move_left");Input.action_release("jump")
    check(observed,"normal Input reaches an authored injury")
    await frames(24)
    check(artwork().is_empty(),"World material naturally retires")
    RETIREMENT.retire_tree(scene);scene.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"observable World audio retirement")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("PLAYER_HURT_WORLD failures="+str(failures)+" input_only=true direct_damage=false")
    quit(1 if failures else 0)
