extends RefCounted
## Refreshing the build page, loadout restore and changes, entry details, craft cart and the save desk.
## Moved out of pilgrimage_interface.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func refresh_build(ui: Node) -> void:
    if ui.build_grid==null:return
    var system: Variant=ui.level.call("get_build_system") if ui.level!=null and ui.level.has_method("get_build_system") else null
    var snapshot: Dictionary = ui._build_snapshot()
    ui.last_build_signature=JSON.stringify(snapshot)
    for child in ui.build_grid.get_children():
        ui.build_grid.remove_child(child)
        child.queue_free()
    if snapshot.is_empty():
        ui.build_summary.text="行装系统尚未就绪"
        ui.build_detail.text="请从完整世界入口开始巡礼。"
        return
    var at_workstation: bool = ui._is_at_build_workstation(snapshot)
    var at_artisan = not at_workstation and ui.level!=null and ui.level.has_method("is_near_artisan") and bool(ui.level.call("is_near_artisan"))
    ui._sync_equipment_filter(at_workstation)
    var seal_page = at_workstation and ui.build_category=="契印"
    ui.build_art.visible=seal_page
    ui.build_art_caption.visible=seal_page
    ui.build_emblem.position=Vector2(645,188 if seal_page else 290)
    ui.build_heading.position=Vector2(710,188 if seal_page else 290)
    ui.build_detail.position=Vector2(646,245 if seal_page else 340)
    ui.build_detail.size=Vector2(418,280 if seal_page else 185)
    if not at_workstation and not at_artisan:
        for tab in ui.build_tabs:tab.hide()
        for button in ui.family_selector_buttons:button.hide()
        for button in ui.build_slot_buttons:button.hide()
        ui.clear_family_slot_button.hide()
        ui.resupply_preview_button.hide()
        ui.resupply_confirm_button.hide()
        ui.resupply_planner_button.hide()
        ui.build_summary.text="巡行配置 · 碎钱 %d" % int(ui.level.currency_count)
        ui.build_detail.text="在钟龛调整装备；校习找织线学徒、雨铸匠或蜂蜡商人。"
        var current_skill: String = ui._build_entry_name(system,"skills",String(snapshot.get("skill","")))
        var current_tool: String = ui._build_entry_name(system,"tools",String(snapshot.get("tool","")))
        var cycle_skill: Button = ui._button(ui.build_grid,"切换技能 · 当前 %s" % current_skill,Vector2.ZERO,Vector2(563,58),func():ui._perform_build_action("cycle_skill",""))
        cycle_skill.custom_minimum_size=Vector2(563,64)
        cycle_skill.focus_mode=Control.FOCUS_ALL
        var cycle_tool: Button = ui._button(ui.build_grid,"切换战具 · 当前 %s" % current_tool,Vector2.ZERO,Vector2(563,58),func():ui._perform_build_action("cycle_tool",""))
        cycle_tool.custom_minimum_size=Vector2(563,64)
        cycle_tool.focus_mode=Control.FOCUS_ALL
        var current_focus = ui.get_viewport().gui_get_focus_owner()
        if ui.build_panel.visible and (current_focus==null or not ui.build_panel.is_ancestor_of(current_focus)):cycle_skill.grab_focus()
        return
    if at_artisan and ui.build_category!="强化":
        ui.build_category="强化"
        ui.build_selection=""
    for tab in ui.build_tabs:tab.visible=not at_artisan or String(tab.get_meta("build_category",""))=="强化"
    if at_artisan:
        ui.build_summary.text="工匠 · 碎钱 %d · 校习技能 · 改制战具" % int(ui.level.currency_count)
    else:
        ui.build_summary.text="碎钱 %d · 饰品容量 %d / %d · %s" % [int(ui.level.currency_count),int(snapshot.get("slots_used",0)),int(snapshot.get("slots_total",0)),ui._all_family_count_summary(snapshot)]
    var family_id: String = ui._build_family_for_page()
    var slots = ui._family_slots(snapshot,family_id) if not family_id.is_empty() else []
    var has_typed_layout: bool=snapshot.get("slot_layout",{}).has(family_id) if snapshot.get("slot_layout",{}) is Dictionary and not family_id.is_empty() else false
    ui._ensure_family_slot_buttons(snapshot,family_id,slots) if has_typed_layout else ui._ensure_family_slot_buttons(snapshot,"",[])
    for index in ui.family_selector_buttons.size():
        var family_button: Button=ui.family_selector_buttons[index]
        var accessory_id: String=["combat_accessory","travel_accessory"][index]
        var family_info: Dictionary = ui._family_row(snapshot,accessory_id)
        family_button.text=String(family_info.get("name",accessory_id))
        family_button.visible=ui.build_category=="铭饰"
        family_button.add_theme_stylebox_override("normal",ui._tab_style(ui.build_family==accessory_id))
    ui.clear_family_slot_button.visible=has_typed_layout and not slots.is_empty()
    if ui.clear_family_slot_button.visible:
        var selected_slot: Dictionary=slots[ui.build_assign_slot]
        ui.clear_family_slot_button.disabled=not bool(selected_slot.get("unlocked",false)) or String(selected_slot.get("equipped_id","")).is_empty()
    var skill_family: Dictionary = ui._family_row(snapshot,"thread_skill")
    var tool_family: Dictionary = ui._family_row(snapshot,"tool")
    if not skill_family.is_empty():ui.build_tabs[1].text=String(skill_family.get("name","技能"))
    if not tool_family.is_empty():ui.build_tabs[2].text=String(tool_family.get("name","战具"))
    for index in ui.build_slot_buttons.size():
        if not has_typed_layout:ui.build_slot_buttons[index].visible=ui.build_category in ["技能","战具"] and index<2
    ui.craft_cart_button.visible=ui.build_category=="强化"
    ui.resupply_planner_button.visible=ui.build_category=="战具"
    ui.resupply_preview_button.visible=ui.build_category=="战具"
    ui.resupply_confirm_button.visible=ui.build_category=="战具"
    ui.resupply_confirm_button.disabled=ui.resupply_quote.is_empty() or not bool(ui.resupply_quote.get("ok",false))
    var entries: Array=[]
    var action:=""
    match ui.build_category:
        "契印":entries=snapshot.get("crests",[]);action="switch_crest"
        "技能":entries=ui._family_options(snapshot,"thread_skill");action="equip_family_slot"
        "战具":entries=ui._family_options(snapshot,"tool");action="equip_family_slot"
        "铭饰":entries=ui._family_options(snapshot,ui.build_family);action="equip_family_slot"
        "强化":
            entries=snapshot.get("recipes",[])
            action="transact"
            # E04: beside an artisan, that artisan's own 改制 come first.
            var here:=String(ui.level.call("near_artisan_id")) if at_artisan and ui.level.has_method("near_artisan_id") else ""
            if not here.is_empty():
                var own: Array=[]
                var rest: Array=[]
                for recipe in entries:(own if String(recipe.get("artisan",""))==here else rest).append(recipe)
                entries=own+rest
        "构筑":
            for id in ui._loadout_names(snapshot):
                var loadouts: Array=snapshot.get("loadouts",[])
                entries.append({"id":id,"name":id,"description":"保存当前契印、技能、战具和铭饰。恢复时仍会检查解锁与槽位条件。","unlocked":true,"exists":loadouts.has(id)})
    for tab in ui.build_tabs:tab.add_theme_stylebox_override("normal",ui._tab_style(String(tab.get_meta("build_category",""))==ui.build_category))
    if ui.equipment_search!=null and ui.equipment_search.visible:
        var selected_slot: Dictionary=slots[ui.build_assign_slot] if has_typed_layout and ui.build_assign_slot<slots.size() else {}
        var validator:=Callable()
        if system!=null and system.has_method("quote_family_slot"):
            validator=func(entry: Dictionary,family: String,slot: Dictionary):
                return bool(system.quote_family_slot(String(entry.get("id","")),family,int(slot.get("index",ui.build_assign_slot)),true).ok)
        var filtered = ui.equipment_filter.select(entries,family_id,selected_slot,ui.equipment_search.text,ui.equipment_compatible.button_pressed,validator)
        entries=filtered.entries
        ui.equipment_compatible.text="仅可装入此槽 · %d/%d" % [filtered.shown,filtered.total]
        if entries.is_empty():
            ui.build_heading.text="没有匹配装备"
            ui.build_detail.text=String(filtered.empty_reason)
            # A locked target slot still names what opens it, filter or not.
            if not selected_slot.is_empty() and not bool(selected_slot.get("unlocked",true)):
                for hint in ui._slot_unlock_hints(snapshot,selected_slot):ui.build_detail.text+="\n◇ "+hint
            ui.build_emblem.texture=null
    if entries.is_empty() and (ui.equipment_search==null or not ui.equipment_search.visible):ui.build_detail.text="此页暂无可用条目。"
    var first: Button
    for entry_value in entries:
        var entry: Dictionary=entry_value
        var id:=String(entry.get("id",entry.get("name","")))
        var text:=String(entry.get("name",id))
        if not bool(entry.get("unlocked",true)):text="◇ "+text+" · 未解锁"
        elif bool(entry.get("selected",false)):text="◆ "+text+" · 已装备"
        var equipped_slots: String = ui._entry_equipped_slots(snapshot,id)
        if not equipped_slots.is_empty():text+=" · 位置 "+equipped_slots
        if entry.has("cost"):text+=" · 容量 %d" % int(entry.cost)
        if entry.has("count"):
            text+=" · %d/%d 次" % [int(entry.count),int(entry.get("capacity",entry.count))]
            if int(entry.count)<=0:text+=" · 已用尽"
        if entry.get("branch","") is String and not String(entry.get("branch","")).is_empty():text+=" · 校习："+String(entry.get("branches",{}).get(String(entry.branch),{}).get("name",""))
        if String(entry.get("kind",""))=="skill_branch":
            if bool(entry.get("current",false)):text="◆ "+text+" · 当前方向"
            elif not ui._skill_practiced(String(entry.get("target",""))):text+=" · 需先练熟"
        elif String(entry.get("kind","")) in ["tool_capacity","slot_part","passive"]:
            if bool(entry.get("crafted",false)):text="◆ "+text+" · 已制作"
            else:
                text+=" · "+String(entry.get("artisan_name","工匠"))
                if not ui._has_patterns(entry):text+=" · 缺图样"
        var slot: Dictionary=slots[ui.build_assign_slot] if has_typed_layout and ui.build_assign_slot<slots.size() else {}
        var compatible: Array=slot.get("compatible",[]) if not slot.is_empty() else []
        var item_family:=String(entry.get("slot_family",family_id))
        var can_assign: bool=bool(entry.get("unlocked",true)) and (not has_typed_layout or (bool(slot.get("unlocked",false)) and item_family==family_id and (compatible.is_empty() or compatible.has(id))))
        if has_typed_layout:
            can_assign=can_assign and ui.equipment_filter.can_assign(entry,family_id,slot)
            if system!=null and system.has_method("quote_family_slot"):
                can_assign=bool(system.quote_family_slot(id,family_id,ui.build_assign_slot,true).ok)
        if has_typed_layout and not compatible.is_empty() and not compatible.has(id):text="× "+text+" · 不兼容"
        var button = ui._button(ui.build_grid,text,Vector2.ZERO,Vector2(563,54),func():
            ui.build_selection=id
            if not bool(entry.get("unlocked",true)):
                ui._show_build_detail(entry)
                return
            if has_typed_layout and not can_assign:
                ui._show_build_detail(entry)
                return
            if has_typed_layout:
                ui._perform_build_action("equip_family_slot",id,{"family":family_id,"slot":ui.build_assign_slot})
            else:
                var fallback_action: String=action
                if ui.build_category=="技能":fallback_action="select_skill"
                elif ui.build_category=="战具":fallback_action="select_tool"
                elif ui.build_category=="铭饰":fallback_action="equip_passive"
                if ui.build_category=="构筑":ui._open_loadout_restore(id)
                else:ui._perform_build_action(fallback_action,id,ui.build_assign_slot if ui.build_category in ["技能","战具"] else -1))
        button.custom_minimum_size=Vector2(563,64)
        if seal_page:
            button.custom_minimum_size=Vector2(230,66)
            button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
            button.set_meta("inscription_tab",true)
        button.alignment=HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_font_size_override("font_size",17)
        button.set_meta("build_id",id)
        button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        button.disabled=not can_assign and ui.build_category in ["技能","战具","铭饰"]
        var icon_path:="res://assets/ui/seals/%s.svg" % id
        if ResourceLoader.exists(icon_path):
            button.icon=load(icon_path)
            button.expand_icon=true
            button.add_theme_constant_override("icon_max_width",30)
        button.tooltip_text=String(entry.get("description",""))
        button.mouse_entered.connect(func():ui._show_build_detail(entry))
        button.focus_entered.connect(func():
            ui.build_selection=id
            ui._show_build_detail(entry))
        if bool(entry.get("selected",false)):button.add_theme_stylebox_override("normal",ui._style(Color(.2,.065,.055,.2),ui.RED,2))
        if first==null or id==ui.build_selection:first=button
        if ui.build_category=="构筑":
            var name_value:=id
            var preview: Dictionary = ui._loadout_quote(id)
            button.disabled=not bool(preview.get("can_restore",false))
            button.tooltip_text=String(preview.get("reason","可在钟龛恢复"))
            var save: Button = ui._button(ui.build_grid,("覆盖" if bool(entry.get("exists",false)) else "保存为")+"「%s」" % id,Vector2.ZERO,Vector2(563,36),func():ui._request_loadout_change("save_loadout",name_value))
            save.custom_minimum_size=Vector2(563,36)
            save.set_meta("build_id",id)
            save.focus_entered.connect(func():
                ui.build_selection=id
                ui._show_build_detail(entry))
            save.mouse_entered.connect(func():ui._show_build_detail(entry))
            if first==button and button.disabled:first=save
            button.text="恢复「%s」%s" % [id,"" if bool(entry.get("exists",false)) else " · 尚未保存"]
            if bool(entry.get("exists",false)):
                var remove: Button = ui._button(ui.build_grid,"删除「%s」" % id,Vector2.ZERO,Vector2(563,30),func():ui._request_loadout_change("delete_loadout",name_value))
                remove.custom_minimum_size=Vector2(563,30)
                remove.set_meta("loadout_delete",id)
                var manage: Button = ui._button(ui.build_grid,"重命名 / 复制「%s」" % id,Vector2.ZERO,Vector2(563,30),func():ui._open_loadout_manager(name_value))
                manage.custom_minimum_size=Vector2(563,30)
                manage.set_meta("loadout_manage",id)
    ui._wire_equipment_result_focus()
    if first!=null:
        var current_focus = ui.get_viewport().gui_get_focus_owner()
        if ui.build_panel.visible and (current_focus==null or not ui.build_panel.is_ancestor_of(current_focus)):first.grab_focus()
        for value in entries:
            if String(value.get("id",value.get("name","")))==ui.build_selection:
                ui._show_build_detail(value)
                return
        ui._show_build_detail(entries[0])


