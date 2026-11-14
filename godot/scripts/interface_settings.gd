extends RefCounted
## The settings page: audio, accessibility and controls sections, remapping, focus navigation and saving preferences.
## Moved out of pilgrimage_interface.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const BINDING_POLICY = preload("res://scripts/input_binding_policy.gd")
const PROMPT_BINDINGS := preload("res://scripts/input_prompt_bindings.gd")
const TYPE := preload("res://scripts/ui_type_scale.gd")

static func build_settings(ui: Node) -> void:
    # Direct callers and budgeted arrivals use the same ordered groups.
    ui._begin_settings()
    ui._build_settings_audio()
    ui._build_settings_accessibility()
    ui._build_settings_controls()
    ui._finish_settings()


static func begin_settings(ui: Node) -> void:
    ui.settings=ui._panel(ui,"设置与无障碍",Vector2(135,48),Vector2(1010,618))
    ui.settings.name="AudioSettingsOverlay"
    preload("res://scripts/decorative_motion_settings.gd").install(ui)
    ui._well(ui.settings,Vector2(22,98),Vector2(458,280))
    ui._well(ui.settings,Vector2(500,98),Vector2(487,280))
    ui._label(ui.settings,"声音",Vector2(34,100),Vector2(440,26),20,ui.GOLD)


static func build_settings_audio(ui: Node) -> void:
    var rows: Array=ui.level.AUDIO_SETTINGS_ROWS
    for i in rows.size():
        var key:=String(rows[i][0])
        ui.settings_labels[key]=ui._label(ui.settings,String(rows[i][1]).split(" ")[0],Vector2(34,140+i*43),Vector2(145,30),16)
        var slider:=HSlider.new()
        slider.position=Vector2(190,146+i*43)
        slider.size=Vector2(257,22)
        slider.min_value=0
        slider.max_value=100
        slider.step=1
        slider.value=ui.level.audio_director.get_user_volume(key) if ui.level.audio_director!=null else 100
        slider.value_changed.connect(func(value: float):
            ui.level.settings_selection=i
            if ui.level.audio_director!=null:
                ui.level.audio_director.set_user_volume(key,value)
                if ui.level.audio_director.has_method("user_volume_save_status"):
                    var saved: Dictionary=ui.level.audio_director.user_volume_save_status()
                    ui._audio_save_feedback(saved)
            ui.refresh_settings_selection())
        ui.settings.add_child(slider)
        ui.settings_sliders[key]=slider
    ui._accessibility_toggle("npc_landmarks","NPC声音地标",Vector2(34,300))
    var comfort_button: Button = ui._button(ui.settings,"手柄校准 / 舒适预设",Vector2(34,332),Vector2(200,32),ui._open_controller_comfort)
    comfort_button.name="ControllerComfortButton";comfort_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    # Row 332 to the right of the comfort button belongs to the danger-caption
    # desk; the retry sits beside the NPC toggle, its notice by the section title.
    ui.settings_save_retry=ui._button(ui.settings,"重试保存当前设置",Vector2(245,298),Vector2(200,32),ui._retry_accessibility_save)
    ui.settings_save_retry.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.settings_save_retry.tooltip_text="保存本次已生效的设置与按键；不重置输入、音量或旅途资源。"
    ui.settings_save_notice=ui._label(ui.settings,"",Vector2(250,102),Vector2(220,24),TYPE.CAPTION,ui.GOLD)
    ui.settings_save_notice.clip_text=true
    ui._refresh_settings_save_notice()


static func build_settings_accessibility(ui: Node) -> void:
    ui._label(ui.settings,"阅读、画面与手柄",Vector2(512,100),Vector2(440,26),20,ui.GOLD)
    ui._accessibility_slider("subtitle_size","字幕字号",Vector2(512,136),17,26,1)
    ui._accessibility_slider("subtitle_speed","字幕速度",Vector2(512,170),0.5,2.0,0.25)
    ui._accessibility_slider("camera_shake","镜头震动",Vector2(512,204),0,1,0.25)
    ui._accessibility_slider("camera_lookahead","镜头前瞻",Vector2(512,238),0,1,0.25)
    preload("res://scripts/camera_observation_dialog.gd").install(ui)
    ui._accessibility_slider("vibration_strength","手柄力度",Vector2(512,272),0,1,0.25)
    ui._accessibility_toggle("flash_enabled","受击闪光",Vector2(512,305))
    ui._accessibility_toggle("vibration_enabled","手柄震动",Vector2(725,305))
    ui._accessibility_toggle("tutorial_hints","探索提示",Vector2(512,339))
    ui._accessibility_toggle("navigation_assist","导航辅助",Vector2(725,339))


