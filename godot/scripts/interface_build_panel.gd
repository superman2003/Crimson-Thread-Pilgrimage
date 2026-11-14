extends RefCounted
## The build page frame: equipment filters, family slots and their dormancy hints, craft lines and tool resupply.
## Moved out of pilgrimage_interface.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CHROME := preload("res://scripts/pilgrimage_chrome.gd")
const TYPE := preload("res://scripts/ui_type_scale.gd")

static func build_build_panel(ui: Node) -> void:
    ui.build_panel=ui._panel(ui,"契印与构筑",Vector2(85,54),Vector2(1110,600))
    ui.build_panel.name="BuildOverlay"
    ui._well(ui.build_panel,Vector2(627,174),Vector2(457,368))
    ui._well(ui.build_panel,Vector2(26,174),Vector2(588,368))
    ui.build_art=CHROME.new()
    ui.build_art.kind="seal_art"
    ui.build_art.position=Vector2(288,192)
    ui.build_art.size=Vector2(309,309)
    ui.build_panel.add_child(ui.build_art)
    ui.build_art_caption=ui._label(ui.build_panel,"以线缝名，借势出针。",Vector2(278,508),Vector2(332,28),18,ui.GOLD)
    ui.build_art_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    ui.build_summary=ui._label(ui.build_panel,"",Vector2(34,101),Vector2(860,26),16,ui.GOLD)
    # Keep the six established pages while exposing both accessory families
    # through an explicit selector inside the 铭饰 page.
    var categories: Array[String]=["契印","技能","战具","铭饰","强化","构筑"]
    for i in categories.size():
        var category:=categories[i]
        var tab = ui._button(ui.build_panel,category,Vector2(34+i*173,135),Vector2(162,38),func():
            ui.build_category=category
            ui.build_selection=""
            if category=="铭饰":ui.build_family="combat_accessory"
            ui.refresh_build())
        tab.set_meta("build_category",category)
        tab.set_meta("inscription_tab",true)
        tab.add_theme_font_size_override("font_size",21)
        ui.build_tabs.append(tab)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(34,180)
    scroll.size=Vector2(575,352)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    ui.build_panel.add_child(scroll)
    ui.equipment_scroll=scroll
    ui.build_grid=VBoxContainer.new()
    ui.build_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    ui.build_grid.add_theme_constant_override("separation",8)
    scroll.add_child(ui.build_grid)
    ui.equipment_search=LineEdit.new()
    ui.equipment_search.position=Vector2(34,180)
    ui.equipment_search.size=Vector2(340,28)
    ui.equipment_search.max_length=ui.equipment_filter.QUERY_LIMIT
    ui.equipment_search.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.equipment_search.placeholder_text="搜索此类已知装备"
    ui.equipment_search.clear_button_enabled=true
    ui.equipment_search.tooltip_text="按装备名称搜索。搜索与筛选不会执行装备操作或消耗资源。"
    ui.build_panel.add_child(ui.equipment_search)
    ui.equipment_compatible=CheckBox.new()
    ui.equipment_compatible.position=Vector2(384,180)
    ui.equipment_compatible.size=Vector2(225,28)
    ui.equipment_compatible.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.equipment_compatible.text="仅可装入此槽"
    ui.equipment_compatible.tooltip_text="只显示已解锁且兼容当前所选槽位的装备。"
    ui.build_panel.add_child(ui.equipment_compatible)
    ui.equipment_search.focus_neighbor_right=ui.equipment_search.get_path_to(ui.equipment_compatible)
    ui.equipment_compatible.focus_neighbor_left=ui.equipment_compatible.get_path_to(ui.equipment_search)
    ui.equipment_search.text_changed.connect(func(_text: String):ui._equipment_filter_changed())
    ui.equipment_compatible.toggled.connect(func(_enabled: bool):ui._equipment_filter_changed())
    ui.equipment_search.text_submitted.connect(func(_text: String):
        var first = ui.equipment_filter.first_enabled(ui.build_grid)
        if first!=null:first.grab_focus())
    ui.build_detail=RichTextLabel.new()
    for family in ["combat_accessory","travel_accessory"]:
        var family_id:=String(family)
        var family_button = ui._button(ui.build_panel,family_id,Vector2(640+ui.family_selector_buttons.size()*216,174),Vector2(207,33),func():
            ui.build_family=family_id
            ui.build_assign_slot=0
            ui.build_selection=""
            ui.refresh_build())
        ui.family_selector_buttons.append(family_button)
    ui.clear_family_slot_button=ui._button(ui.build_panel,"卸下此槽装备",Vector2(640,252),Vector2(207,30),func():
        var family_id: String = ui._build_family_for_page()
        if family_id.is_empty():return
        ui._perform_build_action("equip_family_slot","",{"family":family_id,"slot":ui.build_assign_slot}))
    ui.clear_family_slot_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.build_emblem=ui._icon(ui.build_panel,null,Vector2(645,290),Vector2(48,48))
    ui.build_heading=ui._label(ui.build_panel,"",Vector2(710,290),Vector2(350,45),23,ui.GOLD)
    ui.build_detail.position=Vector2(646,340)
    ui.build_detail.size=Vector2(418,185)
    ui.build_detail.add_theme_font_size_override("normal_font_size",18)
    ui.build_detail.add_theme_color_override("default_color",ui.IVORY)
    ui.build_detail.scroll_active=true
    ui.build_panel.add_child(ui.build_detail)
    ui.resupply_preview_button=ui._button(ui.build_panel,"查看补给报价",Vector2(640,535),Vector2(200,30),ui._preview_tool_resupply)
    ui.resupply_confirm_button=ui._button(ui.build_panel,"确认购买补给",Vector2(850,535),Vector2(220,30),ui._confirm_tool_resupply)
    ui.resupply_preview_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.resupply_confirm_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.resupply_confirm_button.disabled=true
    ui.resupply_planner_button=ui._button(ui.build_panel,"按需与优先补给",Vector2(640,570),Vector2(430,26),ui._open_resupply_planner)
    ui.resupply_planner_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.craft_cart_button=ui._button(ui.build_panel,"多件制作清单",Vector2(640,535),Vector2(430,30),ui._open_craft_cart)
    ui.craft_cart_button.add_theme_font_size_override("font_size",14)
    ui._label(ui.build_panel,"确认键执行  ·  Esc 返回",Vector2(150,561),Vector2(470,13),11,ui.MUTED)


