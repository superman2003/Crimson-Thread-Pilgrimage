extends RefCounted
## NPC wishes: the wish board, what an NPC can be asked or given, and which lines they speak.
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func wish_board_entries(level: Node) -> Array:
    var entries: Array = []
    for wish in level.config.get("wish_board", []):
        if wish is Dictionary and not String((wish as Dictionary).get("id", "")).is_empty():
            entries.append(wish)
    for npc in level.config.get("npcs",[]):
        var topics: Dictionary=npc.get("dialogue_topics",{})
        var quest: Dictionary=topics.get("quest",{})
        if not quest.is_empty():
            entries.append({"id":"npc_"+String(npc.id),"title":level._npc_display_name(npc)+"的心愿","desc":topics.get("wish",""),"kind":"心愿","target_flag":quest.get("complete_flag",""),"reward_currency":0})
    return entries


static func build_wish_board_overlay(level: Node) -> void:
    if level.map_panel == null or level._wish_board_entries().is_empty():
        return
    level.wish_panel = ColorRect.new()
    level.wish_panel.name = "WishBoardPanel"
    level.wish_panel.position = Vector2(826, 106)
    level.wish_panel.size = Vector2(316, 396)
    level.wish_panel.color = Color(0.035, 0.045, 0.05, 0.93)
    level.map_panel.add_child(level.wish_panel)

    var title := Label.new()
    title.text = "巡礼愿板"
    title.position = Vector2(16, 12)
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", level.PILGRIMAGE_UI_SCRIPT.GOLD)
    level.wish_panel.add_child(title)

    level.wish_text = Label.new()
    level.wish_text.position = Vector2(16, 48)
    level.wish_text.size = Vector2(284, 332)
    level.wish_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    level.wish_text.add_theme_font_size_override("font_size", 14)
    level.wish_text.add_theme_color_override("font_color", level.PILGRIMAGE_UI_SCRIPT.IVORY)
    level.wish_panel.add_child(level.wish_text)
    level._refresh_wish_board_overlay()


static func wish_completed(level: Node, wish: Dictionary) -> bool:
    var target_flag := String(wish.get("target_flag", ""))
    return not target_flag.is_empty() and bool(level.story_flags.get(target_flag, false))


static func wish_claim_flag(level: Node, wish: Dictionary) -> String:
    return "wish_claimed_%s" % String(wish.get("id", ""))


static func check_wish_board_rewards(level: Node, announce: bool = true) -> void:
    for wish_value in level._wish_board_entries():
        var wish: Dictionary = wish_value
        if not wish_completed(level, wish):
            continue
        var claim_flag: String = level._wish_claim_flag(wish)
        if bool(level.story_flags.get(claim_flag, false)):
            continue
        # 直接写 flag（不走 _set_story_flag）避免奖励检查递归。
        level.story_flags[claim_flag] = true
        var reward := int(wish.get("reward_currency", 0))
        if reward > 0:
            level._add_currency(reward)
        if not announce:
            continue
        if reward==0:
            level._toast("心愿达成 · "+String(wish.get("title",wish.get("id",""))))
            continue
        level._toast("愿望达成：%s（+%d %s）" % [
            String(wish.get("title", wish.get("id", ""))),
            reward,
            level._item_display_name("currency")
        ])
    if announce:
        level._refresh_wish_board_overlay()


static func refresh_wish_board_overlay(level: Node) -> void:
    if level.wish_text == null:
        return
    var lines: Array[String] = []
    for wish_value in level._wish_board_entries():
        var wish: Dictionary = wish_value
        var done := wish_completed(level, wish)
        lines.append("%s [%s] %s" % [
            "已了" if done else "未了",
            String(wish.get("kind", "wish")),
            String(wish.get("title", wish.get("id", "")))
        ])
        var desc := String(wish.get("desc", ""))
        if not desc.is_empty():
            lines.append("    " + desc)
    level.wish_text.text = "\n".join(lines)


static func resolve_npc_lines(level: Node, area: Area2D) -> Array:
    var lines:=resolve_npc_lines_source(level, area)
    if level.world_mode:
        var result:=preload("res://scripts/npc_recollections.gd").resolved_result(String(area.get_meta("npc_id",area.name)),area.get_meta("world_dialogue_result",{}),String(area.get_meta("dialogue_state","repeat")),lines,String(level.config.get("id","")))
        area.set_meta("world_recollection_result",result)
    return lines