static func finish_settings(ui: Node) -> void:
    for slot_index in 3:
        var slot:=slot_index+1
        ui.save_slot_buttons[slot]=ui._button(ui.settings,"存档槽 %d" % slot,Vector2(34+slot_index*219,573),Vector2(206,30),func():ui._select_save_slot(slot))
        ui.save_slot_buttons[slot].add_theme_font_size_override("font_size",TYPE.CONTROL)
        ui.save_slot_buttons[slot].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    ui._button(ui.settings,"恢复当前槽备份",Vector2(691,573),Vector2(137,30),ui._restore_save_backup).add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.journey_history_button=ui._button(ui.settings,"浏览旧旅途",Vector2(838,573),Vector2(134,30),ui._show_journey_history)
    ui.journey_history_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    preload("res://scripts/audio_output_dialog.gd").install(ui)
    preload("res://scripts/display_dialog.gd").install(ui)
    preload("res://scripts/difficulty_dialog.gd").install(ui)
    preload("res://scripts/achievements_dialog.gd").install(ui)
    ui.legacy_settings=ui._label(ui.settings,"",Vector2.ZERO,Vector2.ZERO)
    ui.legacy_settings.visible=false
    ui.refresh_settings_selection()
    ui._refresh_remap_labels()


static func accessibility_slider(ui: Node, key: String, title: String, point: Vector2, minimum: float, maximum: float, increment: float) -> void:
    var value_label: Label = ui._label(ui.settings,"",point,Vector2(176,28),16)
    var slider:=HSlider.new()
    slider.position=point+Vector2(181,7)
    slider.size=Vector2(253,22)
    slider.min_value=minimum
    slider.max_value=maximum
    slider.step=increment
    slider.value=float(ui.accessibility[key])
    value_label.text=title+"  "+str(slider.value)
    slider.value_changed.connect(func(value: float):
        ui.accessibility[key]=int(value) if key=="subtitle_size" else value
        value_label.text=title+"  "+str(value)
        ui._save_accessibility()
        ui._apply_accessibility())
    ui.settings.add_child(slider)
    ui.accessibility_controls[key]={"slider":slider,"label":value_label,"title":title}


static func accessibility_toggle(ui: Node, key: String, title: String, point: Vector2) -> void:
    var toggle:=CheckButton.new()
    ui.settings.add_child(toggle)
    toggle.text=title
    toggle.position=point
    toggle.size=Vector2(206,35)
    toggle.button_pressed=bool(ui.accessibility[key])
    ui.accessibility_toggles[key]=toggle
    toggle.toggled.connect(func(value: bool):
        ui.accessibility[key]=value
        ui._save_accessibility()
        ui._apply_accessibility())


static func get_accessibility(ui: Node, key: String, fallback: Variant=null) -> Variant:
    return ui.accessibility.get(key,fallback)


