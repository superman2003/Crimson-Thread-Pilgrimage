extends RefCounted
## The journal: records, presentation, read/star marks, sources, batches and scroll memory.
## Moved out of pilgrimage_interface.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func refresh_journal(ui: Node) -> void:
    ui.bag_grid.columns=2
    ui.bag_pin.disabled=true
    ui.bag_name.text="六区旅途记录"
    ui.bag_category_label.text="旅途记录"
    ui.bag_icon.texture=ui.ART.item("moss_lens")
    if ui.journal_reading_key.is_empty():ui.bag_description.text="选择分类查看已知记录。"
    for filter_id in ui.journal_filter_buttons:ui.journal_filter_buttons[filter_id].add_theme_stylebox_override("normal",ui._tab_style(filter_id==ui.journal_filter))
    for tab in ui.bag_tabs:tab.add_theme_stylebox_override("normal",ui._tab_style(tab.text==ui.bag_category))
    if not bool(ui.level.get("world_mode")):
        ui.bag_description.text="完整互联世界旅途中会记录跨区委托与六区证词。"
        return
    var narrative: Variant=ui.level.get("world_narrative")
    if narrative==null:return
    var guide_bindings: Dictionary={}
    for action in ui.REMAPPABLE_ACTIONS:guide_bindings[action]=ui._short_binding(action)
    var heal: Dictionary={}
    if is_instance_valid(ui.level.player) and ui.level.player.has_method("get_combat_ui_state"):heal=ui.level.player.get_combat_ui_state().get("heal",{})
    var recall:=preload("res://scripts/death_recall.gd")
    var records: Array=preload("res://scripts/field_guide.gd").records(heal,guide_bindings,recall.bosses_defeated(ui.level.story_flags)>=recall.REQUIRED_BOSSES,ui.level.inventory_counts)
    records.append_array(preload("res://scripts/scene_history.gd").records(ui.level.story_flags))
    records.append_array(preload("res://scripts/hidden_clue_notes.gd").journal(preload("res://scripts/world_routes.gd").cached_hidden_clues(),ui.level.story_flags))
    records.append_array(preload("res://scripts/protagonist_voice.gd").records(ui.level.inventory_counts,ui.level.story_flags))
    records.append_array(preload("res://scripts/npc_recollections.gd").records(ui.level.story_flags))
    records.append_array(preload("res://scripts/narrative_inquiries.gd").records(ui.level.story_flags))
    records.append_array(preload("res://scripts/ending_return_journal.gd").records(ui.level.inventory_counts,ui.level.story_flags))
    records.append_array(preload("res://scripts/known_world_terms.gd").records(ui.level.inventory_counts))
    records.append_array(preload("res://scripts/guardian_identities.gd").records(ui.level.story_flags))
    records.append_array(preload("res://scripts/known_inquiry_contacts.gd").records(ui.level.inventory_counts,ui.level.story_flags))
    var progress: Dictionary={}
    if narrative.has_method("evaluate_progress"):
        progress=narrative.call("evaluate_progress",ui.level.inventory_counts,ui.level.story_flags)
    if not progress.is_empty():
        # N05: the main line leads the journal, so its conditions are always traceable.
        if progress.get("main_line") is Dictionary and not progress.main_line.is_empty():
            var main_entry: Dictionary=progress.main_line.duplicate(true)
            main_entry["record_kind"]="main"
            records.push_front(main_entry)
        for value in progress.get("quests",[]):
            var entry: Dictionary=value.duplicate(true)
            entry["record_kind"]="quest"
            records.append(entry)
        for value in progress.get("known_entries",progress.get("entries",[])):
            var entry: Dictionary=value.duplicate(true)
            entry["record_kind"]="evidence"
            records.append(entry)
        # The canonical evaluator returns no ending records before the final
        # choice is encountered; keep that withholding intact in the journal.
        for value in progress.get("endings",[]):
            var entry: Dictionary=value.duplicate(true)
            entry["record_kind"]="ending"
            records.append(entry)
    else:
        if narrative.has_method("quest_journal"):
            for value in narrative.call("quest_journal",ui.level.inventory_counts,ui.level.story_flags):
                var entry: Dictionary=value.duplicate(true)
                entry["record_kind"]="quest"
                records.append(entry)
        if narrative.has_method("evaluate_evidence"):
            var evidence: Dictionary=narrative.call("evaluate_evidence",ui.level.inventory_counts,ui.level.story_flags)
            for value in evidence.get("entries",[]):
                var entry: Dictionary=value.duplicate(true)
                entry["record_kind"]="evidence"
                records.append(entry)
    records.append_array(preload("res://scripts/enemy_journal.gd").records(ui.level.story_flags))
    ui.journal_catalog.path=ui.journal_preferences_path
    var scope_value: Variant=ui.level.get("world_save_path")
    ui.journal_catalog.configure(scope_value if scope_value is String else "session")
    records=preload("res://scripts/permanent_ability_roles.gd").select(records,ui.journal_filter)
    var documents: Array=[]
    for entry in records:
        var presentation: Dictionary = ui._journal_presentation(entry)
        var key:=String(entry.get("record_kind",""))+":"+String(entry.get("id",""))
        var doc = ui.journal_catalog.document(key,String(entry.get("title",entry.get("id",""))),String(presentation.category),String(presentation.text))
        doc["entry"]=entry
        documents.append(doc)
    ui.journal_documents=documents
    var visible = ui.journal_catalog.filter_documents(documents,ui.journal_search.text,ui.journal_unread.button_pressed,ui.journal_stars.button_pressed,ui.journal_sort.selected)
    var unread_count:=0
    for doc in documents:
        if not ui.journal_catalog.is_read(doc):unread_count+=1
    ui.journal_count.text="已知 %d / %d · 未读 %d" % [visible.size(),documents.size(),unread_count]
    ui.journal_count.tooltip_text="已知记录 / 全部记录 · 本分类未读。阅读标记不推进任务。"
    records=[]
    for doc in visible:records.append(doc.entry)
    var remembered:=String(ui.journal_memory.get(ui.journal_filter,""))
    for index in records.size():
        if String(records[index].get("record_kind",""))+":"+String(records[index].get("id",""))==remembered:ui.journal_selection=index
    ui.journal_selection=clampi(ui.journal_selection,0,maxi(0,records.size()-1))
    if records.is_empty():
        ui.journal_current_document={}
        if ui.bag.has_node("JournalDocumentFind"):ui.bag.get_node("JournalDocumentFind").refresh_launcher()
        ui._refresh_journal_actions()
        ui.journal_reading_key=""
        ui.journal_restore_pending=false
        ui.bag_name.text="尚无敌人记录" if ui.journal_filter=="enemy" else "这一分类暂无记录"
        ui.bag_description.text="击败后会留下战斗笔记；未交战的敌人不会提前列出。" if ui.journal_filter=="enemy" else "继续探索并与人物交谈，已知的记录会保存在这里。"
        if ui.journal_filter=="ability":
            ui.bag_name.text="尚无已取得的永久能力"
            ui.bag_description.text="在旅途中实际取得能力后，这里会区分其用途与操作；不用装备铭饰就能使用已取得的永久能力。"
        if ui.journal_filter=="people":
            ui.bag_name.text="尚无已确认的交谈"
            ui.bag_description.text="完整读完交谈并成功留下记录后，可以在这里回看相识之人的话。"
        if ui.journal_filter=="voice":
            ui.bag_name.text="尚无自述"
            ui.bag_description.text="获得永久能力、确认交谈或近看遗迹后，可以在这里回看旅途自述。"
        if not ui.journal_search.text.is_empty() or ui.journal_unread.button_pressed or ui.journal_stars.button_pressed:
            ui.bag_name.text="没有符合筛选的已知记录"
            ui.bag_description.text="清空搜索、关闭仅未读/收藏，或切换分类。未发现内容不会列出或被搜索命中。"
    var selected_button: Button
    for record_index in records.size():
        var value: Variant=records[record_index]
        var entry: Dictionary=value
        var title:=String(entry.get("title",entry.get("id","")))
        var status:="已发现" if bool(entry.get("acquired",false)) else "待发现"
        if entry.record_kind=="quest":status="已完成" if String(entry.get("status",""))=="complete" else "进行中"
        elif entry.record_kind=="main":status="主线"
        elif entry.record_kind=="guide":status=preload("res://scripts/permanent_ability_roles.gd").label(entry) if preload("res://scripts/permanent_ability_roles.gd").is_ability(entry) else "可回看"
        elif entry.record_kind=="voice":status="旅途自述"
        elif entry.record_kind=="people":status="已确认交谈 · %d处重逢" % entry.get("places",[]).size()
        elif entry.record_kind=="enemy":status="已击败"
        elif entry.record_kind=="ending":status=ui._ending_status_label(entry)
        var public: Dictionary = ui._journal_presentation(entry)
        var doc = ui.journal_catalog.document(String(entry.record_kind)+":"+String(entry.get("id","")),title,String(public.category),String(public.text))
        status=("★ " if ui.journal_catalog.is_starred(String(doc.key)) else "")+("未读 · " if not ui.journal_catalog.is_read(doc) else "")+status
        var button: Button = ui._button(ui.bag_grid,title+"\n"+status,Vector2.ZERO,Vector2(309,74),func():ui._show_journal_record(entry))
        button.custom_minimum_size=Vector2(309,74)
        button.tooltip_text=title+" · "+status
        var record_key:=String(entry.record_kind)+":"+String(entry.get("id",""))
        button.set_meta("journal_key",record_key)
        button.focus_entered.connect(func():
            ui.journal_selection=record_index
            ui.journal_memory[ui.journal_filter]=record_key
            ui._show_journal_record(entry))
        button.mouse_entered.connect(func():ui._show_journal_record(entry))
        if record_index==ui.journal_selection:selected_button=button
    if not records.is_empty():
        ui.journal_selection=clampi(ui.journal_selection,0,records.size()-1)
        ui._show_journal_record(records[ui.journal_selection])
        if selected_button!=null and ui.bag.visible and not ui._journal_tools_focused():selected_button.grab_focus()


