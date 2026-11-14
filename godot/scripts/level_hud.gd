extends RefCounted
## HUD refresh, toasts, lore pickup banners and pickup effects.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func on_hp_changed(level: Node, value: int) -> void:
    # 濒死混音态（规格 §5.5）：HP==1 挂低通，回升或死亡即摘除。
    level._set_low_hp_audio(value == 1)
    if value <= 0:
        # Enemy body-entered callbacks run during physics query flushing.
        level._defer_region_call("_record_death_cache")
        # 玩家死亡（规格 §5.3/§5.5）：director 在场时全总线 300Hz 低通 + duck 自清；
        # 缺席时保持旧 duck 行为。
        if level.audio_director != null:
            level.audio_director.on_player_death()
        else:
            level.duck_bgm(-10.0, 1.2)
    level._refresh_hud()


static func on_energy_changed(level: Node, _value: int, _maximum: int) -> void:
    level._refresh_hud()


static func refresh_hud(level: Node) -> void:
    if level.hud_label == null:
        return
    var hp_text := str(level.player.hp) if level.player != null else "5"
    var energy_text = "%d/%d" % [level.player.energy, level.player.max_energy] if level.player != null else "0/100"
    var skill_text = "Ready" if level.player != null and level.player.skill_cooldown <= 0.0 and level.player.energy >= level.player.skill_energy_cost else "Charging"
    var shortcut_total: int = level._shortcut_total()
    var opened_shortcut_count: int = level._opened_shortcut_total()
    var shortcut_text = ("%d/%d" % [opened_shortcut_count, shortcut_total]) if shortcut_total > 0 else ("Open" if level.shortcut_open else "Closed")
    var boss_text = "Awake" if level.boss_spawned else ("Ready" if level.boss_unlocked else "Locked")
    var save_text = level.active_save_point_id
    if level._combat_progression_enabled():
        var boss_route_text = "Open" if level.boss_unlocked else "Closed"
        level.hud_label.text = "HP %s/5  EN %s  Skill %s  Enemies %d/%d  Boss Route %s  Shortcuts %s  Boss %s  Save %s  A/D Move W/S Aim Space Jump Shift Dash LMB/J Slash RMB Heal E Skill F Use Tab Bag M Map" % [
            hp_text,
            energy_text,
            skill_text,
            level.enemy_defeated,
            level.enemy_total,
            boss_route_text,
            shortcut_text,
            boss_text,
            save_text
        ]
    else:
        level.hud_label.text = "HP %s/5  EN %s  Skill %s  Marks %d/%d  Enemies %d/%d  Shortcut %s  Boss %s  Save %s  A/D Move W/S Aim Space Jump Shift Dash LMB/J Slash RMB Heal E Skill F Use Tab Bag M Map" % [
            hp_text,
            energy_text,
            skill_text,
            level.bell_count,
            level.max_bells,
            level.enemy_defeated,
            level.enemy_total,
            shortcut_text,
            boss_text,
            save_text
        ]


static func toast(level: Node, text: String) -> void:
    if level.ui_shell!=null:
        level.ui_shell.toast_age=0.0
    if level.toast_label != null:
        level.toast_label.text = text
    # toast 提示微音（音频规格 §4.5 ui_toast）：900ms 冷却防连发刷屏音。
    var now := Time.get_ticks_msec()
    if now - level.last_toast_sfx_ms >= 900:
        level.last_toast_sfx_ms = now
        level._play_sfx("ui_toast", -6.0)
    print(text)


static func is_story_key_item(level: Node, item_id: String) -> bool:
    return item_id.begins_with("testimony_") \
        or item_id.begins_with("silent_mark_") \
        or level.STORY_KEY_ITEM_IDS.has(item_id)


static func announce_lore_pickup(level: Node, item_id: String) -> void:
    if not level._is_story_key_item(item_id):
        return
    # 关键道具拾取混音态（规格 §5.3）：Music -6dB 短暂让位 + 专属拾取音。
    if level.audio_director != null:
        level.audio_director.on_key_item_pickup()
    level._play_sfx("ui_pickup_key_item", -8.0)
    var lore_entry: Dictionary = level.item_lore.get(item_id, {})
    var lore_lines: Array = lore_entry.get("lore", [])
    if lore_lines.is_empty():
        return
    # The inscription itself is the item's backpack description; the banner
    # only names the find (U01 less text).
    var text = "拾获「%s」" % level._item_display_name(item_id)
    level._show_lore_banner(text)
    print("LORE_PICKUP " + text)


static func show_lore_banner(level: Node, text: String) -> void:
    level.lore_banner_time_left = level.LORE_BANNER_SECONDS
    if level.lore_banner_label != null:
        level.lore_banner_label.text = text
        level.lore_banner_label.visible = true


static func tick_lore_banner(level: Node, delta: float) -> void:
    if level.lore_banner_time_left <= 0.0:
        return
    level.lore_banner_time_left -= delta
    if level.lore_banner_time_left <= 0.0 and level.lore_banner_label != null:
        level.lore_banner_label.text = ""
        level.lore_banner_label.visible = false


static func spawn_pickup_effect(level: Node, world_position: Vector2) -> void:
    var ring := Line2D.new()
    ring.name = "PickupEffectRing"
    ring.global_position = world_position
    var points := PackedVector2Array()
    for step in range(24):
        var angle := TAU * float(step) / 24.0
        points.append(Vector2(cos(angle), sin(angle)) * 20.0)
    ring.points = points
    ring.closed = true
    ring.width = 3.0
    ring.default_color = Color(1.0, 0.78, 0.25, 0.95)
    ring.z_index = 90

    var ray := Line2D.new()
    ray.name = "PickupSparkVfx"
    ray.global_position = world_position
    ray.points = PackedVector2Array([
        Vector2(-18.0, 0.0),
        Vector2(18.0, 0.0),
        Vector2(0.0, 0.0),
        Vector2(0.0, -26.0)
    ])
    ray.width = 2.0
    ray.default_color = Color(0.64, 1.0, 0.76, 0.86)
    ray.z_index = 91
    if not level.VISUAL_POLICY.attach_secondary_batch(level, [ring, ray], &"environment", level): return

    var tween: Tween = level._region_tween()
    tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.28)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
    tween.parallel().tween_property(ray, "scale", Vector2(1.5, 1.5), 0.20)
    tween.parallel().tween_property(ray, "modulate:a", 0.0, 0.20)
    tween.finished.connect(Callable(ring, "queue_free"))
    tween.finished.connect(Callable(ray, "queue_free"))