static func open_loadout_restore(ui: Node, name: String) -> void:
    if not ui.build_panel.is_visible_in_tree() or ui.build_category!="构筑":return
    if not ui.level.has_method("quote_loadout_restore") or not ui.level.has_method("apply_reviewed_loadout"):return
    if not is_instance_valid(ui.loadout_restore_dialog):
        ui.loadout_restore_dialog=preload("res://scripts/loadout_restore_dialog.gd").new()
        ui.build_panel.add_child(ui.loadout_restore_dialog)
        ui.register_text_entry_window(ui.loadout_restore_dialog)
        ui.build_panel.visibility_changed.connect(func():
            if not ui.build_panel.visible and is_instance_valid(ui.loadout_restore_dialog):ui.loadout_restore_dialog.hide())
    ui.loadout_restore_dialog.call("open",name,
        func(key: String):return ui.level.call("quote_loadout_restore",key),
        func(key: String,fingerprint: String):
            var result: Dictionary=ui.level.call("apply_reviewed_loadout",key,fingerprint)
            if result.get("ok",false):ui.refresh_build()
            return result,
        func(preview: Dictionary):return ui._loadout_difference_text(preview,ui.level.call("get_build_system")))


static func open_loadout_manager(ui: Node, source: String) -> void:
    if not ui.build_panel.is_visible_in_tree() or ui.build_category!="构筑" or not ui._is_at_build_workstation(ui._build_snapshot()):return
    if not is_instance_valid(ui.loadout_manager):
        ui.loadout_manager=preload("res://scripts/loadout_manager.gd").new()
        ui.build_panel.add_child(ui.loadout_manager)
        ui.register_text_entry_window(ui.loadout_manager)
        ui.build_panel.visibility_changed.connect(func():
            if not ui.build_panel.visible and is_instance_valid(ui.loadout_manager):ui.loadout_manager.hide())
    ui.loadout_manager.open(source,
        func(name: String, copy: bool):return ui.level.call("perform_build_action","quote_loadout_management",source,{"name":name,"copy":copy}),
        func(name: String, copy: bool):
            var result: Dictionary=ui.level.call("perform_build_action","copy_loadout" if copy else "rename_loadout",source,name)
            if bool(result.get("ok",false)):ui.build_selection=name
            ui.refresh_build()
            return result)