static func journal_presentation(ui: Node, entry: Dictionary) -> Dictionary:
    var category:=""
    var lines: Array[String]=[]
    if bool(entry.get("history_note",false)):
        category="环境见闻 · 已观察"
        lines.append(String(entry.get("text","")))
        lines.append("\n地点："+String(entry.get("place","")))
        lines.append("\n环境见闻保留了观察，不计入六区原始证词。")
    elif String(entry.get("record_kind",""))=="people":
        category="人物重逢 · 已确认交谈"
        lines.append(String(entry.get("description","")))
    elif String(entry.get("record_kind",""))=="voice":
        category="自述 · "+String(entry.get("voice_context","获得能力之后"))
        lines.append(String(entry.get("description","")))
        for source in entry.get("voice_sources",[]):lines.append("\n记自："+String(source))
    elif String(entry.get("record_kind",""))=="guide":
        category="永久能力 · "+preload("res://scripts/permanent_ability_roles.gd").label(entry) if preload("res://scripts/permanent_ability_roles.gd").is_ability(entry) else String(entry.get("guide_context","操作手册 · 当前规则"))
        lines.append(String(entry.get("description","")))
    elif String(entry.get("record_kind",""))=="ending":
        var chosen:=bool(entry.get("chosen",false))
        var ready:=bool(entry.get("available",false))
        category="结局选择 · "+ui._ending_status_label(entry)
        if not String(entry.get("message","")).is_empty():lines.append(String(entry.message))
        for requirement in entry.get("known_missing",[]):
            var clue: Dictionary=requirement
            var clue_line:=String(clue.get("label","已知线索"))
            if not String(clue.get("region","")).is_empty():clue_line+=" · "+String(clue.region)
            lines.append("○ "+clue_line)
            if not String(clue.get("hint","")).is_empty():lines.append("  "+String(clue.hint))
        var hidden_count:=int(entry.get("hidden_missing_count",0))
        if hidden_count>0:lines.append("\n另有 %d 项线索尚未在旅记中确认。" % hidden_count)
        if ready or chosen:
            var consequences: Variant=entry.get("consequences",{})
            if consequences is Dictionary and not consequences.is_empty():
                lines.append("\n结局影响")
                for consequence in entry.get("consequence_rows",[]):
                    lines.append("· %s：%s" % [String(consequence.get("title","六城")),String(consequence.get("text",""))])
        if chosen and not entry.get("aftermath_rows",[]).is_empty():
            lines.append("\n各地变化")
            for row in entry.get("aftermath_rows",[]):
                if bool(row.get("seen",false)):lines.append("● %s：%s" % [String(row.get("region_name","")),String(row.get("text",""))])
                else:lines.append("○ %s：回到那里的钟龛看看。" % String(row.get("region_name","")))
        if chosen:
            for scene in preload("res://scripts/narrative_journey.gd").epilogue(String(entry.get("id","")),ui.level.story_flags):
                lines.append("\n尾声 · "+String(scene.title))
                lines.append(String(scene.text))
                lines.append("巡礼者 · "+String(scene.response))
    elif String(entry.get("record_kind",""))=="enemy":
        category="敌人 · 已击败"
        lines.append(String(entry.get("description","")))
        lines.append("\n战斗笔记按已击败种类保存；休息后敌人复现不会重复添加。")
    elif String(entry.get("record_kind",""))=="main":
        category="主线"
        lines.append(String(entry.get("goal","")))
        for step in entry.get("steps",[]):lines.append(("● " if bool(step.get("complete",false)) else "○ ")+String(step.get("label","")))
        lines.append("\n"+String(entry.get("guidance","")))
        for reflection in entry.get("reflections",[]):
            lines.append("\n已拼起的故事 · "+String(reflection.title))
            lines.append(String(reflection.text))
            lines.append("巡礼者手记："+String(reflection.question))
    elif String(entry.get("record_kind",""))=="quest":
        category="委托 · "+("已完成" if String(entry.get("status",""))=="complete" else "进行中")
        lines.append(String(entry.get("description","")))
        for step in entry.get("steps",[]):lines.append(("● " if bool(step.get("complete",false)) else "○ ")+String(step.get("label","")))
        lines.append("\n"+String(entry.get("guidance","")))
        if String(entry.get("status",""))=="complete":lines.append("奖励已领取。" if bool(entry.get("reward_claimed",false)) else "可以返回委托人领取奖励。")
        lines.append_array(preload("res://scripts/quest_contacts.gd").appendix(String(entry.get("id","")),ui.level.inventory_counts,ui.level.story_flags))
    else:
        var acquired:=bool(entry.get("acquired",false))
        category="证词 · "+("已发现" if acquired else "缺页")
        lines.append(String(entry.get("claim","")) if acquired else "尚未拾得这页证词。")
        lines.append("\n线索："+String(entry.get("location_hint","留意区域中的遗物与生产设施。")))
        if acquired:
            var witness: Dictionary=entry.get("scene_witness",{})
            if not witness.is_empty():
                lines.append("\n场景印证 · "+String(witness.get("title","遗留痕迹")))
                lines.append(String(witness.get("text","")))
            for connection in entry.get("connections",[]):
                lines.append("\n互证："+String(connection))
            lines.append_array(preload("res://scripts/testimony_sources.gd").appendix(String(entry.get("id","")),ui.level.inventory_counts))
    return {"text":"\n".join(lines),"category":category}


