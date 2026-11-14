extends RefCounted
## Enemy sound: listener distance and occlusion, attack and material cues, role cues and voice budgeting.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func sfx_listener(actor: Node) -> CollisionObject2D:
    var nearest: CollisionObject2D = null
    var nearest_distance := INF
    for node in actor.get_tree().get_nodes_in_group("player"):
        var candidate := node as CollisionObject2D
        if candidate == null or not candidate.is_inside_tree():
            continue
        var distance = actor.global_position.distance_squared_to(candidate.global_position)
        if distance < nearest_distance:
            nearest = candidate
            nearest_distance = distance
    return nearest


static func sfx_occluded(actor: Node) -> bool:
    var listener: CollisionObject2D = actor._sfx_listener()
    return listener != null and not actor._has_line_of_sight(listener)


static func sfx_volume(actor: Node, volume_db: float, voice_priority: int, occluded: Variant = null) -> float:
    var blocked: bool = occluded if occluded is bool else actor._sfx_occluded()
    if not blocked:
        return volume_db
    return volume_db - (actor.SFX_DANGER_OCCLUSION_DB if voice_priority <= 0 else actor.SFX_OCCLUSION_DB)


static func play_sfx(actor: Node, audio_key: String, volume_db: float = -6.0, pitch_scale: float = 1.0, voice_priority: int = 1) -> void:
    if not actor._should_play_sfx():
        return
    # 声部准入（AudioDirector 契约）：同 key 最小间隔/并发上限/全局 24 声部抢占。
    var voice_ticket = actor._request_voice("enemy_" + audio_key, voice_priority)
    if voice_ticket == 0:
        return
    var stream: AudioStream = actor._load_sfx_stream(audio_key)
    if stream == null:
        # 声部回滚（AudioDirector 契约）：流缺失/解码失败时释放已占用的声部。
        actor._release_voice(voice_ticket)
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "Sfx_" + audio_key
    # 总线归位（音频规格 §5.1）：敌人/Boss 音走 SFXEnemy 子总线，缺席时回落 SFX/Master。
    var occluded: bool = actor._sfx_occluded()
    player_node.bus = actor.SOUND_FILTER.route(actor._sfx_bus_name(), occluded, voice_priority)
    player_node.stream = stream
    player_node.volume_db = actor._sfx_volume(volume_db, voice_priority, occluded)
    player_node.set_meta("authored_volume_db", volume_db)
    player_node.pitch_scale = pitch_scale
    player_node.max_distance = 900.0
    actor.add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    actor._start_voice(voice_ticket,player_node)


static func stop_parade_layer(actor: Node) -> void:
    if is_instance_valid(actor.parade_voice) and not actor.parade_voice.is_queued_for_deletion():
        actor.parade_voice.stop()
        actor.parade_voice.queue_free()
    actor.parade_voice = null