static func loadout_difference_text(ui: Node, preview: Dictionary, system: RefCounted) -> Array[String]:
    var lines: Array[String]=[]
    var family_names:={"thread_skill":"线技","tool":"战具","combat_accessory":"战斗铭饰","travel_accessory":"行旅铭饰"}
    for change in preview.get("changes",[]):
        if change.kind=="crest":
            lines.append("契印：%s → %s" % [system.catalog.crests.get(change.from,{}).get("name",change.from),system.catalog.crests.get(change.to,{}).get("name",change.to)])
        elif change.kind=="slot":
            var family:=String(change.family)
            var table:=String({"thread_skill":"skills","tool":"tools"}.get(family,"passives"))
            var before:=String(system.catalog[table].get(change.from,{}).get("name","空"))
            var after:=String(system.catalog[table].get(change.to,{}).get("name","空"))
            lines.append("%s%d：%s → %s" % [family_names.get(family,family),int(change.slot)+1,before,after])
        elif change.kind=="active":lines.append("%s：%d → %d" % ["活动线技" if change.field=="active_skill_slot" else "活动战具",int(change.from)+1,int(change.to)+1])
    if lines.is_empty():lines.append("装备与当前完全相同。")
    var before: Dictionary=preview.get("current_profile",{})
    var after: Dictionary=preview.get("profile",{})
    lines.append_array(preload("res://scripts/build_profile_comparison.gd").lines(before,after))
    return lines


