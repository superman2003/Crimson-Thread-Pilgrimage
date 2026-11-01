extends SceneTree
## Production AudioDirector + real mixer clocks. No simulated music state machine.
const DIRECTOR = preload("res://scripts/audio_director.gd")
const PHASE = preload("res://scripts/music_layer_phase.gd")
const RETIREMENT = preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0

class Encounter extends Node2D:
    var is_boss := false
    var kind := "fixture"
    var last_ai_decision := "attack"
    var resident := true
    func world_residency_active() -> bool:
        return resident
    func combat_engaged() -> bool:
        return last_ai_decision == "attack"

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL MUSIC_LAYER: " + label)

func _initialize() -> void:
    call_deferred("run")

func director(chapter: String = "ch01") -> Node:
    var audio := DIRECTOR.new()
    audio.settings_path = "user://music_layer_fixture.cfg"
    root.add_child(audio)
    audio.set_process(false)
    audio.npc_landmarks_enabled = false
    audio.chapter_short_id = chapter
    return audio

func release(audio: Node) -> void:
    RETIREMENT.retire_tree(audio)
    audio.queue_free()
    DIRECTOR._stream_cache.clear()
    await process_frame
    await process_frame
    check(await RETIREMENT.drain(self), "native streams and playback retire")
    DIRECTOR.clear_exploration_resume()

func gap(source: AudioStreamPlayer, stem: AudioStreamPlayer) -> float:
    var length := stem.stream.get_length()
    var distance := fposmod(absf(source.get_playback_position() - stem.get_playback_position()), length)
    return minf(distance, length - distance)

func arithmetic() -> void:
    check(is_equal_approx(PHASE.phase(7.0, .01, .02, 1.0, 30.0), 7.03), "next mixer boundary")
    check(is_equal_approx(PHASE.phase(29.99, .01, .02, 1.0, 30.0), .02), "loop boundary wraps")
    check(is_equal_approx(PHASE.phase(7.0, .01, .02, 2.0, 30.0), 7.06), "pitch and global speed")
    check(is_equal_approx(PHASE.phase(7.0, -.01, -.02, 1.0, 30.0), 7.0), "negative driver jitter clamps")
    check(is_equal_approx(PHASE.phase(65.0, 0, 0, 1.0, 30.0), 5.0), "shorter target wraps independently")
    for invalid in [NAN, INF, -INF]:
        check(PHASE.phase(invalid, 0, 0, 1, 30) == 0, "invalid position")
        check(PHASE.phase(7, invalid, 0, 1, 30) == 0, "invalid last mix")
        check(PHASE.phase(7, 0, invalid, 1, 30) == 0, "invalid next mix")
        check(PHASE.phase(7, 0, 0, invalid, 30) == 0, "invalid speed")
        check(PHASE.phase(7, 0, 0, 1, invalid) == 0, "invalid duration")
    check(PHASE.phase(-1, 0, 0, 1, 30) == 0, "negative source position")
    for value in [0, -1]:
        check(PHASE.phase(7, 0, 0, value, 30) == 0, "nonpositive speed")
        check(PHASE.phase(7, 0, 0, 1, value) == 0, "nonpositive duration")

func clock_guards() -> void:
    var voice := AudioStreamPlayer.new()
    var stream := DIRECTOR.load_cached(DIRECTOR.LEGACY_EXPLORE_CH01, true)
    check(PHASE.start_position(null, stream) == 0, "no source")
    # The temporary wrong-type node belongs to this fixture, not production.
    var other := Node.new()
    check(PHASE.start_position(other, stream) == 0, "non-player source")
    other.free()
    check(PHASE.start_position(voice, stream) == 0, "detached source")
    root.add_child(voice)
    check(PHASE.start_position(voice, stream) == 0, "source without stream")
    voice.stream = stream
    check(PHASE.start_position(voice, stream) == 0, "stopped source")
    voice.play(7.0)
    await create_timer(.08).timeout
    check(PHASE.start_position(voice, stream) >= 7.0, "live native source clock")
    check(PHASE.start_position(voice, null) == 0, "target unavailable")
    voice.stream_paused = true
    check(PHASE.start_position(voice, stream) == 0, "paused source")
    voice.stream_paused = false
    RETIREMENT.retire_tree(voice)
    voice.queue_free()
    check(PHASE.start_position(voice, stream) == 0, "queued source")
    await process_frame
    check(PHASE.start_position(voice, stream) == 0, "freed source")
    stream = null
    DIRECTOR._stream_cache.clear()
    check(await RETIREMENT.drain(self), "clock fixture releases playback")