static func show_journal_record(ui: Node, entry: Dictionary) -> void:
    ui._remember_journal_scroll()
    ui.bag_name.text=String(entry.get("title",entry.get("id","")))
    var presentation: Dictionary = ui._journal_presentation(entry)
    ui.bag_category_label.text=String(presentation.category)
    var text:=String(presentation.text)
    var key:=String(entry.get("record_kind",""))+":"+String(entry.get("id",""))
    ui.journal_current_document=ui.journal_catalog.document(key,ui.bag_name.text,ui.bag_category_label.text,text)
    ui._refresh_journal_actions()
    if ui.journal_reading_key==key and ui.bag_description.text==text:return
    ui.bag_description.text=text
    ui.journal_reading_key=key if ui.bag.is_visible_in_tree() else ""
    ui.journal_reading_text=text
    ui.journal_restore_pending=not ui.journal_reading_key.is_empty()
    ui.call_deferred("_restore_journal_scroll",key,text,ui.journal_reading.resume(key,text),ui.reading_session_generation)
    if ui.bag.has_node("JournalDocumentFind"):ui.bag.get_node("JournalDocumentFind").refresh_launcher()


static func register_text_entry_window(ui: Node, window: Window) -> void:
    for reference in ui.text_entry_windows:
        if reference.get_ref()==window:return
    var reference: WeakRef = weakref(window)
    ui.text_entry_windows.append(reference)
    window.visibility_changed.connect(ui._registered_window_visibility.bind(reference))


