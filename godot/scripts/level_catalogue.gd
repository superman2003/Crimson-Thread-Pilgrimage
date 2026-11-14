extends RefCounted
## Theme, item, NPC, chapter and shortcut lookups, and adding items and currency to the inventory.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const WORLD_STATE_SCRIPT := preload("res://scripts/world_state.gd")

static func art_theme_id(level: Node) -> String:
    var theme_id := String(level.config.get("art_theme", ""))
    if not theme_id.is_empty():
        if theme_id == "moss_bell":
            return "moss_cavern"
        return theme_id
    var config_id := String(level.config.get("id", ""))
    if config_id.contains("rain_foundry") or config_id.contains("ch02"):
        return "rain_foundry"
    if config_id.contains("saltwhite") or config_id.contains("ch03"):
        return "salt_archive"
    if config_id.contains("broken_string") or config_id.contains("ch04"):
        return "string_greenhouse"
    if config_id.contains("obsidian") or config_id.contains("ch05"):
        return "obsidian_pilgrim"
    if config_id.contains("silent_crown") or config_id.contains("ch06"):
        return "silent_crown"
    return "moss_cavern"


static func shrine_rest_audio_key(level: Node) -> String:
    var theme: String = level._art_theme_id()
    if theme == "rain_foundry":
        return "shrine_rest_ch02"
    if theme == "salt_archive":
        return "shrine_rest_ch03"
    if theme == "string_greenhouse":
        return "shrine_rest_ch04"
    if theme == "obsidian_pilgrim":
        return "shrine_rest_ch05"
    if theme == "silent_crown":
        return "shrine_rest_ch06"
    return "shrine_rest_ch01"


static func enemy_death_sfx_key(level: Node) -> String:
    var theme: String = level._art_theme_id()
    if theme == "rain_foundry":
        return "death_copper"
    if theme == "salt_archive":
        return "death_salt"
    if theme == "string_greenhouse":
        return "death_fiber"
    if theme == "obsidian_pilgrim":
        return "death_obsidian"
    if theme == "silent_crown":
        return "death_silent"
    return "death_moss"


static func original_map_art(level: Node) -> Dictionary:
    var root = "res://assets/sprites/flat_maps/" + level._art_theme_id() + "/"
    return {"map":root+"background.png","sky":root+"background.png","mid_tile":root+"platform_00.tres"}


static func is_rain_foundry_theme(level: Node) -> bool:
    return level._art_theme_id() == "rain_foundry"


static func theme_map_title(level: Node) -> String:
    var title := String(level.config.get("map_title", ""))
    if not title.is_empty():
        return title
    var theme: String = level._art_theme_id()
    if theme == "rain_foundry":
        return "Rain Foundry Canal Map"
    if theme == "salt_archive":
        return "Saltwhite Archive Map"
    if theme == "string_greenhouse":
        return "Broken String Greenhouse Map"
    if theme == "obsidian_pilgrim":
        return "Obsidian Pilgrim Road Map"
    if theme == "silent_crown":
        return "Silent Crown Core Map"
    return "Moss Bell Court Map"


static func theme_map_background_texture(level: Node) -> String:
    return String(level._original_map_art().get("map", ""))


static func theme_asset_source(level: Node) -> String:
    return "Original hand-drawn 2D PNG atlases / built-in image_gen"


static func background_visual_asset_paths(level: Node) -> Array:
    var root = "res://assets/sprites/flat_maps/"+level._art_theme_id()+"/"
    return [root+"background.png",root+"decor_atlas.png"]


static func theme_boss_material(level: Node) -> String:
    var theme: String = level._art_theme_id()
    if theme == "rain_foundry":
        return "foundry_boss"
    if theme == "salt_archive":
        return "archive_boss"
    if theme == "string_greenhouse":
        return "root_boss"
    if theme == "obsidian_pilgrim":
        return "pilgrim_boss"
    if theme == "silent_crown":
        return "core_boss"
    return "boss_stone"


static func platform_visual_asset_paths_for_material(level: Node, _material: String) -> Array:
    var root = "res://assets/sprites/flat_maps/"+level._art_theme_id()+"/"
    return [root+"platform_atlas.png",root+"terrain_atlas.png"]


