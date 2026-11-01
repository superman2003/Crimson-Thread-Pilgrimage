extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames() -> void:
    for index in 5:await process_frame
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://settings_dialog_layout_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for index in 4:await physics_frame;await process_frame
    world.set_process(false);world.set_physics_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var ui: Control=world.ui_shell;ui.accessibility_path="user://settings_dialog_layout_test.cfg"
    ui.accessibility.subtitle_size=26;ui._apply_accessibility();check(ui._save_accessibility()==OK,"fixture persists large reading preference")
    world._toggle_audio_settings();await frames()
    check(world._save_world(),"fixture saves stable gameplay state before form traversal")
    var disk:=FileAccess.get_file_as_bytes(world.world_save_path);var preferences:=FileAccess.get_file_as_bytes(ui.accessibility_path)
    var before:=var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.hp,world.player.energy,world.player.global_position])
    root.content_scale_size=Vector2i(960,540);root.size=Vector2i(960,540);await frames()
    ui._open_controller_comfort();await frames()
    var comfort: Node=ui.controller_comfort_dialog
    var adapter: Node=comfort.get_node("SettingsDialogLayout")
    var intro:=adapter.content().get_child(0) as Label
    check(comfort.visible and comfort.size.y<=ui.get_viewport_rect().size.y,"actual controller dialog fits smaller logical game viewport")
    check(intro.get_theme_font_size("font_size")==26,"actual global-typeface body follows reading size26")
    check(adapter.body.follow_focus and adapter.body.get_parent()==comfort,"actual comfort retains scroll ownership")
    var baseline: Dictionary=comfort.candidate.duplicate(true)
    comfort.choose_preset("reading");var staged: Dictionary=comfort.candidate.duplicate(true)
    check(staged!=baseline and ui.accessibility.subtitle_size==26,"existing comfort preset remains a staged candidate")
    comfort.deadzone.grab_focus();await frames()
    check(adapter.body.get_global_rect().intersects(comfort.deadzone.get_global_rect()),"actual slider receives reachable keyboard focus")
    comfort.get_cancel_button().grab_focus();await frames()
    check(comfort.get_cancel_button().is_visible_in_tree() and comfort.get_cancel_button().position.y>=0,"native cancel remains reachable outside body")
    root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await frames()
    check(comfort.size.y>=600 and comfort.candidate==staged,"growing viewport preserves staged calibration values")
    ui.accessibility.subtitle_size=17;adapter.request();await frames()
    check(intro.get_theme_font_size("font_size")==17,"actual body returns to smaller reading preference")
    ui.accessibility.subtitle_size=26;adapter.request();await frames()
    check(intro.get_theme_font_size("font_size")==26,"actual typography is reversible")
    check(comfort.candidate==staged,"typography does not apply or replace staged comfort preset")
    comfort.hide();await frames()
    var output: Node=ui.get_node("AudioOutputDesk");var device_before: String=output.model.active()
    ui.settings.get_node("AudioOutputDeviceButton").pressed.emit();await frames()
    var audio_adapter: Node=output.window.get_node("SettingsDialogLayout")
    check(output.window.visible and output.options.has_focus(),"actual audio output keeps authored selector focus")
    check(audio_adapter.body.follow_focus,"actual output form uses same focus-following scroll owner")
    var explanation:=audio_adapter.content().get_child(0) as Label
    check(explanation.get_theme_font_size("font_size")==26,"actual output explanation follows body reading size")
    root.content_scale_size=Vector2i(960,540);root.size=Vector2i(960,540);await frames()
    check(output.window.size.y<=ui.get_viewport_rect().size.y and output.window.position.y>=0,"actual audio output remains framed after shrinking")
    output.ask();await frames()
    check(output.confirm.visible,"original device confirmation still opens")
    output.confirm.get_cancel_button().pressed.emit();await frames()
    check(output.model.active()==device_before,"cancel keeps actual output route unchanged")
    check(var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.hp,world.player.energy,world.player.global_position])==before,"reading and resizing keep actual gameplay state unchanged")
    check(FileAccess.get_file_as_bytes(world.world_save_path)==disk,"form adaptation preserves exact game save bytes")
    check(FileAccess.get_file_as_bytes(ui.accessibility_path)==preferences,"layout never saves staged or temporary reading changes")
    world._close_overlays();await frames()
    check(not output.window.visible and not world.player.ui_input_locked,"original settings close retires form and restores gameplay input")
    var viewport:=ui.get_viewport();var listeners_before:=viewport.size_changed.get_connections().size()
    comfort.queue_free();output.window.queue_free();await frames()
    check(viewport.size_changed.get_connections().size()<=listeners_before-2,"actual settings owners disconnect both viewport listeners")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio ownership retired")
    print("SETTINGS_DIALOG_LAYOUT_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
