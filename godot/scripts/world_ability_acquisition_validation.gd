extends "res://scripts/world_upgrade_validation.gd"
## Local pickup approaches and real disk restarts; no natural full-region claim.
func _run() -> void:
    await _verify_ability_pickups(ROUTES._data())
    _release()
    if is_instance_valid(scene):
        scene.free()
        await process_frame
    _clean()
    _assert(await preload("res://scripts/audio_retirement.gd").drain(self),"Acquisition audio retires")
    print("WORLD_ABILITY_ACQUISITION checks=%d failures=%d actual_pickups=8 local_approach_fixture=true" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