func region_stems() -> void:
    for chapter in DIRECTOR.CHAPTER_SLUGS:
        var audio := director(chapter)
        audio._play_explore_track(audio._explore_track_path())
        var source: AudioStreamPlayer = audio.explore_player
        check(source.stream is AudioStreamOggVorbis, chapter + " actual exploration Ogg")
        var stem_stream: AudioStream = DIRECTOR.load_cached(audio._combat_layer_path(), true)
        check(stem_stream is AudioStreamOggVorbis, chapter + " actual combat Ogg")
        check(stem_stream.get_length() > 8.0, chapter + " delivered stem duration")
        source.seek(4.0)
        await create_timer(.08).timeout
        var phrase := source.get_playback_position()
        var source_id := source.get_instance_id()
        var cached_count := DIRECTOR._stream_cache.size()
        audio.enter_combat()
        await create_timer(.08).timeout
        var stem: AudioStreamPlayer = audio.combat_player
        check(stem != null and stem.playing, chapter + " combat starts")
        check(gap(source, stem) < .12, chapter + " midphrase join within native mix window")
        check(source.get_playback_position() >= phrase, chapter + " exploration never rewinds")
        check(source.get_instance_id() == source_id, chapter + " exploration player retained")
        check(stem.stream == stem_stream, chapter + " uses warm stream cache")
        check(DIRECTOR._stream_cache.size() == cached_count, chapter + " no new cache entries per encounter")
        check(stem.bus == &"MusicCombat", chapter + " original combat bus")
        check(source.bus == &"MusicExplore", chapter + " original exploration bus")
        audio._play_explore_track(audio._explore_track_path())
        check(source.get_playback_position() >= phrase, chapter + " room reapply preserves phrase")
        var playback := stem.get_stream_playback()
        audio.exit_combat()
        await create_timer(.08).timeout
        var exit_phrase := stem.get_playback_position()
        audio.enter_combat()
        check(stem.get_stream_playback() == playback, chapter + " reengage keeps native playback")
        check(stem.get_playback_position() >= exit_phrase, chapter + " reengage cancels fade without seeking")
        check(stem.volume_db == DIRECTOR.COMBAT_LAYER_DB, chapter + " original combat gain")
        playback = null
        stem_stream = null
        source = null
        stem = null
        await release(audio)

func calm_and_shrine() -> void:
    var audio := director()
    audio._play_explore_track(audio._explore_track_path())
    audio.enter_combat()
    audio.start_lullaby()
    check(not audio.lullaby_active, "shrine waits while encounter active")
    for poll in range(15):
        audio._tick_combat_layer(.25, [])
    check(audio.combat_active, "3.75 seconds retains combat")
    check(audio.combat_player.playing, "stem stays live through calm window")
    audio._tick_combat_layer(.25, [])
    check(not audio.combat_active, "full four-second calm exits combat")
    audio.start_lullaby()
    check(audio.lullaby_active and audio.lullaby_player.playing, "shrine can enter after calm")
    await create_timer(.4).timeout
    check(not audio.combat_player.playing, "shrine retires fading combat promptly")
    await create_timer(.5).timeout
    check(audio.explore_player.stream_paused, "lullaby pauses exploration at phrase")
    audio.enter_combat()
    check(not audio.lullaby_active, "fresh threat removes shrine state")
    check(not audio.explore_player.stream_paused, "fresh threat restores exploration")
    check(audio.combat_player.playing, "fresh threat starts combat")
    for poll in range(12):
        audio.start_lullaby()
    check(not audio.lullaby_active, "shrine polling cannot pump music during combat")
    audio.exit_combat()
    audio.start_lullaby()
    check(audio.lullaby_active, "next calm shrine remains available")
    await release(audio)

