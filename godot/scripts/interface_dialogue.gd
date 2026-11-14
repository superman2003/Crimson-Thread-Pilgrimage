extends RefCounted
## The dialogue panel: speaker, topics and wish topics, and reading position memory.
## Moved out of pilgrimage_interface.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func build_dialogue(ui: Node) -> void:
    ui.dialogue=ui._panel(ui,"",Vector2(72,374),Vector2(1136,300))
    ui.dialogue.name="DialogueOverlay"
    ui.dialogue.get_child(0).kind="dialogue"
    ui._well(ui.dialogue,Vector2(18,16),Vector2(188,220))
    ui.dialogue_portrait=preload("res://scripts/npc_dialogue_portrait.gd").new()
    ui.dialogue_portrait.position=Vector2(23,21)
    ui.dialogue_portrait.size=Vector2(173,191)
    ui.dialogue_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    ui.dialogue_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ui.dialogue_portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
    ui.dialogue.add_child(ui.dialogue_portrait)
    ui.dialogue_name=ui._label(ui.dialogue,"",Vector2(221,19),Vector2(740,37),ui.TYPE.DISPLAY,ui.GOLD)
    ui.dialogue_identity=ui._label(ui.dialogue,"",Vector2(221,57),Vector2(770,28),14,ui.MUTED)
    ui.dialogue_scroll=ScrollContainer.new()
    ui.dialogue_scroll.position=Vector2(221,93)
    ui.dialogue_scroll.size=Vector2(854,140)
    ui.dialogue_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    ui.dialogue_scroll.focus_mode=Control.FOCUS_ALL
    ui.dialogue.add_child(ui.dialogue_scroll)
    ui.dialogue_body=ui._label(ui.dialogue_scroll,"",Vector2.ZERO,Vector2(854,140),int(ui.accessibility["subtitle_size"]),ui.IVORY)
    ui.dialogue_body.add_theme_font_override("font",ui.FONT)
    ui.dialogue_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    ui.dialogue_body.custom_minimum_size=Vector2(825,0)
    ui.dialogue_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    ui.dialogue_hint=ui._label(ui.dialogue,ui._dialogue_binding_hint(),Vector2(24,242),Vector2(180,50),ui.TYPE.CAPTION,ui.MUTED)
    ui.dialogue_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    ui.dialogue_hint.mouse_filter=Control.MOUSE_FILTER_PASS
    ui.dialogue_continue_button=ui._button(ui.dialogue,"继续交谈",Vector2(221,250),Vector2(147,34),func():
        if is_instance_valid(ui.dialogue_area):
            if ui.level.world_mode:ui.level._try_interact()
            else:ui.level._talk_to_npc(ui.dialogue_area))
    ui.dialogue_route_button=ui._button(ui.dialogue,"问问道路",Vector2(380,250),Vector2(147,34),func():ui._topic("route"))
    ui.dialogue_quest_button=ui._button(ui.dialogue,"询问心愿",Vector2(540,250),Vector2(147,34),func():ui._topic("wish"))
    ui.dialogue_inquiry_button=ui._button(ui.dialogue,"追问线索",Vector2(990,20),Vector2(125,30),ui._open_narrative_inquiries)
    var reader:=preload("res://scripts/dialogue_reader.gd").new()
    reader.name="DialogueReader"
    reader.position=Vector2(696,250)
    ui.dialogue.add_child(reader)
    reader.configure(ui.dialogue_body,ui.dialogue_scroll,func():
        if not ui.dialogue.is_visible_in_tree() or not is_instance_valid(ui.dialogue_area) or ui.level==null or not is_instance_valid(ui.level) or String(ui.level.active_overlay)!="dialogue":return
        ui.level.subtitle_elapsed=ui.level.subtitle_seconds
        ui.dialogue_body.visible_characters=-1)