static func play_attack_sfx(actor: Node, phase: String) -> void:
    var material = actor.COMBAT_AUDIO.release_family(actor.kind,actor.locomotion,actor.active_attack)
    if phase == "windup":
        actor._play_combat_material(actor.COMBAT_AUDIO.preparation_family(material),-11.0 if actor.is_boss else -15.0)
        if actor.is_boss:
            # Boss 前摇分档（音频规格 §4.4）：damage>=2（各 Boss aoe/shockwave 大招）走 lethal 档。
            actor._play_sfx("boss_windup_lethal" if actor._active_attack_is_heavy() else "boss_windup_light", -6.0 if actor._active_attack_is_heavy() else -18.0, 1.0, 0)
        else:
            # 普通敌前摇=windup_light 低配版：升调 + 压量，与 Boss 档拉开距离。
            actor._play_sfx("enemy_windup", -24.0, 1.12, 0)
        # ch5 beat `parade_charge`（manifest ch05_beat_03）：巡礼指挥官冲锋（vault）前摇
        # 叠低频步伐循环，前摇一结束（出招、被打断或倒下）即停。
        if actor.kind == "silent_pilgrim_commander" and String(actor.active_attack.get("type", "")) == "vault":
            actor._stop_parade_layer()
            actor._play_sfx("ch05_beat_parade", -9.0)
            var last = actor.get_child(actor.get_child_count() - 1) if actor.get_child_count() > 0 else null
            if last is AudioStreamPlayer2D and String(last.name).begins_with("Sfx_ch05_beat_parade"):
                actor.parade_voice = last
        # ch5 beat `silent_order`（manifest ch05_beat_02）：黑曜巡礼道（obsidian 材质族）
        # 敌方前摇附一段低频压迫声（军令低鸣叠层）。
        if actor.death_sfx_key == "death_obsidian":
            actor._play_sfx("ch05_beat_silent_order", -12.0)
    elif actor.is_boss:
        # Boss 出招按档走本章四件套 atk_light/atk_heavy（替换 player_attack.ogg 复用）。
        if not actor._play_combat_material(material,-7.5):
            actor._play_sfx(actor._boss_sfx_key("atk_heavy" if actor._active_attack_is_heavy() else "atk_light"), -7.0)
    else:
        if not actor._play_combat_material(material,-10.5):actor._play_sfx("enemy_attack", -10.0)
        # Beat `delayed_shadow`（manifest ch03_beat_01）：迟影复写玩家动作的回声一击
        # 叠玻璃摩擦与低音翻页声；只认这一招，瞬移不叠。
        if actor.kind == "delayed_shadow" and String(actor.active_attack.get("id", "")) == "shadow_echo":
            actor._play_sfx("ch03_beat_delayed_shadow", -9.0)


static func play_combat_material(actor: Node, family: String, volume: float) -> bool:
    var count = actor.COMBAT_AUDIO.variant_count(family)
    var previous:=int(actor.combat_audio_last_variant.get(family,0))
    var variant = actor.combat_audio_rng.randi_range(1,count)
    if variant==previous and count>1:variant=variant%count+1
    var path = actor.COMBAT_AUDIO.path(family,variant)
    if not actor.STREAM_SOURCE.exists(path):return false
    actor.combat_audio_last_variant[family]=variant
    var pitch = actor.combat_audio_rng.randf_range(.97,1.03)*(0.91 if actor.is_boss and not family.begins_with("prep_") else 1.0)
    actor._play_sfx("combat_"+family+"_"+str(variant),volume,pitch,1)
    return true


static func active_attack_is_heavy(actor: Node) -> bool:
    var tier := String(actor.active_attack.get("telegraph_tier", ""))
    if not tier.is_empty():
        return tier == "lethal" or tier == "heavy"
    return int(actor.active_attack.get("damage", actor.damage)) >= 2


static func boss_sfx_key(actor: Node, piece: String) -> String:
    return "boss_%s_%s" % [String(actor.BOSS_SFX_CHAPTER.get(actor.kind, "ch01")), piece]


static func hit_tier_key(actor: Node) -> String:
    if actor.is_boss:
        return "hit_armor"
    return String(actor.HIT_TIER_BY_MATERIAL.get(actor.death_sfx_key, "hit_soft"))