static func loadout_names(ui: Node, snapshot: Dictionary) -> Array[String]:
    var result: Array[String]=[]
    for name in snapshot.get("loadouts",[]):
        if name is String and not result.has(name):result.append(name)
    for index in 8:
        var name:="巡礼方案 %d" % (index+1)
        if result.size()<8 and not result.has(name):result.append(name)
    result.sort()
    return result


static func request_loadout_change(ui: Node, action: String, name: String) -> void:
    if not ui.build_panel.is_visible_in_tree() or ui.build_category!="构筑":return
    if not ui._is_at_build_workstation(ui._build_snapshot()):return
    var exists: bool=ui._build_snapshot().get("loadouts",[]).has(name)
    if action=="save_loadout" and not exists:
        ui._perform_build_action(action,name)
        return
    if not exists or action not in ["save_loadout","delete_loadout"]:return
    if ui.loadout_dialog==null:
        ui.loadout_dialog=ConfirmationDialog.new()
        ui.add_child(ui.loadout_dialog)
        ui.loadout_dialog.confirmed.connect(ui._confirm_loadout_change)
        ui.loadout_dialog.canceled.connect(func():ui.pending_loadout_action="";ui.pending_loadout_name="")
    ui.pending_loadout_action=action
    ui.pending_loadout_name=name
    ui.loadout_dialog.title="覆盖构筑方案" if action=="save_loadout" else "删除构筑方案"
    ui.loadout_dialog.dialog_text=("用当前装备覆盖「%s」？旧方案将被替换。" if action=="save_loadout" else "删除「%s」？当前装备、资源和其它方案保留。") % name
    ui.loadout_dialog.get_ok_button().text="确认覆盖" if action=="save_loadout" else "确认删除"
    ui.loadout_dialog.get_cancel_button().text="保留原方案"
    ui.loadout_dialog.popup_centered(Vector2i(500,160))
    ui.loadout_dialog.get_cancel_button().grab_focus()