static func request_build_toggle(ui: Node) -> void:
    if ui.level!=null and ui.level.active_overlay!="new_journey" and ui.level.has_method("_toggle_build"):ui.level.call("_toggle_build")


static func wire_equipment_result_focus(ui: Node) -> void:
    if ui.equipment_search==null or not ui.equipment_search.visible:return
    var first = ui.equipment_filter.first_enabled(ui.build_grid)
    ui.equipment_search.focus_neighbor_bottom=NodePath() if first==null else ui.equipment_search.get_path_to(first)
    ui.equipment_compatible.focus_neighbor_bottom=NodePath() if first==null else ui.equipment_compatible.get_path_to(first)
    if first!=null:first.focus_neighbor_top=first.get_path_to(ui.equipment_search)


static func equipment_filter_changed(ui: Node) -> void:
    var family: String = ui._build_family_for_page()
    if family.is_empty() or ui.equipment_search==null:return
    ui.equipment_filter.remember(family,ui.equipment_search.text,ui.equipment_compatible.button_pressed)
    ui.refresh_build()


static func sync_equipment_filter(ui: Node, at_workstation: bool) -> void:
    if ui.equipment_search==null:return
    var family: String = ui._build_family_for_page()
    var shown = at_workstation and not family.is_empty()
    ui.equipment_search.visible=shown
    ui.equipment_compatible.visible=shown
    var row_height:=maxf(32.0,maxf(ui.equipment_search.get_combined_minimum_size().y,ui.equipment_compatible.get_combined_minimum_size().y))
    ui.equipment_search.size.y=row_height
    ui.equipment_compatible.size.y=row_height
    var list_top = 180.0+row_height+8.0 if shown else 180.0
    ui.equipment_scroll.position=Vector2(34,list_top)
    ui.equipment_scroll.size=Vector2(575,532.0-list_top)
    if not shown:return
    var memory = ui.equipment_filter.page(family)
    var blocked = ui.equipment_search.is_blocking_signals()
    ui.equipment_search.set_block_signals(true)
    if ui.equipment_search.text!=String(memory.query):ui.equipment_search.text=String(memory.query)
    ui.equipment_search.set_block_signals(blocked)
    ui.equipment_compatible.set_pressed_no_signal(bool(memory.only_compatible))


