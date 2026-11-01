extends RefCounted
const INPUT:=preload("res://scripts/build_shortcut_input.gd")
const CODEC:=preload("res://scripts/settings_profile_codec.gd")
const MODEL:=preload("res://scripts/settings_profiles.gd")
const TRANSFER:=preload("res://scripts/settings_profile_transfer.gd")
const POLICY:=preload("res://scripts/input_binding_policy.gd")

static func key(code: int, pressed: bool=true, control: bool=false) -> InputEventKey:
    var event:=InputEventKey.new()
    event.physical_keycode=code
    event.pressed=pressed
    event.ctrl_pressed=control
    return event

static func button(code: int, pressed: bool=true, device: int=42) -> InputEventJoypadButton:
    var event:=InputEventJoypadButton.new()
    event.button_index=code
    event.pressed=pressed
    event.device=device
    return event

static func events(action: String, values: Array) -> void:
    InputMap.action_erase_events(action)
    for value in values:InputMap.action_add_event(action,value)

static func pure(tree: SceneTree) -> void:
    var original: Array=InputMap.action_get_events(INPUT.ACTION)
    events(INPUT.ACTION,[])
    INPUT.ensure_action()
    tree.check(InputMap.event_is_action(key(KEY_B),INPUT.ACTION) and InputMap.event_is_action(button(JOY_BUTTON_LEFT_STICK),INPUT.ACTION),"build action installs shipped keyboard and controller defaults in a minimal project")
    var defaults:=CODEC.capture({INPUT.ACTION:"构筑"})
    INPUT.ensure_action()
    tree.check(CODEC.capture({INPUT.ACTION:"构筑"})==defaults,"repeated setup cannot accumulate duplicate shortcut events")
    events(INPUT.ACTION,[key(KEY_F16),button(JOY_BUTTON_PADDLE1)])
    INPUT.ensure_action()
    tree.check(not InputMap.event_is_action(key(KEY_B),INPUT.ACTION),"new region setup preserves a remapped build action without readding B")
    var subscriptions:=Input.get_signal_connection_list("joy_connection_changed").size()
    var gate:=INPUT.new()
    tree.root.add_child(gate)
    tree.check(Input.get_signal_connection_list("joy_connection_changed").size()==subscriptions+1,"shortcut input owns one disconnect listener while alive")
    tree.check(gate.consume(key(KEY_F16)),"fresh build keyboard press produces one edge")
    tree.check(not gate.consume(key(KEY_F16)),"repeated down event cannot open then close a menu")
    var echo:=key(KEY_F16)
    echo.echo=true
    tree.check(not gate.consume(echo),"keyboard auto-repeat cannot retrigger the menu")
    tree.check(not gate.consume(button(JOY_BUTTON_PADDLE1)),"holding keyboard and controller together still represents one shortcut press")
    gate.consume(key(KEY_F16,false))
    tree.check(not gate.consume(button(JOY_BUTTON_PADDLE1)),"one released device does not reset another held device")
    gate.consume(button(JOY_BUTTON_PADDLE1,false))
    tree.check(gate.consume(button(JOY_BUTTON_PADDLE1)),"controller release rearms the shortcut")
    Input.joy_connection_changed.emit(42,false)
    tree.check(gate.consume(key(KEY_F16)),"disconnect removes only that device's stale held token")
    gate.clear()
    events(INPUT.ACTION,[key(KEY_F16,true,true)])
    tree.check(gate.consume(key(KEY_F16,true,true)),"modifier shortcut can activate")
    gate.consume(key(KEY_CTRL,false))
    gate.consume(key(KEY_F16,false,false))
    tree.check(gate.consume(key(KEY_F16,true,true)),"lifting modifier first does not leave a stuck shortcut token")
    gate.suppress_capture(key(KEY_F16,true,true))
    tree.check(not gate.consume(key(KEY_F16,true,true)),"capture press is suppressed until released")
    gate.consume(key(KEY_F16,false,false))
    tree.check(gate.consume(key(KEY_F16,true,true)),"release and a deliberate press after capture rearm even within the same frame")
    await tree.process_frame
    gate.clear()
    events(INPUT.ACTION,[key(KEY_SPACE)])
    tree.check(not gate.consume(key(KEY_SPACE)),"even an injected GUI-confirm binding cannot intercept confirmation")
    for code in [KEY_ESCAPE,KEY_F9]:
        events(INPUT.ACTION,[key(code)])
        tree.check(not gate.consume(key(code)),"fixed escape and new-journey keys cannot be intercepted by a malformed original action")
    var motion:=InputEventJoypadMotion.new()
    motion.axis=JOY_AXIS_RIGHT_X
    motion.axis_value=1.0
    events(INPUT.ACTION,[motion])
    tree.check(not gate.consume(motion),"continuous axis is not treated as a discrete menu shortcut")
    gate.free()
    tree.check(Input.get_signal_connection_list("joy_connection_changed").size()==subscriptions,"retiring a UI releases its shortcut disconnect listener")
    events(INPUT.ACTION,original)

