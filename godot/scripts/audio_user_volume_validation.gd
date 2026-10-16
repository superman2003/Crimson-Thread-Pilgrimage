extends RefCounted

const DIRECTOR := preload("res://scripts/audio_director.gd")
const PATH := "user://audio_user_volume_validation.cfg"
var checks := 0
var failures := 0
var checker: Callable

func run(tree: SceneTree, callback: Callable) -> void:
    checker = callback
    var buses := ["Master", "BGM", "SFX", "Ambience", "SFXDry", "UI"]
    var original: Dictionary = {}
    for name in buses:
        var index := AudioServer.get_bus_index(name)
        original[name] = [AudioServer.get_bus_volume_db(index), AudioServer.is_bus_mute(index)]
    if FileAccess.file_exists(PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
    var director := DIRECTOR.new()
    director.settings_path = PATH
    tree.root.add_child(director)
    director.set_process(false)
    for group in DIRECTOR.USER_VOLUME_BUS:
        var name: String = DIRECTOR.USER_VOLUME_BUS[group]
        director.set_user_volume(group, 0.0)
        _check(AudioServer.is_bus_mute(AudioServer.get_bus_index(name)), "zero slider mutes actual bus: " + group)
        director.set_user_volume(group, 35.0)
        _check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(name)), "positive slider unmutes actual bus: " + group)
        _check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(name)), float(DIRECTOR.BUS_DEFAULT_DB[name]) + linear_to_db(0.35)), "positive slider retains configured mix base: " + group)
    director.set_user_volume("sfx", 0.0)
    _check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFXDry")), "SFX zero also mutes dry heartbeat bus")
    director.set_user_volume("sfx", 25.0)
    _check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFXDry")), "SFX positive restores dry heartbeat bus")
    _check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFXDry")), linear_to_db(0.25)), "dry heartbeat receives SFX gain once")
    _check(AudioServer.get_bus_send(AudioServer.get_bus_index("SFXDry")) == "Master", "dry heartbeat keeps its reverb-free routing")
    _check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "SFX changes leave separately routed UI bus available")
    director.set_user_volume("master", 0.0)
    _check(AudioServer.is_bus_mute(0), "master zero mutes every descendant route")
    director.set_user_volume("master", 100.0)
    var stored := FileAccess.get_file_as_string(PATH)
    var state: Dictionary = director.user_volumes.duplicate()
    var level := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM"))
    for invalid in [NAN, INF, -INF]:
        director.set_user_volume("music", invalid)
        _check(director.user_volumes == state and FileAccess.get_file_as_string(PATH) == stored, "non-finite volume cannot change live or saved preferences")
        _check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")) == level, "non-finite volume cannot reach the mixer")
    director.set_user_volume("unknown", 0.0)
    _check(director.user_volumes == state and FileAccess.get_file_as_string(PATH) == stored, "unknown channel is ignored without rewriting preferences")
    director.set_user_volume("music", 1000.0)
    _check(director.get_user_volume("music") == 100.0, "finite upper bound remains clamped")
    director.set_user_volume("music", -1.0)
    _check(director.get_user_volume("music") == 0.0 and AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")), "finite negative value clamps to mute")

    director.set_user_volume("music", 100.0)
    director.set_user_volume("ambience", 100.0)
    director.on_dialogue(true)
    director.set_user_volume("music", 40.0)
    director.set_user_volume("ambience", 30.0)
    await tree.create_timer(0.35).timeout
    _check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), linear_to_db(0.4) + DIRECTOR.DIALOGUE_MUSIC_DUCK_DB), "old dialogue envelope cannot overwrite new music level")
    _check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), float(DIRECTOR.BUS_DEFAULT_DB.Ambience) + linear_to_db(0.3) + DIRECTOR.DIALOGUE_AMBIENCE_DUCK_DB), "old dialogue envelope cannot overwrite new ambience level")
    director.duck(-6.0, 0.05, 0.01, 0.01)
    director.set_user_volume("music", 55.0)
    await tree.create_timer(0.1).timeout
    _check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), linear_to_db(0.55) + DIRECTOR.DIALOGUE_MUSIC_DUCK_DB), "old pickup duck cannot overwrite new music level")
    director.on_dialogue(false)
    director.set_user_volume("music", 0.0)
    director.set_user_volume("ambience", 0.0)
    await tree.create_timer(0.35).timeout
    _check(AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")), "dialogue close cannot unmute zero-volume channels")
    director.set_user_volume("sfx", 0.0)
    director.queue_free()
    await tree.process_frame
    var restart := DIRECTOR.new()
    restart.settings_path = PATH
    tree.root.add_child(restart)
    restart.set_process(false)
    _check(restart.get_user_volume("music") == 0.0 and restart.get_user_volume("ambience") == 0.0 and restart.get_user_volume("sfx") == 0.0, "restart restores zero-volume preferences")
    for name in ["BGM", "Ambience", "SFX", "SFXDry"]:
        _check(AudioServer.is_bus_mute(AudioServer.get_bus_index(name)), "restart applies actual mute state: " + name)
    restart.set_user_volume("sfx", 60.0)
    _check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFXDry")), "restart can restore both SFX routes")
    restart.queue_free()
    await tree.process_frame
    for name in original:
        var index := AudioServer.get_bus_index(name)
        AudioServer.set_bus_volume_db(index, original[name][0])
        AudioServer.set_bus_mute(index, original[name][1])
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
    print("AUDIO_USER_VOLUME checks=%d failures=%d" % [checks, failures])

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
    checker.call(ok, label)