static func combat_progression_enabled(level: Node) -> bool:
    return String(level.config.get("progression_mode", "keys")).to_lower() == "combat_clear"


static func combat_goal_met(level: Node) -> bool:
    return level.enemy_total <= 0 or level.enemy_defeated >= level.enemy_total


static func shortcut_ids(level: Node) -> Array:
    var ids: Array = []
    for connection in level.config.get("connections", []):
        if not (connection is Dictionary):
            continue
        if String(connection.get("type", "")) != "shortcut":
            continue
        var shortcut_id := String(connection.get("shortcut_id", ""))
        if shortcut_id.is_empty() or ids.has(shortcut_id):
            continue
        ids.append(shortcut_id)
    return ids


static func shortcut_total(level: Node) -> int:
    return level._shortcut_ids().size()


static func opened_shortcut_total(level: Node) -> int:
    return level.opened_shortcuts.size()


static func shortcut_id_for_area(level: Node, area: Area2D) -> String:
    if area == null:
        return ""
    return String(area.get_meta("shortcut_id", ""))


static func is_shortcut_open(level: Node, shortcut_id: String = "") -> bool:
    if shortcut_id.is_empty():
        return level.shortcut_open
    return level.opened_shortcuts.has(shortcut_id)


static func init_inventory_state(level: Node) -> void:
    level.inventory_counts.clear()
    level.inventory_tools.clear()
    level.inventory_relics.clear()
    level.inventory_materials.clear()
    level.currency_count = 0
    level.unlocked_abilities.clear()
    level.opened_shortcuts.clear()
    level.shortcut_open = false
    level.visited_rooms.clear()
    level.current_room_id = ""
    var inventory_config: Dictionary = level.config.get("inventory", {})
    for item_id in inventory_config.get("starting_tools", []):
        if level.world_mode and level.WORLD_ABILITIES.has(String(item_id)):
            continue
        level._add_inventory_item(String(item_id), 1, false)
    for item_id in inventory_config.get("starting_relics", []):
        level._add_inventory_item(String(item_id), 1, false)
    if level.carried_inventory_enabled:
        level._merge_carried_inventory()


static func merge_carried_inventory(level: Node) -> void:
    for item_id_value in level.carried_inventory_counts.keys():
        var item_id := String(item_id_value)
        if item_id.is_empty():
            continue
        var missing := int(level.carried_inventory_counts[item_id_value]) - int(level.inventory_counts.get(item_id, 0))
        if missing > 0:
            level._add_inventory_item(item_id, missing, false)
    if level.carried_currency > 0:
        level._add_currency(level.carried_currency)


static func item_data(level: Node, item_id: String) -> Dictionary:
    var inventory_config: Dictionary = level.config.get("inventory", {})
    var catalog: Dictionary = inventory_config.get("catalog", {})
    if level.world_mode and not catalog.has(item_id) and level.world_catalog.has(item_id):
        return level.world_catalog[item_id]
    return catalog.get(item_id, {"name": item_id, "category": "Materials", "description": ""})


static func item_display_name(level: Node, item_id: String) -> String:
    var lore_entry: Dictionary = level.item_lore.get(item_id, {})
    if lore_entry.has("display_name"):
        return String(lore_entry.get("display_name", item_id))
    var catalog: Dictionary = level.config.get("inventory", {}).get("catalog", {})
    if catalog.has(item_id):
        var entry: Dictionary = catalog.get(item_id, {})
        if entry.has("name"):
            return String(entry.get("name", item_id.capitalize()))
    # 跨章携带兜底：本章 catalog 没有该物品时退回圣典名，最后才退回旧表/原始 id。
    if level.world_mode and level.world_catalog.has(item_id):
        return String(level.world_catalog[item_id].get("name", item_id))
    if lore_entry.has("canon_name"):
        return String(lore_entry.get("canon_name", item_id))
    var display: Dictionary = level.ITEM_DISPLAY.get(item_id, {})
    return String(display.get("name", item_id.capitalize()))


