extends RefCounted
## Exercise production bus initialization while the real audio driver mixes.
const DIRECTOR := preload("res://scripts/audio_director.gd")
const MAIN := preload("res://scripts/main_level.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const EXPECTED := {"Master": "", "BGM": "Master", "SFX": "Master", "Ambience": "Master", "UI": "Master",
    "MusicExplore": "BGM", "MusicCombat": "BGM", "MusicStinger": "BGM", "SFXPlayer": "SFX",
    "SFXEnemy": "SFX", "SFXWorld": "SFX", "ReverbZone": "Master", "SFXDry": "Master"}
var checks := 0
var failures := 0
var checker: Callable

func run(tree: SceneTree, callback: Callable) -> void:
    checker = callback
    _check_lock_contract()
    var original := AudioServer.generate_bus_layout()
    _check(_topology_matches(), "actual default layout has all thirteen intended routes")
    var host := MAIN.new()
    host._ensure_audio_buses()
    var complete := _topology()
    for unused in 8:
        DIRECTOR.ensure_sub_buses()
        host._ensure_audio_buses()
    _check(_topology() == complete, "complete-layout repeated initialization is idempotent")

    var stream := AudioStreamGenerator.new()
    stream.mix_rate = 22050.0
    stream.buffer_length = 0.5
    var voice := AudioStreamPlayer.new()
    voice.bus = "Master"
    voice.stream = stream
    tree.root.add_child(voice)
    voice.play()
    var playback := voice.get_stream_playback() as AudioStreamGeneratorPlayback
    _check(playback != null and voice.playing, "generator playback is active during topology changes")
    var frames := PackedVector2Array()
    frames.resize(4096)
    frames.fill(Vector2(0.01, 0.01))
    if playback != null:
        _check(playback.push_buffer(frames), "seed actual mixer with generator frames")
        var available_before := playback.get_frames_available()
        # The Dummy mixer uses a wall-clock worker even under --fixed-fps.
        # Wait for evidence of mixing, with a bounded scheduling allowance.
        var deadline := Time.get_ticks_msec() + 2000
        while playback.get_frames_available() <= available_before and Time.get_ticks_msec() < deadline:
            await tree.process_frame
        _check(playback.get_frames_available() > available_before, "audio thread actually consumed frames before mutation stress")

    # The Master voice stays live while production repairs genuinely absent
    # base/sub buses. set_bus_count itself takes the driver's recursive lock.
    var fallback_ok := true
    for unused in 32:
        AudioServer.set_bus_count(1)
        host._ensure_audio_buses()
        DIRECTOR.ensure_sub_buses()
        fallback_ok = fallback_ok and _topology_matches()
        await tree.process_frame
    _check(fallback_ok, "missing-layout fallback remains atomic through 32 live-mixer rebuilds")
    DIRECTOR._ensure_bus("TopologyFixture", "NoSuchFixtureDestination")
    var index := AudioServer.get_bus_index("TopologyFixture")
    _check(index >= 0 and AudioServer.get_bus_send(index) == "Master", "missing send target falls back to Master")
    DIRECTOR._ensure_bus("TopologyFixture", "BGM")
    _check(AudioServer.get_bus_send(index) == "BGM", "existing bus is atomically rerouted to valid target")
    var count := AudioServer.bus_count
    for unused in 128:
        DIRECTOR._ensure_bus("TopologyFixture", "BGM")
    _check(AudioServer.bus_count == count and AudioServer.get_bus_send(index) == "BGM", "same-value route initialization creates no duplicate bus")
    AudioServer.remove_bus(index)
    for unused in 3:
        var director := DIRECTOR.new()
        tree.root.add_child(director)
        director.set_process(false)
        director.queue_free()
        await tree.process_frame
        _check(DIRECTOR.instance == null and _topology_matches(), "director initialization and exit preserve topology")

    RETIREMENT.retire_tree(voice)
    voice.queue_free()
    playback = null
    stream = null
    await tree.process_frame
    _check(await RETIREMENT.drain(tree), "topology fixture releases its actual mixer playback")
    host.free()
    AudioServer.set_bus_layout(original)
    _check(_topology_matches(), "fixture restores complete default routing")
    print("AUDIO_BUS_TOPOLOGY checks=%d failures=%d driver=%s live_rebuilds=32" % [checks, failures, AudioServer.get_driver_name()])

func _topology() -> Dictionary:
    var result := {}
    for index in AudioServer.bus_count:
        result[String(AudioServer.get_bus_name(index))] = String(AudioServer.get_bus_send(index))
    return result

func _topology_matches() -> bool:
    return _topology() == EXPECTED

func _check_lock_contract() -> void:
    # Runtime stress cannot deterministically schedule the vulnerable native
    # StringName assignment; also retain the required production lock scope.
    var source := FileAccess.get_file_as_string("res://scripts/audio_director.gd")
    var body := source.get_slice("static func _ensure_bus(", 1).get_slice("\n\nstatic func ", 0)
    var locked := body.find("AudioServer.lock()")
    var unlocked := body.find("AudioServer.unlock()")
    _check(locked >= 0 and unlocked > locked and body.count("AudioServer.lock()") == 1 and body.count("AudioServer.unlock()") == 1, "one explicit driver lock has one matching unlock")
    for method in ["add_bus()", "set_bus_name(", "set_bus_send("]:
        var operation := body.find("AudioServer." + method)
        _check(operation > locked and operation < unlocked, "topology mutation stays inside driver lock: " + method)
    _check(not body.contains("await ") and not body.contains("\n    return"), "locked transaction cannot yield or return before unlocking")
    _check(body.contains("if AudioServer.get_bus_send(index) != send:"), "complete default routes avoid redundant StringName assignment")
    var main_source := FileAccess.get_file_as_string("res://scripts/main_level.gd")
    var fallback := main_source.get_slice("func _ensure_audio_buses()", 1).get_slice("\n\nfunc ", 0)
    _check(fallback.contains("AUDIO_DIRECTOR_SCRIPT._ensure_bus(") and not fallback.contains("AudioServer.add_bus()") and not fallback.contains("AudioServer.set_bus_send("), "Main's actual missing-bus fallback uses the same transaction")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
    checker.call(ok, label)
