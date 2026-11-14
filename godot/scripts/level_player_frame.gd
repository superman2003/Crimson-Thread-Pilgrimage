extends RefCounted
## The player camera set-up, falling out of the world, and releasing region audio when a region is left.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const AUDIO_DIRECTOR_SCRIPT := preload("res://scripts/audio_director.gd")

static func release_region_audio(level: Node) -> void:
    # Preserve phrase position while the actual player still owns playback.
    # The Director exits after this host has already detached every stream.
    if is_instance_valid(level.audio_director):level.audio_director.release_region_audio()
    # Snapshot weak playback/stream handles before stopping and detaching any
    # owned players. AudioServer can retain a completed Ogg voice until its next
    # mix tick, so the shutdown probe drains these exact objects afterward.
    level.AUDIO_RETIREMENT_SCRIPT.retire_tree(level)
    if level.bgm_player != null:
        level.bgm_player.stop()
        level.bgm_player.stream = null
    # Region field reset must not orphan the voices awaiting attachment.
    level._cancel_pending_sfx()
    var active_director: AUDIO_DIRECTOR_SCRIPT = level.AUDIO_DIRECTOR_SCRIPT.instance
    if active_director != null and active_director != level.audio_director:
        if level.bgm_duck_tween != null and level.bgm_duck_tween.is_valid():
            level.bgm_duck_tween.kill()
        return
    # 总线是全局状态：场景销毁时摘掉濒死低通并复位 duck 音量，避免跨章节残留。
    level._set_low_hp_audio(false)
    if level.bgm_duck_tween != null and level.bgm_duck_tween.is_valid():
        level.bgm_duck_tween.kill()
    # 章节转场竞态修复：新场景的 AudioDirector 已接管总线（并按用户音量归位）时，
    # 老场景退树不得再把 BGM 总线打回默认 0dB。
    var live_director: AUDIO_DIRECTOR_SCRIPT = level.AUDIO_DIRECTOR_SCRIPT.instance
    if live_director != null and live_director != level.audio_director:
        return
    level._set_bgm_bus_volume_db(float(level.AUDIO_BUS_DEFAULT_VOLUME_DB.get("BGM", 0.0)))
    # Stream caching is useful across regions while this director owns the mix,
    # but must not pin decoded Ogg streams past the final owning scene.
    if live_director == null or live_director == level.audio_director:
        level.AUDIO_DIRECTOR_SCRIPT._stream_cache.clear()
        level.AUDIO_DIRECTOR_SCRIPT._npc_voice_cache.clear()


static func configure_player_camera(level: Node) -> void:
    var camera = level.player.get_node_or_null("Camera2D") as Camera2D
    if camera == null:
        return
    level.player.configure_camera_focus(Rect2(-40, -120, level.world_width + 120.0, level.world_height + 190.0))
    level.player.configure_room_camera(level.config.get("map_rooms", []))
    if is_instance_valid(level.boss_arena_lock_body):
        level._lock_boss_camera()
    var feel = level.get_node_or_null("/root/FeelKit")
    if feel != null:
        feel.register_camera(camera)


static func void_respawn(level: Node) -> void:
    if level.player == null or not is_instance_valid(level.player):
        return
    if level.world_mode:
        if level.player.death_timer > 0.0:
            level.player.global_position = level.active_spawn
            if level.world_gameplay_residency != null: level.world_gameplay_residency.warm_arrival(level, level.active_spawn)
            level.chapter_terrain.warm_focus(level.active_spawn)
            if is_instance_valid(level.cave_world):
                level.cave_world.warm_collision_focus(level.active_spawn)
            if level.world_platforms != null:
                level.world_platforms.warm(level, level.active_spawn)
            level.player.reset_camera_after_arrival()
            return
        # Falling is a resource cost, never a full-heal shortcut.
        level.player._interrupt_heal()
        level.player.guard_timer = 0.0
        level.player.hurt_timer = 0.0
        level.player.take_damage(1, level.player.global_position + Vector2(50, 0), false)
        level.player._reset_traversal_state()
        level.player.global_position = level.active_spawn
        level.player.velocity = Vector2.ZERO
        if level.world_gameplay_residency != null: level.world_gameplay_residency.warm_arrival(level, level.active_spawn)
        level.chapter_terrain.warm_focus(level.active_spawn)
        if is_instance_valid(level.cave_world):
            level.cave_world.warm_collision_focus(level.active_spawn)
        if level.world_platforms != null:
            level.world_platforms.warm(level, level.active_spawn)
        level.player.reset_camera_after_arrival()
        level._save_world()
        level._toast("坠落 · 生命 -1")
        level._refresh_hud()
        return
    if level.player.has_method("restore_at_save_point"):
        level.player.restore_at_save_point()
    if level.player.has_method("respawn_at"):
        level.player.respawn_at(level.active_spawn)
    else:
        level.player.global_position = level.active_spawn
    level._toast("回到钟龛")
    level._update_room_visit()
    level._refresh_hud()