static func load_accessibility(ui: Node) -> void:
    # Before any saved preference applies, even when there is no preference file yet.
    ui._record_default_bindings()
    # Recover an interrupted replacement before treating a missing file as defaults.
    if ui.settings_persistence.recover(ui.accessibility_path)!=OK:return
    var config:=ConfigFile.new()
    if config.load(ui.accessibility_path)!=OK:return
    # A malformed preference must not prevent the settings screen from opening.
    for key in ["flash_enabled","vibration_enabled","tutorial_hints","navigation_assist","npc_landmarks","danger_captions","danger_caption_contrast"]:
        var value: Variant=config.get_value("accessibility",key,ui.accessibility[key])
        if value is bool:ui.accessibility[key]=value
    ui.accessibility["danger_caption_limit"]=int(ui._finite_setting(config,"danger_caption_limit",1,3))
    ui.accessibility["controller_deadzone"]=ui._finite_setting(config,"controller_deadzone",0.1,0.6)
    ui.accessibility["subtitle_size"]=int(ui._finite_setting(config,"subtitle_size",17,26))
    ui.accessibility["subtitle_speed"]=ui._finite_setting(config,"subtitle_speed",0.5,2.0)
    ui.accessibility["camera_shake"]=ui._finite_setting(config,"camera_shake",0,1)
    ui.accessibility["camera_lookahead"]=ui._finite_setting(config,"camera_lookahead",0,1)
    var observation:=preload("res://scripts/camera_observation_preferences.gd").DEFAULTS.duplicate()
    for key in observation:observation[key]=config.get_value("accessibility",key,observation[key])
    observation=preload("res://scripts/camera_observation_preferences.gd").normalize(observation)
    for key in observation:ui.accessibility[key]=observation[key]
    ui.accessibility["vibration_strength"]=ui._finite_setting(config,"vibration_strength",0,1)
    var saved := {}
    for action in ui.REMAPPABLE_ACTIONS:
        if config.has_section_key("bindings",action):saved[action]=config.get_value("bindings",action)
    var result: Dictionary=BINDING_POLICY.restore(BINDING_POLICY.snapshot(),saved,ui.REMAPPABLE_ACTIONS)
    for action in ui.REMAPPABLE_ACTIONS:
        if not result.bindings.has(action):continue
        InputMap.action_erase_events(action)
        for event in result.bindings[action]:InputMap.action_add_event(action,event)
    ui._apply_controller_deadzone()
    ui.binding_recovery_notice="部分输入设置无效或冲突，已保留对应设备的可用绑定。" if result.rejected>0 else ""
    if ui.remap_status!=null:
        ui.remap_status.text=ui.binding_recovery_notice if not ui.binding_recovery_notice.is_empty() else "确认键改键  ·  Esc／手柄 B 取消"


static func finite_setting(ui: Node, config: ConfigFile, key: String, minimum: float, maximum: float) -> float:
    var value: Variant=config.get_value("accessibility",key,ui.accessibility[key])
    if not (value is int or value is float) or not is_finite(float(value)):
        return float(ui.accessibility[key])
    return clampf(float(value),minimum,maximum)


static func is_remapping_input(ui: Node) -> bool:
    return ui.settings!=null and ui.settings.visible and (not ui.remap_target.is_empty() or Engine.get_process_frames()==ui.remap_capture_frame)


static func remember_gui_focus(ui: Node, _focused: Control) -> void:
    if ui.level==null or not is_instance_valid(ui.level):return
    var focused = ui.get_viewport().gui_get_focus_owner()
    if not ui._is_navigable_focus(focused):return
    for overlay in ["settings","backpack","map","dialogue","build"]:
        var controls: Array[Control] = ui._overlay_controls(overlay)
        for control in controls:
            if control==focused or control.is_ancestor_of(focused):
                ui.overlay_focus_memory[overlay]=weakref(focused)
                return
    var overlay:=String(ui.level.active_overlay)
    if not overlay.is_empty():ui.overlay_focus_memory[overlay]=weakref(focused)


static func is_navigable_focus(ui: Node, control: Control) -> bool:
    if not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree():return false
    if control.focus_mode!=Control.FOCUS_ALL:return false
    if control is BaseButton and (control as BaseButton).disabled:return false
    return true


static func overlay_controls(ui: Node, overlay: String) -> Array[Control]:
    var root: Node=null
    match overlay:
        "settings":root=ui.settings
        "backpack":root=ui.bag
        "map":root=ui.level.get("map_panel") if ui.level!=null else null
        "dialogue":root=ui.dialogue
        "build":root=ui.build_panel
    var result: Array[Control]=[]
    if root is Control and is_instance_valid(root):ui._collect_navigable(root,result)
    return result


static func collect_navigable(ui: Node, node: Node, result: Array[Control]) -> void:
    for child in node.get_children():
        if child is Control:
            var control:=child as Control
            if ui._is_navigable_focus(control):result.append(control)
        ui._collect_navigable(child,result)


static func focus_overlay(ui: Node, overlay: String, restore: bool=true) -> void:
    var controls: Array[Control] = ui._overlay_controls(overlay)
    if controls.is_empty():return
    if restore and ui.overlay_focus_memory.has(overlay):
        var reference: Variant=ui.overlay_focus_memory[overlay]
        var remembered:=reference.get_ref() as Control if reference is WeakRef else null
        if controls.has(remembered) and ui._is_navigable_focus(remembered):
            remembered.grab_focus()
            return
    controls[0].grab_focus()


