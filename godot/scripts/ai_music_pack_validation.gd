extends SceneTree
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const NETWORK := preload("res://scripts/shrine_return_network.gd")
const TOKEN := preload("res://scripts/world_transition_token.gd")
var checks := 0
var failures := 0

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures += 1;push_error(label)

class TravelHost extends Node:
    var audio_director: Node

func run() -> void:
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/bgm/ai_generated/music_pack.json"))
    check(manifest.entries.size() == 34, "34 declared roles")
    var audio := AUDIO.new()
    audio.settings_path="user://ai_music_pack_test.cfg"
    root.add_child(audio)
    audio.set_process(false)
    var voice := AudioStreamPlayer.new()
    root.add_child(voice)
    var paths := {}
    for entry in manifest.entries:
        if entry.status == "intentional_silence":
            check(entry.key == "ch06_silent_crown_core_combat_layer" and entry.runtime.is_empty(), "silent city contract")
            continue
        paths[entry.runtime] = true
        var stream := AUDIO.load_cached(entry.runtime, entry.loop) as AudioStreamOggVorbis
        check(stream != null, "decode " + entry.key)
        if stream == null:continue
        check(stream.loop == entry.loop, "loop mode " + entry.key)
        check(absf(stream.get_length() - float(entry.duration_seconds)) < .1, "length " + entry.key)
        RETIRE.watch_player(voice)
        voice.stream = stream
        voice.play(stream.get_length() - .12)
        await create_timer(.35).timeout
        check(voice.playing if entry.loop else not voice.playing, "native end behavior " + entry.key)
    check(paths.size()==33, "33 delivered native cues")
    for chapter in AUDIO.CHAPTER_SLUGS:
        audio.chapter_short_id = chapter
        audio._play_explore_track(audio._explore_track_path())
        check(paths.has(audio._explore_track_path()), chapter + " exploration connected")
        check(paths.has(audio._lullaby_path()), chapter + " shrine connected")
        audio.enter_combat()
        await create_timer(.9).timeout
        check(audio.explore_player.stream_paused, chapter + " combat owns music")
        if chapter == "ch06":check(audio.combat_player == null or not audio.combat_player.playing, "CH06 combat silent")
        else:check(paths.has(audio.combat_player.stream.resource_path) or audio.combat_player.stream == AUDIO.load_cached(audio._combat_layer_path(),true), chapter + " combat cue connected")
        audio.exit_combat()
        check(not audio.explore_player.stream_paused, chapter + " exploration resumes")
        audio.start_lullaby()
        check(audio.lullaby_player.stream == AUDIO.load_cached(audio._lullaby_path(),true), chapter + " shrine plays")
        audio.stop_lullaby()
    for boss in ["rust_crown_guardian"] + AUDIO.BOSS_CHAPTER_SLUG.keys() + [AUDIO.FINAL_BOSS_ID]:
        audio.start_boss_music(boss)
        check(audio.boss_player.playing,"boss plays " + boss)
        if boss == AUDIO.FINAL_BOSS_ID:
            check(audio.boss_player.stream == AUDIO.load_cached(AUDIO.CROWN_ENTRANCE,true),"sixth guardian entrance is connected")
            audio.boss_tween.custom_step(AUDIO.CROWN_ENTRANCE_SECONDS + .1)
            check(audio.boss_player.stream == AUDIO.load_cached(AUDIO.FINAL_BOSS_MOVEMENTS[0],true),"quiet movement follows entrance")
            audio.set_boss_phase(2)
            check(audio.boss_player.stream == AUDIO.load_cached(AUDIO.FINAL_BOSS_MOVEMENTS[1],true),"movement II connected")
            audio.set_boss_phase(3)
            check(audio.boss_player.stream == AUDIO.load_cached(AUDIO.FINAL_BOSS_MOVEMENTS[2],true),"movement III connected")
        else:check(paths.has(audio._boss_track_path(boss,1)),"boss mapping " + boss)
        audio.stop_boss_music()
    for key in AUDIO.STINGER_TRACKS:
        audio.play_stinger(key)
        check(audio.stinger_player.stream == AUDIO.load_cached(AUDIO.STINGER_TRACKS[key],false),"one-shot connected " + key)
    audio.on_room_changed("transit")
    await create_timer(.9).timeout
    check(audio.transit_player.playing and audio.transit_player.stream == AUDIO.load_cached(AUDIO.BELLWAY_TRANSIT_LOOP,true),"transit loop connected")
    check(audio.explore_player.stream_paused,"transit replaces independent exploration")
    audio.start_lullaby()
    await create_timer(1.1).timeout
    check(not audio.transit_player.playing,"shrine owns transit room music")
    audio.stop_lullaby()
    check(audio.transit_player.playing,"leaving shrine restores transit cue")
    audio.on_room_changed("corridor")
    check(not audio.explore_player.stream_paused,"leaving transit restores exploration")
    audio.set_hidden_zone(true)
    check(audio.hidden_drone_player.playing and audio.hidden_drone_player.stream == AUDIO.load_cached(AUDIO.HIDDEN_DRONE,true),"hidden zone connected")
    audio.set_hidden_zone(false)
    var host:=TravelHost.new()
    host.audio_director=audio
    root.add_child(host)
    var token:=TOKEN.new()
    token.succeeded=true
    NETWORK._arrival_cue(weakref(host),token)
    check(audio.stinger_player.stream == AUDIO.load_cached(AUDIO.STINGER_TRACKS.bellway_arrive,false),"successful travel arrival cue")
    audio.play_stinger("bellway_depart")
    token.succeeded=false
    NETWORK._arrival_cue(weakref(host),token)
    check(audio.stinger_player.stream == AUDIO.load_cached(AUDIO.STINGER_TRACKS.bellway_depart,false),"failed travel never announces arrival")
    host.queue_free()
    RETIRE.retire_tree(voice);voice.queue_free()
    RETIRE.retire_tree(audio);audio.queue_free()
    AUDIO._stream_cache.clear()
    await process_frame
    await process_frame
    check(await RETIRE.drain(self),"all music playback retires")
    print("AI_MUSIC_PACK checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