static func item_display_description(level: Node, item_id: String) -> String:
    var lore_entry: Dictionary = level.item_lore.get(item_id, {})
    var parts: Array[String] = []
    for lore_line in lore_entry.get("lore", []):
        parts.append(String(lore_line))
    if not parts.is_empty():
        var function_line := String(lore_entry.get("function", ""))
        if not function_line.is_empty():
            parts.append(preload("res://scripts/authored_control_hints.gd").render(function_line))
        return "\n".join(parts)
    var item: Dictionary = level._item_data(item_id)
    if item.has("description"):
        return preload("res://scripts/authored_control_hints.gd").render(String(item.get("description", "")))
    var display: Dictionary = level.ITEM_DISPLAY.get(item_id, {})
    return preload("res://scripts/authored_control_hints.gd").render(String(display.get("description", "")))


static func room_map_copy(level: Node, room_id: String, field: String, fallback: String) -> String:
    for room in level.config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if String(room_data.get("id", "")) == room_id and room_data.has(field):
            return preload("res://scripts/authored_control_hints.gd").render(String(room_data.get(field, fallback)))
    var copy: Dictionary = level.ROOM_MAP_COPY.get(room_id, {})
    return preload("res://scripts/authored_control_hints.gd").render(String(copy.get(field, fallback)))


static func npc_display_name(level: Node, data: Dictionary) -> String:
    if data.has("name"):
        return String(data.get("name", "旅人"))
    var role := String(data.get("role", ""))
    return String(level.NPC_DISPLAY_NAMES.get(role, "旅人"))


static func npc_dialogue(level: Node, data: Dictionary) -> Array:
    var config_dialogue: Array = data.get("dialogue", [])
    if not config_dialogue.is_empty():
        return config_dialogue
    var role := String(data.get("role", ""))
    return level.NPC_DIALOGUE.get(role, ["..."])


static func campaign_chapter_for_id(level: Node, chapter_id: String) -> Dictionary:
    for chapter in level.campaign.get("chapters", []):
        var item := chapter as Dictionary
        if String(item.get("id", "")) == chapter_id or String(item.get("runtime_config_id", "")) == chapter_id:
            return item
    var chapters: Array = level.campaign.get("chapters", [])
    return chapters[0] if not chapters.is_empty() else {}


static func chapter_objective_text(level: Node) -> String:
    if level.world_mode:
        return level._world_exploration_hint() + "  %s 地图 / %s 世界图 · F9 新旅途。" % [level.ui_shell._short_binding("map"), level.ui_shell._short_binding("inventory")]
    if bool(level.config.get("boss_route_via_exploration",false)):
        return "第%d章 %s：探索洞道，接通捷径，挑战守门者。%s 呼叫升降笼。" % [int(level.current_campaign_chapter.get("index",1)),String(level.config.get("chapter_name",level.config.get("name",""))),preload("res://scripts/input_prompt_bindings.gd").action_label("interact")]
    if level.current_campaign_chapter.is_empty():
        return "Defeat normal enemies, open the boss route, and clear the chapter boss."
    return "第%d章 %s：%s" % [
        int(level.current_campaign_chapter.get("index", 1)),
        String(level.current_campaign_chapter.get("name", "苔钟庭")),
        String(level.current_campaign_chapter.get("objective", "Defeat normal enemies, open the boss route, and clear the chapter boss."))
    ]


static func next_campaign_chapter_name(level: Node) -> String:
    var current_index := int(level.current_campaign_chapter.get("index", 1))
    for chapter in level.campaign.get("chapters", []):
        var item := chapter as Dictionary
        if int(item.get("index", 0)) == current_index + 1:
            return String(item.get("name", ""))
    return "二周目挑战"


static func show_chapter_entry_message(level: Node) -> void:
    var message = level.transition_entry_message
    if message.is_empty() and not level.entered_from_config_id.is_empty():
        message = "进入" + String(level.config.get("name", "下一章"))
    if message.is_empty():
        level._toast(level._chapter_objective_text())
        return
    # Arrival is a short notification. The persistent label belongs to
    # completion/ending events; using it here left a banner over exploration.
    if level.world_mode and message.begins_with("旧路重新接通"):
        message = String(level.current_campaign_chapter.get("name", message))
    level._toast(message)