static func on_joy_connection_changed(ui: Node, _device: int, connected: bool) -> void:
    if not connected and not ui.remap_target.is_empty():
        ui.remap_target=""
        ui.remap_capture_frame=Engine.get_process_frames()
        if is_instance_valid(ui.remap_status):ui.remap_status.text="手柄已断开，重映射已取消。"
    elif connected and ui.level!=null and is_instance_valid(ui.level):
        var overlay:=String(ui.level.active_overlay)
        if not overlay.is_empty() and not ui._is_navigable_focus(ui.get_viewport().gui_get_focus_owner()):
            ui.call_deferred("_focus_overlay",overlay,true)


static func accessibility_config(ui: Node) -> ConfigFile:
    var config:=ConfigFile.new()
    # Keep sections owned by other settings features when updating this panel.
    config.load(ui.accessibility_path)
    for key in ui.accessibility:config.set_value("accessibility",key,ui.accessibility[key])
    for action in ui.REMAPPABLE_ACTIONS:
        if InputMap.has_action(action):config.set_value("bindings",action,InputMap.action_get_events(action))
    return config


static func save_accessibility(ui: Node) -> Error:
    if ui.is_queued_for_deletion():return ERR_UNAVAILABLE
    var result: Error=ui.settings_persistence.save(ui._accessibility_config(),ui.accessibility_path)
    ui._refresh_settings_save_notice()
    if result!=OK and ui.toast!=null:ui.toast.text="设置保存失败（%d），当前设置仍有效。" % result
    return result


static func refresh_settings_save_notice(ui: Node) -> void:
    if ui.settings_save_notice!=null:
        ui.settings_save_notice.text="设置尚未保存" if ui.settings_persistence.pending else ""
        ui.settings_save_notice.tooltip_text=ui.settings_persistence.message()
        ui.settings_save_notice.visible=ui.settings_persistence.pending
    if ui.settings_save_retry!=null:ui.settings_save_retry.visible=ui.settings_persistence.pending


static func retry_accessibility_save(ui: Node) -> void:
    if ui.is_queued_for_deletion():return
    var saved: Error = ui._save_accessibility()
    if saved==OK and ui.toast!=null:ui.toast.text="当前设置与按键已保存。"
    if saved==OK and ui.settings!=null and ui.settings.is_visible_in_tree():ui._focus_overlay("settings",false)


static func apply_controller_deadzone(ui: Node) -> void:
    preload("res://scripts/controller_preferences.gd").apply_deadzone(float(ui.accessibility.get("controller_deadzone",0.2)))


static func sync_accessibility_controls(ui: Node) -> void:
    for key in ui.accessibility_controls:
        var row: Dictionary=ui.accessibility_controls[key]
        if is_instance_valid(row.slider):row.slider.set_value_no_signal(float(ui.accessibility[key]))
        if is_instance_valid(row.label):row.label.text=String(row.title)+"  "+str(ui.accessibility[key])
    for key in ui.accessibility_toggles:
        if is_instance_valid(ui.accessibility_toggles[key]):ui.accessibility_toggles[key].set_pressed_no_signal(bool(ui.accessibility[key]))


static func open_controller_comfort(ui: Node) -> void:
    if ui.settings==null or not ui.settings.is_visible_in_tree():return
    if not is_instance_valid(ui.controller_comfort_dialog):
        ui.controller_comfort_dialog=preload("res://scripts/controller_comfort_dialog.gd").new()
        ui.settings.add_child(ui.controller_comfort_dialog)
        ui.register_text_entry_window(ui.controller_comfort_dialog)
        ui.settings.visibility_changed.connect(func():
            if not ui.settings.visible and is_instance_valid(ui.controller_comfort_dialog):ui.controller_comfort_dialog.hide())
    ui.controller_comfort_dialog.open(ui.accessibility,func(values: Dictionary):
        var normalized: Dictionary=preload("res://scripts/controller_preferences.gd").normalize(values)
        for key in normalized:ui.accessibility[key]=normalized[key]
        ui._apply_accessibility()
        var saved: Error = ui._save_accessibility()
        return {"ok":true,"persisted":saved==OK})


