extends SceneTree
## Exact earned camp restore, actual descent/enemy injury/H; no state/HP/position grants.
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const SAVE := "user://test_v04_heal_world_20261023.json"
const SEED := "res://../artifacts/t04_obsidian_route/earned_camp_seed.json"
var failures := 0
var scene: Node2D
var output := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if not ok: failures += 1; push_error("HEAL_WORLD: " + label)
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
    print("PLAYER_HEAL_WORLD failures="+str(failures))
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
    print("HEAL_WORLD start=",scene.player.position," hp=",scene.player.hp," energy=",scene.player.energy)
    Input.action_press("move_right")
    for frame in 720:
        if frame%60==0: print("HEAL_WORLD descent frame=",frame," pos=",scene.player.position," hp=",scene.player.hp)
        if scene.player.hp < scene.player.max_hp or scene.player.death_timer>0: break
        await frames(1)
    Input.action_release("move_right")
    check(scene.player.hp>0 and scene.player.hp<scene.player.max_hp,"actual production enemy or hazard caused injury during normal descent")
    print("HEAL_WORLD injury pos=",scene.player.position," hp=",scene.player.hp," energy=",scene.player.energy)
    await capture("world_actual_injury")
    if failures: await finish(); return
    # Retreat with ordinary input before tending the wound; no teleport or AI pause.
    Input.action_press("move_left"); await frames(32); Input.action_release("move_left")
    for frame in 120:
        if scene.player.is_on_floor() and scene.player.hurt_timer<=0: break
        await frames(1)
    var hp_before: int=scene.player.hp
    var energy_before: int=scene.player.energy
    var cost: int=scene.player.heal_energy_cost
    Input.action_press("heal"); await frames(3); Input.action_release("heal")
    check(scene.player.heal_timer>0 and scene.player.hp==hp_before and scene.player.energy==energy_before-cost,"actual H reserves normally after real injury")
    await capture("world_heal_channel")
    await frames(int(ceil(scene.player.heal_duration*60))+3)
    check(scene.player.hp==mini(scene.player.max_hp,hp_before+scene.player.heal_amount) and scene.player.heal_reserved_cost==0,"actual uninterrupted paid heal completes in World")
    await capture("world_heal_complete")
    print("HEAL_WORLD result pos=",scene.player.position," hp=",scene.player.hp," energy=",scene.player.energy," wallet=",scene.currency_count)
    await finish()
