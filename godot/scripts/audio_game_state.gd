extends RefCounted
## Audio following game state: shrine lullaby, combat layer and boss phase ticks, dialogue, chapter transitions, rooms, hidden zones, low HP and death.
## Moved out of audio_director.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func engage_shrine(director: Node, anchor: Vector2) -> void:
    director.shrine_anchor = anchor
    director.shrine_engaged = true
    director.start_lullaby()


static func process(director: Node, delta: float) -> void:
    if director._npc_speaker != null:
        var speaker: Node = director._npc_speaker.get_ref()
        if not is_instance_valid(speaker) or not speaker.is_inside_tree() or speaker.is_queued_for_deletion() \
                or (speaker.has_method("accepts_utterance") and not bool(speaker.call("accepts_utterance"))):
            director.stop_npc_voice()
    director._tick_shrine_lullaby()
    director.ambient_soundscape.tick(director, director.runtime_player as Node2D)
    director.ai_poll_accum += delta
    if director.ai_poll_accum < director.COMBAT_POLL_INTERVAL_S:
        return
    var tick = director.ai_poll_accum
    director._retire_invalid_landmarks()
    director._tick_npc_landmarks()
    director.ai_poll_accum = 0.0
    var enemies: Array = director._runtime_enemies()
    director._tick_combat_layer(tick, enemies)
    director._tick_boss_phase(enemies)


static func runtime_enemies(director: Node) -> Array:
    if director.get_enemies_source.is_valid():
        var result: Variant = director.get_enemies_source.call()
        if typeof(result) == TYPE_ARRAY:
            return result
    return []


static func tick_shrine_lullaby(director: Node) -> void:
    if not director.shrine_engaged:
        return
    var player_2d = director.runtime_player as Node2D
    if player_2d == null or not is_instance_valid(player_2d):
        return
    if player_2d.global_position.distance_to(director.shrine_anchor) > director.LULLABY_LEAVE_DISTANCE:
        director.shrine_engaged = false
        director.stop_lullaby()
    elif not director.lullaby_active and not director.boss_active:
        director.start_lullaby()


static func tick_combat_layer(director: Node, tick: float, enemies: Array) -> void:
    if director.boss_active:
        return
    var engaged := false
    for enemy_variant in enemies:
        var enemy_node := enemy_variant as Node
        if enemy_node == null or not is_instance_valid(enemy_node) or enemy_node.get("is_boss") == true:
            continue
        if enemy_node.has_method("world_residency_active") and not enemy_node.world_residency_active(): continue
        var decision_value: Variant = enemy_node.get("last_ai_decision")
        if typeof(decision_value) != TYPE_STRING:
            continue
        var decision := String(decision_value)
        # Lurking ambushers and guards at their post are calm, not combat.
        var in_combat := bool(enemy_node.combat_engaged()) if enemy_node.has_method("combat_engaged") else decision != "patrol" and decision != "return"
        if not decision.is_empty() and in_combat:
            engaged = true
            # An encounter has one quiet material voice accent, never one per poll.
            if not director.combat_active:
                director.play_enemy_alert(String(enemy_node.get("kind")), enemy_node as Node2D)
            break
    if engaged:
        director.combat_calm_time = 0.0
        director.enter_combat()
    elif director.combat_active:
        director.combat_calm_time += tick
        if director.combat_calm_time >= director.COMBAT_CALM_SECONDS:
            director.combat_calm_time = 0.0
            director.exit_combat()


static func tick_boss_phase(director: Node, enemies: Array) -> void:
    if not director.boss_active:
        return
    for enemy_variant in enemies:
        var enemy_node := enemy_variant as Node
        if enemy_node == null or not is_instance_valid(enemy_node) or enemy_node.get("is_boss") != true:
            continue
        var hp_value: Variant = enemy_node.get("hp")
        var max_hp_value: Variant = enemy_node.get("max_hp")
        if typeof(hp_value) != TYPE_INT or typeof(max_hp_value) != TYPE_INT:
            return
        var ratio := float(hp_value) / maxf(1.0, float(max_hp_value))
        var phase := 1
        if ratio <= 1.0 / 3.0:
            phase = 3
        elif ratio <= 2.0 / 3.0:
            phase = 2
        director.set_boss_phase(phase)
        return


