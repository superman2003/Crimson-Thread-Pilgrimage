extends RefCounted
## Backpack and settings pages, and the shared overlay bookkeeping (close all, input lock, dialogue-closed notice).
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func build_backpack_overlay(level: Node) -> void:
    level.backpack_panel=level.ui_shell.bag
    level.backpack_text=level.ui_shell.legacy_bag_text
    level.backpack_detail_text=level.ui_shell.legacy_bag_detail
    level._refresh_backpack_overlay(false)


static func toggle_backpack(level: Node) -> void:
    if level.active_overlay in ["cartographer", "recall"]: level._close_overlays()
    if level.ui_shell != null and is_instance_valid(level.ui_shell.get("build_panel")):
        level.ui_shell.build_panel.visible = false
    if level.active_overlay == "backpack":
        level._close_overlays()
        return
    level._play_sfx("ui_inventory_open", -2.0)
    level._notify_dialogue_closed()
    level.active_overlay = "backpack"
    if level.map_panel != null:
        level.map_panel.visible = false
    if level.dialogue_panel != null:
        level.dialogue_panel.visible = false
    if level.settings_panel != null:
        level.settings_panel.visible = false
    if level.backpack_panel != null:
        level.backpack_panel.visible = true
    level._sync_ui_input_lock()
    level._refresh_backpack_overlay()


static func build_settings_overlay(level: Node) -> void:
    level.settings_panel=level.ui_shell.settings
    level.settings_text=level.ui_shell.legacy_settings
    level._refresh_settings_overlay()


static func toggle_audio_settings(level: Node) -> void:
    if level.active_overlay in ["cartographer", "recall"]: level._close_overlays()
    if level.ui_shell != null and is_instance_valid(level.ui_shell.get("build_panel")):
        level.ui_shell.build_panel.visible = false
    if level.active_overlay == "settings":
        level._close_overlays()
        return
    level._play_sfx("ui_menu_confirm", -2.0)
    level._notify_dialogue_closed()
    level.active_overlay = "settings"
    if level.backpack_panel != null:
        level.backpack_panel.visible = false
    if level.map_panel != null:
        level.map_panel.visible = false
    if level.dialogue_panel != null:
        level.dialogue_panel.visible = false
    if level.settings_panel != null:
        level.settings_panel.visible = true
    level._sync_ui_input_lock()
    level._refresh_settings_overlay()


static func settings_selection_clamped(level: Node) -> int:
    return clampi(level.settings_selection, 0, level.AUDIO_SETTINGS_ROWS.size() - 1)


static func move_settings_selection(level: Node, delta: int) -> void:
    level._play_sfx_random(["ui_menu_move_1", "ui_menu_move_2"], -5.0)
    level.settings_selection = wrapi(level._settings_selection_clamped() + delta, 0, level.AUDIO_SETTINGS_ROWS.size())
    level._refresh_settings_overlay()


static func adjust_settings_volume(level: Node, delta: float) -> void:
    if level.audio_director == null:
        return
    var which := String(level.AUDIO_SETTINGS_ROWS[level._settings_selection_clamped()][0])
    var value: float = clampf(float(level.audio_director.get_user_volume(which)) + delta, 0.0, 100.0)
    level.audio_director.set_user_volume(which, value)
    if which == "sfx":
        # SFX 行试听反馈改播世界音（走 SFXWorld→SFX 总线）：调的就是它，所听即所调。
        level._play_sfx("pickup")
    else:
        level._play_sfx_random(["ui_menu_move_1", "ui_menu_move_2"], -5.0)
    level._refresh_settings_overlay()


static func refresh_settings_overlay(level: Node) -> void:
    if level.settings_text == null:
        return
    var lines: Array[String] = []
    for index in level.AUDIO_SETTINGS_ROWS.size():
        var row: Array = level.AUDIO_SETTINGS_ROWS[index]
        var percent := 100.0
        if level.audio_director != null:
            percent = float(level.audio_director.get_user_volume(String(row[0])))
        var filled := clampi(int(round(percent / 10.0)), 0, 10)
        var bar := "█".repeat(filled) + "░".repeat(10 - filled)
        var marker = "▶ " if index == level._settings_selection_clamped() else "  "
        lines.append("%s%s  [%s] %d%%" % [marker, String(row[1]), bar, int(round(percent))])
    lines.append("")
    lines.append("W/S 选择   A/D 调节   V/Esc 关闭")
    level.settings_text.text = "\n".join(lines)
    if level.ui_shell != null:
        level.ui_shell.refresh_settings_selection()


static func close_overlays(level: Node) -> void:
    if level.ui_shell != null and is_instance_valid(level.ui_shell.get("build_panel")):
        level.ui_shell.build_panel.visible = false
    # UI 关闭音（音频规格 §4.5）：按正在关的 overlay 选音，空关不发声。
    if level.active_overlay == "backpack":
        level._play_sfx("ui_inventory_close", -3.0)
    elif level.active_overlay == "map":
        level._play_sfx("ui_map_close", -3.0)
    elif level.active_overlay == "dialogue":
        level._play_sfx("ui_dialogue_close", -4.0)
    elif level.active_overlay == "settings":
        level._play_sfx("ui_menu_cancel", -4.0)
    var map_purchase = level.get_node_or_null("MapPurchaseDialog")
    if map_purchase != null:
        map_purchase.hide()
    var recall_dialog = level.get_node_or_null(level.DEATH_RECALL.DIALOG)
    if recall_dialog != null:
        recall_dialog.hide()
    var ending_story = level.get_node_or_null("EndingStoryDesk")
    if ending_story != null:
        ending_story.hide()
    level._notify_dialogue_closed()
    level.active_overlay = ""
    if level.backpack_panel != null:
        level.backpack_panel.visible = false
    if level.map_panel != null:
        level.map_panel.visible = false
    if level.dialogue_panel != null:
        level.dialogue_panel.visible = false
    if level.settings_panel != null:
        level.settings_panel.visible = false
    level._sync_ui_input_lock()


