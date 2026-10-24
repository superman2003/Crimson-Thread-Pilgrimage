extends SceneTree
## Observe the actual OS close path without fixture-owned audio cleanup.
var world: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var close_at := "ready"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--close-at="):
            close_at = arg.trim_prefix("--close-at=")
    root.close_requested.connect(_close_observed)
    world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://window_close_probe.json"
    root.add_child(world)
    if close_at == "startup":
        var deadline := Time.get_ticks_msec() + 15000
        while Time.get_ticks_msec() < deadline:
            var snapshot: Dictionary = world.world_loader._startup_exit_snapshot()
            if snapshot.startup_pending and (snapshot.reader_busy or snapshot.player_art_pending):
                break
            await process_frame
    else:
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
        for frame in 12:
            await process_frame
        if close_at == "paused":
            paused = true
    var voices := _playing(root)
    print("WINDOW_CLOSE_READY " + JSON.stringify({"pid": OS.get_process_id(), "playing": voices,
        "auto_accept_quit": auto_accept_quit, "private_user_dir": OS.get_user_data_dir(),
        "world_ready": world.initial_region_ready, "paused": paused, "close_at": close_at,
        "startup": world.world_loader._startup_exit_snapshot()}))

func _playing(node: Node) -> Array:
    var result := []
    if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
        if node.playing and node.stream != null:
            result.append({"path": String(node.get_path()), "stream": node.stream.get_class(),
                "playback": node.has_stream_playback()})
    for child in node.get_children():
        result.append_array(_playing(child))
    return result

func _close_observed() -> void:
    print("WINDOW_CLOSE_OBSERVED pid=%d" % OS.get_process_id())
