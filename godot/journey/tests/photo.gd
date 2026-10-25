extends "res://journey/tests/support.gd"
const ARCHIVE := preload("res://journey/photo/archive.gd")
const SESSION := preload("res://journey/photo/session.gd")
func run() -> void:
    label = "PHOTO"
    var context := fixture("photo")
    var photo := {"path":"user://journey_workbench/photos/pilgrimage_1.png", "sha256":"a".repeat(64), "width":1280, "height":720, "created":int(Time.get_unix_time_from_system()), "region":"苔钟庭", "room":"entry_bell", "options":ARCHIVE.camera_options("natural")}
    var state := ARCHIVE.add(ARCHIVE.fresh(), photo)
    check(ARCHIVE.valid(state) and state.photos.size() == 1, "photo index has bounded validated metadata")
    check(ARCHIVE.add(state, photo) == state, "duplicate photo identity rejected")
    check(ARCHIVE.permitted(String(photo.path), "user://journey_workbench/photos"), "own capture path is accepted")
    check(not ARCHIVE.permitted("user://primary.json", "user://journey_workbench/photos"), "arbitrary file cannot become photo deletion target")
    check(not ARCHIVE.permitted("user://journey_workbench/photos/../primary.json", "user://journey_workbench/photos"), "path traversal rejected")
    var annotated := ARCHIVE.annotate(state, String(photo.path), "雨声", true)
    check(ARCHIVE.records(annotated, "雨声", true).size() == 1, "photo notes and favorites search")
    check(ARCHIVE.camera_options("monochrome").saturation == 0.0, "preset affects only photo compositor parameters")
    var world := PhotoWorld.new()
    root.add_child(world)
    await process_frame
    var original_mode := world.process_mode
    var original_camera := world.player.get_node("Camera2D") as Camera2D
    var camera_enabled := original_camera.enabled
    var session := SESSION.new()
    session.directory = context.store.directory.path_join("photos")
    root.add_child(session)
    var outcome := session.begin(world, context.snapshot())
    check(outcome.ok and session.active, "photo session begins with real native window and camera")
    check(world.process_mode == Node.PROCESS_MODE_DISABLED and not world.ui_shell.visible and not original_camera.enabled, "photo mode freezes only owning world and hides UI")
    session.options.zoom = 2.0
    session.pan = Vector2(100000, -100000)
    session._apply()
    check(session.camera.global_position.is_finite() and session.pan.length() < 100000, "reframing is bounded to original visible frame")
    if DisplayServer.get_name() != "headless":
        var captures := []
        session.captured.connect(func(record: Dictionary):captures.append(record))
        await session.capture()
        check(captures.size() == 1 and FileAccess.file_exists(String(captures[0].path)), "real renderer produces a verified PNG capture")
        if not captures.is_empty():
            var image := Image.load_from_file(String(captures[0].path))
            check(not image.is_empty() and image.get_width() == int(captures[0].width), "captured image dimensions roundtrip")
            DirAccess.remove_absolute(String(captures[0].path))
    session.reset()
    check(session.options.zoom == 1.0 and session.pan == Vector2.ZERO, "reset restores photo parameters")
    session.end()
    check(not session.active and world.process_mode == original_mode and world.ui_shell.visible and original_camera.enabled == camera_enabled, "closing restores exact world and camera ownership")
    session.end()
    session.queue_free()
    world.queue_free()
    await process_frame
    var feature := preload("res://journey/features/photo.gd").new()
    feature.setup(context)
    var box := node_container()
    feature.draw(box)
    await process_frame
    check(box.get_child_count() > 5, "photo gallery controls render without a hardware camera fixture")
    box.free()
    finish()