static func confirm_loadout_change(ui: Node) -> void:
    var action = ui.pending_loadout_action
    var name = ui.pending_loadout_name
    ui.pending_loadout_action=""
    ui.pending_loadout_name=""
    if not ui.build_panel.is_visible_in_tree() or ui.build_category!="构筑" or not ui._is_at_build_workstation(ui._build_snapshot()):return
    if action in ["save_loadout","delete_loadout"]:ui._perform_build_action(action,name)


static func build_entry_name(ui: Node, system: Variant, family: String, id: String) -> String:
    if id.is_empty():return "未配置"
    var entries: Dictionary=system.catalog.get(family,{}) if system!=null else {}
    var named:=String(entries.get(id,{}).get("name",""))
    return named if not named.is_empty() else "未配置"


static func entry_equipped_slots(ui: Node, snapshot: Dictionary, id: String) -> String:
    var family_id: String = ui._build_family_for_page()
    if family_id.is_empty():return ""
    var layout: Variant=snapshot.get("slot_layout",{})
    var family_slots: Array = ui._family_slots(snapshot,family_id)
    if layout is Dictionary and layout.has(family_id):
        var active_positions: Array[String]=[]
        var dormant_positions: Array[String]=[]
        for slot_value in family_slots:
            var slot: Dictionary=slot_value
            if String(slot.get("equipped_id",""))!=id:continue
            var position:=str(int(slot.get("index",0))+1)
            if ui._slot_dormancy_reason(slot,id).is_empty():active_positions.append(position)
            else:dormant_positions.append(position)
        var result:="/".join(active_positions)
        if not dormant_positions.is_empty():result+=(" · " if not result.is_empty() else "")+"休眠 "+"/".join(dormant_positions)
        return result
    var equipped: Array=[]
    for slot_value in family_slots:
        var slot: Dictionary=slot_value
        if String(slot.get("equipped_id",""))==id:equipped.append(int(slot.get("index",equipped.size())))
    if equipped.is_empty():
        var system: Variant=ui.level.call("get_build_system") if ui.level.has_method("get_build_system") else null
        if system!=null:
            if family_id=="thread_skill":equipped=system.state.get("skills",[])
            elif family_id=="tool":equipped=system.state.get("tools",[])
            else:equipped=system.state.get("passives",[])
    var slots: Array[String]=[]
    if equipped.size()>0 and equipped[0] is String:
        for index in equipped.size():
            if String(equipped[index])==id:slots.append(str(index+1))
    else:
        for index in equipped:slots.append(str(int(index)+1))
    return "/".join(slots)


static func loadout_quote(ui: Node, name: String) -> Dictionary:
    var system: Variant=ui.level.call("get_build_system")
    if system!=null and system.has_method("preview_loadout"):
        return system.preview_loadout(name,ui._is_at_build_workstation(ui._build_snapshot()))
    return {"can_restore":false,"reason":"方案预览尚未就绪"}


