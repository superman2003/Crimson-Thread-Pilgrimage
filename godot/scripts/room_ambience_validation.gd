extends SceneTree
## Real bed streams and AudioServer effects; no synthetic listening certificate.
const MIX := preload("res://scripts/room_ambience_mix.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
var checks := 0
var failures := 0
var evidence: Array = []

class RoomHost:
    extends Node2D
    var current_room_id := ""

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func filter_enabled(mix: Node) -> bool:
    var index: int = mix.owned_index()
    if index < 0: return false
    for slot in AudioServer.get_bus_effect_count(index):
        if AudioServer.get_bus_effect(index,slot) == mix.effect:
            return AudioServer.is_bus_effect_enabled(index,slot)
    return false

func bus_snapshot(bus: String) -> Array:
    var index := AudioServer.get_bus_index(bus)
    return [AudioServer.get_bus_volume_db(index),AudioServer.is_bus_mute(index),AudioServer.get_bus_effect_count(index)]

func chapter_fixture(id: String) -> void:
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
    var host := RoomHost.new()
    root.add_child(host)
    var director := AUDIO.new()
    director.settings_path = "user://room_ambience_"+id+".cfg"
    director.autoplay_enabled = true
    host.add_child(director)
    director.set_chapter(id)
    var original_count := AudioServer.bus_count
    var bed: AudioStreamPlayer = director.ambience_bed_player
    var stream_id: int = bed.stream.get_instance_id()
    var playback_id: int = bed.get_stream_playback().get_instance_id()
    director.configure_ambience(config,host)
    var mix: Node = director.room_ambience_mix
    check(mix != null and mix.get_parent() == director,"production configuration owns one room mixer under its director")
    check(mix.owned_index() == -1,"unselected initial room allocates no treatment bus")
    director.set_user_volume("ambience",43)
    var parent := bus_snapshot("Ambience")
    var music := bus_snapshot("BGM")
    var sfx := bus_snapshot("SFX")
    var profiles: Dictionary = MIX.ROOMS[id]
    var seen := {}
    for kind in ["open","sheltered"]:
        for room_id in profiles[kind]:
            var matches: Array = config.map_rooms.filter(func(row):return row.id == room_id)
            check(matches.size() == 1 and not seen.has(room_id),"authored treatment names exactly one distinct actual room")
            seen[room_id] = true
            host.current_room_id = room_id
            director.on_room_changed(String(matches[0].kind))
            check(mix.current_profile == kind,"actual room callback selects authored exposure independently of room kind")
            check(mix.apply_profile(kind,0),"selected room can settle its actual effect for target inspection")
            if kind == "sheltered":
                var index: int = mix.owned_index()
                check(index >= 0 and AudioServer.get_bus_name(index) == bed.bus,"only the actual bed routes through its owned treatment")
                check(is_equal_approx(AudioServer.get_bus_volume_db(index),-6.0) and is_equal_approx(mix.effect.cutoff_hz,3200.0),"shelter attenuates six decibels and limits high frequencies to 3200 Hz")
                check(filter_enabled(mix),"sheltered bed enables its actual lowpass")
                check(AudioServer.get_bus_send(index) == "Ambience" and index > AudioServer.get_bus_index("Ambience"),"treatment feeds the existing user ambience bus in legal mix order")
            check(bed.stream.get_instance_id() == stream_id and bed.get_stream_playback().get_instance_id() == playback_id,"room changes never reload the track or replace playback")
            check(bus_snapshot("Ambience") == parent and bus_snapshot("BGM") == music and bus_snapshot("SFX") == sfx,"room treatment leaves user volume, music and SFX routes intact")
    check(seen.size() == 4,"each of six regions has two exposed and two sheltered authored rooms")
    host.current_room_id = "unrecognised_room_fixture"
    director.on_room_changed("secret")
    check(mix.current_profile == "neutral","an unknown secret does not acquire an invented indoor classification")
    mix.apply_profile("neutral",0)
    check(is_zero_approx(AudioServer.get_bus_volume_db(mix.owned_index())) and not filter_enabled(mix),"unknown rooms restore zero gain with their lowpass bypassed")
    check(not mix.apply_profile("invalid",0) and not mix.apply_profile("sheltered",NAN),"invalid treatment and duration reject without allocating effects")
    var effect_ref: WeakRef = weakref(mix.effect)
    var mix_ref: WeakRef = weakref(mix)
    var bus: String = mix.bus_name
    var count_after := AudioServer.bus_count
    check(count_after == original_count+1,"all room changes reuse exactly one treatment bus")
    evidence.append({"region":id,"rooms":seen.keys(),"same_stream":true,"same_playback":true,"extra_buses":count_after-original_count})
    RETIRE.retire_tree(host)
    host.free()
    await process_frame
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"actual bed playback retires after host removal")
    check(mix_ref.get_ref() == null and effect_ref.get_ref() == null,"mixer and filter have no retained strong owner after exit")
    check(AudioServer.get_bus_index(bus) == -1 and AudioServer.bus_count == original_count,"retired room bus is removed rather than accumulating per region")