func bosses() -> void:
    var bosses: Array = ["rust_crown_guardian"] + DIRECTOR.BOSS_CHAPTER_SLUG.keys() + [DIRECTOR.FINAL_BOSS_ID]
    for boss_id in bosses:
        var audio := director()
        audio._play_explore_track(audio._explore_track_path())
        audio.enter_combat()
        audio.start_boss_music(boss_id)
        check(audio.boss_active, boss_id + " boss state active")
        check(not audio.combat_active, boss_id + " ordinary encounter flag cleared")
        check(audio.boss_player.playing, boss_id + " delivered boss theme plays")
        var boss_playback: AudioStreamPlayback = audio.boss_player.get_stream_playback()
        audio.start_boss_music(boss_id)
        check(audio.boss_player.get_stream_playback() == boss_playback, boss_id + " repeated trigger keeps phrase")
        audio.enter_combat()
        check(not audio.combat_active, boss_id + " ordinary enemy cannot reserve dormant layer")
        audio.start_lullaby()
        check(not audio.lullaby_active, boss_id + " shrine cannot replace boss theme")
        await create_timer(.4).timeout
        check(not audio.combat_player.playing, boss_id + " original short combat fade finishes")
        if boss_id == DIRECTOR.FINAL_BOSS_ID:
            for movement in [2, 3]:
                audio.set_boss_phase(movement)
                check(audio.boss_player.stream == DIRECTOR.load_cached(DIRECTOR.FINAL_BOSS_MOVEMENTS[movement - 1], true), "final boss movement %d" % movement)
                var position: float = audio.boss_player.get_playback_position()
                audio.set_boss_phase(movement)
                check(audio.boss_player.get_playback_position() >= position, "same movement does not restart")
        audio.stop_boss_music()
        audio.enter_combat()
        check(audio.combat_active and audio.combat_player.playing, boss_id + " next ordinary encounter recovers")
        check(not audio.explore_player.stream_paused, boss_id + " exploration resumed")
        boss_playback = null
        await release(audio)

func muted_mode() -> void:
    var audio := director()
    audio.autoplay_enabled = false
    audio.enter_combat()
    check(audio.combat_active and audio.combat_player == null, "non-playing mode tracks encounter without creating voice")
    audio.exit_combat()
    audio.start_lullaby()
    check(audio.lullaby_active and audio.lullaby_player == null, "non-playing mode shrine has no voice")
    audio.enter_combat()
    check(not audio.lullaby_active, "non-playing threat still clears shrine ownership")
    check(audio.combat_player == null, "no playback accidentally enabled")
    audio.start_boss_music("rust_crown_guardian")
    check(not audio.combat_active, "non-playing boss also releases ordinary encounter state")
    audio.enter_combat()
    check(not audio.combat_active, "non-playing boss rejects ordinary encounter reservation")
    audio.stop_boss_music()
    audio.enter_combat()
    check(audio.combat_active and audio.combat_player == null, "non-playing boss exit permits next encounter without voice")
    await release(audio)

