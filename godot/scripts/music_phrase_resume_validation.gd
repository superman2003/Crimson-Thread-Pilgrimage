extends RefCounted
const DIRECTOR := preload("res://scripts/audio_director.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
var checkfn: Callable
var checks := 0
func check(ok: bool, label: String) -> void:
    checks += 1
    checkfn.call(ok, "MUSIC_RESUME: " + label)
func run(tree: SceneTree, callback: Callable) -> void:
    checkfn = callback
    DIRECTOR.clear_exploration_resume()
    var stage := Node.new(); tree.root.add_child(stage)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 8000
    var samples := PackedByteArray(); samples.resize(8000 * 2 * 30); stream.data = samples
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = 8000 * 30
    var keys: Array[String] = ["res://test_phrase_a", "res://test_phrase_b"]
    for key in keys: DIRECTOR._stream_cache[key + "|1"] = stream
    var first := DIRECTOR.new(); stage.add_child(first); first.set_process(false)
    first._play_explore_track(keys[0]); first.explore_player.seek(4.0)
    await tree.create_timer(.06).timeout
    var phrase := first.explore_player.get_playback_position()
    check(phrase >= 3.9 and phrase < 4.5, "real player reaches a nonzero phrase")
    first.explore_player.stream_paused = true
    first._play_explore_track(keys[0])
    check(first.explore_player.stream_paused and absf(first.explore_player.get_playback_position() - phrase) < .2, "same room cannot restart a paused Boss/shrine phrase")
    first._play_explore_track(keys[1])
    check(first.explore_player.get_playback_position() < .5, "new chapter starts its own phrase")
    check(absf(float(DIRECTOR._explore_resume[keys[0]]) - phrase) < .2, "outgoing chapter stores its own position")
    first._play_explore_track(keys[0])
    check(absf(first.explore_player.get_playback_position() - phrase) < .2, "revisit resumes previous chapter")
    first.explore_player.seek(6.0); await tree.create_timer(.04).timeout
    var second := DIRECTOR.new(); stage.add_child(second); second.set_process(false)
    second._play_explore_track(keys[0])
    check(second.explore_player.get_playback_position() >= 5.9, "overlapping replacement captures the live old player before handoff")
    second.explore_player.seek(9.0); await tree.create_timer(.04).timeout; second._remember_explore_position()
    first.queue_free(); await tree.process_frame
    check(float(DIRECTOR._explore_resume[keys[0]]) >= 8.9, "late old-scene exit cannot overwrite the new owner")
    for index in range(12):
        var key := "res://test_phrase_%d" % index
        keys.append(key); DIRECTOR._stream_cache[key + "|1"] = stream
        second._play_explore_track(key)
    check(DIRECTOR._explore_resume.size() <= DIRECTOR.MAX_EXPLORE_BOOKMARKS and DIRECTOR._explore_owners.size() == 1, "session cache is bounded and inactive ownership is removed")
    DIRECTOR.clear_exploration_resume()
    second._remember_explore_position()
    check(DIRECTOR._explore_resume.is_empty() and DIRECTOR._explore_owners.is_empty(), "new journey reset prevents old-scene repopulation")
    AUDIO.retire_tree(stage); stage.queue_free()
    await tree.process_frame; await tree.process_frame
    for key in keys: DIRECTOR._stream_cache.erase(key + "|1")
    stream = null
    check(await AUDIO.drain(tree), "music fixture releases native playback")
    print("MUSIC_PHRASE_RESUME checks=%d" % checks)