func envelope_fixture() -> void:
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path("demo_ch01_moss_bell_court")))
    var host := RoomHost.new()
    root.add_child(host)
    var director := AUDIO.new()
    director.autoplay_enabled = true
    host.add_child(director)
    director.set_chapter(String(config.id))
    director.configure_ambience(config,host)
    var mix: Node = director.room_ambience_mix
    var bed: AudioStreamPlayer = director.ambience_bed_player
    var playback_id: int = bed.get_stream_playback().get_instance_id()
    mix.apply_profile("sheltered")
    await create_timer(0.22).timeout
    var gain := AudioServer.get_bus_volume_db(mix.owned_index())
    check(gain < 0.0 and gain > -6.0 and mix.effect.cutoff_hz > 3200.0 and mix.effect.cutoff_hz < 20500.0,"actual Tween reaches intermediate gain and frequency rather than stepping abruptly")
    mix.apply_profile("open")
    mix.apply_profile("sheltered")
    await create_timer(0.7).timeout
    check(is_equal_approx(AudioServer.get_bus_volume_db(mix.owned_index()),-6.0) and filter_enabled(mix),"a superseded open fade cannot disable the newest sheltered filter")
    mix.apply_profile("open")
    await create_timer(0.7).timeout
    check(is_zero_approx(AudioServer.get_bus_volume_db(mix.owned_index())) and not filter_enabled(mix),"completed exposed fade restores the original bed spectrum and gain")
    check(bed.get_stream_playback().get_instance_id() == playback_id,"interrupted transitions retain the actual running playback")
    mix.apply_profile("sheltered",0)
    var own_index: int = mix.owned_index()
    var inserted := AudioEffectAmplify.new()
    AudioServer.add_bus_effect(own_index,inserted,0)
    mix.apply_profile("open",0)
    check(AudioServer.is_bus_effect_enabled(own_index,0) and not filter_enabled(mix),"filter bypass follows effect identity without disabling another inserted effect")
    director.set_user_volume("ambience",0)
    mix.apply_profile("sheltered",0)
    check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")),"room treatment cannot unmute a zero-volume user ambience channel")
    director.set_user_volume("ambience",71)
    mix.apply_profile("open",0)
    check(director.get_user_volume("ambience") == 71 and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")),"explicit user volume remains authoritative after a room transition")
    mix.apply_profile("sheltered",0)
    var old_name: String = mix.bus_name
    var old_index := AudioServer.get_bus_index(old_name)
    AudioServer.remove_bus(old_index)
    AudioServer.add_bus()
    var foreign := AudioServer.bus_count-1
    AudioServer.set_bus_name(foreign,old_name)
    AudioServer.set_bus_volume_db(foreign,-11.0)
    var foreign_effect := AudioEffectLowPassFilter.new()
    foreign_effect.cutoff_hz = 8300.0
    AudioServer.add_bus_effect(foreign,foreign_effect)
    check(mix.apply_profile("sheltered",0) and mix.bus_name != old_name,"replaced foreign bus is never reclaimed by name alone")
    mix.release()
    mix.release()
    check(not mix.apply_profile("sheltered",0) and bed.bus == "Ambience","released mixer is idempotent and cannot reacquire its route")
    foreign = AudioServer.get_bus_index(old_name)
    check(foreign >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(foreign),-11.0) and AudioServer.get_bus_effect(foreign,0) == foreign_effect,"retirement preserves a foreign replacement bus and effect")
    AudioServer.remove_bus(foreign)
    RETIRE.retire_tree(host)
    host.free()
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    await process_frame
    check(await RETIRE.drain(self),"interrupted-envelope fixture releases real bed playback")

func run() -> void:
    for id in MIX.ROOMS:
        await chapter_fixture(String(id))
    await envelope_fixture()
    var output := ProjectSettings.globalize_path("res://../artifacts/room_ambience_v23")
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output.path_join("room-contract.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"regions":evidence},"  "))
    file.close()
    print("ROOM_AMBIENCE checks=%d failures=%d rooms=24" % [checks,failures])
    quit(0 if failures == 0 else 1)