func runtime_polling() -> void:
    var audio := director()
    var player := Node2D.new()
    var enemy := Encounter.new()
    root.add_child(player)
    root.add_child(enemy)
    audio.bind_runtime(player, func(): return [enemy])
    audio._play_explore_track(audio._explore_track_path())
    audio.enter_combat()
    audio.engage_shrine(Vector2.ZERO)
    check(audio.shrine_engaged and not audio.lullaby_active, "actual shrine request remains pending during threat")
    for poll in range(20):
        audio._process(.25)
    check(audio.combat_active, "runtime enemy source refreshes encounter")
    check(audio.combat_calm_time == 0, "engaged enemy resets calm timer")
    check(not audio.lullaby_active, "shrine-before-enemy polling cannot replace combat")
    enemy.resident = false
    for poll in range(16):
        audio._process(.25)
    check(not audio.combat_active, "nonresident enemies do not extend encounter")
    audio._process(.25)
    check(audio.lullaby_active, "pending shrine enters on next calm frame")
    player.position = Vector2(151, 0)
    audio._process(.25)
    check(not audio.shrine_engaged and not audio.lullaby_active, "walking outside radius releases pending shrine")
    enemy.resident = true
    audio.enter_combat()
    audio.start_boss_music("rust_crown_guardian")
    for poll in range(20):
        audio._process(.25)
    check(not audio.combat_active, "runtime ordinary enemy cannot reserve layer during boss")
    check(audio.combat_calm_time == 0, "boss poll never accumulates stale calm time")
    audio.stop_boss_music()
    # Resume through the same public encounter method used by polling, without
    # playing an unrelated spatial alert whose art is outside this music fixture.
    audio.enter_combat()
    audio._process(.25)
    check(audio.combat_active and audio.combat_player.playing, "runtime recovers after boss even with nearby old enemy")
    enemy.last_ai_decision = "return"
    for poll in range(16):
        audio._process(.25)
    check(not audio.combat_active, "returning enemy permits normal calm exit")
    player.queue_free()
    enemy.queue_free()
    await release(audio)

func preferences_and_ownership() -> void:
    var first := director()
    first.set_user_volume("music", 35.0)
    var bus := AudioServer.get_bus_index("BGM")
    var saved_db := AudioServer.get_bus_volume_db(bus)
    var saved_preferences: Dictionary = first.user_volumes.duplicate()
    var saved_file := FileAccess.get_file_as_string(first.settings_path)
    first._play_explore_track(first._explore_track_path())
    first.explore_player.seek(8.0)
    await create_timer(.08).timeout
    first.enter_combat()
    first.exit_combat()
    first.start_lullaby()
    first.stop_lullaby()
    first.start_boss_music("rust_crown_guardian")
    first.stop_boss_music()
    first.enter_combat()
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus), saved_db), "transition envelopes retain user music gain")
    check(first.user_volumes == saved_preferences, "transitions retain all four saved sliders")
    check(FileAccess.get_file_as_string(first.settings_path) == saved_file, "music transitions never rewrite preferences")
    var second := director()
    second._play_explore_track(second._explore_track_path())
    var transferred: float = second.explore_player.get_playback_position()
    check(transferred >= 7.9, "replacement director inherits phrase during active fades")
    second.enter_combat()
    await create_timer(.08).timeout
    check(gap(second.explore_player, second.combat_player) < .12, "replacement encounter aligns with inherited phrase")
    RETIREMENT.retire_tree(first)
    first.queue_free()
    await process_frame
    check(DIRECTOR.instance == second, "old director teardown keeps current owner")
    check(second.explore_player.playing and second.combat_player.playing, "old teardown never stops new music")
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus), saved_db), "old teardown leaves shared music gain intact")
    second.set_user_volume("music", 0.0)
    second.exit_combat()
    second.start_lullaby()
    second.start_boss_music("rust_crown_guardian")
    check(AudioServer.is_bus_mute(bus), "mute survives all music-state transitions")
    second.set_user_volume("music", 35.0)
    check(not AudioServer.is_bus_mute(bus), "saved positive gain restores actual bus")
    check(is_equal_approx(AudioServer.get_bus_volume_db(bus), saved_db), "restoring gain applies once")
    await release(second)
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://music_layer_fixture.cfg"))

func existing_audio_contracts() -> void:
    await preload("res://scripts/audio_user_volume_validation.gd").new().run(self, check)
    await preload("res://scripts/audio_voice_budget_validation.gd").new().run(self, check)
    await preload("res://scripts/audio_bus_topology_validation.gd").new().run(self, check)

func run() -> void:
    var layout := AudioServer.generate_bus_layout()
    DIRECTOR.clear_exploration_resume()
    arithmetic()
    await clock_guards()
    await region_stems()
    await calm_and_shrine()
    await bosses()
    await muted_mode()
    await runtime_polling()
    await preferences_and_ownership()
    await existing_audio_contracts()
    AudioServer.set_bus_layout(layout)
    print("MUSIC_LAYER_TRANSITIONS checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
