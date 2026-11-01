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
    for unused in 4:await process_frame
func snapshot(world: Node) -> Dictionary:
    return {"wallet":world.currency_count,"inventory":world.inventory_counts.duplicate(true),
        "flags":world.story_flags.duplicate(true),"build":world.build_system.serialize().duplicate(true),
        "hp":world.player.hp,"energy":world.player.energy,"position":world.player.global_position}
func run() -> void:
    var size_before:=root.size
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://journey_window_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World did not become ready");quit(1);return
    # Let the normal spawn contact/hint finish before measuring read-only UI.
    for unused in 4:
        await physics_frame
        await process_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    check(world._save_world(),"fixture creates a real gameplay save before UI traversal")
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    var before:=snapshot(world)
    var ui: Control=world.ui_shell
    var original_reading: Variant=ui.accessibility.subtitle_size
    world._toggle_audio_settings()
    var profiles: Node=ui.get_node("SettingsProfilesDesk")
    ui.accessibility.subtitle_size=26
    ui.settings.get_node("SettingsProfilesButton").pressed.emit();await frames()
    check(profiles.window.visible and profiles.name_input.has_focus(),"actual saved-profile desk opens with its original input focus")
    check(profiles.window.body.follow_focus,"actual shared desk uses focus-following scroll body")
    var first_label:=profiles.window.column.get_child(0) as Label
    check(first_label!=null and first_label.get_theme_font_size("font_size")==26,"real explanatory body follows current reading preference")
    var actual_viewport:=ui.get_viewport_rect().size
    check(profiles.window.size.x<=actual_viewport.x and profiles.window.size.y<=actual_viewport.y,"actual profile desk fits current viewport")
    profiles.name_input.text="布局检查但不保存"
    profiles.name_input.grab_focus();await frames()
    check(profiles.window.body.get_global_rect().intersects(profiles.name_input.get_global_rect()),"actual focused input remains reachable in scroll viewport")
    profiles.window.get_ok_button().grab_focus();await frames()
    check(profiles.window.get_ok_button().is_visible_in_tree(),"native close button stays available separately from scrolling form")
    profiles.window.hide();await frames()
    root.size=Vector2i(640,360);await frames()
    profiles.open();await frames()
    actual_viewport=ui.get_viewport_rect().size
    check(profiles.window.visible and profiles.window.size.x<=actual_viewport.x and profiles.window.size.y<=actual_viewport.y,"same actual desk can reopen after reducing the game window")
    profiles.name_input.grab_focus();await frames()
    check(profiles.name_input.has_focus(),"small viewport preserves actual editable control focus")
    var small_size: Vector2i=profiles.window.size
    root.size=Vector2i(1280,720);await frames()
    check(profiles.window.size.x>=small_size.x and profiles.window.size.y>=small_size.y,"visible real desk responds to game-window growth")
    profiles.window.hide();ui.accessibility.subtitle_size=17;profiles.open();await frames()
    check(first_label.get_theme_font_size("font_size")==17,"actual desk reverses enlarged typography without accumulating scale")
    check(snapshot(world)==before,"adaptive layout does not change gameplay resources, position, flags or build")
    check(FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"resizing and reading never rewrite gameplay save bytes")
    world._close_overlays();await frames()
    check(not profiles.window.visible and not world.player.ui_input_locked,"closing the real owner releases nested window and player input lock")
    root.size=size_before;await frames()
    world._toggle_build()
    var practice: Node=ui.get_node("PracticeDesk")
    ui.build_panel.get_node("PracticeDeskButton").pressed.emit();await frames()
    check(practice.window.visible and practice.list.has_focus(),"actual practice desk retains authored list focus")
    check(practice.window.body.get_parent()==practice.window,"different build-owned desk uses the same adaptive body")
    var practice_intro:=practice.window.column.get_child(0) as Label
    check(practice_intro.get_theme_font_size("font_size")==17,"practice explanatory text follows the smaller current reading setting")
    practice.search.grab_focus();await frames()
    check(practice.window.body.get_global_rect().intersects(practice.search.get_global_rect()),"practice search is reachable without starting a course")
    world._close_overlays();await frames()
    check(not practice.window.visible and not practice.curriculum.active,"closing build owner cannot start or retain a practice course")
    world._toggle_build()
    var contracts: Node=ui.get_node("FieldContractDesk")
    ui.build_panel.get_node("FieldContractButton").pressed.emit();await frames()
    check(contracts.window.visible and contracts.query.has_focus(),"actual contract desk preserves its search focus")
    check(contracts.window.body.follow_focus and contracts.rows.size()>0,"known contract rows remain reachable in the adaptive window")
    contracts.region_filter.grab_focus();await frames()
    check(contracts.region_filter.has_focus(),"contract region selector remains keyboard reachable")
    world._close_overlays();await frames()
    check(not contracts.window.visible and contracts.pending.is_empty(),"owner close retires the contract window without a pending transaction")
    check(snapshot(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"opening different adaptive desks changes no gameplay record or resource")
    ui.accessibility.subtitle_size=original_reading;await frames()
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"real World audio fully retires after resize traversal")
    for suffix in ["",".bak",".tmp",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://journey_window_world.json"+suffix))
    print("JOURNEY_WINDOW_WORLD checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
