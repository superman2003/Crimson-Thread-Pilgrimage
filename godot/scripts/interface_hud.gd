extends RefCounted
## The HUD: building it, combat status, HUD occlusion, thread thresholds, skill readiness and tactical cards.
## Moved out of pilgrimage_interface.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const CHROME := preload("res://scripts/pilgrimage_chrome.gd")
const HEAL_READOUT := preload("res://scripts/heal_resource_readout.gd")
const HUD_OCCLUSION := preload("res://scripts/hud_occlusion.gd")
const TYPE := preload("res://scripts/ui_type_scale.gd")

static func build_hud(ui: Node) -> void:
    ui.healing_payment=HEAL_READOUT.create_label(ui,ui.display_font(),ui.GOLD)
    ui.healing_payment_track=preload("res://scripts/heal_reservation_track.gd").new()
    ui.add_child(ui.healing_payment_track)
    ui.hud_card=Control.new()
    ui.hud_card.position=Vector2(26,24)
    ui.hud_card.size=Vector2(330,106)
    ui.hud_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    ui.add_child(ui.hud_card)
    var backing = CHROME.new()
    backing.kind="hud"
    backing.size=ui.hud_card.size
    backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
    ui.hud_card.add_child(backing)
    ui.hud_crest=ui._icon(ui.hud_card,load("res://assets/ui/seals/crimson.svg"),Vector2(10,16),Vector2(55,55))
    ui.health_glyphs=CHROME.new()
    ui.health_glyphs.kind="health"
    ui.health_glyphs.position=Vector2(77,7)
    ui.health_glyphs.size=Vector2(205,46)
    ui.hud_card.add_child(ui.health_glyphs)
    ui.hearts=ui._label(ui.hud_card,"",Vector2(266,17),Vector2(55,27),TYPE.ACTION,ui.IVORY)
    ui.hearts.add_theme_font_override("font",ui.display_font())
    ui.hearts.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    ui._label(ui.hud_card,"绯线",Vector2(79,58),Vector2(65,22),TYPE.CONTROL,ui.GOLD).add_theme_font_override("font",ui.display_font())
    ui.energy_status=ui._label(ui.hud_card,"",Vector2(205,58),Vector2(112,22),TYPE.CONTROL,ui.IVORY)
    ui.energy_status.add_theme_font_override("font",ui.display_font())
    ui.energy_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    ui.thread_bar=ProgressBar.new()
    ui.thread_bar.position=Vector2(80,85)
    ui.thread_bar.size=Vector2(224,5)
    ui.thread_bar.custom_minimum_size=Vector2(0,5)
    ui.thread_bar.show_percentage=false
    ui.thread_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    ui.thread_bar.add_theme_font_size_override("font_size",1)
    ui.thread_bar.add_theme_constant_override("outline_size",0)
    ui.thread_bar.add_theme_stylebox_override("background",ui._meter_style(Color("293237")))
    ui.thread_bar.add_theme_stylebox_override("fill",ui._meter_style(ui.RED))
    ui.thread_bar.size=Vector2(224,5)
    ui.hud_card.add_child(ui.thread_bar)
    ui.thread_bar.update_minimum_size()
    ui.thread_bar.size=Vector2(224,5)
    ui.thread_thresholds=CHROME.new()
    ui.thread_thresholds.kind="thresholds"
    ui.thread_thresholds.position=Vector2(80,81)
    ui.thread_thresholds.size=Vector2(224,13)
    ui.hud_card.add_child(ui.thread_thresholds)
    ui.currency_emblem=ui._icon(ui,ART.item("currency"),Vector2(1130,31),Vector2(28,28))
    ui.currency=ui._label(ui,"0",Vector2(1168,30),Vector2(88,30),TYPE.READING,ui.GOLD)
    ui.location_rule=CHROME.new()
    ui.location_rule.kind="location"
    ui.location_rule.position=Vector2(443,24)
    ui.location_rule.size=Vector2(394,51)
    ui.add_child(ui.location_rule)
    ui.location=ui._label(ui,"",Vector2(478,27),Vector2(324,38),TYPE.HUD_PLACE,ui.IVORY)
    ui.location.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    ui.toast=ui._label(ui,"",Vector2(395,102),Vector2(490,60),TYPE.BODY,ui.IVORY)
    ui.toast.add_theme_stylebox_override("normal",ui._style(Color(0.04,0.07,0.08,0.94),Color("514e3e")))
    ui.toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    ui.toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    ui.prompt=ui._label(ui,"",Vector2(370,549),Vector2(540,42),TYPE.TITLE,ui.IVORY)
    ui.prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    ui.prompt.clip_text=true
    ui.prompt.add_theme_stylebox_override("normal",ui._style(Color(0.04,0.07,0.08,0.94),ui.GOLD))
    ui.combat_status=ui._label(ui,"",Vector2(28,144),Vector2(360,76),TYPE.CONTROL,ui.IVORY)
    ui.combat_status.visible=false
    ui.mechanism_status=ui._label(ui,"",Vector2(30,141),Vector2(360,26),TYPE.CONTROL,ui.GOLD)
    ui.healing_status=ui._label(ui,"",Vector2(30,169),Vector2(360,24),TYPE.CONTROL,ui.MUTED)
    ui.healing_status.mouse_filter=Control.MOUSE_FILTER_PASS
    ui.healing_status.add_theme_stylebox_override("normal",ui._meter_style(Color(0.04,0.07,0.08,0.9)))
    ui.healing_bar=ProgressBar.new()
    ui.healing_bar.position=Vector2(30,197)
    ui.healing_bar.size=Vector2(300,6)
    ui.healing_bar.show_percentage=false
    ui.healing_bar.add_theme_font_size_override("font_size",1)
    ui.healing_bar.add_theme_constant_override("outline_size",0)
    ui.healing_bar.max_value=1.0
    ui.healing_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    ui.healing_bar.add_theme_stylebox_override("background",ui._meter_style(Color("233039")))
    ui.healing_bar.add_theme_stylebox_override("fill",ui._meter_style(ui.IVORY))
    ui.healing_bar.visible=false
    ui.healing_bar.size=Vector2(300,6)
    ui.add_child(ui.healing_bar)
    ui.healing_bar.update_minimum_size()
    ui.healing_bar.size=Vector2(300,6)
    ui.pinned=ui._label(ui,"",Vector2(30,212),Vector2(300,45),TYPE.CONTROL,ui.MUTED)
    ui.pinned.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for index in 4:
        var card:=Panel.new()
        card.position=Vector2(28+index*105,610)
        card.size=Vector2(96,78)
        card.mouse_filter=Control.MOUSE_FILTER_IGNORE
        card.add_theme_stylebox_override("panel",ui._style(Color(0.04,0.07,0.08,0.94),Color("514e3e")))
        ui.add_child(card)
        ui.tactical_cards.append(card)
        var card_frame = CHROME.new()
        card_frame.kind="tactical"
        card_frame.size=card.size
        card.add_child(card_frame)
        ui.tactical_icons.append(ui._icon(card,null,Vector2(6,6),Vector2(46,46)))
        ui.tactical_values.append(ui._label(card,"",Vector2(53,13),Vector2(39,30),TYPE.CAPTION,ui.GOLD))
        ui.tactical_names.append(ui._label(card,"",Vector2(8,54),Vector2(83,20),TYPE.CAPTION,ui.IVORY))
        ui.tactical_names[-1].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    ui.tutorial_hint=ui._label(ui,"",Vector2(28,687),Vector2(620,23),TYPE.CAPTION,ui.MUTED)
    for entry in [["B  构筑",ui._request_build_toggle],["Tab  行囊",func():ui.level._toggle_backpack()],["M  地图",func():ui.level._toggle_map()],["V  设置",func():ui.level._toggle_audio_settings()]]:
        ui.quick_actions.append(ui._button(ui,entry[0],Vector2(827+ui.quick_actions.size()*108,673),Vector2(100,33),entry[1]))
    ui.boss_name=ui._label(ui,"",Vector2(395,593),Vector2(490,27),TYPE.ACTION,ui.GOLD)
    ui.boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    ui.boss_bar=ProgressBar.new()
    ui.boss_bar.position=Vector2(468,628)
    ui.boss_bar.size=Vector2(344,7)
    ui.boss_bar.show_percentage=false
    ui.boss_bar.add_theme_font_size_override("font_size",1)
    ui.boss_bar.add_theme_constant_override("outline_size",0)
    ui.boss_bar.add_theme_stylebox_override("background",ui._meter_style(Color("20262a")))
    ui.boss_bar.add_theme_stylebox_override("fill",ui._meter_style(ui.RED))
    ui.boss_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    ui.boss_bar.size=Vector2(344,7)
    ui.add_child(ui.boss_bar)
    ui.boss_bar.update_minimum_size()
    ui.boss_bar.size=Vector2(344,7)


