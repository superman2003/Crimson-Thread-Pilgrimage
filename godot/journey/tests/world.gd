extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("JOURNEY_WORLD: " + message)
func run() -> void:
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://journey_real_world_validation.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    if not scene.initial_region_ready:
        quit(1)
        return
    var host: Node = root.get_node("JourneyWorkbench")
    for index in 120:
        if is_instance_valid(host.entry):
            break
        await process_frame
    check(is_instance_valid(host.entry), "autoload attaches real settings entry after production readiness")
    scene.set_process(false)
    scene.player.set_physics_process(false)
    var before_inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var before_currency: int = scene.currency_count
    var before_build: Dictionary = scene.build_system.state.duplicate(true)
    scene._toggle_audio_settings()
    await process_frame
    host.open()
    await process_frame
    await process_frame
    check(host.dialog.visible and scene.ui_shell.has_modal_window(), "native workbench participates in real modal input lock")
    check(scene.ui_shell.settings.get_rect().encloses(host.entry.get_rect()), "settings entry stays inside actual panel")
    var directory := OS.get_environment("JOURNEY_CAPTURE_DIR")
    for id in host.features:
        host._select(String(id))
        await process_frame
        await process_frame
        check(host.content.get_child_count() > 1, "production feature opens: " + String(id))
        if not directory.is_empty() and DisplayServer.get_name() != "headless":
            DirAccess.make_dir_recursive_absolute(directory)
            await RenderingServer.frame_post_draw
            # Native subwindows have their own viewport; capture the actual tool.
            host.dialog.get_texture().get_image().save_png(directory.path_join(String(id) + ".png"))
    check(scene.inventory_counts == before_inventory and scene.currency_count == before_currency and scene.build_system.state == before_build, "opening every workstation preserves game resources and actual build")
    if host.features.has("photo"):
        var photo: RefCounted = host.features.photo
        var mode: int = scene.process_mode
        await photo._start()
        check(is_instance_valid(photo.session) and photo.session.active, "production photo feature starts through actual workbench context")
        check(scene.process_mode == Node.PROCESS_MODE_DISABLED and not host.dialog.visible, "photo owns world freeze after closing workbench")
        photo.shutdown()
        await process_frame
        check(scene.process_mode == mode and scene.ui_shell.visible and photo.session == null, "production photo shutdown restores world and releases session")
        host.open()
        await process_frame
    var primary_before := FileAccess.get_file_as_bytes(scene.world_save_path)
    var first_id := String(host.features.keys()[0])
    var scope: String = host.context.store.scope
    check(not scope.is_empty() and host.context.latest.region == String(scene.config.id), "context is bound to actual slot and region")
    host.close()
    await process_frame
    check(not host.dialog.visible and scene.active_overlay == "settings", "closing returns to existing settings overlay")
    check(FileAccess.get_file_as_bytes(scene.world_save_path) == primary_before, "workbench analysis does not rewrite primary save")
    scene.free()
    await process_frame
    await process_frame
    check(not is_instance_valid(host.entry) or host._owner() == null, "retired world cannot retain an actionable entry")
    print("JOURNEY_WORLD checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
