extends "res://scripts/world_crown_entry_playback.gd"
## A new PID reads the exact earned seed. No positioned fixture or route replay.
func _run() -> void:
    const SAVE := "user://test_world_c06_earned_restore_image.json"
    var raw:=FileAccess.get_file_as_bytes("res://../artifacts/t04_crown_entry/earned_lower_seed.json")
    var file:=FileAccess.open(SAVE,FileAccess.WRITE)
    file.store_buffer(raw)
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(120)
    _check(scene.active_save_point_id=="save_ch06_lower_loop" and scene.currency_count==529,"earned restore retains lower shrine and wallet")
    _check(scene.inventory_counts.size()==27 and scene.inventory_counts.get("crown_echo_shard",0)==13 and scene.player.hp==5,"earned restore retains inventory and HP")
    _check(not scene.boss_spawned and not scene.player.debug_invulnerable,"earned restore is exploration with damage enabled")
    await RenderingServer.frame_post_draw
    var output:="res://../artifacts/t04_crown_entry/earned_restore_image/lower_shrine.png"
    _check(root.get_texture().get_image().save_png(output)==OK,"earned restore PNG saved")
    print("CROWN_EARNED_IMAGE ",JSON.stringify({"pid":OS.get_process_id(),"wallet":scene.currency_count,"checkpoint":scene.active_save_point_id,"position":str(scene.player.position),"hp":scene.player.hp,"failures":failures}))
    _release()
    preload("res://scripts/audio_retirement.gd").retire_tree(scene)
    scene.queue_free()
    for unused in 10:await process_frame
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    preload("res://scripts/audio_director.gd")._npc_voice_cache.clear()
    _check(await preload("res://scripts/audio_retirement.gd").drain(self),"earned restore retires audio")
    quit(0 if failures==0 else 1)
