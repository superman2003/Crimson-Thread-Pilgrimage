extends SceneTree
const FILTER := preload("res://scripts/enemy_sound_filter.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
var checks := 0
var failures := 0
var saved_layout: AudioBusLayout

class SoundProbe extends "res://scripts/enemy_actor.gd":
    var blocked := false
    var queries := 0
    func _ready() -> void:
        pass
    func _exit_tree() -> void:
        pass
    func _should_play_sfx() -> bool:
        return true
    func _sfx_occluded() -> bool:
        queries += 1
        return blocked
    func _load_sfx_stream(_key: String) -> AudioStream:
        var stream := AudioStreamWAV.new()
        stream.format = AudioStreamWAV.FORMAT_16_BITS
        stream.mix_rate = 22050
        var data := PackedByteArray()
        data.resize(4410)
        stream.data = data
        return stream

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func clean_layout() -> void:
    AudioServer.set_bus_layout(AudioBusLayout.new())

func add_bus(name: String, parent: String = "Master") -> int:
    AudioServer.lock()
    AudioServer.add_bus()
    var index := AudioServer.bus_count - 1
    AudioServer.set_bus_name(index, name)
    AudioServer.set_bus_send(index, parent)
    AudioServer.unlock()
    return index

func run() -> void:
    saved_layout = AudioServer.generate_bus_layout()
    fallback_checks()
    ownership_checks()
    global_effect_checks()
    ordering_checks()
    budget_checks()
    await playback_checks()
    AudioServer.set_bus_layout(saved_layout)
    saved_layout = null
    print("ENEMY_SOUND_FILTER checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)

func fallback_checks() -> void:
    clean_layout()
    check(FILTER.route("missing",false,1)=="Master", "missing buses fall back to Master")
    check(AudioServer.bus_count==1, "clear sound creates no filter bus")
    add_bus("SFX")
    check(FILTER.fallback("missing")=="SFX", "SFX is the next available parent")
    add_bus("SFXEnemy","SFX")
    check(FILTER.fallback()=="SFXEnemy", "normal parent remains the preferred enemy bus")
    for priority in [-10, -1, 0]:
        check(FILTER.route("SFXEnemy",true,priority)=="SFXEnemy", "danger and confirmations bypass lowpass")
    check(AudioServer.get_bus_index(FILTER.BUS)==-1, "danger-only playback creates no processing bus")
    var route := FILTER.route("SFXEnemy",true,1)
    check(route==FILTER.BUS, "ordinary obstructed sound receives the shared filter bus")
    var index := AudioServer.get_bus_index(route)
    check(String(AudioServer.get_bus_send(index))=="SFXEnemy", "filtered sound still reaches the original user SFX controls")
    check(is_equal_approx(AudioServer.get_bus_volume_db(index),0), "filter bus adds no gain on top of existing attenuation")
    var effect := FILTER.owned_effect(index)
    check(effect is AudioEffectLowPassFilter, "actual AudioServer effect is a lowpass")
    check(is_equal_approx(effect.cutoff_hz,FILTER.CUTOFF_HZ), "actual lowpass uses the authored cutoff")
    check(AudioServer.is_bus_effect_enabled(index,0), "new effect is enabled")
    check(FILTER.route("SFXEnemy",false,1)=="SFXEnemy", "unobstructed ordinary sound remains clear")
    check(FILTER.fallback(FILTER.BUS)=="SFX", "filter cannot send recursively to itself")

func ownership_checks() -> void:
    clean_layout()
    var foreign := add_bus(FILTER.BUS)
    var reverb := AudioEffectReverb.new()
    AudioServer.add_bus_effect(foreign,reverb)
    var before := AudioServer.bus_count
    check(FILTER.ensure_bus()=="Master", "same-named foreign bus causes a safe clear fallback")
    check(AudioServer.bus_count==before and AudioServer.get_bus_effect_count(foreign)==1, "foreign bus/effects are not hijacked")
    check(AudioServer.get_bus_effect(foreign,0)==reverb, "foreign effect identity remains intact")
    clean_layout()
    add_bus("SFX")
    FILTER.ensure_bus()
    var index := AudioServer.get_bus_index(FILTER.BUS)
    var original := FILTER.owned_effect(index)
    add_bus("SFXEnemy","SFX")
    check(FILTER.ensure_bus()==FILTER.BUS, "existing owned bus is reusable after parent appears")
    index=AudioServer.get_bus_index(FILTER.BUS)
    check(String(AudioServer.get_bus_send(index))=="SFXEnemy", "reused bus follows the restored preferred parent")
    check(FILTER.owned_effect(index)==original, "parent repair reuses the same filter resource")
    AudioServer.remove_bus(AudioServer.get_bus_index("SFXEnemy"))
    FILTER.ensure_bus()
    index=AudioServer.get_bus_index(FILTER.BUS)
    check(String(AudioServer.get_bus_send(index))=="SFX", "removed parent is resolved by name, never stale bus index")
    AudioServer.remove_bus(index)
    FILTER.ensure_bus()
    check(FILTER.owned_effect(AudioServer.get_bus_index(FILTER.BUS))!=null, "removed owned bus can be recreated")
    check(FILTER.owned_effect(-1)==null and FILTER.owned_effect(9999)==null, "invalid indexes never access audio effects")

func budget_checks() -> void:
    clean_layout()
    var sfx := add_bus("SFX")
    var enemy := add_bus("SFXEnemy","SFX")
    AudioServer.set_bus_volume_db(sfx,-17.0)
    AudioServer.set_bus_mute(sfx,true)
    AudioServer.set_bus_volume_db(enemy,-4.0)
    var expected := AudioServer.bus_count+1
    var effect: AudioEffectLowPassFilter
    for index in 120:
        var result := FILTER.route("SFXEnemy",index%2==0,1)
        check(result==(FILTER.BUS if index%2==0 else "SFXEnemy"), "alternating obstruction routes each new voice independently")
        check(AudioServer.bus_count==expected, "repeated voices do not grow the bus graph")
        var bus := AudioServer.get_bus_index(FILTER.BUS)
        check(AudioServer.get_bus_effect_count(bus)==1, "repeated voices do not accumulate filters")
        if effect==null:
            effect=FILTER.owned_effect(bus)
        check(FILTER.owned_effect(bus)==effect, "filter ownership remains stable across voices")
    check(is_equal_approx(AudioServer.get_bus_volume_db(sfx),-17.0) and AudioServer.is_bus_mute(sfx), "SFX user volume and mute are untouched")
    check(is_equal_approx(AudioServer.get_bus_volume_db(enemy),-4.0), "enemy bus volume is not repurposed for occlusion")

func playback_checks() -> void:
    clean_layout()
    add_bus("SFX")
    add_bus("SFXEnemy","SFX")
    var actor := SoundProbe.new()
    actor.process_mode=Node.PROCESS_MODE_DISABLED
    root.add_child(actor)
    for item in [[false,1],[true,1],[true,0],[false,0]]:
        var blocked: bool=item[0]
        var priority: int=item[1]
        actor.blocked=blocked
        actor.queries=0
        var key:="filter_fixture_"+str(checks)
        actor._play_sfx(key,-10.0,1.0,priority)
        var voice: AudioStreamPlayer2D=actor.get_node_or_null("Sfx_"+key)
        check(voice!=null, "actual enemy playback creates a voice")
        if voice==null:
            continue
        check(voice.stream.get_length() > 0 and voice.playing, "real nonempty fixture stream starts through the production voice owner")
        check(String(voice.bus)==(FILTER.BUS if blocked and priority>0 else "SFXEnemy"), "actual enemy playback uses the selected route")
        var reduction := (ENEMY.SFX_DANGER_OCCLUSION_DB if priority<=0 else ENEMY.SFX_OCCLUSION_DB) if blocked else 0.0
        check(is_equal_approx(voice.volume_db,-10.0-reduction), "existing gain and danger hierarchy are preserved")
        check(actor.queries==1, "one voice makes one obstruction query")
        check(is_equal_approx(float(voice.get_meta("authored_volume_db")),-10), "authored gain remains available for diagnostics")
        voice.stop()
        voice.free()
    actor.free()
    await process_frame
    ENEMY.audio_director_script=null

func ordering_checks() -> void:
    clean_layout()
    add_bus("SFX")
    FILTER.ensure_bus()
    var effect := FILTER.owned_effect(AudioServer.get_bus_index(FILTER.BUS))
    add_bus("SFXEnemy", "SFX")
    for iteration in 20:
        # Reproduce external layout edits that put the parent to the right.
        AudioServer.move_bus(AudioServer.get_bus_index("SFXEnemy"), -1)
        check(AudioServer.get_bus_index("SFXEnemy") > AudioServer.get_bus_index(FILTER.BUS), "fixture puts parent to the right before repair")
        var before := AudioServer.bus_count
        var routed := FILTER.ensure_bus()
        var own := AudioServer.get_bus_index(FILTER.BUS)
        var parent := AudioServer.get_bus_index("SFXEnemy")
        check(routed == FILTER.BUS and parent < own, "owned filter is always mixed before its parent")
        check(AudioServer.bus_count == before, "reordering repairs do not allocate replacement buses")
        check(FILTER.owned_effect(own) == effect, "ordering repair retains the live filter resource")
        check(String(AudioServer.get_bus_send(own)) == "SFXEnemy", "ordering repair preserves the intended SFX route")

func global_effect_checks() -> void:
    clean_layout()
    var master_filter := AudioEffectLowPassFilter.new()
    master_filter.cutoff_hz = 900.0
    AudioServer.add_bus_effect(0,master_filter)
    var music := add_bus("BGM")
    var music_filter := AudioEffectLowPassFilter.new()
    music_filter.cutoff_hz = 1400.0
    AudioServer.add_bus_effect(music,music_filter)
    add_bus("SFX")
    var enemy := add_bus("SFXEnemy","SFX")
    var authored_reverb := AudioEffectReverb.new()
    AudioServer.add_bus_effect(enemy,authored_reverb)
    for priority in [0,1,2,0,1,3]:
        FILTER.route("SFXEnemy",true,priority)
    check(AudioServer.get_bus_effect_count(0)==1 and AudioServer.get_bus_effect(0,0)==master_filter, "occlusion never replaces an existing death/master filter")
    check(is_equal_approx(master_filter.cutoff_hz,900), "master cutoff remains owned by its original system")
    check(AudioServer.get_bus_effect_count(music)==1 and AudioServer.get_bus_effect(music,0)==music_filter, "occlusion never replaces an existing low-health/music filter")
    check(is_equal_approx(music_filter.cutoff_hz,1400), "music cutoff remains owned by its original system")
    check(AudioServer.get_bus_effect_count(enemy)==1 and AudioServer.get_bus_effect(enemy,0)==authored_reverb, "authored enemy parent effects remain intact")
    var diagnostic := FILTER.describe("SFXEnemy",true,1)
    check(diagnostic.filtered and diagnostic.bus==FILTER.BUS, "diagnostics identify the actual dedicated ordinary route")
    check(is_equal_approx(diagnostic.cutoff_hz,FILTER.CUTOFF_HZ), "diagnostics describe the actual lowpass resource")
    diagnostic=FILTER.describe("SFXEnemy",true,0)
    check(not diagnostic.filtered and diagnostic.bus=="SFXEnemy", "diagnostics do not report danger cues as lowpass filtered")