static func show_speaker(ui: Node, area: Area2D) -> void:
    if is_instance_valid(ui.dialogue_area) and ui.dialogue_area != area:
        ui._speaker_motion(ui.dialogue_area,false)
    ui.dialogue_area=area
    ui.dialogue_scroll.scroll_vertical=0
    ui.dialogue_reading_key=ui._dialogue_reading_key(area,ui.dialogue_body.text)
    var reading = ui.dialogue_reading.restore(ui.dialogue_reading_key)
    if not reading.is_empty():ui._restore_dialogue_scroll(ui.dialogue_reading_key,int(reading.scroll))
    var history := String(area.get_meta("kind",""))=="history"
    ui.dialogue_continue_button.text="记入旅记" if history else "继续交谈"
    ui.dialogue_route_button.visible=not history
    ui.dialogue_quest_button.visible=not history
    ui.dialogue_inquiry_button.visible=not history and ui.level.world_mode and not preload("res://scripts/narrative_inquiries.gd").available(String(area.get_meta("npc_id","")),ui.level.inventory_counts,ui.level.story_flags).is_empty()
    ui.dialogue_hint.text=ui._dialogue_binding_hint()
    ui.dialogue_hint.tooltip_text=ui.dialogue_hint.text
    var topics: Dictionary=area.get_meta("dialogue_topics",{})
    var quest: Dictionary=topics.get("quest",{})
    ui.dialogue_quest_button.text="询问心愿"
    if not quest.is_empty():
        var required:=String(quest.get("item",""))
        if ui.level.wish_offering_available(required) and not bool(ui.level.story_flags.get(String(quest.get("complete_flag","")),false)):
            ui.dialogue_quest_button.text="预览交付"
        elif bool(ui.level.story_flags.get(String(quest.get("complete_flag","")),false)):
            ui.dialogue_quest_button.text="回访心愿"
    ui._speaker_motion(area,true)
    ui.dialogue_portrait.call("bind_speaker", area, ui.ART.item("moss_lens") if history else ui.ART.portrait(String(area.get_meta("npc_id",""))))


static func speaker_motion(ui: Node, area, talking: bool) -> void:
    if not is_instance_valid(area): return
    var sprite := area.get_node_or_null("FriendlyFamilySprite") as AnimatedSprite2D
    if sprite==null: return
    var method := &"begin_conversation" if talking else &"end_conversation"
    if sprite.has_method(method): sprite.call(method)
    else: sprite.play(&"talk" if talking else &"idle")
    var listener: Node2D = ui.level.get("player") as Node2D if is_instance_valid(ui.level) else null
    if talking and sprite.has_method("face_listener") and is_instance_valid(listener):
        sprite.call("face_listener", listener.global_position.x)


static func open_narrative_inquiries(ui: Node) -> void:
    if not preload("res://scripts/narrative_inquiries.gd").can_talk(ui,ui.dialogue_area):return
    if not is_instance_valid(ui.narrative_inquiry_desk):
        ui.narrative_inquiry_desk=preload("res://scripts/narrative_inquiry_desk.gd").new()
        ui.add_child(ui.narrative_inquiry_desk)
        ui.register_text_entry_window(ui.narrative_inquiry_desk)
    ui.narrative_inquiry_desk.open(ui,ui.dialogue_area)


static func topic(ui: Node, key: String) -> void:
    if not is_instance_valid(ui.dialogue_area):return
    if ui.level.world_mode and key == "wish":
        var topics: Dictionary = ui.dialogue_area.get_meta("dialogue_topics", {})
        var quest: Dictionary = topics.get("quest", {})
        if not quest.is_empty():
            var quote: Dictionary = ui.level.quote_wish_topic(quest,ui.dialogue_area)
            if not quote.get("ok",false):ui.level._toast(String(quote.reason));return
            if quote.delivered:
                if not is_instance_valid(ui.wish_confirmation):
                    ui.wish_confirmation=preload("res://scripts/wish_confirmation.gd").new()
                    ui.dialogue.add_child(ui.wish_confirmation)
                    ui.wish_confirmation.setup(ui)
                    ui.register_text_entry_window(ui.wish_confirmation)
                    ui.dialogue.visibility_changed.connect(func():
                        if not ui.dialogue.visible and is_instance_valid(ui.wish_confirmation):ui.wish_confirmation.hide())
                ui.wish_confirmation.open(ui.dialogue_area,quest,quote)
                return
        ui._commit_wish_topic(quest,ui.dialogue_area)
        return
    if ui.level.world_mode:
        ui.level._commit_world_dialogue()
        # A route/wish answer is not an unread final line from the story round.
        ui.dialogue_area.set_meta("world_line_committed",true)
        ui.dialogue_area.set_meta("world_displayed_index",-1)
    var topics: Dictionary=ui.dialogue_area.get_meta("dialogue_topics",{})
    var line:=String(topics.get(key,"你若愿意听，我们就再坐一会儿。"))
    if key=="wish":
        var quest: Dictionary=topics.get("quest",{})
        if not quest.is_empty():
            var required:=String(quest.get("item",""))
            var flag:=String(quest.get("complete_flag",""))
            if ui.level.wish_offering_available(required) and not bool(ui.level.story_flags.get(flag,false)):
                ui.level._set_story_flag(flag)
                if bool(quest.get("consume",false)):
                    ui.level.inventory_counts[required]=int(ui.level.inventory_counts[required])-1
                    if int(ui.level.inventory_counts[required])<=0:ui.level.inventory_counts.erase(required)
                    if ui.level.inventory_materials.has(required):
                        ui.level.inventory_materials[required]=maxi(0,int(ui.level.inventory_materials[required])-1)
                        if int(ui.level.inventory_materials[required])==0:ui.level.inventory_materials.erase(required)
                var reward:=String(quest.get("reward",""))
                if not reward.is_empty():ui.level._add_inventory_item(reward,1,true)
                line=String(quest.get("thanks","我会记住你带回的消息。"))
            else:
                ui.level._set_story_flag(String(quest.get("accept_flag","")))
    ui.level._show_dialogue(ui.dialogue_area,line)
    if ui.level.world_mode:ui.level._save_world()


