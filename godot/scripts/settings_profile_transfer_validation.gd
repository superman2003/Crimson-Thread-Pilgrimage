extends RefCounted
const TRANSFER:=preload("res://scripts/settings_profile_transfer.gd")
const CODEC:=preload("res://scripts/settings_profile_codec.gd")
const MODEL:=preload("res://scripts/settings_profiles.gd")
const POLICY:=preload("res://scripts/input_binding_policy.gd")
static func run(tree: SceneTree,main: Node,desk: Node) -> void:
    pure(tree)
    await native(tree,main,desk)

static func pure(tree: SceneTree) -> void:
    var actions:={"transfer_contract_left":"左侧测试","transfer_contract_right":"右侧测试"}
    for pair in [["transfer_contract_left",KEY_F17],["transfer_contract_right",KEY_F18]]:
        InputMap.add_action(pair[0])
        var event:=InputEventKey.new();event.physical_keycode=pair[1];InputMap.action_add_event(pair[0],event)
    var profile:={"values":MODEL.values({}),"bindings":CODEC.capture(actions)}
    var before:=profile.duplicate(true)
    var live:=CODEC.capture(actions)
    var exported:=TRANSFER.export_code("设备方案",profile,actions)
    tree.check(exported.ok and exported.text.to_utf8_buffer().size()<TRANSFER.MAX_BYTES,"complete profile exports as a bounded versioned JSON share code")
    var parsed:=TRANSFER.parse_code(exported.text,actions)
    tree.check(parsed.ok and parsed.name_hint=="设备方案" and parsed.profile==profile,"share roundtrip preserves exact typed settings and all input fields")
    tree.check(profile==before and CODEC.capture(actions)==live,"export and parsing do not mutate the stored source or actual InputMap")
    tree.check(TRANSFER.parse_code("\n  "+String(exported.text)+"\n",actions).ok,"normal clipboard whitespace does not invalidate the share format")
    var packet: Dictionary=JSON.parse_string(exported.text)
    var bad: Array=[]
    var changed:=packet.duplicate(true);changed.format="another-game";bad.append(changed)
    changed=packet.duplicate(true);changed.version=TRANSFER.VERSION+1;bad.append(changed)
    changed=packet.duplicate(true);changed.version=true;bad.append(changed)
    changed=packet.duplicate(true);changed.extra="ignored?";bad.append(changed)
    changed=packet.duplicate(true);changed.name=" bad";bad.append(changed)
    changed=packet.duplicate(true);changed.name="x\ny";bad.append(changed)
    changed=packet.duplicate(true);changed.profile.values.erase("subtitle_size");bad.append(changed)
    changed=packet.duplicate(true);changed.profile.values.subtitle_size=100;bad.append(changed)
    changed=packet.duplicate(true);changed.profile.values.flash_enabled=1;bad.append(changed)
    changed=packet.duplicate(true);changed.profile.values.danger_caption_limit=1.5;bad.append(changed)
    changed=packet.duplicate(true);changed.profile.values.controller_deadzone=-0.2;bad.append(changed)
    changed=packet.duplicate(true);changed.profile.values.unknown_setting=true;bad.append(changed)
    changed=packet.duplicate(true);changed.profile.bindings.erase("transfer_contract_left");bad.append(changed)
    changed=packet.duplicate(true);changed.profile.bindings.unknown_action=[];bad.append(changed)
    changed=packet.duplicate(true);changed.profile.bindings.transfer_contract_left=[];bad.append(changed)
    changed=packet.duplicate(true);changed.profile.bindings.transfer_contract_left=[{"type":"Object","script":"arbitrary"}];bad.append(changed)
    changed=packet.duplicate(true);changed.profile.bindings.transfer_contract_left[0].physical=KEY_ESCAPE;bad.append(changed)
    changed=packet.duplicate(true);changed.profile.bindings.transfer_contract_left[0].extra="ignored?";bad.append(changed)
    changed=packet.duplicate(true);changed.profile.bindings.transfer_contract_left=changed.profile.bindings.transfer_contract_right.duplicate(true);bad.append(changed)
    for value in bad:
        tree.check(not TRANSFER.parse_code(JSON.stringify(value),actions).ok and CODEC.capture(actions)==live,"malformed, conflicting or unsupported share packet never changes current input")
    for text in ["", "{", "null", "[]", "字".repeat(TRANSFER.MAX_BYTES)]:
        tree.check(not TRANSFER.parse_code(text,actions).ok,"empty, broken, non-object or oversized UTF-8 input is rejected")
    var events: Array=[]
    var key:=InputEventKey.new();key.physical_keycode=KEY_F16;key.ctrl_pressed=true;events.append(key)
    var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_XBUTTON2;mouse.shift_pressed=true;events.append(mouse)
    var button:=InputEventJoypadButton.new();button.button_index=JOY_BUTTON_PADDLE1;events.append(button)
    var axis:=InputEventJoypadMotion.new();axis.axis=JOY_AXIS_RIGHT_X;axis.axis_value=-1;events.append(axis)
    for event in events:
        var sample:=profile.duplicate(true)
        sample.bindings.transfer_contract_left=[CODEC.encode(event)]
        var code:=TRANSFER.export_code("输入设备",sample,actions)
        tree.check(code.ok and TRANSFER.parse_code(code.text,actions).profile==sample,"keyboard modifiers, mouse buttons, controller buttons and axis direction survive transfer")
    var model:=MODEL.new();model.configure("transfer_contract_"+str(OS.get_process_id()))
    var malformed:=profile.duplicate(true);malformed.values.subtitle_speed=INF
    tree.check(not TRANSFER.export_code("无效",malformed,actions).ok,"nonfinite in-memory preferences cannot create a misleading export")
    var precise:=profile.duplicate(true)
    precise.values.controller_deadzone=0.43000000000000005
    var shared:=TRANSFER.export_code("精确参数",precise,actions)
    var roundtrip:=TRANSFER.parse_code(shared.text,actions)
    tree.check(roundtrip.ok and float(roundtrip.profile.values.controller_deadzone)==float(precise.values.controller_deadzone),"sharing text preserves full precision for actual controller parameters")
    var store:=preload("res://scripts/journey_desk_store.gd").new()
    store.configure("transfer_precision",str(OS.get_process_id()))
    tree.check(store.write({"profile":roundtrip.profile}),"full-precision imported parameters write through the real auxiliary store")
    var stored:=store.read()
    tree.check(float(stored.profile.values.controller_deadzone)==float(precise.values.controller_deadzone),"actual profile storage does not truncate imported floating-point parameters")
    for action in actions:InputMap.erase_action(action)