static func sync_ui_input_lock(level: Node) -> void:
    if level.player != null and is_instance_valid(level.player):
        level.player.set("ui_input_locked", level.active_overlay != "")
    if level.is_inside_tree():
        for actor in level.get_tree().get_nodes_in_group("enemy"):
            if actor.has_method("_set_combat_visuals_paused"):
                actor._set_combat_visuals_paused(level.active_overlay != "")


static func notify_dialogue_closed(level: Node) -> void:
    var history = level.ui_shell!=null and is_instance_valid(level.ui_shell.dialogue_area) and String(level.ui_shell.dialogue_area.get_meta("kind",""))=="history"
    if not history:level._commit_world_dialogue()
    if level.ui_shell!=null:
        level.ui_shell.close_dialogue()
    if level.active_overlay == "dialogue" and level.audio_director != null:
        level.audio_director.on_dialogue(false)


static func refresh_backpack_overlay(level: Node, render_inventory: bool = true) -> void:
    if level.backpack_text == null:
        return
    level.backpack_entry_ids.clear()
    var lines: Array[String] = []
    level.backpack_entry_ids.append("currency")
    lines.append("%s%s x%d" % [level._selection_marker("currency"), level._item_display_name("currency"), level.currency_count])
    if not level._combat_progression_enabled():
        lines.append("")
        lines.append("Route Marks")
        lines.append(level._inventory_line_for_category("Combat"))
    for section in level.BACKPACK_SECTIONS:
        var section_ids: Array[String] = level._inventory_ids_for_category(String(section[1]))
        if section_ids.is_empty():
            continue
        lines.append("")
        lines.append(String(section[0]))
        for item_id in section_ids:
            level.backpack_entry_ids.append(item_id)
            var count := int(level.inventory_counts.get(item_id, 0))
            var count_suffix := " x%d" % count if count > 1 else ""
            lines.append("%s%s%s" % [level._selection_marker(item_id), level._item_display_name(item_id), count_suffix])
    lines.append("")
    lines.append("%s 行囊   %s/%s 查看铭文   %s 地图   %s 关闭" % [level.ui_shell._short_binding("inventory"), level.ui_shell._short_binding("aim_up"), level.ui_shell._short_binding("aim_down"), level.ui_shell._short_binding("map"), level.ui_shell._short_binding("close_overlay")])
    level.backpack_text.text = "\n".join(lines)
    level._refresh_backpack_detail()
    if render_inventory and level.ui_shell!=null:
        level.ui_shell.refresh_inventory()


static func inventory_ids_for_category(level: Node, category: String) -> Array[String]:
    var ids: Array[String] = []
    for item_id in level.inventory_counts.keys():
        var data: Dictionary = level._item_data(String(item_id))
        if String(data.get("category", "")) == category:
            ids.append(String(item_id))
    return ids


static func selection_marker(level: Node, item_id: String) -> String:
    var index = level.backpack_entry_ids.find(item_id)
    return "▶ " if index == level._backpack_selection_clamped() else "  "


static func backpack_selection_clamped(level: Node) -> int:
    if level.backpack_entry_ids.is_empty():
        return -1
    return clampi(level.backpack_selection, 0, level.backpack_entry_ids.size() - 1)


static func move_backpack_selection(level: Node, delta: int) -> void:
    if level.backpack_entry_ids.is_empty():
        return
    level._play_sfx_random(["ui_menu_move_1", "ui_menu_move_2"], -5.0)
    if level.ui_shell != null:
        level.ui_shell.move_inventory_selection(delta)
    else:
        level.backpack_selection = wrapi(level._backpack_selection_clamped() + delta, 0, level.backpack_entry_ids.size())
    level._refresh_backpack_overlay()


static func refresh_backpack_detail(level: Node) -> void:
    if level.backpack_detail_text == null:
        return
    var index: int = level._backpack_selection_clamped()
    if index < 0:
        level.backpack_detail_text.text = ""
        return
    var item_id = level.backpack_entry_ids[index]
    var lines: Array[String] = []
    if item_id == "currency":
        lines.append("%s x%d" % [level._item_display_name("currency"), level.currency_count])
    else:
        var count := int(level.inventory_counts.get(item_id, 0))
        lines.append(level._item_display_name(item_id) + (" x%d" % count if count > 1 else ""))
    var description: String = level._item_display_description(item_id)
    if not description.is_empty():
        lines.append("")
        for description_line in description.split("\n"):
            lines.append(description_line)
    level.backpack_detail_text.text = "\n".join(lines)


static func inventory_line_for_category(level: Node, category: String) -> String:
    var entries: Array[String] = []
    for item_id in level.inventory_counts.keys():
        var data: Dictionary = level._item_data(String(item_id))
        if String(data.get("category", "")) == category:
            entries.append("%s x%d" % [level._item_display_name(String(item_id)), int(level.inventory_counts[item_id])])
    return "  None" if entries.is_empty() else "  " + ", ".join(entries)