static func toggle_build(ui: Node) -> void:
    ui.build_panel.visible=not ui.build_panel.visible
    if ui.build_panel.visible:ui.refresh_build()


static func close_build(ui: Node) -> void:
    ui.build_panel.visible=false


static func build_snapshot(ui: Node) -> Dictionary:
    if ui.level==null or not ui.level.has_method("get_build_system"):return {}
    var system: Variant=ui.level.call("get_build_system")
    if system==null or not system.has_method("get_snapshot"):return {}
    var snapshot: Dictionary=system.call("get_snapshot")
    # Live cooldown belongs in HUD; it must not rebuild a focused menu every tick.
    for skill in snapshot.get("skills",[]):skill.erase("cooldown_remaining")
    return snapshot


static func is_at_build_workstation(ui: Node, snapshot: Dictionary) -> bool:
    if snapshot.has("at_workstation"):
        return bool(snapshot.at_workstation)
    if ui.level.has_method("is_near_shrine"):
        return bool(ui.level.call("is_near_shrine"))
    # Legacy/demo adapters have no location state. The production adapter
    # supplies the authoritative live snapshot field above.
    return not ui.level.has_method("_near_workstation") or bool(ui.level.call("_near_workstation"))


static func skill_practiced(ui: Node, skill_id: String) -> bool:
    var flags: Variant=ui.level.get("story_flags") if ui.level!=null else null
    # Fixture adapters without story state are not gated.
    if not flags is Dictionary:return true
    return bool(flags.get("skill_practiced_"+skill_id,false))


static func has_patterns(ui: Node, recipe: Dictionary) -> bool:
    var counts: Variant=ui.level.get("inventory_counts") if ui.level!=null else null
    if not counts is Dictionary:return true
    for item in recipe.get("requires_items",[]):
        if int(counts.get(item,0))<=0:return false
    return true


static func craft_lines(ui: Node, entry: Dictionary, snapshot: Dictionary) -> Array:
    var lines: Array=[]
    if bool(entry.get("crafted",false)):lines.append("\n◆ 已制作；每件只做一次。")
    if String(entry.get("kind",""))=="tool_capacity":
        var tool_name:=String(entry.get("target",""))
        for tool in snapshot.get("tools",[]):
            if String(tool.get("id",""))==tool_name:tool_name=String(tool.get("name",tool_name))
        var now:=int(entry.get("capacity_now",0))
        if bool(entry.get("crafted",false)):lines.append("%s 携带上限：%d（含改制 +%d）" % [tool_name,now,int(entry.get("amount",1))])
        else:lines.append("\n%s 携带上限：%d → %d" % [tool_name,now,now+int(entry.get("amount",1))])
        lines.append("改制不附带次数；多出的一份在钟龛按原价补给。")
        if not bool(entry.get("target_unlocked",true)):lines.append("◇ 先取得%s，工匠才能改制。" % tool_name)
    elif String(entry.get("kind",""))=="slot_part":
        lines.append("\n解锁：三枚契印的第 3 个行旅铭饰槽。各契印仍需先修复自己的专属机制。")
    elif String(entry.get("kind",""))=="passive":
        lines.append("制作后在钟龛选择铭饰槽装备；不会自动穿戴或补充生命、绯线。")
    var counts: Variant=ui.level.get("inventory_counts") if ui.level!=null else {}
    for item in entry.get("requires_items",[]):
        var owned: bool=counts is Dictionary and int(counts.get(item,0))>0
        var item_name:=String(ui.level.call("_item_display_name",String(item))) if ui.level!=null and ui.level.has_method("_item_display_name") else String(item)
        lines.append("图样「%s」：%s" % [item_name,"已取得，制作时只给工匠看，不会收走" if owned else "未取得"])
        if not owned:lines.append("◇ "+String(entry.get("unlock_hint","")))
    var flags: Variant=ui.level.get("story_flags") if ui.level!=null else null
    var flag:=String(entry.get("requires_flag",""))
    if not flag.is_empty() and flags is Dictionary and not bool(flags.get(flag,false)):lines.append("◇ "+String(entry.get("requires_flag_hint","")))
    var artisan_name:=String(entry.get("artisan_name","工匠"))
    lines.append("制作者：%s" % artisan_name)
    if ui.level!=null and ui.level.has_method("near_artisan_id") and String(ui.level.call("near_artisan_id"))!=String(entry.get("artisan","")):
        lines.append("◇ 要到%s面前才能制作。" % artisan_name)
    return lines


