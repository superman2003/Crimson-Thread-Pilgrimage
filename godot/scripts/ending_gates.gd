extends RefCounted
## Ending gates: placing them after the final gatekeeper, what each still needs, choosing one, and the aftermath.
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func spawn_ending_aftermath(level: Node) -> void:
    if level.ending_aftermath != null and is_instance_valid(level.ending_aftermath):
        level.ending_aftermath.queue_free()
    level.ending_aftermath = null
    if level.world_narrative == null:
        return
    var scene: Dictionary = level.world_narrative.aftermath_scene(String(level.config.get("id", "")), level.story_flags)
    for data in level.config.get("save_points", []) if not scene.is_empty() else []:
        if String(data.get("id", "")) != String(scene.anchor):
            continue
        level.ending_aftermath = Node2D.new()
        level.ending_aftermath.set_script(level.ENDING_AFTERMATH_SCRIPT)
        level.ending_aftermath.name = "EndingAftermath"
        level.ending_aftermath.look = String(scene.get("look", "bells"))
        # Beside the lamp, standing on the floor the pedestal stands on.
        level.ending_aftermath.position = level._vec2(data.position) + Vector2(70, 28)
        level.ending_aftermath.set_meta("aftermath", scene)
        level.add_child(level.ending_aftermath)


static func notice_ending_aftermath(level: Node) -> void:
    if not level.active_overlay.is_empty() or level.ending_aftermath == null or not is_instance_valid(level.ending_aftermath):
        return
    var scene: Dictionary = level.ending_aftermath.get_meta("aftermath")
    var flag := String(scene.get("seen_flag", ""))
    if bool(level.story_flags.get(flag, false)) or level.player.global_position.distance_to(level.ending_aftermath.global_position) > level.AFTERMATH_NOTICE_RANGE:
        return
    level.story_flags[flag] = true
    level._save_world()
    # The shrine's own prompt would cover a toast at once; the banner stays.
    level._show_lore_banner("%s · %s" % [String(scene.get("region_name", "")), String(scene.get("line", ""))])


static func ending_gate_entries(level: Node) -> Array:
    var entries: Array = []
    for gate in level.config.get("ending_gates", []):
        if gate is Dictionary:
            entries.append(gate)
    return entries


static func spawn_ending_gates(level: Node, announce: bool = false) -> void:
    if level.ending_gates_spawned:
        return
    var entries: Array = level._ending_gate_entries()
    if entries.is_empty():
        return
    level.ending_gates_spawned = true
    if announce:
        level._play_sfx("ch06_beat_ending_doors", -6.0)
    var anchor := Vector2(level.world_width * 0.5, level.world_height * 0.5)
    if level.boss_actor != null and is_instance_valid(level.boss_actor):
        anchor = level.boss_actor.global_position
    elif level.config.get("boss", {}).has("position"):
        # Reloaded completed regions have no boss actor: keep the ending choice
        # in the authored arena instead of moving it to the player checkpoint.
        anchor = level._vec2(level.config.boss.position)
    elif level.player != null and is_instance_valid(level.player):
        anchor = level.player.global_position
    for index in range(entries.size()):
        var data: Dictionary = entries[index]
        var ending := String(data.get("ending", String(data.get("id", "ending_%d" % index))))
        var area := Area2D.new()
        area.name = String(data.get("id", "ending_gate_%d" % index))
        var fallback := anchor + Vector2(-230.0 + 230.0 * float(index), 0.0)
        area.position = level._vec2(data.get("position", [fallback.x, fallback.y]))
        area.set_meta("kind", "ending_gate")
        area.set_meta("label", String(data.get("label", "结局之门")))
        area.set_meta("ending", ending)
        area.set_meta("requires", data.get("requires", {}))
        area.set_meta("message", String(data.get("message", "")))
        area.set_meta("reject_message", String(data.get("reject_message", "")))
        area.set_meta("object_id", "interactable/" + area.name)

        var shape := CollisionShape2D.new()
        var rectangle := RectangleShape2D.new()
        rectangle.size = level._vec2(data.get("interaction_size", [150, 150]))
        shape.shape = rectangle
        area.add_child(shape)

        var tint: Color = level.ENDING_GATE_TINTS.get(ending, Color(0.82, 0.90, 1.0, 0.90))
        var sprite := Sprite2D.new()
        sprite.name = "EndingGateSprite"
        sprite.texture = load(level.SPRITES["boss_gate"])
        sprite.scale = Vector2(0.66, 0.66)
        sprite.modulate = tint
        sprite.z_index = 7
        area.add_child(sprite)

        var glow := Line2D.new()
        glow.name = "EndingGateGlow"
        glow.width = 3.0
        glow.closed = true
        glow.default_color = Color(tint.r, tint.g, tint.b, 0.66)
        glow.points = PackedVector2Array([
            Vector2(-36, -52), Vector2(36, -52), Vector2(46, 0), Vector2(30, 54), Vector2(-30, 54), Vector2(-46, 0)
        ])
        glow.z_index = 8
        area.add_child(glow)

        var tween: Tween = level._region_tween()
        tween.set_loops()
        tween.tween_property(glow, "scale", Vector2(1.12, 1.12), 0.8)
        tween.parallel().tween_property(glow, "modulate:a", 0.42, 0.8)
        tween.tween_property(glow, "scale", Vector2(0.96, 0.96), 0.8)
        tween.parallel().tween_property(glow, "modulate:a", 1.0, 0.8)

        level._add_wayfinding(area)
        area.body_entered.connect(level._on_interactable_entered.bind(area))
        area.body_exited.connect(level._on_interactable_exited.bind(area))
        level.add_child(area)
    level._toast("守门者陨落 · 结局之门显现")