static func resolve_npc_lines_source(level: Node, area: Area2D) -> Array:
    var fallback: Array = area.get_meta("dialogue", [])
    if level.world_mode and level.world_narrative != null:
        var result: Dictionary = level.world_narrative.resolve(String(area.get_meta("npc_id", area.name)), fallback, level.inventory_counts.keys(), level.story_flags, level.inventory_counts)
        area.set_meta("world_dialogue_result", result)
        if not result.is_empty():
            area.set_meta("dialogue_state", String(result.get("state", "world_repeat")))
            return result.get("lines", fallback)
    var story_dialogue_value: Variant = area.get_meta("story_dialogue", {})
    if typeof(story_dialogue_value) != TYPE_DICTIONARY:
        area.set_meta("dialogue_state", "repeat")
        return fallback
    var story_dialogue: Dictionary = story_dialogue_value
    if story_dialogue.is_empty():
        area.set_meta("dialogue_state", "repeat")
        return fallback
    var npc_id := String(area.get_meta("npc_id", area.name))
    var dialogue_meta_value: Variant = area.get_meta("dialogue_meta", {})
    var dialogue_meta: Dictionary = dialogue_meta_value if typeof(dialogue_meta_value) == TYPE_DICTIONARY else {}
    if not bool(level.story_flags.get("npc_met_%s" % npc_id, false)):
        area.set_meta("dialogue_state", "first_meet")
        var first_lines: Array = story_dialogue.get("first_meet", [])
        return first_lines if not first_lines.is_empty() else fallback
    for state in ["true_ending_branch", "late_game", "sidequest_done", "after_boss", "after_ability"]:
        var lines: Array = story_dialogue.get(state, [])
        if not lines.is_empty() and dialogue_state_ok(level, String(state), dialogue_meta):
            area.set_meta("dialogue_state", state)
            return lines
    area.set_meta("dialogue_state", "repeat")
    var repeat_lines: Array = story_dialogue.get("repeat", [])
    return repeat_lines if not repeat_lines.is_empty() else fallback


static func dialogue_state_ok(level: Node, state: String, dialogue_meta: Dictionary) -> bool:
    match state:
        "true_ending_branch":
            return bool(level.story_flags.get("true_ending_testimony_complete", false))
        "late_game":
            var testimony_ref := String(dialogue_meta.get("testimony_ref", ""))
            return not testimony_ref.is_empty() and level.inventory_counts.has(testimony_ref)
        "sidequest_done":
            var quest_flag := String(dialogue_meta.get("quest_flag", ""))
            return not quest_flag.is_empty() and bool(level.story_flags.get(quest_flag, false))
        "after_boss":
            return level.demo_complete or bool(level.story_flags.get("boss_down_%s" % level._chapter_story_id(), false))
        "after_ability":
            var ability_ref := String(dialogue_meta.get("ability_ref", dialogue_meta.get("ability_key", "")))
            return not ability_ref.is_empty() and level.inventory_counts.has(ability_ref)
    return false


static func wish_offering_available(level: Node, item_id: String) -> bool:
    var count: Variant = level.inventory_counts.get(item_id, 0)
    return not item_id.is_empty() and (count is int or count is float) and is_finite(float(count)) and float(count) >= 1.0 and floor(float(count)) == float(count)


static func wish_dialogue_candidate(level: Node, area: Area2D, flags: Dictionary, wallet: int) -> Dictionary:
    if not is_instance_valid(area) or level.active_overlay != "dialogue" or level.dialogue_text_label == null or bool(area.get_meta("world_line_committed", false)):
        return {"flags":flags,"currency":wallet}
    if level.dialogue_text_label.visible_characters >= 0 and level.dialogue_text_label.visible_characters < level.dialogue_text_label.text.length():
        return {"flags":flags,"currency":wallet}
    var state := String(area.get_meta("dialogue_state", "repeat"))
    var indices: Dictionary = area.get_meta("dialogue_state_indices", {}).duplicate(true)
    var index := int(area.get_meta("world_displayed_index", -1))
    indices[state] = index + 1
    if state == "first_meet" and index + 1 >= int(area.get_meta("world_displayed_total", 0)):
        flags["npc_met_%s" % String(area.get_meta("npc_id", area.name))] = true
    if bool(flags.get("quest_bring_names_rewarded", false)):
        flags["reward_returned_names_claimed"] = true
    var recollection: String = preload("res://scripts/npc_recollections.gd").completion_marker(String(area.get_meta("npc_id",area.name)),area.get_meta("world_recollection_result",area.get_meta("world_dialogue_result",{})),index,String(level.config.get("id","")))
    if not recollection.is_empty():flags[recollection]=true
    var response_memory: Dictionary = preload("res://scripts/protagonist_response_memory.gd").quote(String(area.get_meta("npc_id",area.name)),area.get_meta("world_dialogue_result",{}),index,flags,String(level.config.get("id","")))
    var completion: Dictionary = level.WORLD_NARRATIVE_SCRIPT.completion_outcome(area.get_meta("world_dialogue_result", {}), index, flags)
    for flag in completion.flags:flags[String(flag)] = true
    wallet += int(completion.rewards.get("currency", 0))
    if bool(flags.get("reward_returned_names_claimed", false)):
        flags["quest_bring_names_rewarded"] = true
    if not response_memory.is_empty():flags[String(response_memory.marker)]=true
    return {"flags":flags,"currency":wallet,"indices":indices,"response_text":String(response_memory.get("text",""))}