static func boss_display_name(level: Node, boss_data: Dictionary) -> String:
    if boss_data.has("name"):
        return String(boss_data.get("name", "守门者"))
    var chapter_boss: Dictionary = level.current_campaign_chapter.get("boss", {})
    return String(chapter_boss.get("name", "守门者"))


static func chapter_file_ids(level: Node) -> Array:
    var ids: Array = []
    for chapter in level.chapter_file_configs:
        var item := chapter as Dictionary
        ids.append(String(item.get("id", "")))
    return ids


static func prepare_inventory_progress(level: Node, items: Dictionary, next_flags: Dictionary, next_currency: int) -> Dictionary:
    var failure: Dictionary={"ok":false,"reason":"奖励记录未写入，请重试。"}
    if level.build_system==null or not WORLD_STATE_SCRIPT._whole(next_currency):return failure
    var counts = level.inventory_counts.duplicate(true)
    for id in counts:
        if not id is String or not WORLD_STATE_SCRIPT._whole(counts[id]):return failure
    for id in items:
        if not id is String or id.is_empty() or not WORLD_STATE_SCRIPT._whole(items[id]) or int(items[id])<=0:return failure
        counts[id]=int(counts.get(id,0))+int(items[id])
    var flags:=next_flags.duplicate(true)
    var all_testimonies:=true
    for index in range(1,7):
        if int(counts.get("testimony_%02d" % index,0))<1:all_testimonies=false
    if all_testimonies:flags["true_ending_testimony_complete"]=true
    if level.world_narrative!=null:
        for flag in level.world_narrative.evaluate_progress(counts,flags).get("grant_flags",[]):flags[String(flag)]=true
    var next_build=level.build_system.get_script().new()
    if not next_build.restore(level.build_system.serialize()).ok:return failure
    next_build.catalog=level.build_system.catalog.duplicate(true)
    next_build.sync_progress(counts,String(level.config.get("id","")),flags)
    return {"ok":true,"counts":counts,"flags":flags,"currency":next_currency,"build":next_build.serialize()}


static func publish_inventory_progress(level: Node, plan: Dictionary, candidate: Dictionary) -> void:
    level.world_state.data=candidate
    level.inventory_counts=plan.counts;level.story_flags=plan.flags;level.currency_count=int(plan.currency)
    level.inventory_materials.clear();level.inventory_tools.clear();level.inventory_relics.clear()
    for item in level.inventory_counts:
        match String(level._item_data(String(item)).get("category","Materials")):
            "Materials":level.inventory_materials[item]=int(level.inventory_counts[item])
            "Tools":level.inventory_tools.append(item)
            "Relics":level.inventory_relics.append(item)
    level.build_system.restore(plan.build)
    level._sync_player_build()


static func add_inventory_item(level: Node, item_id: String, amount: int = 1, announce: bool = true) -> void:
    var data: Dictionary = level._item_data(item_id)
    var category := String(data.get("category", "Materials"))
    level.inventory_counts[item_id] = int(level.inventory_counts.get(item_id, 0)) + amount
    if category == "Tools" and not level.inventory_tools.has(item_id):
        level.inventory_tools.append(item_id)
    elif category == "Relics" and not level.inventory_relics.has(item_id):
        level.inventory_relics.append(item_id)
    elif category == "Materials":
        level.inventory_materials[item_id] = int(level.inventory_materials.get(item_id, 0)) + amount
    if item_id.begins_with("testimony_"):
        level._refresh_testimony_chain_flag()
    if level.world_mode and level.world_narrative != null:
        var progress: Dictionary = level.world_narrative.evaluate_progress(level.inventory_counts, level.story_flags)
        for flag in progress.get("grant_flags", []):
            level.story_flags[String(flag)] = true
    if level.build_system != null and level.build_system.catalog.get("permanent_upgrades", {}).has(item_id):
        level._sync_player_build()
    if announce:
        level._toast("收入行囊 · " + level._item_display_name(item_id))
    if level.active_overlay == "backpack":
        level._refresh_backpack_overlay()


static func add_currency(level: Node, amount: int) -> void:
    level.currency_count += amount
    if level.active_overlay == "backpack":
        level._refresh_backpack_overlay()
