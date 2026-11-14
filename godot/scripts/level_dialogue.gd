extends RefCounted
## Talking to NPCs: resolving lines, story flags, testimony chains, whispers and showing the dialogue.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func talk_to_npc(level: Node, area: Area2D) -> void:
    var lines: Array = level._resolve_npc_lines(area)
    if lines.is_empty():
        level._show_dialogue(area, "...")
        return
    var state := String(area.get_meta("dialogue_state", "repeat"))
    var state_indices: Dictionary = area.get_meta("dialogue_state_indices", {})
    var index := int(state_indices.get(state, 0))
    level._play_sfx("interact", -10.0)
    level._show_dialogue(area, String(lines[index % lines.size()]))
    area.set_meta("world_displayed_index", index % lines.size())
    area.set_meta("world_line_committed", false)
    area.set_meta("world_displayed_total", lines.size())
    if not level.world_mode:
        state_indices[state] = index + 1
        area.set_meta("dialogue_state_indices", state_indices)
    area.set_meta("dialogue_index", int(area.get_meta("dialogue_index", 0)) + 1)
    # first_meet flips npc_met_<id> only after the full round has been heard
    # (doc 2.1: 播完整轮后置位).
    if not level.world_mode and state == "first_meet" and index + 1 >= lines.size():
        level._set_story_flag("npc_met_%s" % String(area.get_meta("npc_id", area.name)))


static func chapter_story_id(level: Node) -> String:
    for part in String(level.config.get("id", "")).split("_"):
        var token := String(part)
        if token.length() >= 3 and token.begins_with("ch") and token.substr(2).is_valid_int():
            return token
    return String(level.config.get("id", ""))


static func set_story_flag(level: Node, flag: String) -> void:
    if flag.is_empty():
        return
    level.story_flags[flag] = true
    level._check_wish_board_rewards()
    level._save_world()


static func refresh_testimony_chain_flag(level: Node) -> void:
    if bool(level.story_flags.get("true_ending_testimony_complete", false)):
        return
    for index in range(1, 7):
        if not level.inventory_counts.has("testimony_%02d" % index):
            return
    # 证词链集齐达成音（音频规格 §4.5 ui_testimony_complete）：置 flag 前一次性播。
    level._play_sfx("ui_testimony_complete", -4.0)
    level._set_story_flag("true_ending_testimony_complete")


static func trigger_whispers(level: Node, trigger: String, key: String) -> void:
    if key.is_empty():
        return
    for whisper in level.config.get("whispers", []):
        if not (whisper is Dictionary):
            continue
        var data: Dictionary = whisper
        if String(data.get("trigger", "enter_room")) != trigger:
            continue
        if String(data.get("room_id", data.get("item_id", ""))) != key:
            continue
        var whisper_id := String(data.get("id", ""))
        if whisper_id.is_empty() or bool(level.story_flags.get("whisper_%s" % whisper_id, false)):
            continue
        level._set_story_flag("whisper_%s" % whisper_id)
        level._toast(String(data.get("line", "")))


static func show_dialogue(level: Node, area: Area2D, line: String) -> void:
    var voice_requested := false
    if level.ui_shell != null and is_instance_valid(level.ui_shell.get("build_panel")):
        level.ui_shell.build_panel.visible = false
    # 对话混音态（规格 §5.3）：Music -4dB / Ambience -6dB，关闭时归还。
    if level.active_overlay != "dialogue" and level.audio_director != null:
        level.audio_director.on_dialogue(true)
    level.active_overlay = "dialogue"
    if level.backpack_panel != null:
        level.backpack_panel.visible = false
    if level.map_panel != null:
        level.map_panel.visible = false
    if level.settings_panel != null:
        level.settings_panel.visible = false
    if level.dialogue_panel != null:
        level.dialogue_panel.visible = true
    if level.dialogue_name_label != null:
        level.dialogue_name_label.text = String(area.get_meta("label", area.name))
    if level.dialogue_meta_label != null:
        level.dialogue_meta_label.text = String(area.get_meta("identity", ""))
    if level.dialogue_text_label != null:
        level.dialogue_text_label.text = line
        if level.world_mode:
            level.subtitle_seconds = level.WORLD_NARRATIVE_SCRIPT.subtitle_duration(line) / (float(level.ui_shell.get_accessibility("subtitle_speed")) if level.ui_shell != null and level.ui_shell.has_method("get_accessibility") else 1.0)
            var reading: Dictionary = level.ui_shell.dialogue_reading_state(area, line) if level.ui_shell != null and level.ui_shell.has_method("dialogue_reading_state") else {}
            level.subtitle_elapsed = level.subtitle_seconds * float(reading.get("progress", 0.0))
            level.dialogue_text_label.visible_characters = int(reading.get("characters", 0))
            voice_requested = reading.is_empty()
        else:
            level.dialogue_text_label.visible_characters = -1
            voice_requested = true
    if level.dialogue_hint_label != null:
        level.dialogue_hint_label.text = String(area.get_meta("help", ""))
    if level.ui_shell!=null:
        level.ui_shell.show_speaker(area)
    if level.audio_director != null:
        if String(area.get_meta("kind", "")) == "npc":
            var profile := String(area.get_meta("world_dialogue_result", {}).get("voice_profile", "warm"))
            level.audio_director.play_npc_voice(String(area.get_meta("npc_id", area.name)), line, profile,
                area.get_node_or_null("FriendlyFamilySprite"), voice_requested)
        else:
            level.audio_director.stop_npc_voice()
    level._sync_ui_input_lock()