static func on_dialogue(director: Node, open: bool) -> void:
    if open == director.dialogue_open:
        if not open: director.stop_npc_voice()
        return
    director.dialogue_open = open
    if open:director.ambient_soundscape.stop()
    if not open: director.stop_npc_voice()
    # Dialogue changes the baseline; independent transient ducks keep their leases.
    if open:director._stop_npc_landmarks()
    director._tween_bus_db("BGM", director._music_rest_db(), 0.25)
    director._tween_bus_db("Ambience", director._ambience_rest_db(), 0.25)


static func on_key_item_pickup(director: Node) -> void:
    director.duck(-6.0, 1.4)


static func begin_chapter_transition(director: Node) -> void:
    director.ambient_soundscape.transitioning = true
    director.ambient_soundscape.stop()
    director._clear_duck_layers()
    director._stop_npc_landmarks()
    director.set_hidden_zone(false)
    director._tween_bus_db("BGM", director.SILENT_DB, director.CHAPTER_EXIT_BGM_FADE_S)


static func cancel_chapter_transition(director: Node) -> void:
    director.ambient_soundscape.transitioning = false
    var transition: Tween = director.bus_tweens.get("BGM")
    if transition != null and transition.is_valid():
        transition.kill()
    director.bus_tweens.erase("BGM")
    director._apply_user_volume("music")


static func on_room_changed(director: Node, kind: String) -> void:
    if director.is_queued_for_deletion() or (is_instance_valid(director.instance) and director.instance != director):
        return
    if is_instance_valid(director.room_ambience_mix):
        director.room_ambience_mix.update_room()
    var leaving_transit = director.in_transit_room and kind != "transit"
    director.in_transit_room = kind == "transit"
    director._update_transit_loop(director.in_transit_room and not director.combat_active and not director.boss_active and not director.lullaby_active)
    if leaving_transit and not director.combat_active and not director.boss_active and not director.lullaby_active:
        director._fade_explore_resume(director.TRANSIT_LOOP_FADE_OUT_S)
    var delta := float(director.ROOM_REVERB_WET_DELTA.get(kind, 0.0))
    for bus_name in ["SFX", "Ambience"]:
        var reverb: AudioEffectReverb = director._bus_reverb(String(bus_name))
        if reverb == null:
            director.room_reverb_mix.release_bus(director, String(bus_name))
            director.base_reverb_wet.erase(bus_name)
            continue
        var baseline: float = director.room_reverb_mix.capture(director, String(bus_name), reverb)
        director.base_reverb_wet[bus_name] = baseline
        director.reverb_tweens[bus_name] = director.room_reverb_mix.fade(director, String(bus_name), reverb, baseline + delta, 0.6)


static func update_transit_loop(director: Node, in_transit: bool) -> void:
    if in_transit:
        if not director.autoplay_enabled or director.combat_active or director.boss_active or director.lullaby_active:
            return
        if director.transit_tween != null and director.transit_tween.is_valid():
            director.transit_tween.kill()
        if director.transit_player != null and is_instance_valid(director.transit_player) and director.transit_player.playing:
            director.transit_player.volume_db = director.TRANSIT_LOOP_DB
            director._fade_explore_to_pause(0.8)
            return
        var stream = director.load_cached(director.BELLWAY_TRANSIT_LOOP, true)
        if stream == null:
            return
        if director.transit_player == null or not is_instance_valid(director.transit_player):
            director.transit_player = AudioStreamPlayer.new()
            director.transit_player.name = "BellwayTransitLoop"
            director.transit_player.bus = director._bus_or("MusicStinger", "BGM")
            director.add_child(director.transit_player)
        director.transit_player.stream = stream
        director.transit_player.volume_db = director.TRANSIT_LOOP_DB
        director.transit_player.play()
        director._fade_explore_to_pause(0.8)
        return
    if director.transit_player == null or not is_instance_valid(director.transit_player) or not director.transit_player.playing:
        return
    if director.transit_tween != null and director.transit_tween.is_valid():
        director.transit_tween.kill()
    if not director.is_inside_tree():
        director.transit_player.stop()
        return
    director.transit_tween = director.create_tween()
    director.transit_tween.tween_property(director.transit_player, "volume_db", director.SILENT_DB, director.TRANSIT_LOOP_FADE_OUT_S)
    director.transit_tween.tween_callback(director.transit_player.stop)


