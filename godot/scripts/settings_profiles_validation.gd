extends SceneTree
const MODEL := preload("res://scripts/settings_profiles.gd")
const CODEC := preload("res://scripts/settings_profile_codec.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures.append(message)
func run() -> void:
    var key:=InputEventKey.new();key.physical_keycode=KEY_H;key.ctrl_pressed=true
    var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_RIGHT;mouse.alt_pressed=true
    var button:=InputEventJoypadButton.new();button.button_index=JOY_BUTTON_X
    var axis:=InputEventJoypadMotion.new();axis.axis=JOY_AXIS_LEFT_X;axis.axis_value=-1
    for event in [key,mouse,button,axis]:
        var encoded: Dictionary=CODEC.encode(event)
        check(CODEC.encode(CODEC.decode(encoded))==encoded,"JSON event codec preserves supported family and modifiers")
    check(CODEC.decode({"type":"key","physical":true,"logical":0})==null and CODEC.decode({"type":"axis","axis":0,"value":NAN})==null,"malformed and non-finite event fields are rejected")
    var model:=MODEL.new();model.configure("profile_unit")
    var sample: Dictionary=JSON.parse_string(JSON.stringify({"values":MODEL.values({}),"bindings":{"heal":[CODEC.encode(key)]}},"",true,true))
    for index in 6:check(model.manage("save","","方案"+str(index),sample).ok,"named setting slot saves")
    check(not model.manage("save","","第七套",sample).ok,"profile capacity is bounded")
    check(not model.manage("rename","方案0","方案1").ok,"rename cannot overwrite another profile")
    check(model.manage("rename","方案0","更名").ok and model.profiles.has("更名"),"rename remains available at capacity")
    check(not MODEL.valid_name(" bad") and not MODEL.valid_name("a\nb") and not MODEL.valid_name("字".repeat(25)),"profile names reject ambiguity and control characters")
    var loaded:=MODEL.new();loaded.configure("profile_unit")
    check(loaded.profiles==model.profiles,"new instance restores actual persisted named profiles")
    check(model.manage("delete","方案5","").ok and model.manage("copy","更名","副本").ok and model.profiles["副本"]==model.profiles["更名"],"delete frees capacity and copy creates an independent saved snapshot")
    var original:=model.profiles.duplicate(true);model.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    check(not model.manage("delete","更名","").ok and model.profiles==original,"management write failure leaves original profiles intact")

    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_resume=false;main.world_save_path="user://profiles_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    var ui: Control=main.ui_shell
    ui.accessibility_path="user://profiles_actual_settings.cfg"
    main._toggle_audio_settings()
    var desk: Node=ui.get_node("SettingsProfilesDesk")
    ui.settings.get_node("SettingsProfilesButton").pressed.emit();await process_frame
    check(desk.window.visible and desk.name_input.has_focus(),"production settings menu opens named profile management")
    desk.name_input.text="夜间阅读";desk.manage("save")
    check(desk.model.profiles.has("夜间阅读"),"actual controls capture a full profile")
    var snapshot: Dictionary=desk.model.profiles["夜间阅读"].duplicate(true)
    ui.accessibility.subtitle_size=18;ui.accessibility.flash_enabled=true
    var quote: Dictionary=desk.model.quote("夜间阅读",ui,1)
    check(quote.ok and not quote.lines.is_empty(),"scope preview describes actual current-to-saved changes")
    var current: Dictionary=ui.accessibility.duplicate(true)
    var bindings: Dictionary=CODEC.capture(ui.REMAPPABLE_ACTIONS)
    desk.model.apply_writer=func(_config: ConfigFile,_path: String):return ERR_CANT_CREATE
    check(not desk.model.apply("夜间阅读",ui,1,snapshot).ok and ui.accessibility==current and CODEC.capture(ui.REMAPPABLE_ACTIONS)==bindings,"failed settings write leaves real preferences and InputMap untouched")
    desk.model.apply_writer=Callable()
    check(desk.model.apply("夜间阅读",ui,1,snapshot).ok and ui.accessibility.subtitle_size==snapshot.values.subtitle_size,"successful scoped write applies actual accessibility values")
    var config:=ConfigFile.new()
    check(config.load(ui.accessibility_path)==OK and config.get_value("accessibility","subtitle_size")==snapshot.values.subtitle_size,"applied settings exist in the real preference file")
    check(CODEC.capture(ui.REMAPPABLE_ACTIONS)==bindings,"visual-only scope preserves all actual input mappings")
    check(desk.model.quote("夜间阅读",ui,0).ok,"full saved keyboard/controller capture passes shared conflict policy")
    var custom:=snapshot.duplicate(true)
    for event in custom.bindings.jump:
        if event.type=="key":event.physical=KEY_F6;event.logical=0
    check(desk.model.manage("replace","夜间阅读","",custom).ok,"named profile can explicitly replace its saved input mapping")
    check(desk.model.apply("夜间阅读",ui,3,custom).ok and InputMap.action_get_events("jump").any(func(event):return event is InputEventKey and event.physical_keycode==KEY_F6),"input-only application updates actual InputMap after durable config write")
    var conflicting:=custom.duplicate(true)
    var attack_events: Array=InputMap.action_get_events("attack")
    for event in attack_events:
        if event is InputEventKey:conflicting.bindings.jump=[CODEC.encode(event)];break
    desk.model.manage("replace","夜间阅读","",conflicting)
    var working: Dictionary=CODEC.capture(ui.REMAPPABLE_ACTIONS)
    check(not desk.model.quote("夜间阅读",ui,3).ok and CODEC.capture(ui.REMAPPABLE_ACTIONS)==working,"conflicting saved mapping is rejected as a whole without changing live inputs")
    desk.model.manage("replace","夜间阅读","",custom)
    desk.ask("apply")
    check(desk.confirm.get_cancel_button().has_focus(),"destructive/apply confirmation defaults to cancel")
    ui.accessibility.subtitle_size=19;desk._confirm()
    check(ui.accessibility.subtitle_size==19 and desk.window.status.text.contains("变化"),"current changes after preview require reconfirmation")
    await preload("res://scripts/settings_profile_transfer_validation.gd").run(self,main,desk)
    await preload("res://scripts/build_shortcut_validation.gd").run(self,main,desk)
    main._close_overlays()
    check(not desk.window.visible and not desk.confirm.visible,"closing settings dismisses both management and confirmation windows")
    var retirement:=preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main);main.free();await process_frame
    check(await retirement.drain(self),"fixture drains actual audio")
    for failure in failures:push_error(failure)
    if failures.is_empty():print("SETTINGS_PROFILES checks=%d failures=0" % checks)
    quit(0 if failures.is_empty() else 1)