static func native(tree: SceneTree,main: Node,desk: Node) -> void:
    var ui: Control=main.ui_shell
    desk.confirm.hide()
    var source: String=desk.selected
    var profile: Dictionary=desk.model.profiles[source].duplicate(true)
    var preferences: Dictionary=ui.accessibility.duplicate(true)
    var bindings:=CODEC.capture(ui.REMAPPABLE_ACTIONS)
    var wallet: Dictionary=main._build_wallet_snapshot()
    var bytes:=FileAccess.get_file_as_bytes(ui.accessibility_path)
    var game:=FileAccess.get_file_as_bytes(main.world_save_path)
    var records: Dictionary=desk.model.profiles.duplicate(true)
    desk.window.find_child("ExportSettingsCode",true,false).pressed.emit()
    await tree.process_frame
    var dialog: ConfirmationDialog=desk.transfer
    tree.check(dialog.visible and not dialog.code.editable and dialog.code.has_focus() and not dialog.code.get_selected_text().is_empty(),"native export opens selectable plain sharing text without touching active settings")
    var text: String=dialog.code.text
    var clipboard: Array=[""]
    dialog.clipboard_writer=func(value: String):clipboard[0]=value
    dialog.copy_button.pressed.emit()
    tree.check(clipboard[0]==text and ui.accessibility==preferences,"gamepad-focusable copy action copies exactly the exported code without applying settings")
    tree.check(TRANSFER.parse_code(text,ui.REMAPPABLE_ACTIONS).profile==profile,"native share code represents the selected saved profile rather than the currently edited UI values")
    dialog.confirmed.emit()
    tree.check(not dialog.visible and desk.window.find_child("ExportSettingsCode",true,false).has_focus(),"closing export restores focus to its source action")
    desk.window.find_child("ImportSettingsCode",true,false).pressed.emit()
    await tree.process_frame
    tree.check(dialog.visible and dialog.code.editable and dialog.name_input.has_focus(),"native import starts with a new-name field and an explicit preview action")
    dialog.clipboard_reader=func():return clipboard[0]
    dialog.paste_button.pressed.emit()
    tree.check(dialog.code.text==text and dialog.code.has_focus(),"explicit paste action fills the native share editor and retains text-entry ownership")
    clipboard[0]="x".repeat(TRANSFER.MAX_BYTES+1)
    dialog.paste_button.pressed.emit()
    tree.check(dialog.code.text==text and dialog.detail.text.contains("64 KiB"),"oversized clipboard content cannot replace a valid code already in the editor")
    clipboard[0]=text
    dialog.name_input.text="导入方案";dialog.code.text=text
    dialog.confirmed.emit()
    tree.check(not dialog.pending.is_empty() and dialog.get_cancel_button().has_focus() and desk.model.profiles==records,"first confirmation previews differences and defaults to cancellation without storing a profile")
    tree.check(ui.accessibility==preferences and CODEC.capture(ui.REMAPPABLE_ACTIONS)==bindings,"import preview does not apply any visual, controller or keyboard preference")
    dialog.code.text=text+" "
    dialog.confirmed.emit()
    tree.check(not desk.model.profiles.has("导入方案") and dialog.pending.fingerprint==dialog.code.text.sha256_text(),"editing sharing text after preview requires a fresh preview even if the parsed values match")
    var disk:=FileAccess.get_file_as_bytes(desk.model.store.path)
    desk.model.store.writer=func(_value: Dictionary):return ERR_CANT_CREATE
    dialog.confirmed.emit()
    tree.check(dialog.visible and desk.model.profiles==records and FileAccess.get_file_as_bytes(desk.model.store.path)==disk,"failed auxiliary write preserves every existing named profile and exact profile-store bytes")
    tree.check(ui.accessibility==preferences and CODEC.capture(ui.REMAPPABLE_ACTIONS)==bindings and FileAccess.get_file_as_bytes(ui.accessibility_path)==bytes,"failed import preserves live controls and the real preference file")
    desk.model.store.writer=Callable()
    dialog.confirmed.emit();dialog.confirmed.emit()
    tree.check(not dialog.visible and desk.model.profiles.has("导入方案") and desk.model.profiles["导入方案"]==profile,"deliberate retry creates exactly the confirmed profile")
    tree.check(ui.accessibility==preferences and CODEC.capture(ui.REMAPPABLE_ACTIONS)==bindings and FileAccess.get_file_as_bytes(ui.accessibility_path)==bytes,"successful import stores only a profile and still does not apply it")
    tree.check(main._build_wallet_snapshot()==wallet and FileAccess.get_file_as_bytes(main.world_save_path)==game,"sharing/import never touches gameplay resources or save bytes")
    var reloaded:=MODEL.new();reloaded.configure()
    var canonical:=TRANSFER.validate(reloaded.profiles.get("导入方案",{}),ui.REMAPPABLE_ACTIONS)
    tree.check(canonical.ok and canonical.profile==profile and reloaded.quote("导入方案",ui,0).ok,"a new actual store reader restores valid imported settings and semantic input bindings")
    var broken:=MODEL.new();broken.configure("transfer_corrupt_"+str(OS.get_process_id()))
    var file:=FileAccess.open(broken.store.path,FileAccess.WRITE)
    file.store_string("{broken original profile file");file.close()
    var corrupt_bytes:=FileAccess.get_file_as_bytes(broken.store.path)
    broken.configure("transfer_corrupt_"+str(OS.get_process_id()))
    var refused:=TRANSFER.import_new(broken,"不覆盖损坏记录",text,ui,text.sha256_text())
    tree.check(not refused.ok and not broken.store.writable and broken.profiles.is_empty(),"an unreadable existing profile store blocks import instead of silently replacing its records")
    tree.check(FileAccess.get_file_as_bytes(broken.store.path)==corrupt_bytes and ui.accessibility==preferences,"blocked import preserves exact corrupt original bytes and active preferences")
    var accepted: Dictionary=desk.model.profiles.duplicate(true)
    desk.open_transfer("import");dialog.name_input.text="导入方案";dialog.code.text=text;dialog.confirmed.emit()
    tree.check(dialog.pending.is_empty() and desk.model.profiles==accepted and dialog.detail.text.contains("同名"),"same-name import is refused without replacing an existing profile")
    dialog.name_input.text="第二份";dialog.confirmed.emit()
    desk.window.hide()
    tree.check(not dialog.visible and dialog.pending.is_empty(),"closing the management window also closes and retires its child import preview")
    dialog.confirmed.emit()
    tree.check(desk.model.profiles==accepted,"late confirmation after owner-window closure cannot import")
    desk.open()
    desk.open_transfer("import");dialog.name_input.text="上限测试";dialog.code.text=text
    while desk.model.profiles.size()<MODEL.LIMIT:desk.model.profiles["占位"+str(desk.model.profiles.size())]=profile.duplicate(true)
    var full: Dictionary=desk.model.profiles.duplicate(true)
    dialog.confirmed.emit();dialog.confirmed.emit()
    tree.check(dialog.visible and desk.model.profiles==full and dialog.detail.text.contains("六套"),"capacity limit remains authoritative after preview and cannot partially overwrite another profile")
    desk.model.profiles=accepted
    dialog.hide()
    desk.open_transfer("import")
    await tree.process_frame
    var bounds:=Rect2(Vector2.ZERO,Vector2(dialog.size))
    tree.check(bounds.encloses(dialog.code.get_global_rect()) and bounds.encloses(dialog.detail.get_global_rect()),"share editor and scrolling preview fit the native import window")
    tree.check(not dialog.code.get_global_rect().intersects(dialog.detail.get_global_rect()),"sharing text and preview controls do not overlap")
    dialog.hide()
    var owner_bounds:=Rect2(Vector2.ZERO,Vector2(desk.window.size))
    tree.check(owner_bounds.encloses(desk.window.find_child("ImportSettingsCode",true,false).get_global_rect()),"new sharing actions remain inside the actual management window")
    tree.check(desk.window.size.y<=ui.get_viewport_rect().size.y,"management with sharing actions fits the configured game viewport height")
    desk.selected=source;desk.refresh()
