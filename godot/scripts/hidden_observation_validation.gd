extends "res://scripts/hidden_routes_validation.gd"
## Focused entry for semantic controls; the same checks run in hidden_routes.
func run() -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false;scene.world_save_path=SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await preload("res://scripts/hidden_clue_notes_validation.gd").visibility(self,scene)
    var audio:=preload("res://scripts/audio_retirement.gd")
    audio.retire_tree(scene);scene.free();current_scene=null
    await process_frame
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    check(await audio.drain(self),"focused observation retires its real World audio")
    print("HIDDEN_OBSERVATION checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