static func skill_branch_lines(ui: Node, skill: Dictionary, recipe: Dictionary) -> Array:
    var lines: Array=[]
    var branches: Dictionary=skill.get("branches",{})
    var key:="a" if int(recipe.get("branch",1))==1 else "b"
    var other:="b" if key=="a" else "a"
    var current:=String(skill.get("branch",""))
    lines.append("\n%s · 当前：%s" % [String(skill.get("name","")),String(branches.get(current,{}).get("name","未校习")) if not current.is_empty() else "未校习"])
    lines.append("「%s」的改变：" % String(branches.get(key,{}).get("name","")))
    var labels:={"damage":"伤害","range":"距离","windup":"起手（秒）","recovery":"收势（秒）","duration":"持续（秒）","energy_cost":"绯线消耗","stagger":"踉跄（秒）"}
    var modifiers: Dictionary=branches.get(key,{}).get("modifiers",{})
    for stat in modifiers:
        var delta:=float(modifiers[stat])
        var amount:=str(int(delta)) if is_equal_approx(delta,roundf(delta)) else "%.2f" % delta
        lines.append("  %s %s%s" % [String(labels.get(stat,stat)),"+" if delta>0.0 else "",amount])
    lines.append("另一方向「%s」：%s" % [String(branches.get(other,{}).get("name","")),String(branches.get(other,{}).get("description",""))])
    lines.append("两个方向只能取其一；之后改选另一方向需再付全价。")
    if not ui._skill_practiced(String(recipe.get("target",""))):
        lines.append("◇ 先在练针架上用这个技能命中三次，练熟后才能选方向。")
    if ui.level!=null and ui.level.has_method("is_near_artisan") and not bool(ui.level.call("is_near_artisan")):
        lines.append("◇ 校习要与织线学徒、雨铸匠或蜂蜡商人面对面进行。")
    return lines


static func family_row(ui: Node, snapshot: Dictionary, family_id: String) -> Dictionary:
    var families: Variant=snapshot.get("slot_families",{})
    if families is Dictionary and families.get(family_id) is Dictionary:return families[family_id]
    if families is Array:
        for value in families:
            if value is Dictionary and String(value.get("id",""))==family_id:return value
    return {}


static func family_slots(ui: Node, snapshot: Dictionary, family_id: String) -> Array:
    var layout: Variant=snapshot.get("slot_layout",{})
    if layout is Dictionary and layout.get(family_id) is Array:return layout[family_id]
    var row: Dictionary = ui._family_row(snapshot,family_id)
    return row.get("slots",[]) if row.get("slots",[]) is Array else []


static func slot_unlock_hints(ui: Node, snapshot: Dictionary, slot: Dictionary) -> Array[String]:
    var hints: Array[String]=[]
    var mechanism:=String(slot.get("requires_mechanism",""))
    if not mechanism.is_empty():
        for crest in snapshot.get("crests",[]):
            if crest is Dictionary and String(crest.get("id",""))==mechanism and not bool(crest.get("mechanism_unlocked",false)):
                hints.append("需要唤醒「%s」的契印机制：%s" % [String(crest.get("name",mechanism)),String(crest.get("source","完成该契印的委托"))])
    if not bool(slot.get("part_ready",true)):
        var part_entry: Dictionary={}
        for recipe in snapshot.get("recipes",[]):
            if recipe is Dictionary and String(recipe.get("id",""))==String(slot.get("part_recipe","")):part_entry=recipe
        hints.append("需要工匠制作「%s」（%s）。" % [String(part_entry.get("name","承力扣")),String(part_entry.get("artisan_name","工匠"))])
    return hints