static func loadout_preview(ui: Node, build: Dictionary, system: RefCounted) -> String:
    var crest_id:=String(build.get("crest","crimson"))
    var lines: Array[String]=["契印："+String(system.catalog.crests.get(crest_id,{}).get("name",crest_id))]
    for field in ["skills","tools","passives"]:
        var table: String={"skills":"skills","tools":"tools","passives":"passives"}[field]
        var title: String={"skills":"技能","tools":"战具","passives":"铭饰"}[field]
        var names: Array[String]=[]
        for id in build.get(field,[]):names.append(String(system.catalog[table].get(id,{}).get("name","未装备")))
        lines.append(title+"："+(" / ".join(names) if not names.is_empty() else "未装备"))
    return "\n".join(lines)


static func show_build_detail(ui: Node, entry: Dictionary) -> void:
    if ui.build_art!=null and entry.has("slots"):
        ui.build_art.seal_id=String(entry.get("id","crimson"))
        ui.build_art.queue_redraw()
    var entry_name:=String(entry.get("name",entry.get("id","")))
    ui.build_heading.text=entry_name
    var icon_path:="res://assets/ui/seals/%s.svg" % String(entry.get("id",""))
    ui.build_emblem.texture=load(icon_path) if ResourceLoader.exists(icon_path) else null
    var lines: Array[String]=[String(entry.get("description",""))]
    var snapshot: Dictionary = ui._build_snapshot()
    var family_id: String = ui._build_family_for_page()
    if not family_id.is_empty() and snapshot.get("slot_layout",{}) is Dictionary and snapshot.slot_layout.get(family_id) is Array:
        var slots: Array=snapshot.slot_layout[family_id]
        var family_info: Dictionary = ui._family_row(snapshot,family_id)
        var family_names: Dictionary={"tool":"战具","combat_accessory":"战斗饰件","travel_accessory":"行旅饰件","thread_skill":"线技"}
        var family_name:=String(family_info.get("name",family_names.get(family_id,family_id)))
        lines.append("\n装备类别：%s" % family_name)
        lines.append(ui._family_count_summary(snapshot,family_id,slots))
        if ui.build_assign_slot<slots.size():
            var target_slot: Dictionary=slots[ui.build_assign_slot]
            var equipped_id:=String(target_slot.get("equipped_id",""))
            var current_entry: Dictionary = ui._family_entry(snapshot,family_id,equipped_id)
            lines.append("\n目标位置：%d · %s" % [ui.build_assign_slot+1,"已解锁" if bool(target_slot.get("unlocked",false)) else "未解锁"])
            lines.append("当前装备：%s" % String(current_entry.get("name",equipped_id if not equipped_id.is_empty() else "空")))
            if not bool(target_slot.get("unlocked",false)):
                lines.append("该槽位尚未解锁，无法装备。")
                for hint in ui._slot_unlock_hints(snapshot,target_slot):lines.append("◇ "+hint)
            var compatible: Array=target_slot.get("compatible",[])
            if not compatible.is_empty():lines.append("兼容条目："+"、".join(ui._family_option_names(snapshot,family_id,compatible)))
            if not compatible.is_empty() and not compatible.has(String(entry.get("id",""))):
                lines.append("此条目与目标位置不兼容，装备请求会被拒绝。")
            if entry.has("cost"):
                var used:=int(snapshot.get("slots_used",0))
                var total:=int(snapshot.get("slots_total",0))
                var old_cost:=int(current_entry.get("cost",0))
                var projected:=used-old_cost+int(entry.cost)
                lines.append("容量比较：当前 %d / %d · 替换后 %d / %d" % [used,total,projected,total])
    if ui.build_category=="构筑":
        var system: Variant=ui.level.call("get_build_system")
        lines.append("\n当前整体配置\n"+ui._loadout_preview(system.state,system))
        var saved_value: Variant=system.state.loadouts.get(String(entry.get("id","")),{})
        var saved_build: Dictionary=saved_value if saved_value is Dictionary else {}
        if not saved_build.is_empty():lines.append("\n已保存配置\n"+ui._loadout_preview(saved_build,system))
        var preview: Dictionary = ui._loadout_quote(String(entry.get("id","")))
        lines.append("\n恢复条件："+("可以恢复 · 不花碎钱或材料" if bool(preview.get("can_restore",false)) else String(preview.get("reason","当前不可恢复"))))
        if bool(preview.get("ok",false)):lines.append("\n实际变化\n"+"\n".join(ui._loadout_difference_text(preview,system)))
        var projected: Dictionary=preview.get("profile",{})
        if not projected.is_empty():
            lines.append("生命上限：%d → %d" % [int(ui.level.player.max_hp),int(projected.get("max_hp",ui.level.player.max_hp))])
            lines.append("绯线上限：%d → %d" % [int(ui.level.player.max_energy),int(projected.get("max_energy",ui.level.player.max_energy))])
            lines.append("地面移动：%d%% → %d%%" % [int(round(float(ui.level.player.build_profile.get("move_mult",1.0))*100)),int(round(float(projected.get("move_mult",1.0))*100))])
        lines.append("恢复不补充生命、绯线或次数，不清空冷却；超出新上限的生命与绯线会截断。")
    if entry.has("mechanism_unlocked") and not bool(entry.mechanism_unlocked):lines.append("\n◇ 专属机制尚未修复：基础战斗与永久探索能力仍可使用，完成来源委托后启用。")
    if entry.has("slots"):
        for crest in snapshot.get("crests",[]):
            if String(crest.get("id",""))!=String(snapshot.get("crest","")):continue
            lines.append("\n契印基础值 · 当前 → 所选")
            for pair in [["slots","铭饰槽"],["max_hp","生命"],["max_energy","绯线容量"],["heal_cost","治疗耗能"],["heal_amount","治疗恢复"]]:
                lines.append("%s：%s → %s" % [pair[1],str(crest.get(pair[0],0)),str(entry.get(pair[0],0))])
            lines.append("治疗时间：%.2f → %.2f 秒" % [float(crest.get("heal_duration",0)),float(entry.get("heal_duration",0))])
            lines.append("铭饰效果在装备后合并计算。")
    if String(entry.get("kind",""))=="skill_branch" and entry.has("target"):
        for skill in snapshot.get("skills",[]):
            if String(skill.get("id",""))==String(entry.target):
                lines.append_array(ui._skill_branch_lines(skill,entry))
    if String(entry.get("kind","")) in ["tool_capacity","slot_part","passive"]:lines.append_array(ui._craft_lines(entry,snapshot))
    if not bool(entry.get("unlocked",true)):
        var unlock_hint:=String(entry.get("unlock_hint","继续探索、完成委托或挑战后获得。"))
        if not String(entry.get("unlock_item","")).is_empty():unlock_hint="需要取得「%s」。" % ui.level._item_display_name(String(entry.unlock_item))
        lines.append("\n尚未解锁 · "+unlock_hint)
    for field in [["source","来源"],["attack_description","攻击"],["mechanism","专属机制"],["heal_effect","治疗完成"],["risk","动作风险与代价"],["synergy","契印协同"],["practice","练习"],["encounter","适合遭遇"]]:
        if entry.has(field[0]):lines.append("\n%s：%s" % [field[1],str(entry[field[0]])])
    if not family_id.is_empty():lines.append("\n确认后装备到所选位置 %d；上方按钮选择位置。" % (ui.build_assign_slot+1))
    if ui.build_category=="战具":lines.append("补给需碎钱与材料；换装不会补充次数。")
    if entry.has("cost"):
        var used:=int(snapshot.get("slots_used",0))
        var total:=int(snapshot.get("slots_total",0))
        if not bool(entry.get("selected",false)) and used+int(entry.cost)>total:lines.append("◇ 容量不足：需要 %d，剩余 %d。" % [int(entry.cost),maxi(0,total-used)])
    if entry.has("energy_cost"):lines.append("\n消耗绯线：%d" % int(entry.energy_cost))
    if entry.has("cooldown"):lines.append("冷却：%.1f 秒" % float(entry.cooldown))
    if entry.has("cost"):lines.append("铭饰容量消耗：%d；再次确认可卸下。" % int(entry.cost))
    if entry.has("count"):lines.append("剩余携带：%d / %d" % [int(entry.count),int(entry.get("capacity",entry.count))])
    if entry.has("count") and int(entry.count)<=0:lines.append("\n当前携带量为零，不能使用此战具；可在钟龛先查看补给报价，再单独确认购买。")
    elif entry.has("count") and int(entry.count)<int(entry.get("capacity",entry.count)):lines.append("\n携带量不足上限；可在钟龛购买部分补给。")
    if int(entry.get("currency",0))>0:lines.append("\n制作费用：%d 碎钱" % int(entry.currency))
    if entry.has("materials"):
        var materials: Dictionary=entry.materials
        for material in materials:lines.append("材料 %s：需要 %d / 持有 %d" % [ui.level._item_display_name(String(material)),int(materials[material]),int(ui.level.inventory_counts.get(material,0))])
    if bool(entry.get("selected",false)):lines.append("\n当前已装备。")
    ui.build_detail.text="\n".join(lines)


