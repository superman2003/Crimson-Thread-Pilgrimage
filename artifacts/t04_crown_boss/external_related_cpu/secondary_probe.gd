extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
    var failures: int=await preload("res://scripts/secondary_visual_budget_validation.gd").new().run(self)
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    preload("res://scripts/audio_director.gd")._npc_voice_cache.clear()
    if not await preload("res://scripts/audio_retirement.gd").drain(self):failures+=1
    print("CROWN_EXTERNAL_SECONDARY failures=",failures)
    quit(0 if failures==0 else 1)