static func wish_topic_plan(level: Node, quest: Dictionary, area: Area2D) -> Dictionary:
    var next_counts: Dictionary = level.inventory_counts.duplicate(true)
    var next_flags: Dictionary = level.story_flags.duplicate(true)
    var dialogue: Dictionary = level._wish_dialogue_candidate(area, next_flags, level.currency_count)
    next_flags = dialogue.flags
    var next_currency := int(dialogue.currency)
    var complete_flag := String(quest.get("complete_flag", ""))
    var delivered: bool = not complete_flag.is_empty() and not bool(next_flags.get(complete_flag, false)) and level.wish_offering_available(String(quest.get("item", "")))
    var reward := ""
    if delivered:
        var required := String(quest.get("item", ""))
        if bool(quest.get("consume", false)):
            next_counts[required] = int(next_counts[required]) - 1
            if int(next_counts[required]) == 0:next_counts.erase(required)
        reward = String(quest.get("reward", ""))
        if not reward.is_empty():next_counts[reward] = int(next_counts.get(reward, 0)) + 1
        next_flags[complete_flag] = true
        if reward.begins_with("testimony_"):
            var all_testimonies := true
            for index in range(1, 7):
                if float(next_counts.get("testimony_%02d" % index, 0)) < 1.0:all_testimonies = false
            if all_testimonies:next_flags["true_ending_testimony_complete"] = true
        if level.world_narrative != null:
            for flag in level.world_narrative.evaluate_progress(next_counts, next_flags).get("grant_flags", []):
                next_flags[String(flag)] = true
    elif not bool(next_flags.get(complete_flag, false)):
        var accept_flag := String(quest.get("accept_flag", ""))
        if not accept_flag.is_empty():next_flags[accept_flag] = true
    for wish in level._wish_board_entries():
        var target := String(wish.get("target_flag", ""))
        var claim: String = level._wish_claim_flag(wish)
        if not target.is_empty() and bool(next_flags.get(target, false)) and not bool(next_flags.get(claim, false)):
            next_flags[claim] = true
            next_currency += maxi(0, int(wish.get("reward_currency", 0)))
    return {"counts":next_counts,"flags":next_flags,"currency":next_currency,"dialogue":dialogue,"delivered":delivered,"reward":reward}


static func quote_wish_topic(level: Node, quest: Dictionary, area: Area2D) -> Dictionary:
    var failure := {"ok":false,"reason":"请回到这位人物身旁，重新打开当前心愿。"}
    if not level.world_mode or level.world_loading or level.world_save_blocked or level.player == null or level.player.hp <= 0 or level.build_system == null:return failure
    if not is_instance_valid(area) or not area.is_inside_tree() or not area.is_visible_in_tree() or area.is_queued_for_deletion():return failure
    if area.get_world_2d() != level.player.get_world_2d() or area.global_position.distance_to(level.player.global_position) > level.INTERACTION_REACH:return failure
    if level.ui_shell == null or level.ui_shell.dialogue_area != area or level.active_overlay != "dialogue" or not level.ui_shell.dialogue.visible:return failure
    var topics: Dictionary = area.get_meta("dialogue_topics",{})
    if quest.is_empty() or topics.get("quest",{}) != quest:return failure
    for key in ["item","reward","complete_flag"]:
        if not quest.get(key,"") is String or String(quest.get(key,"")).is_empty():return failure
    if not quest.get("consume",false) is bool:return failure
    var plan: Dictionary = level._wish_topic_plan(quest,area)
    var required := String(quest.item)
    var next_build = level.build_system.get_script().new()
    if not next_build.restore(level.build_system.serialize()).ok:return failure
    next_build.sync_progress(plan.counts,String(level.config.get("id","")),plan.flags)
    var owned: Variant = level.inventory_counts.get(required,0)
    var text: String = "所需：%s × 1（持有 %s）\n%s\n回礼：%s × 1\n碎钱变化：%+d\n确认后写入归途记录；不会补满当前生命或能量。" % [level._item_display_name(required),str(owned),"交付将消耗一份信物。" if quest.get("consume",false) else "只需出示信物，不消耗持有物。",level._item_display_name(String(quest.reward)),int(plan.currency)-level.currency_count]
    var profile: Dictionary=next_build.profile()
    text += "\n永久容量：生命 %d → %d；能量 %d → %d" % [level.player.max_hp,int(profile.get("max_hp",level.player.max_hp)),level.player.max_energy,int(profile.get("max_energy",level.player.max_energy))]
    var fingerprint: String = var_to_str([quest,level.inventory_counts,level.story_flags,level.currency_count,level.build_system.serialize(),plan,level.dialogue_text_label.text,level.dialogue_text_label.visible_characters]).sha256_text()
    return {"ok":true,"delivered":plan.delivered,"summary":text,"fingerprint":fingerprint}