static func slot_dormancy_reason(ui: Node, slot: Dictionary, item_id: String) -> String:
    if item_id.is_empty():return ""
    if not bool(slot.get("unlocked",true)):return "槽位未解锁"
    var compatible: Array=slot.get("compatible",[])
    if not compatible.is_empty() and not compatible.has(item_id):return "装备与槽位不兼容"
    return ""


static func family_slot_dormancy_reason(ui: Node, snapshot: Dictionary,family_id: String,slot_index: int,item_id: String) -> String:
    if item_id.is_empty():return ""
    for slot_value in ui._family_slots(snapshot,family_id):
        var slot: Dictionary=slot_value
        if int(slot.get("index",-1))==slot_index:return ui._slot_dormancy_reason(slot,item_id)
    return ""


static func family_options(ui: Node, snapshot: Dictionary, family_id: String) -> Array:
    var row: Dictionary = ui._family_row(snapshot,family_id)
    var options: Variant=row.get("options",[])
    if options is Array and not options.is_empty():return options
    var legacy_key: String={"tool":"tools","thread_skill":"skills","combat_accessory":"passive_options","travel_accessory":"passive_options"}.get(family_id,"")
    return snapshot.get(legacy_key,[]) if not legacy_key.is_empty() else []


static func build_family_for_page(ui: Node) -> String:
    match ui.build_category:
        "技能":return "thread_skill"
        "战具":return "tool"
        "铭饰":return ui.build_family
    return ""


static func family_entry(ui: Node, snapshot: Dictionary, family_id: String, id: String) -> Dictionary:
    for value in ui._family_options(snapshot,family_id):
        if value is Dictionary and String(value.get("id",""))==id:return value
    return {}


static func family_option_names(ui: Node, snapshot: Dictionary,family_id: String,ids: Array) -> Array[String]:
    var names: Array[String]=[]
    for value in ids:
        var id:=String(value)
        var entry: Dictionary=ui._family_entry(snapshot,family_id,id)
        names.append(String(entry.get("name",id)))
    return names


static func ensure_family_slot_buttons(ui: Node, snapshot: Dictionary, family_id: String, slots: Array) -> void:
    if not slots.is_empty():ui.build_assign_slot=clampi(ui.build_assign_slot,0,slots.size()-1)
    while ui.build_slot_buttons.size()<slots.size():
        var slot_index = ui.build_slot_buttons.size()
        var button = ui._button(ui.build_panel,"",Vector2.ZERO,Vector2(207,33),func():
            ui.build_assign_slot=slot_index
            ui.refresh_build())
        ui.build_slot_buttons.append(button)
    while ui.build_slot_buttons.size()>slots.size():
        var old: Button=ui.build_slot_buttons.pop_back()
        old.queue_free()
    var offset_y = 212 if ui.build_category=="铭饰" else 174
    var slot_left:=640.0
    var slot_gap:=8.0
    var slot_width:=minf(207.0,(float(ui.build_panel.size.x)-26.0-slot_left-slot_gap*maxi(0,slots.size()-1))/maxi(1,slots.size()))
    var options: Array = ui._family_options(snapshot,family_id)
    for index in ui.build_slot_buttons.size():
        var slot: Dictionary=slots[index]
        var button: Button=ui.build_slot_buttons[index]
        button.position=Vector2(slot_left+index*(slot_width+slot_gap),offset_y)
        button.size.x=slot_width
        button.custom_minimum_size.x=slot_width
        button.visible=true
        var equipped_id:=String(slot.get("equipped_id",""))
        var equipped: Dictionary = ui._family_entry(snapshot,family_id,equipped_id)
        var dormant_reason: String = ui._slot_dormancy_reason(slot,equipped_id)
        var label:=String(slot.get("name","位置 %d" % (index+1)))
        if label.is_empty():label="位置 %d" % (index+1)
        if not bool(slot.get("unlocked",true)):label="🔒 "+label
        if not equipped_id.is_empty():
            label+=" · "+String(equipped.get("name",equipped_id))
            if not dormant_reason.is_empty():label+=" · 休眠"
        else:label+=" · 空"
        button.text=("▶ " if index==ui.build_assign_slot else "○ ")+label
        button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        # A locked slot stays focusable so a controller can select it and read
        # its unlock condition in the detail panel; every catalog option is
        # disabled while it is the target, so nothing can be equipped into it.
        var locked:=not bool(slot.get("unlocked",true))
        button.disabled=false
        button.modulate=ui.LOCKED_CONTROL_TINT if locked else ui.NORMAL_CONTROL_TINT
        var compatible_ids: Array=slot.get("compatible",[])
        var compatible_names: Array[String] = ui._family_option_names(snapshot,family_id,compatible_ids)
        var tooltip:=label+"\n"
        if locked:
            tooltip+="此槽位尚未解锁"
            for hint in ui._slot_unlock_hints(snapshot,slot):tooltip+="\n◇ "+hint
            if not dormant_reason.is_empty():tooltip+="\n休眠装备："+String(equipped.get("name",equipped_id))+"\n未激活："+dormant_reason
        else:
            tooltip+="当前装备："+(String(equipped.get("name",equipped_id)) if not equipped_id.is_empty() else "空")
            if not dormant_reason.is_empty():tooltip+="\n未激活："+dormant_reason
            tooltip+="\n兼容："+("、".join(compatible_names) if not compatible_names.is_empty() else "不限")
        button.tooltip_text=tooltip
        button.add_theme_stylebox_override("normal",ui._tab_style(index==ui.build_assign_slot))
        button.focus_neighbor_left=button.get_path_to(ui.build_slot_buttons[index-1]) if index>0 else NodePath("")
        button.focus_neighbor_right=button.get_path_to(ui.build_slot_buttons[index+1]) if index+1<ui.build_slot_buttons.size() else NodePath("")
    for index in range(slots.size(),ui.build_slot_buttons.size()):ui.build_slot_buttons[index].hide()


