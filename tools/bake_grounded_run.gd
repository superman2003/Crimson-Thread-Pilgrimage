extends SceneTree
const RIG := preload("res://scripts/grounded_run_presentation.gd")
const OUT := "res://assets/sprites/player/grounded_run_v1/"
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(768, 768)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var rig := RIG.new()
    rig.position = Vector2(384, 384)
    rig.scale = Vector2.ONE * 2.0
    viewport.add_child(rig)
    assert(rig.setup())
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
    for index in 24:
        rig.apply_pose(float(index) / 24.0)
        await process_frame
        await RenderingServer.frame_post_draw
        var image := viewport.get_texture().get_image()
        image.resize(384, 384, Image.INTERPOLATE_LANCZOS)
        assert(image.save_png(OUT + "frames/run_%02d.png" % index) == OK)
    viewport.queue_free()
    await process_frame
    print("GROUNDED_RUN_BAKE frames=24")
    quit()