static func open_craft_cart(ui: Node) -> void:
    if ui.level==null or not ui.build_panel.visible:return
    if not is_instance_valid(ui.craft_cart):
        ui.craft_cart=preload("res://scripts/craft_cart.gd").new()
        ui.build_panel.add_child(ui.craft_cart)
        ui.craft_cart.setup(ui)
        ui.register_text_entry_window(ui.craft_cart)
        ui.build_panel.visibility_changed.connect(func():
            if not ui.build_panel.visible and is_instance_valid(ui.craft_cart):ui.craft_cart.hide())
    ui.craft_cart.open()


static func perform_build_action(ui: Node, action: String, id: String, extra: Variant = -1) -> void:
    if ui.level==null or not ui.level.has_method("perform_build_action"):return
    var result: Variant=ui.level.call("perform_build_action",action,id,extra)
    ui.refresh_build()
    if result is Dictionary:
        var message:=String(result.get("reason","已完成" if bool(result.get("ok",false)) else "条件不足"))
        if message.is_empty():message="构筑已更新并保存。" if bool(result.get("ok",false)) else "当前条件不足。"
        ui.toast.text=message
        ui.toast_age=0.0
        ui.build_detail.text+="\n\n"+message


static func open_save_desk(ui: Node, slot: int, action: String) -> void:
    if not is_instance_valid(ui.save_desk):
        ui.save_desk=preload("res://scripts/save_desk.gd").new()
        ui.settings.add_child(ui.save_desk);ui.save_desk.setup(ui);ui.register_text_entry_window(ui.save_desk)
        ui.settings.visibility_changed.connect(func():
            if not ui.settings.visible and is_instance_valid(ui.save_desk):ui.save_desk.hide())
    ui.save_desk.open(slot,action)