static func family_count_summary(ui: Node, snapshot: Dictionary, family_id: String, slots: Array) -> String:
    var active:=0
    var unlocked:=0
    var dormant:=0
    for slot_value in slots:
        var slot: Dictionary=slot_value
        if bool(slot.get("unlocked",true)):unlocked+=1
        var item_id:=String(slot.get("equipped_id",""))
        if item_id.is_empty():continue
        if ui._slot_dormancy_reason(slot,item_id).is_empty():active+=1
        else:dormant+=1
    var row: Dictionary = ui._family_row(snapshot,family_id)
    return "%s 有效 %d / %d（已解锁 %d 槽 · 休眠 %d）" % [String(row.get("name",family_id)),active,slots.size(),unlocked,dormant]


static func all_family_count_summary(ui: Node, snapshot: Dictionary) -> String:
    var parts: Array[String]=[]
    for family_id in ["tool","combat_accessory","travel_accessory","thread_skill"]:
        var slots: Array = ui._family_slots(snapshot,family_id)
        if slots.is_empty():continue
        var active:=0
        var dormant:=0
        for value in slots:
            var slot: Dictionary=value
            var item_id:=String(slot.get("equipped_id",""))
            if item_id.is_empty():continue
            if ui._slot_dormancy_reason(slot,item_id).is_empty():active+=1
            else:dormant+=1
        var family: Dictionary = ui._family_row(snapshot,family_id)
        parts.append("%s %d/%d%s" % [String(family.get("name",family_id)),active,slots.size()," · 休眠 %d" % dormant if dormant>0 else ""])
    return " · ".join(parts)


static func open_resupply_planner(ui: Node) -> void:
    if ui.level==null or not ui.level.has_method("perform_build_action"):return
    if not is_instance_valid(ui.resupply_planner):
        ui.resupply_planner=preload("res://scripts/resupply_planner.gd").new()
        ui.build_panel.add_child(ui.resupply_planner)
        ui.register_text_entry_window(ui.resupply_planner)
        ui.build_panel.visibility_changed.connect(func():
            if not ui.build_panel.visible and is_instance_valid(ui.resupply_planner):ui.resupply_planner.hide())
    # Fixture runtimes have no journey save; only a real World scopes the memory.
    var journey_path: Variant=ui.level.get("world_save_path")
    if ui.level.get("world_mode")==true and journey_path is String:ui.resupply_planner.configure_memory(journey_path)
    ui.resupply_planner.open(ui._build_snapshot().get("tools",[]),
        func(plan: Dictionary):return ui.level.call("perform_build_action","quote_resupply","",plan),
        func(plan: Dictionary):
            var result: Dictionary=ui.level.call("perform_build_action","resupply_tools","",plan)
            ui.refresh_build()
            return result,
        func(id: String):return ui.level._item_display_name(id) if ui.level.has_method("_item_display_name") else id)