static func role_cue(actor: Node, cue: String) -> void:
    actor.role_cue_counts[cue] = int(actor.role_cue_counts.get(cue, 0)) + 1
    actor._play_sfx("role_" + cue, -8.0 if cue == "alarm_call" else -10.0, 1.0, 1)
    var director: Node=preload("res://scripts/audio_director.gd").instance
    if is_instance_valid(director):director.foreground_warning(actor)
    if cue == "support_mend":
        return
    var reveal := cue == "ambush_reveal"
    for index in (1 if reveal else 2):
        var ring := Line2D.new()
        ring.name = "EnemyAmbushRevealCue" if reveal else ("EnemyAlarmCue" if index == 0 else "EnemyAlarmCueEcho")
        var points := PackedVector2Array()
        var steps := 16 if reveal else 28
        for step in steps + 1:
            var angle := TAU * float(step) / float(steps)
            var radius := (34.0 if step % 2 == 0 else 22.0) if reveal else 30.0
            points.append(Vector2(cos(angle), sin(angle)) * radius)
        ring.points = points
        ring.position = Vector2(0, -48)
        ring.width = 3.0 if reveal else 2.0
        ring.default_color = Color(0.96, 0.32, 0.28, 0.95) if reveal else Color(1.0, 0.82, 0.42, 0.9)
        actor.VISUAL_POLICY.place_danger(ring, true)
        actor.add_child(ring)
        var tween: Tween = actor._combat_tween()
        var life := 0.4 if reveal else 0.55
        tween.tween_interval(0.2 * index)
        tween.tween_property(ring, "scale", Vector2.ONE * (1.5 if reveal else 3.2), life)
        # Hold full strength first so the cue reads, then fade.
        tween.parallel().tween_property(ring, "modulate:a", 0.0, life * 0.6).set_delay(life * 0.4)
        tween.tween_callback(ring.queue_free)


static func combat_engaged(actor: Node) -> bool:
    return not actor.CALM_DECISIONS.has(actor.last_ai_decision)


static func announce_engagement(actor: Node) -> void:
    actor.engage_announced = true
    if actor.is_boss:
        actor._play_sfx(actor._boss_sfx_key("roar"), -4.0, 1.0, 0)
    elif actor.is_elite or actor.encounter_role.contains("elite"):
        actor._play_sfx("elite_ritual_start", -6.0)


static func sfx_bus_name(actor: Node) -> String:
    if AudioServer.get_bus_index("SFXEnemy") != -1:
        return "SFXEnemy"
    return "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"


static func play_detached_sfx(actor: Node, audio_key: String, volume_db: float = -6.0) -> void:
    if not actor._should_play_sfx():
        return
    # 死亡音属 P0：声部抢占最高优先级。
    var voice_ticket = actor._request_voice("enemy_" + audio_key, 0)
    if voice_ticket == 0:
        return
    var stream: AudioStream = actor._load_sfx_stream(audio_key)
    if stream == null:
        # 声部回滚（AudioDirector 契约）：流缺失/解码失败时释放已占用的声部。
        actor._release_voice(voice_ticket)
        return
    var host = actor.get_parent()
    if host == null:
        actor._release_voice(voice_ticket)
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "Sfx_" + audio_key
    var occluded: bool = actor._sfx_occluded()
    player_node.bus = actor.SOUND_FILTER.route(actor._sfx_bus_name(), occluded, 0)
    player_node.stream = stream
    player_node.volume_db = actor._sfx_volume(volume_db, 1, occluded)
    player_node.max_distance = 900.0
    host.add_child(player_node)
    player_node.global_position = actor.global_position
    player_node.finished.connect(Callable(player_node, "queue_free"))
    actor._start_voice(voice_ticket,player_node)


static func should_play_sfx(actor: Node) -> bool:
    if DisplayServer.get_name() != "headless":
        return true
    for arg in OS.get_cmdline_args():
        if String(arg).contains("audio_visual_validation.gd"):
            return true
    return false


static func load_sfx_stream(actor: Node, audio_key: String) -> AudioStream:
    var path := String(actor.SFX.get(audio_key, ""))
    if path.is_empty() and audio_key.begins_with("combat_"):
        path=actor.COMBAT_AUDIO.ROOT+audio_key.trim_prefix("combat_")+".ogg"
    if path.is_empty() and audio_key.begins_with("boss_ch"):
        # Boss 四件套（roar/phase_shift/atk_light/atk_heavy × 六章）按键名直取合成包文件。
        path = "res://assets/audio/sfx/generated/%s.ogg" % audio_key
    return actor._load_stream_for_path(path)