static func commit_wish_topic(ui: Node, quest: Dictionary, area: Area2D) -> bool:
    if not is_instance_valid(area) or ui.dialogue_area != area:return false
    var result: Dictionary = ui.level.perform_wish_topic(quest,area)
    if not result.get("ok",false):ui.level._toast(String(result.get("reason","心愿尚未确认，请重试。")));return false
    area.set_meta("world_line_committed",true)
    area.set_meta("world_displayed_index",-1)
    var topics: Dictionary = area.get_meta("dialogue_topics",{})
    var line := String(quest.get("thanks","我会记住你带回的消息。")) if result.get("delivered",false) else String(topics.get("wish","你若愿意听，我们就再坐一会儿。"))
    ui.level._show_dialogue(area,line)
    return true


static func dialogue_reading_key(ui: Node, area: Area2D,line: String) -> String:
    return "%s|%s|%s|%d|%s" % [String(ui.level.config.get("id","")),String(area.get_meta("npc_id",area.name)),String(area.get_meta("dialogue_state","")),int(area.get_meta("world_displayed_index",-1)),line.sha256_text()]


static func dialogue_reading_state(ui: Node, area: Area2D,line: String) -> Dictionary:
    return ui.dialogue_reading.restore(ui._dialogue_reading_key(area,line))


static func forget_dialogue_reading(ui: Node) -> void:
    ui.dialogue_reading.forget(ui.dialogue_reading_key)


static func restore_dialogue_scroll(ui: Node, key: String,value: int) -> void:
    if not ui.is_inside_tree() or ui.is_queued_for_deletion():return
    if ui.pending_dialogue_restore.is_valid() and ui.get_tree().process_frame.is_connected(ui.pending_dialogue_restore):
        ui.get_tree().process_frame.disconnect(ui.pending_dialogue_restore)
    ui.pending_dialogue_restore=ui._apply_dialogue_scroll.bind(key,value,ui.reading_session_generation)
    ui.get_tree().process_frame.connect(ui.pending_dialogue_restore,CONNECT_ONE_SHOT)


static func apply_dialogue_scroll(ui: Node, key: String,value: int,request_generation: int) -> void:
    ui.pending_dialogue_restore=Callable()
    if request_generation != ui.reading_session_generation or ui.is_queued_for_deletion():return
    if not is_instance_valid(ui.dialogue) or not is_instance_valid(ui.dialogue_scroll):return
    if ui.is_inside_tree() and key==ui.dialogue_reading_key and ui.dialogue.visible and is_instance_valid(ui.dialogue_area):
        ui.dialogue_scroll.scroll_vertical=value


static func remember_dialogue_reading(ui: Node) -> void:
    if ui.dialogue_reading_key.is_empty() or not is_instance_valid(ui.level) or not ui.level.get("world_mode"):
        return
    if not is_instance_valid(ui.dialogue_area) or not is_instance_valid(ui.dialogue_body) or not is_instance_valid(ui.dialogue_scroll):
        return
    var committed:=bool(ui.dialogue_area.get_meta("world_line_committed",false)) and int(ui.dialogue_area.get_meta("world_displayed_index",-1))>=0
    ui.dialogue_reading.capture(ui.dialogue_reading_key,ui.dialogue_body.text.length(),ui.dialogue_body.visible_characters,ui.dialogue_scroll.scroll_vertical,committed)


static func close_dialogue(ui: Node) -> void:
    ui._remember_dialogue_reading()
    ui._speaker_motion(ui.dialogue_area,false)
    if is_instance_valid(ui.dialogue_portrait): ui.dialogue_portrait.call("release_speaker")
    var director: Node = ui.level.get("audio_director") as Node if is_instance_valid(ui.level) else null
    if is_instance_valid(director) and director.has_method("stop_npc_voice"): director.call("stop_npc_voice")
    ui.dialogue_area=null
    ui.dialogue_reading_key=""