static func run(tree: SceneTree, main: Node, desk: Node) -> void:
    var ui: Control=main.ui_shell
    var original:=CODEC.capture(ui.REMAPPABLE_ACTIONS)
    var values: Dictionary=ui.accessibility.duplicate(true)
    var config_exists:=FileAccess.file_exists(ui.accessibility_path)
    var config_bytes:=FileAccess.get_file_as_bytes(ui.accessibility_path) if config_exists else PackedByteArray()
    var save:=FileAccess.get_file_as_bytes(main.world_save_path)
    var world:=var_to_str([main.inventory_counts,main.currency_count,main.world_state.data,main.player.hp,main.player.energy])
    await pure(tree)
    desk.window.hide()
    desk.confirm.hide()
    main._close_overlays()
    main._toggle_audio_settings()
    await tree.process_frame
    tree.check(ui.REMAPPABLE_ACTIONS.has(INPUT.ACTION) and ui.remap_buttons.has(INPUT.ACTION),"actual settings exposes the build shortcut as a regular named action")
    ui.remap_buttons[INPUT.ACTION].grab_focus()
    await tree.process_frame
    await tree.process_frame
    var button_rect: Rect2=ui.remap_buttons[INPUT.ACTION].get_global_rect()
    var visible_rect: Rect2=ui.remap_scroll.get_global_rect()
    tree.check(ui.remap_buttons[INPUT.ACTION].has_focus() and visible_rect.encloses(button_rect),"following focus scrolls the last of 21 actual action buttons fully into view")
    tree.check(ui.remap_scroll.position.y+ui.remap_scroll.size.y<=ui.remap_status.position.y,"new action grid cannot cover the capture status or save controls")
    ui._begin_remap(INPUT.ACTION)
    ui._input(key(KEY_F13))
    tree.check(ui.remap_target.is_empty() and InputMap.event_is_action(key(KEY_F13),INPUT.ACTION),"actual capture saves a custom build keyboard shortcut")
    tree.check(not InputMap.event_is_action(key(KEY_B),INPUT.ACTION) and InputMap.event_is_action(button(JOY_BUTTON_LEFT_STICK),INPUT.ACTION),"changing keyboard removes B while preserving the controller family")
    tree.check(main.active_overlay=="settings","the capture press does not also open the build panel")
    tree.check(ui.quick_actions[0].text.contains("F13") and not ui.quick_actions[0].text.begins_with("B "),"HUD build prompt immediately follows the actual custom keyboard binding")
    ui._input(key(KEY_F13,false))
    await tree.process_frame
    main._close_overlays()
    ui._input(key(KEY_B))
    tree.check(main.active_overlay=="","old B key no longer invokes a hidden hard-coded build shortcut")
    ui._input(key(KEY_B,false))
    ui._input(key(KEY_F13))
    tree.check(main.active_overlay=="build","custom physical keyboard event opens the actual build panel")
    ui._input(key(KEY_F13))
    tree.check(main.active_overlay=="build","held custom key does not close the just-opened build panel")
    ui._input(key(KEY_F13,false))
    ui._input(key(KEY_F13))
    tree.check(main.active_overlay=="","new press of custom key closes build normally")
    ui._input(key(KEY_F13,false))
    main._toggle_audio_settings()
    ui._begin_remap(INPUT.ACTION)
    ui._input(button(JOY_BUTTON_PADDLE2))
    tree.check(ui.remap_target.is_empty() and InputMap.event_is_action(button(JOY_BUTTON_PADDLE2),INPUT.ACTION) and not InputMap.event_is_action(button(JOY_BUTTON_LEFT_STICK),INPUT.ACTION),"controller remap replaces only its family, freeing L3")
    ui._input(button(JOY_BUTTON_PADDLE2,false))
    await tree.process_frame
    main._close_overlays()
    ui._input(button(JOY_BUTTON_LEFT_STICK))
    tree.check(main.active_overlay=="","old L3 has no hard-coded menu route after remapping")
    ui._input(button(JOY_BUTTON_LEFT_STICK,false))
    ui._input(button(JOY_BUTTON_PADDLE2))
    tree.check(main.active_overlay=="build","custom controller button opens the actual build menu")
    ui._input(button(JOY_BUTTON_PADDLE2,false))
    main._close_overlays()
    main._toggle_audio_settings()
    var before_navigation:=CODEC.capture(ui.REMAPPABLE_ACTIONS)
    var navigation: Array=[key(KEY_ENTER),key(KEY_TAB),key(KEY_UP),button(JOY_BUTTON_A),button(JOY_BUTTON_B),button(JOY_BUTTON_DPAD_DOWN)]
    var axis:=InputEventJoypadMotion.new()
    axis.axis=JOY_AXIS_RIGHT_X
    axis.axis_value=1.0
    navigation.append(axis)
    var wheel:=InputEventMouseButton.new()
    wheel.button_index=MOUSE_BUTTON_WHEEL_UP
    wheel.pressed=true
    navigation.append(wheel)
    for input in navigation:
        ui._begin_remap(INPUT.ACTION)
        ui._input(input)
        tree.check(ui.remap_target==INPUT.ACTION and CODEC.capture(ui.REMAPPABLE_ACTIONS)==before_navigation,"navigation input is rejected without changing any action")
        ui._input(key(KEY_ESCAPE))
    ui._begin_remap("heal")
    ui._input(key(KEY_B))
    tree.check(ui.remap_target.is_empty() and InputMap.event_is_action(key(KEY_B),"heal"),"freed B can become a gameplay binding through the normal conflict policy")
    ui._input(key(KEY_B,false))
    ui._begin_remap("heal")
    ui._input(button(JOY_BUTTON_LEFT_STICK))
    tree.check(ui.remap_target.is_empty() and InputMap.event_is_action(button(JOY_BUTTON_LEFT_STICK),"heal"),"freed L3 can become a gameplay binding instead of remaining globally reserved")
    ui._input(button(JOY_BUTTON_LEFT_STICK,false))
    var current_profile: Dictionary=desk.model.capture(ui)
    var shared:=TRANSFER.export_code("构筑改键",current_profile,ui.REMAPPABLE_ACTIONS)
    tree.check(shared.ok and JSON.parse_string(shared.text).version==2 and TRANSFER.parse_code(shared.text,ui.REMAPPABLE_ACTIONS).ok,"version 2 share format preserves custom build and freed gameplay inputs")
    # Use the real previous action set, which could not contain B or L3.
    var old_profile: Dictionary={"values":MODEL.values(values),"bindings":original.duplicate(true)}
    old_profile.bindings.erase(INPUT.ACTION)
    events("heal",[key(KEY_H)])
    var model:=MODEL.new()
    model.profiles={"旧方案":old_profile.duplicate(true)}
    var expected_build:=CODEC.capture({INPUT.ACTION:"构筑"})
    var quote:=model.quote("旧方案",ui,3)
    tree.check(quote.ok and String("\n".join(quote.lines)).contains("沿用当前构筑输入") and model.profiles["旧方案"]==old_profile,"legacy named profile quotes current build input without rewriting the stored profile")
    tree.check(model.apply("旧方案",ui,3,quote.snapshot).ok and CODEC.capture({INPUT.ACTION:"构筑"})==expected_build,"real legacy profile application preserves the current custom build input")
    var persisted:=ConfigFile.new()
    tree.check(persisted.load(ui.accessibility_path)==OK and persisted.has_section_key("bindings",INPUT.ACTION),"legacy application writes a complete current binding set to actual preferences")
    quote=model.quote("旧方案",ui,3)
    events(INPUT.ACTION,[key(KEY_F14),button(JOY_BUTTON_PADDLE2)])
    var changed:=CODEC.capture(ui.REMAPPABLE_ACTIONS)
    var bytes:=FileAccess.get_file_as_bytes(ui.accessibility_path)
    tree.check(not model.apply("旧方案",ui,3,quote.snapshot).ok and CODEC.capture(ui.REMAPPABLE_ACTIONS)==changed and FileAccess.get_file_as_bytes(ui.accessibility_path)==bytes,"legacy preview becomes stale if its inherited build binding changes before confirmation")
    var packet:={"format":TRANSFER.FORMAT,"version":1,"name":"旧分享码","profile":old_profile}
    var parsed:=TRANSFER.parse_code(JSON.stringify(packet),ui.REMAPPABLE_ACTIONS)
    tree.check(parsed.ok and parsed.profile.bindings.build_menu==CODEC.capture({INPUT.ACTION:"构筑"}).build_menu,"version 1 share code preserves current build shortcut while importing only historical actions")
    var bad:=packet.duplicate(true)
    bad.version=2
    tree.check(not TRANSFER.parse_code(JSON.stringify(bad),ui.REMAPPABLE_ACTIONS).ok,"version 2 cannot disguise an incomplete binding set as legacy")
    bad=packet.duplicate(true)
    bad.profile.bindings.erase("jump")
    tree.check(not TRANSFER.parse_code(JSON.stringify(bad),ui.REMAPPABLE_ACTIONS).ok,"legacy compatibility never fills arbitrary missing old actions")
    bad=packet.duplicate(true)
    bad.profile.bindings.build_menu=expected_build.build_menu
    tree.check(not TRANSFER.parse_code(JSON.stringify(bad),ui.REMAPPABLE_ACTIONS).ok,"version 1 cannot claim a newer build action")
    for input in [key(KEY_B),button(JOY_BUTTON_LEFT_STICK)]:
        bad=packet.duplicate(true)
        bad.profile.bindings.heal=[CODEC.encode(input)]
        tree.check(not TRANSFER.parse_code(JSON.stringify(bad),ui.REMAPPABLE_ACTIONS).ok,"legacy packet still enforces its historical B and L3 reservation")
    var upgraded:=TRANSFER.export_code("旧方案再分享",old_profile,ui.REMAPPABLE_ACTIONS)
    tree.check(upgraded.ok and JSON.parse_string(upgraded.text).version==2 and TRANSFER.parse_code(upgraded.text,ui.REMAPPABLE_ACTIONS).profile.bindings.has(INPUT.ACTION),"exporting a legacy stored profile creates a complete current share without mutating it")
    tree.check(model.profiles["旧方案"]==old_profile,"legacy export and preview keep the original stored bytes representable")
    ui._reset_bindings()
    tree.check(InputMap.event_is_action(key(KEY_B),INPUT.ACTION) and InputMap.event_is_action(button(JOY_BUTTON_LEFT_STICK),INPUT.ACTION),"one reset restores both shipped build shortcut families")
    ui._begin_remap("heal")
    ui._input(key(KEY_B))
    tree.check(ui.remap_target=="heal" and ui.remap_status.text.contains("构筑"),"B is now protected by an honest action conflict until build is moved")
    ui._input(key(KEY_ESCAPE))
    tree.check(FileAccess.get_file_as_bytes(main.world_save_path)==save and var_to_str([main.inventory_counts,main.currency_count,main.world_state.data,main.player.hp,main.player.energy])==world,"shortcut remaps, legacy application and menu toggles never change journey resources or its save")
    for action in original:
        var restored: Array=[]
        for raw in original[action]:restored.append(CODEC.decode(raw))
        events(action,restored)
    ui.accessibility=values
    ui.build_shortcut.clear()
    ui._apply_accessibility()
    ui._refresh_remap_labels()
    if config_exists:
        var file:=FileAccess.open(ui.accessibility_path,FileAccess.WRITE)
        file.store_buffer(config_bytes)
        file.close()
    else:DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.accessibility_path))
    main._close_overlays()
