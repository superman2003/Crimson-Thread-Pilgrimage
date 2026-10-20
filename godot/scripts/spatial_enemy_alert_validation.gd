extends RefCounted
const ALERT := preload("res://scripts/spatial_enemy_alert.gd")
const DIRECTOR := preload("res://scripts/audio_director.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
var checkfn: Callable
var checks := 0
func check(ok: bool, label: String) -> void:
    checks += 1
    checkfn.call(ok, "SPATIAL_ALERT: " + label)
func run(tree: SceneTree, callback: Callable) -> void:
    checkfn = callback
    var stage := Node2D.new(); tree.root.add_child(stage)
    var listener := CharacterBody2D.new(); stage.add_child(listener)
    var source := Node2D.new(); source.position = Vector2(200, 0); stage.add_child(source)
    check(ALERT.in_range(Vector2(900, 0), Vector2.ZERO) and not ALERT.in_range(Vector2(900.1, 0), Vector2.ZERO), "hearing boundary is finite and inclusive")
    check(not ALERT.in_range(Vector2(INF, 0), Vector2.ZERO) and not ALERT.in_range(Vector2.ZERO, Vector2(NAN, 0)), "invalid coordinates cannot enter audio")
    var clear := ALERT.new(); stage.add_child(clear)
    check(clear.place(source.position, listener) and not clear.occluded and clear.volume_db == -19, "clear source keeps original mix level")
    check(clear.global_position == source.global_position and clear.max_distance == 900 and clear.attenuation == 1, "native spatial voice carries actual location and distance attenuation")
    var wall := StaticBody2D.new(); wall.position = Vector2(100, 0)
    var shape := RectangleShape2D.new(); shape.size = Vector2(20, 200)
    var collider := CollisionShape2D.new(); collider.shape = shape; wall.add_child(collider); stage.add_child(wall)
    await tree.physics_frame; await tree.process_frame
    var blocked := ALERT.new(); stage.add_child(blocked)
    check(blocked.place(source.position, listener) and blocked.occluded and blocked.volume_db == -31, "actual terrain ray applies twelve dB occlusion")
    wall.collision_layer = 2; await tree.physics_frame; await tree.process_frame
    check(blocked.place(source.position, listener) and not blocked.occluded and blocked.volume_db == -19, "actor collision layer cannot muffle an alert")
    var director := DIRECTOR.new(); stage.add_child(director); director.set_process(false); director.runtime_player = listener
    DIRECTOR._voice_entries.clear(); DIRECTOR._voice_last_ms.clear()
    var detached := Node2D.new()
    check(not director.play_enemy_alert("moss_mite", detached) and DIRECTOR._voice_entries.is_empty(), "detached sources consume no voice quota")
    detached.free()
    source.position = Vector2(901, 0)
    check(not director.play_enemy_alert("moss_mite", source) and DIRECTOR._voice_entries.is_empty(), "inaudible sources allocate neither voice nor quota")
    source.position = Vector2(-200, 0)
    check(director.play_enemy_alert("moss_mite", source), "real director emits a nearby voice")
    var emitted: AudioStreamPlayer2D = null
    for child in director.get_children():
        if child is AudioStreamPlayer2D: emitted = child
    check(emitted != null and emitted.global_position == source.global_position and emitted.bus == "SFXEnemy", "director's production path uses a positional enemy bus voice")
    check(not director.play_enemy_alert("moss_mite", source), "existing family retrigger gate remains in force")
    source.queue_free()
    check(not director.play_enemy_alert("moss_mite", source), "retired source cannot produce a stale accent")
    AUDIO.retire_tree(stage); stage.queue_free(); await tree.process_frame; await tree.process_frame
    DIRECTOR._stream_cache.clear(); DIRECTOR._voice_entries.clear(); DIRECTOR._voice_last_ms.clear()
    check(await AUDIO.drain(tree), "spatial voices release native playback on retirement")
    print("SPATIAL_ENEMY_ALERT checks=%d" % checks)