static func registered_window_visibility(ui: Node, reference: WeakRef) -> void:
    var window := reference.get_ref() as Window
    if not is_instance_valid(window) or not window.visible:ui.modal_closed_frame=Engine.get_process_frames()


static func has_modal_window(ui: Node) -> bool:
    if ui.modal_closed_frame == Engine.get_process_frames():return true
    for reference in ui.text_entry_windows.duplicate():
        var window := reference.get_ref() as Window
        if not is_instance_valid(window):ui.text_entry_windows.erase(reference);continue
        if window.visible:return true
    return false


static func is_text_entry_focused(ui: Node) -> bool:
    var focus = ui.get_viewport().gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit:return true
    for reference in ui.text_entry_windows.duplicate():
        var window:=reference.get_ref() as Window
        if not is_instance_valid(window):ui.text_entry_windows.erase(reference);continue
        if not window.visible:continue
        var window_focus:=window.gui_get_focus_owner()
        if window_focus is LineEdit or window_focus is TextEdit:return true
    return false


static func journal_tools_focused(ui: Node) -> bool:
    var focus = ui.get_viewport().gui_get_focus_owner()
    return focus!=null and (ui.journal_tools.is_ancestor_of(focus) or focus in [ui.journal_mark_button,ui.journal_star_button,ui.journal_batch_button])