static func perform_wish_topic(level: Node, quest: Dictionary, area: Area2D) -> Dictionary:
    var failure := {"ok":false,"reason":"归途记录未能写入；本次心愿尚未确认，请重试。"}
    if not level.world_mode or level.world_loading or level.world_state == null or level.player == null or level.build_system == null or level.world_save_blocked:
        return failure
    var plan: Dictionary = level._wish_topic_plan(quest,area)
    var next_counts: Dictionary = plan.counts
    var next_flags: Dictionary = plan.flags
    var dialogue: Dictionary = plan.dialogue
    var next_currency: int = plan.currency
    var delivered: bool = plan.delivered
    var reward: String = plan.reward
    if next_counts == level.inventory_counts and next_flags == level.story_flags and next_currency == level.currency_count:
        if dialogue.has("indices"):area.set_meta("dialogue_state_indices", dialogue.indices)
        return {"ok":true,"delivered":false}
    var next_build = level.build_system.get_script().new()
    if not next_build.restore(level.build_system.serialize()).ok:return failure
    next_build.sync_progress(next_counts, String(level.config.get("id", "")), next_flags)
    var prepared: Dictionary = level._prepare_world_checkpoint({"inventory_counts":next_counts,"story_flags":next_flags,"currency":next_currency,
        "current_region":String(level.config.get("id", "")),"entry":level.active_spawn,"hp":level.player.hp,
        "energy":maxi(0, level.player.energy - level.player.practice_energy),"build_state":next_build.serialize()})
    if not prepared.ok:return failure
    if level.world_save_failure_injected_for_validation or not level.world_state.write_candidate(prepared.candidate, level.world_save_path):return failure
    var testimony_completed: bool = not bool(level.story_flags.get("true_ending_testimony_complete", false)) and bool(next_flags.get("true_ending_testimony_complete", false))
    # No live gameplay object has been touched before this point.
    level.world_state.data = prepared.candidate
    level.inventory_counts = next_counts
    level.story_flags = next_flags
    level.currency_count = next_currency
    level.inventory_materials.clear()
    level.inventory_relics.clear()
    level.inventory_tools.clear()
    for item_id in level.inventory_counts:
        match String(level._item_data(String(item_id)).get("category", "Materials")):
            "Materials":level.inventory_materials[item_id] = int(level.inventory_counts[item_id])
            "Relics":level.inventory_relics.append(item_id)
            "Tools":level.inventory_tools.append(item_id)
    level.build_system.restore(next_build.serialize())
    if dialogue.has("indices"):area.set_meta("dialogue_state_indices", dialogue.indices)
    level._sync_player_build()
    level._apply_world_npc_state(area)
    if testimony_completed:level._play_sfx("ui_testimony_complete", -4.0)
    if delivered and not reward.is_empty():level._toast("收入行囊 · " + level._item_display_name(reward))
    if not String(dialogue.get("response_text","")).is_empty():level._toast(String(dialogue.response_text))
    level._refresh_wish_board_overlay()
    level._refresh_hud()
    return {"ok":true,"delivered":delivered}


static func wish_claimed_total(level: Node) -> int:
    var claimed := 0
    for wish_value in level._wish_board_entries():
        if bool(level.story_flags.get(level._wish_claim_flag(wish_value), false)):
            claimed += 1
    return claimed