static func refresh_combat_status(ui: Node, player: Node) -> void:
    var state: Dictionary={}
    if player.has_method("get_combat_ui_state"):state=player.call("get_combat_ui_state")
    var snapshot: Dictionary = ui._combat_snapshot()
    var skill_lines: Array[String]=[]
    var tool_lines: Array[String]=[]
    var system: Variant=ui.level.call("get_build_system") if ui.level.has_method("get_build_system") else null
    var build_state: Dictionary=system.state if system!=null else {}
    var equipped_skills: Array=build_state.get("skills",[build_state.get("skill","cleave")])
    var equipped_tools: Array=build_state.get("tools",[build_state.get("tool","shard")])
    for slot in equipped_skills.size():
        var id:=String(equipped_skills[slot])
        if id.is_empty():skill_lines.append("○%d 未装备技能" % (slot+1));continue
        for skill in snapshot.get("skills",[]):
            if String(skill.get("id",""))!=id:continue
            var remaining:=float(system.cooldowns.get(id,0)) if system!=null else float(state.get("skill_cooldown",0))
            var dormant_reason: String = ui._family_slot_dormancy_reason(snapshot,"thread_skill",slot,id)
            var status = ("休眠："+dormant_reason) if not dormant_reason.is_empty() else "%.1fs" % remaining if remaining>0 else "就绪"
            skill_lines.append("%s%d %s %s" % ["▶" if slot==int(build_state.get("active_skill_slot",0)) and dormant_reason.is_empty() else "○",slot+1,String(skill.get("name",id)),status])
    for slot in equipped_tools.size():
        var id:=String(equipped_tools[slot])
        if id.is_empty():tool_lines.append("○%d 未携带战具" % (slot+1));continue
        for tool in snapshot.get("tools",[]):
            if String(tool.get("id",""))==id:
                var dormant_reason: String = ui._family_slot_dormancy_reason(snapshot,"tool",slot,id)
                var status = "休眠："+dormant_reason if not dormant_reason.is_empty() else "%d次" % int(tool.get("count",0))
                tool_lines.append("%s%d %s %s" % ["▶" if slot==int(build_state.get("active_tool_slot",0)) and dormant_reason.is_empty() else "○",slot+1,String(tool.get("name",id)),status])
    ui.combat_status.text=" · ".join(skill_lines)+"\n"+" · ".join(tool_lines)
    if player.has_method("get_seal_mechanism_snapshot"):
        var mechanism: Dictionary=player.call("get_seal_mechanism_snapshot")
        var maximum:=int(mechanism.get("max_stacks",mechanism.get("max",3)))
        var amount:=int(mechanism.get("stacks",mechanism.get("value",0)))
        ui.mechanism_status.text=String(mechanism.get("label",mechanism.get("name","契印")))+"  "+("%d / %d" % [amount,maximum] if maximum>0 else "%d 个目标" % amount)
        if not bool(mechanism.get("unlocked",true)):
            ui.mechanism_status.text=String(mechanism.get("label","契印"))+" · 尚未修复"
        elif float(mechanism.get("remaining",0.0))>0.0 and amount>0:
            ui.mechanism_status.text+=" · %.1fs" % float(mechanism.remaining)
        if float(mechanism.get("heal_remaining",0.0))>0.0:
            ui.mechanism_status.text+=" · %s %.1fs" % [String(mechanism.get("heal_effect","治疗效果")),float(mechanism.heal_remaining)]
        ui.combat_status.text+="\n"+ui.mechanism_status.text
    var heal: Dictionary=state.get("heal",{})
    var paid = HEAL_READOUT.apply(ui.healing_payment,heal,int(player.energy),int(player.max_energy),ui.level.active_overlay!="")
    if is_instance_valid(ui.healing_payment_track):ui.healing_payment_track.update_snapshot(paid,ui.level.active_overlay!="")
    if is_instance_valid(ui.pinned):ui.pinned.position.y=248.0 if bool(paid.active) else 212.0
    # Full health leaves nothing to do: keep the corner quiet (U01 less text).
    ui.healing_status.visible=not heal.is_empty() and ui.level.active_overlay=="" and String(heal.get("reason",""))!="full_health"
    if not heal.is_empty():
        var reason := String(heal.get("reason","busy"))
        var status: String = {"ready":"可用 +%d" % int(heal.get("amount",1)),"channeling":"治疗中 %.1fs" % float(heal.get("remaining",0.0)),
            "dead":"等待复生","busy":"动作中","full_health":"生命已满","energy":"缺 %d 绯线" % int(heal.get("missing_energy",0)),
            "airborne":"落地后可用","moving":"停稳后可用","cooldown":"冷却 %.1fs" % float(heal.get("cooldown",0.0))}.get(reason,"动作中")
        var heal_text := "[%s] 治疗 %d · %s" % [ui._short_binding("heal"),int(heal.get("cost",0)),status]
        if ui.healing_status.text != heal_text:
            ui.healing_status.text = heal_text
        var heal_tip := "消耗 %d 绯线 · 恢复 %d 生命 · %.2f秒\n中断损失 %d 绯线；移动、跳跃、冲刺或受击会中断。" % [int(heal.get("cost",0)),int(heal.get("amount",0)),float(heal.get("duration",0.0)),int(heal.get("interrupt_loss",0))]
        if ui.healing_status.tooltip_text != heal_tip:
            ui.healing_status.tooltip_text = heal_tip
        var heal_color: Color = ui.GOLD if bool(heal.get("available",false)) else ui.IVORY if reason=="channeling" else ui.MUTED
        if ui.healing_status.get_theme_color("font_color") != heal_color:
            ui.healing_status.add_theme_color_override("font_color", heal_color)
    ui.healing_bar.visible=bool(state.get("heal_active",false)) and ui.level.active_overlay==""
    ui.healing_bar.value=clampf(float(state.get("heal_progress",0)),0,1)
    if ui.healing_bar.visible:ui.combat_status.text+=" · 治疗中"
    ui.combat_status.visible=false
    ui._refresh_tactical_cards(snapshot,build_state,system)