static func preview_tool_resupply(ui: Node) -> void:
    ui.resupply_quote={}
    if ui.level==null or not ui.level.has_method("perform_build_action"):
        ui.build_heading.text="战具补给报价"
        ui.build_detail.text="补给报价不可用。"
        ui.build_detail.scroll_to_line(0)
        ui.resupply_confirm_button.disabled=true
        return
    var quote: Variant=ui.level.call("perform_build_action","quote_resupply")
    if not quote is Dictionary:
        ui.build_heading.text="战具补给报价"
        ui.build_detail.text="补给报价暂不可用。"
        ui.build_detail.scroll_to_line(0)
        ui.resupply_confirm_button.disabled=true
        return
    ui.resupply_quote=quote.duplicate(true)
    ui.build_heading.text="战具补给报价"
    ui.build_detail.text=ui._resupply_quote_text(ui.resupply_quote)
    ui.build_detail.scroll_to_line(0)
    ui.resupply_confirm_button.disabled=not bool(ui.resupply_quote.get("ok",false))


static func resupply_quote_text(ui: Node, quote: Dictionary) -> String:
    if not bool(quote.get("ok",false)):
        return "补给不可购买 · "+String(quote.get("reason","当前无可补给内容"))
    var lines: Array[String]=["补给预览 · 确认前不扣费"]
    var charges: Variant=quote.get("charges",quote.get("refill",{}))
    if charges is Dictionary:
        for id in charges:
            var amount: Variant=charges[id]
            if amount is Dictionary:amount=amount.get("amount",amount.get("charges",0))
            if int(amount)>0:lines.append("%s +%d" % [ui._resupply_tool_name(String(id)),int(amount)])
    var cost: Variant=quote.get("cost",{})
    if cost is Dictionary:
        if int(cost.get("currency",0))>0:lines.append("碎钱：%d" % int(cost.currency))
        var materials: Variant=cost.get("materials",{})
        if materials is Dictionary:
            for material in materials:
                lines.append("%s：%d" % [ui.level._item_display_name(String(material)) if ui.level.has_method("_item_display_name") else String(material),int(materials[material])])
    return "\n".join(lines)


static func resupply_tool_name(ui: Node, item_id: String) -> String:
    var snapshot: Dictionary=ui._build_snapshot()
    var entry: Dictionary=ui._family_entry(snapshot,"tool",item_id)
    var localized_name:=String(entry.get("name",""))
    if not localized_name.is_empty():return localized_name
    if ui.level!=null and ui.level.has_method("_item_display_name"):
        return String(ui.level.call("_item_display_name",item_id))
    return item_id


static func confirm_tool_resupply(ui: Node) -> void:
    if ui.resupply_quote.is_empty() or not bool(ui.resupply_quote.get("ok",false)):return
    var current: Variant=ui.level.call("perform_build_action","quote_resupply") if ui.level!=null and ui.level.has_method("perform_build_action") else {}
    if not current is Dictionary or not bool(current.get("ok",false)):
        ui.resupply_quote=current if current is Dictionary else {}
        ui.build_heading.text="战具补给报价"
        ui.build_detail.text="先前报价已失效。\n\n"+ui._resupply_quote_text(ui.resupply_quote)
        ui.build_detail.scroll_to_line(0)
        ui.resupply_confirm_button.disabled=true
        return
    if current.get("charges",{})!=ui.resupply_quote.get("charges",{}) or current.get("cost",{})!=ui.resupply_quote.get("cost",{}):
        ui.resupply_quote=current.duplicate(true)
        ui.build_heading.text="战具补给报价"
        ui.build_detail.text="钱包或库存已变化，请复核最新报价后再次确认。\n\n"+ui._resupply_quote_text(ui.resupply_quote)
        ui.build_detail.scroll_to_line(0)
        ui.resupply_confirm_button.disabled=false
        return
    ui.resupply_quote={}
    ui._perform_build_action("resupply_tools","",{})
