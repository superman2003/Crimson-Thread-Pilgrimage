extends SceneTree

const Narrative = preload("res://scripts/world_narrative.gd")
const Director = preload("res://scripts/audio_director.gd")
var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(description)

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    var narrative := Narrative.new()
    check(not narrative.entries.is_empty(), "Narrative JSON loaded")
    var flags := {}
    var apprentice := "npc_threadsmith_apprentice"
    var start: Dictionary = narrative.resolve(apprentice, [], [], flags)
    check(start.get("state") == "names_request", "New player receives invitation")
    check(Narrative.completion_flags(start, 0, flags).is_empty(), "One line does not accept quest")
    for flag in Narrative.completion_flags(start, 2, flags):
        flags[flag] = true
    check(flags.has("quest_bring_names_started"), "Full conversation accepts quest")
    var waiting: Dictionary = narrative.resolve(apprentice, [], [], flags)
    check(waiting.get("state") == "names_waiting", "Return before evidence gives useful route")
    var child: Dictionary = narrative.resolve("npc_canal_child", [], [], flags)
    for flag in Narrative.completion_flags(child, child.lines.size() - 1, flags):
        flags[flag] = true
    var locked: Dictionary = narrative.resolve("npc_fugitive_scribe", [], [], flags)
    check(locked.get("state") == "names_scribe_search", "Scribe needs actual evidence")
    var evidence: Dictionary = narrative.resolve("npc_fugitive_scribe", [], [], flags, {"contract_original_fragment": 1})
    check(evidence.get("state") == "names_scribe_evidence", "Exploration fragment unlocks testimony without boss")
    check(not flags.has("quest_bring_names_archive_heard"), "Resolving a dialogue cannot grant progress")
    for flag in Narrative.completion_flags(evidence, evidence.lines.size() - 1, flags):
        flags[flag] = true
    var home: Dictionary = narrative.resolve(apprentice, [], ["double_thread_jump"], flags)
    check(home.get("state") == "names_homecoming", "Cross-region evidence unlocks homecoming")
    for flag in Narrative.completion_flags(home, home.lines.size() - 1, flags):
        flags[flag] = true
    check(flags.has("testimony_returned_names"), "Return grants unique testimony marker")
    check(Narrative.completion_flags(home, 9, flags).is_empty(), "Reward cannot be granted twice")
    var saved: Dictionary = JSON.parse_string(JSON.stringify(flags))
    check(narrative.resolve(apprentice, [], [], saved).get("state") == "names_returned", "Saved flags restore completed state")
    check(narrative.resolve("npc_unknown", ["legacy"], [], flags).is_empty(), "Unknown NPC retains legacy dialogue machine")
    check(narrative.resolve("npc_salt_librarian_ye", [], ["double_thread_jump"], {}).get("state") == "names_librarian_jump", "Ability changes route dialogue")
    check(Narrative.subtitle_duration("你好。") < Narrative.subtitle_duration("雨渠把工人的声音冲走，书库把他们的名字刮掉。"), "Reading timing follows subtitle length")
    var warm: AudioStreamWAV = Director.npc_voice_stream("warm")
    check(warm == Director.npc_voice_stream("warm"), "Voice profile synthesis caches stream")
    check(warm == Director.npc_voice_stream("unknown"), "Unknown profile uses warm voice")
    check(warm.data.size() > 0 and warm.mix_rate == 22050, "Greeting has playable PCM waveform")
    check(warm.data != Director.npc_voice_stream("bright").data, "Characters have differentiated voices")
    check(warm.get_length() <= 0.25, "Nonverbal cue remains brief")
    var director := Director.new()
    director.autoplay_enabled = false
    root.add_child(director)
    check(director.play_npc_voice(apprentice, "你好", "warm"), "Greeting plays from runtime node")
    check(not director.play_npc_voice(apprentice, "下一句", "warm"), "Fast dialogue skips suppress stacked greetings")
    check(not director.play_npc_voice("empty", ""), "Empty subtitles remain silent")
    Director._stream_cache["res://test_phrase.wav|1"] = warm
    director._play_explore_track("res://test_phrase.wav")
    director.explore_player.volume_db = -27.0
    director._play_explore_track("res://test_phrase.wav")
    check(director.explore_player.volume_db == -27.0, "Reapplying identical music does not reset phrase fade")
    director._npc_voice_player.stop()
    director.explore_player.stop()
    director._npc_voice_player.stream = null
    director.explore_player.stream = null
    await process_frame
    var next_director := Director.new()
    next_director.autoplay_enabled = false
    root.add_child(next_director)
    next_director.on_player_death()
    var master := AudioServer.get_bus_index("Master")
    check(Director._find_bus_effect(master, "AudioEffectLowPassFilter") != -1, "New scene applies death filter")
    director.free()
    check(Director.instance == next_director, "Old exit preserves new director ownership")
    check(Director._find_bus_effect(master, "AudioEffectLowPassFilter") != -1, "Old exit cannot delete new scene death filter")
    next_director.free()
    check(Director._find_bus_effect(master, "AudioEffectLowPassFilter") == -1, "Last director cleans global death filter")
    Director._stream_cache.clear()
    Director._npc_voice_cache.clear()
    print("Narrative/audio checks: %d, failures: %d" % [checks, failures])
    call_deferred("finish_checks")

func finish_checks() -> void:
    await create_timer(0.25).timeout
    quit(1 if failures else 0)
