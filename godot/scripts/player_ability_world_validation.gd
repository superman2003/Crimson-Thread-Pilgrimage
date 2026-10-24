extends SceneTree
## Exact earned camp save, normal Input only. No direct damage, position, HP or ability writes.
const SAVE := "user://test_v04_ability_world_20261024.json"
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
    if not ok: failures += 1; push_error("ABILITY_WORLD: "+label)
func frames(count: int) -> void:
    for i in count: await physics_frame; await process_frame
func artwork() -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("player_ability_art") and not n.is_queued_for_deletion())
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
    check(scene.player.hp==5 and scene.player.max_hp==6 and scene.player.energy==100 and scene.currency_count==287 and not scene.player.debug_invulnerable and scene.player.thorn_downstrike_unlocked and scene.player.lantern_phase_unlocked,"unchanged earned resources, real injury enabled")
    print("ABILITY_WORLD_START ",scene.player.position," hp=",scene.player.hp)
    var hp_before:int=scene.player.hp
    Input.action_press("move_right");await frames(45);Input.action_release("move_right");await frames(5)
    Input.action_press("jump");await frames(3);Input.action_release("jump");await frames(3)
    Input.action_press("aim_down");Input.action_press("attack");await frames(2);Input.action_release("attack");Input.action_release("aim_down")
    check(scene.player.traversal_downstrike_active,"normally earned World downstrike accepts actual air attack")
    for i in 40:
        if scene.player.is_on_floor():break
        await frames(1)
    check(artwork().filter(func(n):return n.family=="downstrike").size()==1,"actual World downstrike landing owns authored ground burst")
    print("ABILITY_WORLD_DOWNSTRIKE pos=",scene.player.position," hp=",scene.player.hp," energy=",scene.player.energy)
    await capture("world_downstrike_land");await frames(30)
    var energy_before:int=scene.player.energy
    Input.action_press("lantern_phase");await frames(3)
    check(scene.player.phase_active and artwork().filter(func(n):return n.family=="phase").size()==1,"normally earned World held phase owns one authored shell")
    await frames(8);await capture("world_phase_held")
    Input.action_release("lantern_phase");await frames(2)
    check(not scene.player.phase_active and artwork().filter(func(n):return n.family=="phase" and n.exiting).size()==1,"actual World phase release owns exit state")
    print("ABILITY_WORLD_PHASE pos=",scene.player.position," hp=",scene.player.hp," before_energy=",energy_before," after_energy=",scene.player.energy," wallet=",scene.currency_count)
    await capture("world_phase_exit");await frames(20)
    check(scene.player.hp==hp_before and scene.currency_count==287 and artwork().is_empty(),"World abilities preserve real HP/wallet and retire material")
    RETIREMENT.retire_tree(scene);scene.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"observable World audio retirement")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("PLAYER_ABILITY_WORLD failures="+str(failures)+" input_only=true direct_damage=false")
    quit(1 if failures else 0)