static func apply_accessibility(ui: Node) -> void:
    if ui.settings_persistence.pending:
        ui.settings_persistence.reconcile(ui._accessibility_config(),ui.accessibility_path)
        ui._refresh_settings_save_notice()
    ui._apply_controller_deadzone()
    ui._sync_accessibility_controls()
    if ui.level!=null and is_instance_valid(ui.level.get("audio_director")) and ui.level.audio_director.has_method("set_npc_landmarks"):ui.level.audio_director.set_npc_landmarks(bool(ui.accessibility.get("npc_landmarks",true)))
    var feel = ui.get_node_or_null("/root/FeelKit")
    if feel != null and feel.has_method("set_accessibility"):
        feel.set_accessibility(ui.accessibility)
    if ui.dialogue_body!=null:ui.dialogue_body.add_theme_font_size_override("font_size",int(ui.accessibility["subtitle_size"]))
    if ui.build_detail!=null:ui.build_detail.add_theme_font_size_override("normal_font_size",int(ui.accessibility["subtitle_size"]))
    # U05: the journal/item reading body follows the reading size too; its
    # authored 17 stays the size at the default reading baseline.
    if ui.bag_description!=null:ui.bag_description.add_theme_font_size_override("normal_font_size",preload("res://scripts/journey_window_layout.gd").scaled_font(TYPE.ACTION,ui.accessibility["subtitle_size"]))
    if is_instance_valid(ui.dialog_reading):ui.dialog_reading.refresh()
    if ui.level!=null and is_instance_valid(ui.level.player):
        ui.level.player.set_meta("accessibility",ui.accessibility.duplicate())
        ui.applied_player=ui.level.player


static func record_default_bindings(ui: Node) -> void:
    if not ui.default_bindings.is_empty():return
    for action in ui.REMAPPABLE_ACTIONS:
        if not InputMap.has_action(action):continue
        var events: Array=[]
        for event in InputMap.action_get_events(action):events.append(event.duplicate())
        ui.default_bindings[action]=events


static func reset_bindings(ui: Node) -> void:
    ui.remap_target=""
    if is_instance_valid(ui.build_shortcut):ui.build_shortcut.clear()
    for action in ui.default_bindings:
        InputMap.action_erase_events(action)
        for event in ui.default_bindings[action]:InputMap.action_add_event(action,event.duplicate())
    ui._apply_controller_deadzone()
    ui._save_accessibility()
    ui._refresh_remap_labels()
    ui.remap_status.text="已恢复全部默认按键；声音、字幕与画面设置不变。"


static func begin_remap(ui: Node, action: String) -> void:
    if not ui.REMAPPABLE_ACTIONS.has(action) or ui.settings==null or not ui.settings.is_visible_in_tree():return
    ui.remap_target=action
    ui.remap_status.text="请为「%s」按键、鼠标按钮或手柄输入；Esc／手柄 B 取消。" % ui.REMAPPABLE_ACTIONS[action]
    if action=="build_menu":ui.remap_status.text="构筑使用键盘、鼠标按钮或非导航手柄按键；确认、返回、方向键和滚轮保留给界面。Esc／手柄 B 取消。"


static func cancel_remap(ui: Node, reason: String) -> void:
    if ui.remap_target.is_empty():return
    ui.remap_target=""
    ui.remap_capture_frame=Engine.get_process_frames()
    if is_instance_valid(ui.remap_status):ui.remap_status.text=reason


static func remap_visibility_changed(ui: Node) -> void:
    if not ui.settings.is_visible_in_tree():ui._cancel_remap("已离开设置，重映射已取消。")


static func refresh_remap_labels(ui: Node) -> void:
    for action in ui.remap_buttons:
        var names: Array[String]=[]
        if InputMap.has_action(action):
            for event in InputMap.action_get_events(action):names.append(ui._binding_name(event))
        ui.remap_buttons[action].text=String(ui.REMAPPABLE_ACTIONS[action])+" · "+(" / ".join(names) if not names.is_empty() else "未设置")
        ui.remap_buttons[action].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        ui.remap_buttons[action].tooltip_text=ui.remap_buttons[action].text
    ui._refresh_quick_action_bindings()


