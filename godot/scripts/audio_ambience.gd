extends RefCounted
## Ambience beds and their timed one-shot variants.
## Moved out of audio_director.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func start_ambience(director: Node) -> void:
    if director.region_audio_released:
        return
    var bed_stream = director.load_cached(director._ambience_bed_path(), true)
    if bed_stream != null:
        if director.ambience_bed_player == null or not is_instance_valid(director.ambience_bed_player):
            director.ambience_bed_player = AudioStreamPlayer.new()
            director.ambience_bed_player.name = "AmbienceBedPlayer"
            director.ambience_bed_player.bus = director._bus_or("Ambience", "Master")
            director.ambience_bed_player.volume_db = director.AMBIENCE_BED_DB
            director.add_child(director.ambience_bed_player)
        if director.ambience_bed_player.stream != bed_stream or not director.ambience_bed_player.playing:
            director.ambience_bed_player.stream = bed_stream
            director.ambience_bed_player.play()
    if is_instance_valid(director.room_ambience_mix):
        director.room_ambience_mix.bind_player(director.ambience_bed_player)
    director.oneshot_variant_count = director._probe_oneshot_variant_count()
    if director.oneshot_timer == null or not is_instance_valid(director.oneshot_timer):
        director.oneshot_timer = Timer.new()
        director.oneshot_timer.name = "AmbienceOneShotTimer"
        director.oneshot_timer.one_shot = true
        director.oneshot_timer.timeout.connect(director._on_oneshot_timer)
        director.add_child(director.oneshot_timer)
    director.oneshot_timer.start(randf_range(director.ONESHOT_INTERVAL_MIN_S, director.ONESHOT_INTERVAL_MAX_S))
    if director.chapter_short_id == "ch02":
        # ch02 远砧：雨铸运河的远处锻打声，独立稀疏调度。
        if director.anvil_timer == null or not is_instance_valid(director.anvil_timer):
            director.anvil_timer = Timer.new()
            director.anvil_timer.name = "AmbienceAnvilTimer"
            director.anvil_timer.one_shot = true
            director.anvil_timer.timeout.connect(director._on_anvil_timer)
            director.add_child(director.anvil_timer)
        director.anvil_timer.start(randf_range(director.ANVIL_INTERVAL_MIN_S, director.ANVIL_INTERVAL_MAX_S))


static func probe_oneshot_variant_count(director: Node) -> int:
    var count := 0
    while count < 32 and FileAccess.file_exists("res://assets/audio/ambience/amb_%s_os_%d.ogg" % [director.chapter_short_id, count + 1]):
        count += 1
    return count


static func on_oneshot_timer(director: Node) -> void:
    if director.oneshot_variant_count > 0:
        director._play_ambience_oneshot(director.AMBIENCE_ONESHOT_DB)
    director.oneshot_timer.start(randf_range(director.ONESHOT_INTERVAL_MIN_S, director.ONESHOT_INTERVAL_MAX_S))


static func on_anvil_timer(director: Node) -> void:
    director._play_ambience_oneshot(director.ANVIL_FAR_DB, "anvil")
    director.anvil_timer.start(randf_range(director.ANVIL_INTERVAL_MIN_S, director.ANVIL_INTERVAL_MAX_S))


static func play_ambience_oneshot(director: Node, volume_db: float, family: String = "regional") -> bool:
    return director.ambient_soundscape.play_nearby(director,director.runtime_player as Node2D,volume_db,family)
