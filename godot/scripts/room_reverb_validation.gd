extends SceneTree
## Real AudioServer effects and production AudioDirector methods; no media fixture.
const DIRECTOR := preload("res://scripts/audio_director.gd")
const MIX := preload("res://scripts/room_reverb_mix.gd")
const USER_VOLUME := preload("res://scripts/audio_user_volume_validation.gd")
const CHAPTER := preload("res://scripts/chapter_reverb_contract_host.gd")
const BASES := {"SFX": 0.2, "Ambience": 0.4}
var effects: Dictionary = {}
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func director() -> Node:
    var value := DIRECTOR.new()
    value.autoplay_enabled = false
    value.settings_path = "user://room_reverb_contract.cfg"
    root.add_child(value)
    value.set_process(false)
    return value

func finish(value: Node) -> void:
    for tween in value.reverb_tweens.values():
        if tween != null and tween.is_valid():
            tween.custom_step(0.7)

func run() -> void:
    var original := AudioServer.generate_bus_layout()
    for bus in ["BGM", "SFX", "Ambience", "UI"]:
        DIRECTOR._ensure_bus(bus, "Master")
    for bus in ["SFX", "Ambience"]:
        var effect := AudioEffectReverb.new()
        effect.wet = 0.2 if bus == "SFX" else 0.4
        effects[bus] = effect
        AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), effect)
    var active := director()
    active.set_chapter("ch01")
    active.on_room_changed("hub")
    finish(active)
    active.set_chapter("ch02")
    check(is_equal_approx(float(active.base_reverb_wet.SFX), 0.2), "chapter change retains the authored SFX reverb baseline")
    check(is_equal_approx(float(active.base_reverb_wet.Ambience), 0.4), "chapter change retains the authored ambience reverb baseline")
    active.on_room_changed("hub")
    finish(active)
    check(is_equal_approx(active._bus_reverb("SFX").wet, 0.3), "revisiting hubs does not accumulate reverb")
    active.free()
    var sfx := AudioServer.get_bus_index("SFX")
    var effect := AudioServer.get_bus_effect(sfx, AudioServer.get_bus_effect_count(sfx) - 1) as AudioEffectReverb
    check(is_equal_approx(effect.wet, 0.2), "last director exit restores authored room reverb")
    _check_repeated_chapters()
    _check_reverse_fade()
    _check_overlap()
    await _check_queued_handoff()
    _check_replaced_effect()
    _check_missing_effect()
    _check_clamping()
    _check_user_mix()
    _check_chapter_presets()
    assert_bases("all room cases leave the authored bus layout clean")
    var volumes := USER_VOLUME.new()
    await volumes.run(self, check)
    check(volumes.failures == 0, "existing user-volume contract passes unchanged")
    check(DIRECTOR.instance == null, "no director survives the combined contracts")
    assert_bases("user-volume regression also leaves the room baseline clean")
    AudioServer.set_bus_layout(original)
    effects.clear()
    print("ROOM_REVERB checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func step(value: Node, seconds: float = 0.7) -> void:
    for tween in value.reverb_tweens.values():
        if tween != null and tween.is_valid():
            tween.custom_step(seconds)

func assert_wet(bus: String, expected: float, message: String) -> void:
    check(is_equal_approx(float(effects[bus].wet), expected), message + " / " + bus)

func assert_bases(message: String) -> void:
    for bus: String in BASES:
        assert_wet(bus, BASES[bus], message)
        check(not effects[bus].has_meta(MIX.KEY), "released effect has no room lease / " + bus)

func _check_repeated_chapters() -> void:
    var active := director()
    active.set_chapter("ch01")
    for index in 12:
        var kind: String = ["hub", "vista", "corridor", "secret", "ordinary", "hub"][index % 6]
        active.set_chapter("ch0%d" % (index % 6 + 1))
        active.on_room_changed(kind)
        step(active)
        for bus: String in BASES:
            assert_wet(bus, BASES[bus] + float(DIRECTOR.ROOM_REVERB_WET_DELTA.get(kind, 0.0)), "repeated visits never accumulate wet")
    active.free()
    assert_bases("last director exit restores authored wet")

func _check_reverse_fade() -> void:
    var active := director()
    active.set_chapter("ch01")
    active.on_room_changed("hub")
    step(active, 0.15)
    var before: float = effects.SFX.wet
    var previous: Tween = active.reverb_tweens.SFX
    active.on_room_changed("corridor")
    check(not previous.is_valid(), "a changed room retires its pending fade")
    assert_wet("SFX", before, "room reversal starts at current wet without a snap")
    step(active)
    for bus: String in BASES:
        assert_wet(bus, BASES[bus] - 0.08, "reversed fade settles relative to the authored base")
    active.free()

func _check_overlap() -> void:
    var old := director()
    old.set_chapter("ch01")
    old.on_room_changed("hub")
    step(old, 0.2)
    var previous: Tween = old.reverb_tweens.SFX
    var before: float = effects.SFX.wet
    var next := director()
    next.set_chapter("ch02")
    check(not previous.is_valid(), "new director cancels predecessor fade before claiming the bus")
    assert_wet("SFX", before, "claiming a shared effect preserves current envelope position")
    next.on_room_changed("secret")
    step(next, 0.12)
    before = effects.SFX.wet
    old.on_room_changed("vista")
    old.set_chapter("ch06")
    assert_wet("SFX", before, "superseded director cannot reclaim the current room mix")
    var retired: WeakRef = weakref(old)
    old.free()
    check(retired.get_ref() == null, "shared bus lease does not retain the previous director")
    assert_wet("SFX", before, "old exit cannot reset successor fade")
    step(next)
    for bus: String in BASES:
        check(is_equal_approx(float(next.base_reverb_wet[bus]), BASES[bus]), "successor inherits authored baseline / " + bus)
        assert_wet(bus, BASES[bus] - 0.08, "successor completes its own room fade")
    next.free()
    assert_bases("successor exit restores the original base")

func _check_queued_handoff() -> void:
    var old := director()
    old.set_chapter("ch01")
    old.on_room_changed("hub")
    step(old)
    old.queue_free()
    var next := director()
    next.set_chapter("ch02")
    next.on_room_changed("corridor")
    step(next, 0.1)
    var before: float = effects.Ambience.wet
    for tween in next.reverb_tweens.values():
        tween.pause()
    await process_frame
    assert_wet("Ambience", before, "queued old region exit preserves successor's ambience fade")
    step(next)
    assert_wet("Ambience", 0.32, "queued handoff finishes on the original baseline")
    next.free()

func _check_replaced_effect() -> void:
    var active := director()
    active.set_chapter("ch01")
    active.on_room_changed("hub")
    step(active, 0.2)
    var old_fade: Tween = active.reverb_tweens.SFX
    var index := AudioServer.get_bus_index("SFX")
    AudioServer.remove_bus_effect(index, AudioServer.get_bus_effect_count(index) - 1)
    var replacement := AudioEffectReverb.new()
    replacement.wet = 0.33
    AudioServer.add_bus_effect(index, replacement)
    active.set_chapter("ch03")
    check(not old_fade.is_valid(), "layout replacement retires the detached effect's fade")
    assert_wet("SFX", 0.2, "detached effect is restored rather than left modified")
    check(not effects.SFX.has_meta(MIX.KEY), "detached effect releases all room ownership")
    check(is_equal_approx(float(active.base_reverb_wet.SFX), 0.33), "new effect captures its own authored wet")
    active.on_room_changed("vista")
    step(active)
    check(is_equal_approx(replacement.wet, 0.43), "replacement effect gets only its own room delta")
    active.free()
    check(is_equal_approx(replacement.wet, 0.33), "replacement exit restores its own baseline")
    check(not replacement.has_meta(MIX.KEY), "replacement exit clears its lease")
    AudioServer.remove_bus_effect(index, AudioServer.get_bus_effect_count(index) - 1)
    AudioServer.add_bus_effect(index, effects.SFX)

func _check_missing_effect() -> void:
    var active := director()
    active.set_chapter("ch01")
    active.on_room_changed("hub")
    step(active, 0.1)
    var index := AudioServer.get_bus_index("Ambience")
    AudioServer.remove_bus_effect(index, AudioServer.get_bus_effect_count(index) - 1)
    active._capture_base_reverb()
    check(not active.base_reverb_wet.has("Ambience"), "missing reverb discards the old per-bus baseline")
    assert_wet("Ambience", 0.4, "missing bus effect releases its former wet modifier")
    active.on_room_changed("secret")
    step(active)
    AudioServer.add_bus_effect(index, effects.Ambience)
    active.on_room_changed("hub")
    step(active)
    assert_wet("Ambience", 0.5, "restored bus effect starts from its authored baseline")
    active.free()

func _check_clamping() -> void:
    effects.SFX.wet = 0.95
    effects.Ambience.wet = 0.03
    var active := director()
    active.set_chapter("ch01")
    active.on_room_changed("hub")
    step(active)
    assert_wet("SFX", 1.0, "high authored baseline clamps at one")
    active.on_room_changed("corridor")
    step(active)
    assert_wet("Ambience", 0.0, "low authored baseline clamps at zero")
    active.set_chapter("ch02")
    check(is_equal_approx(float(active.base_reverb_wet.SFX), 0.95), "clamping never replaces the authored high baseline")
    check(is_equal_approx(float(active.base_reverb_wet.Ambience), 0.03), "clamping never replaces the authored low baseline")
    active.free()
    assert_wet("SFX", 0.95, "clamped effect restores its authored high wet")
    assert_wet("Ambience", 0.03, "clamped effect restores its authored low wet")
    for bus: String in BASES:
        effects[bus].wet = BASES[bus]

func _check_user_mix() -> void:
    var active := director()
    active.set_chapter("ch01")
    var sfx := AudioServer.get_bus_index("SFX")
    var ambience := AudioServer.get_bus_index("Ambience")
    AudioServer.set_bus_volume_db(sfx, -11.0)
    AudioServer.set_bus_mute(ambience, true)
    active.on_room_changed("vista")
    step(active)
    active.on_room_changed("corridor")
    step(active)
    check(is_equal_approx(AudioServer.get_bus_volume_db(sfx), -11.0), "room mixing preserves user bus gain")
    check(AudioServer.is_bus_mute(ambience), "room mixing preserves user ambience mute")
    active.free()
    check(is_equal_approx(AudioServer.get_bus_volume_db(sfx), -11.0), "room lease retirement does not reset bus gain")
    check(AudioServer.is_bus_mute(ambience), "room lease retirement does not unmute ambience")
    AudioServer.set_bus_mute(ambience, false)

func _check_chapter_presets() -> void:
    # The isolated host contains Main's exact method bodies and authored presets.
    var host := CHAPTER.new()
    var previous: Node
    for chapter: String in CHAPTER.CHAPTER_REVERB_TIER:
        var old_fade: Tween
        if previous != null:
            previous.on_room_changed("hub")
            step(previous, 0.15)
            old_fade = previous.reverb_tweens.SFX
        host._apply_chapter_reverb(chapter)
        if old_fade != null:
            check(not old_fade.is_valid(), "production chapter preset cancels the previous room envelope")
        var tier: Dictionary = CHAPTER.REVERB_TIERS[CHAPTER.CHAPTER_REVERB_TIER[chapter]]
        var active := director()
        active.set_chapter(chapter)
        active.on_room_changed("corridor")
        if previous != null:
            previous.free()
        step(active)
        for bus: String in BASES:
            check(is_equal_approx(float(active.base_reverb_wet[bus]), float(tier.wet)), "actual Main chapter wet becomes the new baseline / " + chapter + "/" + bus)
            assert_wet(bus, clampf(float(tier.wet) - 0.08, 0.0, 1.0), "room delta follows actual Main chapter preset")
            check(is_equal_approx(effects[bus].room_size, float(tier.room_size)), "chapter room size is preserved / " + chapter + "/" + bus)
            check(is_equal_approx(effects[bus].damping, float(tier.damping)), "chapter damping is preserved / " + chapter + "/" + bus)
        previous = active
    previous.free()
    host.free()
    for bus: String in BASES:
        check(not effects[bus].has_meta(MIX.KEY), "last authored chapter has no retired room lease / " + bus)
        effects[bus].wet = BASES[bus]