static func input(ui: Node, event: InputEvent) -> void:
    if ui.level==null or not ui.construction_complete:return
    var build_pressed: bool=is_instance_valid(ui.build_shortcut) and ui.build_shortcut.consume(event)
    PROMPT_BINDINGS.observe(event)
    if not ui.settings.visible:ui.remap_target=""
    if not ui.remap_target.is_empty():
        ui.remap_capture_frame=Engine.get_process_frames()
        # Joypad B is the reserved back button; it cancels capture like Escape.
        if (event is InputEventKey and event.pressed and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE)) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B):
            ui.remap_target=""
            ui.remap_status.text="已取消重映射。"
            ui.get_viewport().set_input_as_handled()
        elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>0.7):
            var accepted: InputEvent = ui._normalized_binding(event)
            if accepted==null:
                ui.get_viewport().set_input_as_handled()
                return
            if BINDING_POLICY.is_reserved(accepted):
                ui.remap_status.text="此输入保留给界面快捷键，请换一个输入，或按 Esc／手柄 B 取消。"
                ui.get_viewport().set_input_as_handled()
                return
            var action = ui.remap_target
            if not BINDING_POLICY.allowed_for(action,accepted):
                ui.remap_status.text="此输入需要留给界面导航；构筑请改用字母/功能键、鼠标按钮或非导航手柄按键。"
                ui.get_viewport().set_input_as_handled()
                return
            var conflicts: Array[String]=[]
            for other in BINDING_POLICY.conflicts(accepted,action,BINDING_POLICY.snapshot()):
                conflicts.append(String(ui.REMAPPABLE_ACTIONS.get(other,"其他动作")))
            if not conflicts.is_empty():
                ui.remap_status.text="此输入已用于「%s」，请换一个输入，或按 Esc／手柄 B 取消。" % "、".join(conflicts)
                ui.get_viewport().set_input_as_handled()
                return
            if not InputMap.has_action(action):InputMap.add_action(action)
            for old in InputMap.action_get_events(action):
                if BINDING_POLICY.family(old)==BINDING_POLICY.family(accepted):InputMap.action_erase_event(action,old)
            InputMap.action_add_event(action,accepted)
            if action=="build_menu" and is_instance_valid(ui.build_shortcut):ui.build_shortcut.suppress_capture(event)
            ui.remap_target=""
            ui._apply_controller_deadzone()
            ui._save_accessibility()
            ui._refresh_remap_labels()
            ui.remap_status.text="已保存「%s」的新输入；其余设备的绑定继续可用。" % ui.REMAPPABLE_ACTIONS[action]
            ui.get_viewport().set_input_as_handled()
        return
    if ui.bag.visible and ui.bag_category=="旅记" and event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode==KEY_F:
        var finder = ui.bag.get_node_or_null("JournalDocumentFind") as Window
        if finder!=null and finder.visible:
            finder.query.grab_focus();finder.query.select_all()
        elif ui.has_modal_window():return
        else:ui.journal_search.grab_focus()
        ui.get_viewport().set_input_as_handled()
        return
    if ui.has_modal_window():return
    if event is InputEventKey and ui.is_text_entry_focused():return
    if ui.bag.visible and ui.bag_category=="旅记":
        var step:=0
        if event is InputEventKey and event.pressed and not event.echo:
            var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
            step={KEY_PAGEUP:-1,KEY_PAGEDOWN:1,KEY_HOME:-2,KEY_END:2}.get(key,0)
        elif event is InputEventJoypadButton and event.pressed:
            step=-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1 if event.button_index==JOY_BUTTON_RIGHT_SHOULDER else 0
        if step!=0:
            ui._scroll_journal(step)
            ui.get_viewport().set_input_as_handled()
            return
    if ui.bag.visible and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_UP,KEY_DOWN]:
        # Main polls these keys to move bag selection; consume GUI navigation
        # so one key never advances both the gameplay selection and focus.
        ui.get_viewport().set_input_as_handled()
        return
    if build_pressed:
        ui._request_build_toggle()
        ui.get_viewport().set_input_as_handled()


static func bind_ui_navigation(ui: Node) -> void:
    preload("res://scripts/build_shortcut_input.gd").ensure_action()
    if not is_instance_valid(ui.build_shortcut):
        ui.build_shortcut=preload("res://scripts/build_shortcut_input.gd").new()
        ui.build_shortcut.name="BuildShortcutInput"
        ui.add_child(ui.build_shortcut)
    for pair in [["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN],["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT],["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B],["close_overlay",JOY_BUTTON_B],["inventory",JOY_BUTTON_START],["map",JOY_BUTTON_RIGHT_STICK],["interact",JOY_BUTTON_BACK]]:
        var action:=String(pair[0])
        if not InputMap.has_action(action):InputMap.add_action(action)
        var event:=InputEventJoypadButton.new()
        event.button_index=int(pair[1])
        if not InputMap.action_has_event(action,event):InputMap.action_add_event(action,event)