static func set_hidden_zone(director: Node, active: bool) -> void:
    if director.is_queued_for_deletion() or (is_instance_valid(director.instance) and director.instance != director):
        return
    if active == director.hidden_zone:
        return
    director.hidden_zone = active
    if director.hidden_drone_tween != null and director.hidden_drone_tween.is_valid():
        director.hidden_drone_tween.kill()
    if active:
        if not director.autoplay_enabled:
            return
        var stream = director.load_cached(director.HIDDEN_DRONE, true)
        if stream == null:
            return
        if director.hidden_drone_player == null or not is_instance_valid(director.hidden_drone_player):
            director.hidden_drone_player = AudioStreamPlayer.new()
            director.hidden_drone_player.name = "HiddenDrone"
            director.hidden_drone_player.bus = director._bus_or("Ambience", "Master")
            director.add_child(director.hidden_drone_player)
        if not director.hidden_drone_player.playing:
            director.hidden_drone_player.stream = stream
            director.hidden_drone_player.volume_db = director.SILENT_DB
            director.hidden_drone_player.play()
        if not director.is_inside_tree():
            director.hidden_drone_player.volume_db = director.HIDDEN_DRONE_DB
            return
        director.hidden_drone_tween = director.create_tween()
        director.hidden_drone_tween.tween_property(director.hidden_drone_player, "volume_db", director.HIDDEN_DRONE_DB, director.HIDDEN_DRONE_FADE_IN_S)
        return
    if director.hidden_drone_player == null or not is_instance_valid(director.hidden_drone_player) or not director.hidden_drone_player.playing:
        return
    if not director.is_inside_tree():
        director.hidden_drone_player.stop()
        return
    director.hidden_drone_tween = director.create_tween()
    director.hidden_drone_tween.tween_property(director.hidden_drone_player, "volume_db", director.SILENT_DB, director.HIDDEN_DRONE_FADE_OUT_S)
    director.hidden_drone_tween.tween_callback(director.hidden_drone_player.stop)


static func set_low_hp(director: Node, active: bool) -> void:
    if active == director.low_hp_active:
        return
    director.low_hp_active = active
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index == -1:
        return
    if director.low_hp_tween != null and director.low_hp_tween.is_valid():
        director.low_hp_tween.kill()
    var effect_index = director._find_bus_effect(bus_index, "AudioEffectLowPassFilter")
    if active:
        var lowpass: AudioEffectLowPassFilter
        if effect_index == -1:
            lowpass = AudioEffectLowPassFilter.new()
            lowpass.cutoff_hz = director.LOW_HP_SWEEP_START_HZ
            AudioServer.add_bus_effect(bus_index, lowpass)
        else:
            lowpass = AudioServer.get_bus_effect(bus_index, effect_index) as AudioEffectLowPassFilter
        if lowpass == null:
            return
        if director.is_inside_tree():
            director.low_hp_tween = director.create_tween()
            director.low_hp_tween.tween_property(lowpass, "cutoff_hz", director.LOW_HP_SWEEP_TARGET_HZ, director.LOW_HP_SWEEP_SECONDS)
        else:
            lowpass.cutoff_hz = director.LOW_HP_SWEEP_TARGET_HZ
    elif effect_index != -1:
        AudioServer.remove_bus_effect(bus_index, effect_index)


static func on_player_death(director: Node) -> void:
    director.ambient_soundscape.stop()
    director.duck(-10.0, 1.2)
    var master_index := AudioServer.get_bus_index("Master")
    if master_index == -1:
        return
    if director._find_bus_effect(master_index, "AudioEffectLowPassFilter") == -1:
        var lowpass := AudioEffectLowPassFilter.new()
        lowpass.cutoff_hz = director.DEATH_LOWPASS_HZ
        AudioServer.add_bus_effect(master_index, lowpass)
    if director.death_tween != null and director.death_tween.is_valid():
        director.death_tween.kill()
    if director.is_inside_tree():
        director.death_tween = director.create_tween()
        director.death_tween.tween_interval(1.6)
        director.death_tween.tween_callback(director._clear_death_lowpass)
    else:
        director._clear_death_lowpass()


static func clear_death_lowpass(director: Node) -> void:
    var master_index := AudioServer.get_bus_index("Master")
    if master_index == -1:
        return
    var effect_index = director._find_bus_effect(master_index, "AudioEffectLowPassFilter")
    if effect_index != -1:
        AudioServer.remove_bus_effect(master_index, effect_index)