static func select_save_slot(ui: Node, slot: int) -> void:
    if ui.level.has_method("quote_save_operation"):ui._open_save_desk(slot,"switch");return
    if not ui.level.has_method("select_save_slot"):
        ui.remap_status.text="当前入口尚未支持多存档。"
        return
    var result: bool=ui.level.call("select_save_slot",slot)
    ui.remap_status.text="已切换到存档槽 %d。" % slot if result else "存档切换失败；当前进度未被覆盖。"


static func restore_save_backup(ui: Node) -> void:
    if ui.level.has_method("quote_save_operation"):ui._open_save_desk(ui.level.world_slot,"recover");return
    if not ui.level.has_method("restore_save_backup"):
        ui.remap_status.text="当前入口尚未支持备份恢复。"
        return
    var result: bool=ui.level.call("restore_save_backup")
    ui.remap_status.text="已恢复当前槽备份。" if result else "未找到可恢复的有效备份。"


static func show_journey_history(ui: Node) -> void:
    if ui.level == null or not ui.level.has_method("get_journey_history"):return
    if ui.journey_history_dialog == null:
        ui.journey_history_dialog=preload("res://scripts/journey_history_browser.gd").new()
        ui.add_child(ui.journey_history_dialog)
        ui.journey_history_text=ui.journey_history_dialog.get("summary_text")
        ui.journey_history_dialog.confirmed.connect(ui._journey_history_closed)
        ui.journey_history_dialog.canceled.connect(ui._journey_history_closed)
    ui.journey_history_dialog.call("open",func(offset: int,limit: int):
        if not is_instance_valid(ui.level):return {}
        if ui.level.has_method("get_journey_history_page"):return ui.level.get_journey_history_page(offset,limit)
        return ui.level.get_journey_history(),
        func(file: String,sha: String):
            if is_instance_valid(ui.level) and ui.level.has_method("get_journey_archive_detail"):
                return ui.level.get_journey_archive_detail(file,sha)
            return {"ok":false,"reason":"当前入口尚未支持归档详情。"},
        func(file: String,sha: String):
            if is_instance_valid(ui.level):
                return preload("res://scripts/journey_archive_comparison.gd").inspect(String(ui.level.world_save_path),file,sha)
            return {"ok":false,"reason":"当前旅途已退出，请重新打开。"})


static func journey_history_closed(ui: Node) -> void:
    ui.journey_history_close_frame=Engine.get_process_frames()
    ui.journey_history_button.grab_focus()


static func is_browsing_journey_history(ui: Node) -> bool:
    return (ui.journey_history_dialog != null and ui.journey_history_dialog.visible) or ui.journey_history_close_frame==Engine.get_process_frames()


static func refresh_save_slots(ui: Node) -> void:
    if not ui.level.has_method("get_save_slots"):return
    for value in ui.level.call("get_save_slots"):
        var entry: Dictionary=value
        var slot:=int(entry.get("slot",0))
        if not ui.save_slot_buttons.has(slot):continue
        var button: Button=ui.save_slot_buttons[slot]
        var status:="新旅途"
        if bool(entry.get("exists",false)):
            status="%d%% · %s" % [int(entry.get("completion",0)),preload("res://scripts/journey_progress.gd").clock_text(int(entry.get("play_seconds",0)))] if bool(entry.get("valid",false)) else "记录损坏"
        button.text="槽 %d · %s" % [slot,status]
        button.tooltip_text="读取失败：%s。原文件会保留，请恢复备份。" % String(entry.get("error","未知错误")) if bool(entry.get("exists",false)) and not bool(entry.get("valid",false)) else "切换前会保存当前进度。" if not bool(entry.get("exists",false)) else "完成度 %d%% · 游玩 %s\n%d 区 · %d 钱" % [int(entry.get("completion",0)),preload("res://scripts/journey_progress.gd").clock_text(int(entry.get("play_seconds",0))),int(entry.get("regions",0)),int(entry.get("currency",0))]