static func ending_status_label(ui: Node, entry: Dictionary) -> String:
    if bool(entry.get("chosen",false)):return "已选择"
    if bool(entry.get("available",false)):return "可以选择"
    if String(entry.get("status",""))=="closed":return "已关闭"
    return "准备中"


static func hud_groups(ui: Node) -> Dictionary:
    return {"top":[ui.hud_card,ui.mechanism_status,ui.healing_status,ui.healing_bar,ui.healing_payment,ui.healing_payment_track,ui.pinned],"tactical":ui.tactical_cards}


static func refresh_hud_occlusion(ui: Node, delta: float) -> void:
    var occupants = HUD_OCCLUSION.occupant_rects(ui.level) if ui.level.active_overlay=="" else ([] as Array[Rect2])
    var groups: Dictionary = ui._hud_groups()
    for key in groups:
        var faded = HUD_OCCLUSION.covered(HUD_OCCLUSION.group_rect(groups[key]),occupants)
        var alpha = HUD_OCCLUSION.step_alpha(float(ui.hud_group_alpha.get(key,1.0)),faded,delta)
        ui.hud_group_alpha[key]=alpha
        for item in groups[key]:
            if is_instance_valid(item):(item as CanvasItem).modulate.a=alpha


static func refresh_thread_thresholds(ui: Node, player: Node) -> void:
    # UI fixtures drive the HUD with lightweight players that have no heal cost.
    var heal_cost:=int(player.get("heal_energy_cost")) if "heal_energy_cost" in player else 0
    var skill_cost:=0
    var system: Variant=ui.level.call("get_build_system") if ui.level.has_method("get_build_system") else null
    if system!=null and system.has_method("selected_skill"):
        var skill: Dictionary=system.selected_skill()
        if not skill.is_empty():skill_cost=maxi(0,int(skill.get("energy_cost",0)))
    var energy:=int(player.energy)
    var maximum:=maxi(1,int(player.max_energy))
    if ui.thread_thresholds.energy!=energy or ui.thread_thresholds.heal_cost!=heal_cost or ui.thread_thresholds.skill_cost!=skill_cost or ui.thread_thresholds.maximum!=maximum:
        ui.thread_thresholds.energy=energy
        ui.thread_thresholds.heal_cost=heal_cost
        ui.thread_thresholds.skill_cost=skill_cost
        ui.thread_thresholds.maximum=maximum
        ui.thread_thresholds.queue_redraw()