static func refresh_journal_actions(ui: Node) -> void:
    var valid = not ui.journal_current_document.is_empty()
    ui.journal_mark_button.disabled=not valid
    ui.journal_star_button.disabled=not valid
    ui.journal_batch_button.disabled=not ui.journal_catalog.batch_quote(ui._journal_batch_documents()).get("ok",false)
    ui.journal_mark_button.text="标为未读" if valid and ui.journal_catalog.is_read(ui.journal_current_document) else "标为已读"
    ui.journal_star_button.text="取消收藏" if valid and ui.journal_catalog.is_starred(String(ui.journal_current_document.key)) else "收藏记录"
    if ui.has_node("JournalMarkDesk"):ui.get_node("JournalMarkDesk").refresh_launcher()
    if ui.bag_category=="旅记":
        var sources = preload("res://scripts/journal_sources.gd").links(String(ui.journal_current_document.get("key","")),ui.level.inventory_counts,ui.level.story_flags)
        ui.bag_pin.disabled=sources.is_empty()
        ui.bag_pin.text="回看来源 · %d条" % sources.size() if not sources.is_empty() else "PgUp/PgDn · LB/RB 翻页"
        ui.bag_pin.tooltip_text="回看本条引用的已知原始记录；关闭后回到原文。" if not sources.is_empty() else "Home 到开头，End 到末尾；切换记录后保留本次阅读位置。"
    if is_instance_valid(ui.journal_source_dialog):ui.journal_source_dialog.refresh_binding()


static func journal_preference_result(ui: Node, result: Dictionary) -> void:
    if not String(result.get("reason","")).is_empty() and is_instance_valid(ui.toast):ui.toast.text=String(result.reason)
    ui.refresh_inventory()


static func toggle_journal_read(ui: Node) -> void:
    if ui.journal_current_document.is_empty() or not ui.bag.visible or ui.bag_category!="旅记":return
    ui.journal_memory[ui.journal_filter]=String(ui.journal_current_document.key)
    ui._journal_preference_result(ui.journal_catalog.mark_read(ui.journal_current_document,not ui.journal_catalog.is_read(ui.journal_current_document)))


static func toggle_journal_star(ui: Node) -> void:
    if ui.journal_current_document.is_empty() or not ui.bag.visible or ui.bag_category!="旅记":return
    ui.journal_memory[ui.journal_filter]=String(ui.journal_current_document.key)
    ui._journal_preference_result(ui.journal_catalog.toggle_star(String(ui.journal_current_document.key)))


static func journal_batch_available(ui: Node) -> bool:
    return ui.bag.visible and ui.bag_category=="旅记" and not ui.level.world_loading and not ui.level.chapter_transitioning


static func journal_batch_documents(ui: Node) -> Array:
    return ui.journal_catalog.filter_documents(ui.journal_documents,ui.journal_search.text,ui.journal_unread.button_pressed,ui.journal_stars.button_pressed,ui.journal_sort.selected)


static func open_journal_sources(ui: Node) -> void:
    if not ui._journal_batch_available():return
    if not is_instance_valid(ui.journal_source_dialog):
        ui.journal_source_dialog=preload("res://scripts/journal_source_desk.gd").new()
        ui.bag.add_child(ui.journal_source_dialog)
        ui.register_text_entry_window(ui.journal_source_dialog)
        var popup_ref: WeakRef=weakref(ui.journal_source_dialog)
        ui.bag.visibility_changed.connect(func():
            var popup: AcceptDialog=popup_ref.get_ref()
            if is_instance_valid(popup) and not ui.bag.is_visible_in_tree():popup.hide())
    ui.journal_source_dialog.open_for(ui)


