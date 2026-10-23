extends SceneTree
## Resume a published earned camp exactly; actual Q at its checkpoint, no grants/movement.
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const SAVE := "user://test_v04_guard_world_20261023.json"
const SEED := "res://../artifacts/t04_obsidian_route/earned_camp_seed.json"
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if not ok: failures += 1; push_error(label)
func frames(count: int) -> void:
    for i in count: await physics_frame; await process_frame
func run() -> void:
    var output := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    var bytes := FileAccess.get_file_as_bytes(SEED)
    var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
    check(hash.finish().hex_encode() == "91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b", "published exact earned camp seed")
    var file := FileAccess.open(SAVE,FileAccess.WRITE); file.store_buffer(bytes); file.close()
    var scene: Node2D = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = true; scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await frames(15)
    var start: Vector2 = scene.player.position
    check(scene.currency_count == 287 and scene.player.hp == 5 and scene.player.energy == 100, "published camp resources restore")
    check(scene.player.bell_guard_unlocked and not scene.player.debug_invulnerable, "only normally earned guard, damage enabled")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join("world_baseline.png"))
    Input.action_press("bell_guard"); await frames(3); Input.action_release("bell_guard")
    var guards: Array = scene.player.get_children().filter(func(n): return n.has_meta("player_guard_art") and not n.is_queued_for_deletion())
    check(scene.player.guard_timer > 0 and scene.player.energy == 92 and guards.size() == 1, "actual Q at original earned checkpoint")
    if guards.size() == 1: check(guards[0].z_index == 60 and not guards[0].z_as_relative, "shield preserves old absolute60 above world terrain12")
    await frames(5)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join("world_guard.png"))
    print("GUARD_WORLD checkpoint=" + scene.active_save_point_id + " start=" + str(start) + " actual=" + str(scene.player.position) + " wallet=" + str(scene.currency_count))
    RETIREMENT.retire_tree(scene); scene.queue_free(); await frames(5)
    AUDIO._stream_cache.clear(); AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self), "world fixture audio retirement")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    print("PLAYER_GUARD_WORLD failures=" + str(failures))
    quit(0 if failures == 0 else 1)