static func skill_readiness(ui: Node, item: Dictionary, remaining: float, active: bool) -> Dictionary:
    var cost := maxi(0, int(item.get("energy_cost", 0)))
    var energy := int(ui.level.player.energy) if ui.level != null and is_instance_valid(ui.level.player) else 0
    var detail := "需要 %d 绯线；当前 %d。" % [cost, energy]
    if remaining > 0.0:
        return {"text":"%.1fs" % remaining, "available":false, "detail":"冷却中。" + detail}
    if ui.level != null and is_instance_valid(ui.level.player) and ui.level.player.has_method("get_cast_readiness"):
        var action: Dictionary = ui.level.player.get_cast_readiness(String(item.get("id","")))
        if not bool(action.available):return {"text":action.text,"available":false,"detail":String(action.detail)+detail}
    if energy < cost:
        return {"text":"缺%d" % (cost - energy), "available":false, "detail":"绯线不足。" + detail}
    return {"text":ui._short_binding("skill_1") if active else "待切换", "available":true, "detail":detail}


static func refresh_tactical_cards(ui: Node, snapshot: Dictionary, build_state: Dictionary, system: Variant) -> void:
    var crest_id:=String(build_state.get("crest","crimson"))
    if ui.hud_crest.get_meta("crest_id","")!=crest_id:
        ui.hud_crest.set_meta("crest_id",crest_id)
        var crest_path:="res://assets/ui/seals/%s.svg" % crest_id
        ui.hud_crest.texture=load(crest_path) if ResourceLoader.exists(crest_path) else null
    for index in ui.tactical_cards.size():
        var is_skill: bool=index<2
        var slot: int=index%2
        var equipped: Array=build_state.get("skills" if is_skill else "tools",[])
        var id:=String(equipped[slot]) if slot<equipped.size() else ""
        var family_id:="thread_skill" if is_skill else "tool"
        var dormant_reason: String = ui._family_slot_dormancy_reason(snapshot,family_id,slot,id)
        var path:="res://assets/ui/seals/%s.svg" % id
        if ui.tactical_icons[index].get_meta("asset_id","")!=id:
            ui.tactical_icons[index].set_meta("asset_id",id)
            ui.tactical_icons[index].texture=load(path) if not id.is_empty() and ResourceLoader.exists(path) else null
        var next_name := "未装备" if is_skill else "未携带"
        var next_value := "—"
        var next_tooltip := ui.tactical_cards[index].tooltip_text
        var next_modulate := ui.tactical_icons[index].modulate
        var active = slot==int(build_state.get("active_skill_slot" if is_skill else "active_tool_slot",0)) and dormant_reason.is_empty()
        var signature = id+str(active)+dormant_reason
        if ui.tactical_signatures[index]!=signature:
            ui.tactical_signatures[index]=signature
            ui.tactical_cards[index].set_meta("inscription_active",active)
            ui.tactical_cards[index].get_child(0).queue_redraw()
            var card_style: StyleBoxFlat = ui._style(Color(.025,.065,.07,.94),ui.RED if active else Color("65583f"))
            card_style.border_width_bottom=2 if active else 1
            ui.tactical_cards[index].add_theme_stylebox_override("panel",card_style)
        for item in snapshot.get("skills" if is_skill else "tools",[]):
            if String(item.get("id",""))!=id:continue
            var item_name:=String(item.get("name",id))
            next_name=("休眠 · "+item_name) if not dormant_reason.is_empty() else item_name
            next_tooltip="未激活："+dormant_reason if not dormant_reason.is_empty() else item_name
            if not dormant_reason.is_empty():
                next_value=dormant_reason
                next_modulate=Color(0.45,0.45,0.45)
                break
            if is_skill:
                var remaining:=float(system.cooldowns.get(id,0)) if system!=null else 0.0
                var readiness: Dictionary = ui._skill_readiness(item,remaining,active)
                next_value=String(readiness.text)
                next_tooltip=item_name+" · "+String(readiness.detail)
                next_modulate=Color.WHITE if readiness.available else Color(0.45,0.45,0.45)
            else:
                var count := int(item.get("count",0))
                var readiness: Dictionary = ui.level.get_tool_readiness(id) if ui.level.has_method("get_tool_readiness") else {"available":count>0,"text":"" if count>0 else "已用尽","detail":""}
                next_value=String(readiness.text) if not String(readiness.text).is_empty() else "× %d" % count
                next_tooltip=item_name+" · 剩余 %d / %d 次。" % [count,int(item.get("capacity",count))]+String(readiness.detail)
                next_modulate=Color.WHITE if bool(readiness.available) else Color(0.45,0.45,0.45)
        if ui.tactical_names[index].text != next_name:
            ui.tactical_names[index].text = next_name
        if ui.tactical_values[index].text != next_value:
            ui.tactical_values[index].text = next_value
        if ui.tactical_cards[index].tooltip_text != next_tooltip:
            ui.tactical_cards[index].tooltip_text = next_tooltip
        if ui.tactical_icons[index].modulate != next_modulate:
            ui.tactical_icons[index].modulate = next_modulate