static func ending_gate_missing_requirements(level: Node, requires_value: Variant) -> Array[String]:
    var missing: Array[String] = []
    if typeof(requires_value) != TYPE_DICTIONARY:
        return missing
    var requires: Dictionary = requires_value
    for item_value in requires.get("items", []):
        var item_id := String(item_value)
        if not item_id.is_empty() and int(level.inventory_counts.get(item_id, 0)) <= 0:
            missing.append(level._item_display_name(item_id))
    for flag_value in requires.get("flags", []):
        var flag := String(flag_value)
        if not flag.is_empty() and not bool(level.story_flags.get(flag, false)):
            missing.append(flag)
    return missing


static func activate_ending_gate(level: Node, area: Area2D) -> void:
    if not level._can_interact_with_world() or area == null or not is_instance_valid(area):
        return
    var ending := String(area.get_meta("ending", ""))
    var chosen := String(level.story_flags.get("ending_chosen", ""))
    if level.world_mode and level.world_narrative != null:
        chosen = String(level.world_narrative.restored_ending_flags(level.story_flags).get("ending_chosen", ""))
    if not chosen.is_empty():
        if chosen == ending:
            if level.win_label != null:
                var saved_message := String(area.get_meta("message", ""))
                if level.world_mode and level.world_narrative != null:
                    saved_message = String(level.world_narrative.evaluate_ending(chosen, level.inventory_counts, level.story_flags).get("message", saved_message))
                level.win_label.text = saved_message
                level.win_label.visible = true
            level._toast("结局已选定：" + String(area.get_meta("label", ending)))
        else:
            var chosen_title := chosen
            if level.world_mode and level.world_narrative != null:
                chosen_title = String(level.world_narrative.evaluate_ending(chosen, level.inventory_counts, level.story_flags).get("title", chosen))
            level._toast("结局已定（%s），此门不再回应。" % chosen_title)
        return
    var evaluated: Dictionary = {}
    var missing: Array[String] = []
    var gate_available := false
    if level.world_mode and level.world_narrative != null:
        evaluated = level.world_narrative.evaluate_ending(ending, level.inventory_counts, level.story_flags)
        gate_available = bool(evaluated.get("available", false))
        for requirement in evaluated.get("known_missing", []):
            missing.append(String(requirement.get("label", requirement.get("id", ""))))
        var hidden_missing_count := int(evaluated.get("hidden_missing_count", 0))
        if hidden_missing_count > 0:
            missing.append("尚有%d条未发现证言" % hidden_missing_count)
        if not gate_available and missing.is_empty():
            missing.append("仍有未完成要求")
    else:
        missing = ending_gate_missing_requirements(level, area.get_meta("requires", {}))
        gate_available = missing.is_empty()
    if not gate_available:
        var reject := String(area.get_meta("reject_message", ""))
        if reject.is_empty():
            reject = "此门未应：缺少 " + "、".join(missing)
        # 门拒绝=取消音（音频规格 §4.5 ui_menu_cancel，Kenney Interface）。
        level._play_sfx("ui_menu_cancel", -4.0)
        level._toast(reject)
        return
    var flags_before: Dictionary = level.story_flags.duplicate(true)
    var currency_before: int = level.currency_count
    var world_before: Dictionary = level.world_state.data.duplicate(true) if level.world_state != null else {}
    var build_before: Dictionary = level.build_system.serialize() if level.build_system != null else {}
    if not evaluated.is_empty():
        for flag in evaluated.get("grant_flags", []):
            level.story_flags[String(flag)] = true
        level.story_flags["ending_consequences"] = evaluated.get("consequences", {}).duplicate(true)
    level.story_flags["ending_chosen"] = ending
    level.story_flags[ending + "_done"] = true
    if level.world_mode and level.world_narrative != null:
        level.story_flags = level.world_narrative.restored_ending_flags(level.story_flags)
    level._check_wish_board_rewards(false)
    if not level._save_world():
        level._rollback_narrative_transaction(flags_before, currency_before, world_before, build_before)
        level._toast("归途记录未能写入；结局尚未选定，请重试。")
        return
    if not evaluated.is_empty():
        area.set_meta("message", String(evaluated.get("message", area.get_meta("message", ""))))
    level._spawn_ending_aftermath()
    for child in level.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "npc":
            level._apply_world_npc_state(child)
    level._refresh_wish_board_overlay()
    level._play_sfx("interact", -6.0)
    # 结局确认音 + 终止式 stinger（音频规格 §3.8）：stinger 挂 root 防演出切场截断。
    level._play_sfx("ui_menu_confirm", 0.0)
    level._play_sfx_persistent(String(level.ENDING_STINGER_SFX.get(ending, "ending_a_stinger")), -5.0)
    # 三结局全曲（规格 §3.8）：短 stinger 之后紧跟整曲（MusicStinger 总线）。
    if level.audio_director != null:
        level.audio_director.play_stinger(ending)
    if level.win_label != null:
        level.win_label.text = String(area.get_meta("message", "结局：" + ending))
        level.win_label.visible = true
    level._toast("结局达成：" + String(area.get_meta("label", ending)))
    level._refresh_hud()