static func open_journal_batch(ui: Node) -> void:
    if not ui._journal_batch_available():return
    if not is_instance_valid(ui.journal_batch_dialog):
        ui.journal_batch_dialog=preload("res://scripts/journal_batch_read.gd").new()
        ui.bag.add_child(ui.journal_batch_dialog)
        ui.register_text_entry_window(ui.journal_batch_dialog)
        var popup_ref: WeakRef=weakref(ui.journal_batch_dialog)
        ui.bag.visibility_changed.connect(func():
            var popup: ConfirmationDialog=popup_ref.get_ref()
            if is_instance_valid(popup) and not ui.bag.is_visible_in_tree():popup.hide())
    var result: Dictionary=ui.journal_batch_dialog.open_for(ui)
    if not result.get("ok",false):ui._journal_preference_result(result)


static func remember_journal_scroll(ui: Node, force: bool=false) -> void:
    if not is_instance_valid(ui.bag_description) or ui.journal_reading_key.is_empty() or ui.journal_restore_pending:return
    if force or ui.bag.is_visible_in_tree():ui.journal_reading.capture(ui.journal_reading_key,ui.journal_reading_text,ui.bag_description.get_v_scroll_bar().value)


static func journal_bag_visibility_changed(ui: Node) -> void:
    if not ui.bag.is_visible_in_tree():
        ui._remember_journal_scroll(true)
        ui.journal_reading_key=""
        ui.journal_restore_pending=false


static func restore_journal_scroll(ui: Node, key: String, text: String, offset: float, generation: int = -1) -> void:
    if not ui.is_inside_tree() or ui.is_queued_for_deletion():return
    var request_generation = ui.reading_session_generation if generation < 0 else generation
    # Object-bound one-shot connections are discarded when this HUD is freed.
    # An instance coroutine would instead resume after its owner is gone.
    if ui.pending_journal_restore.is_valid() and ui.get_tree().process_frame.is_connected(ui.pending_journal_restore):
        ui.get_tree().process_frame.disconnect(ui.pending_journal_restore)
    ui.pending_journal_restore=ui._apply_journal_scroll.bind(key,text,offset,request_generation)
    ui.get_tree().process_frame.connect(ui.pending_journal_restore,CONNECT_ONE_SHOT)


static func apply_journal_scroll(ui: Node, key: String, text: String, offset: float, request_generation: int) -> void:
    ui.pending_journal_restore=Callable()
    if request_generation != ui.reading_session_generation or ui.is_queued_for_deletion():return
    if not is_instance_valid(ui.bag) or not is_instance_valid(ui.bag_description):return
    if ui.is_inside_tree() and ui.bag.is_visible_in_tree() and ui.journal_reading_key==key and ui.bag_description.text==text:
        var bar = ui.bag_description.get_v_scroll_bar()
        bar.value=clampf(offset,bar.min_value,maxf(bar.min_value,bar.max_value-bar.page))
        ui.journal_restore_pending=false
        if ui.has_node("JournalMarkDesk"):ui.get_node("JournalMarkDesk").refresh_launcher()
    if ui.bag_category=="旅记":
        var sources = preload("res://scripts/journal_sources.gd").links(String(ui.journal_current_document.get("key","")),ui.level.inventory_counts,ui.level.story_flags)
        ui.bag_pin.disabled=sources.is_empty()
        ui.bag_pin.text="回看来源 · %d条" % sources.size() if not sources.is_empty() else "PgUp/PgDn · LB/RB 翻页"
        ui.bag_pin.tooltip_text="回看本条引用的已知原始记录；关闭后回到原文。" if not sources.is_empty() else "Home 到开头，End 到末尾；切换记录后保留本次阅读位置。"
    if is_instance_valid(ui.journal_source_dialog):ui.journal_source_dialog.refresh_binding()


static func scroll_journal(ui: Node, step: int) -> void:
    if ui.bag_description==null:return
    var bar = ui.bag_description.get_v_scroll_bar()
    var maximum:=maxf(bar.min_value,bar.max_value-bar.page)
    if absi(step)==2:bar.value=bar.min_value if step<0 else maximum
    else:bar.value=clampf(bar.value+step*maxf(64.0,ui.bag_description.size.y*0.8),bar.min_value,maximum)
    ui._remember_journal_scroll()
