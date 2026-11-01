extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const STORE:=preload("res://scripts/journal_mark_store.gd")
var checks:=0
var failures:=0
class FailingInstall extends "res://scripts/settings_persistence.gd":
    var fail:=true
    func _install(temporary: String, destination: String) -> Error:
        return ERR_CANT_CREATE if fail else super._install(temporary,destination)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames() -> void:
    for unused in 4:await process_frame
func snapshot(world: Node) -> Dictionary:
    return {"currency":world.currency_count,"inventory":world.inventory_counts.duplicate(true),"flags":world.story_flags.duplicate(true),"build":world.build_system.serialize().duplicate(true),"hp":world.player.hp,"energy":world.player.energy,"position":world.player.global_position}
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://journal_marks_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:
        await physics_frame
        await process_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    check(world._save_world(),"fixture saves actual World before reading-only actions")
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    var before:=snapshot(world)
    var ui: Control=world.ui_shell
    var desk: Node=ui.get_node("JournalMarkDesk")
    check(desk.launcher.disabled,"mark action is unavailable outside journal reading")
    world._toggle_backpack();ui.bag_category="旅记";ui.refresh_inventory();await frames()
    var chosen: Dictionary={}
    for document in ui.journal_documents:
        if String(document.text).length()>String(chosen.get("text","")).length():chosen=document
    check(not chosen.is_empty(),"fixture uses an actual already-public journal record")
    if chosen.is_empty():quit(1);return
    ui._show_journal_record(chosen.entry);await frames()
    var body: RichTextLabel=ui.bag_description
    var bar:=body.get_v_scroll_bar()
    var maximum:=maxf(0,bar.max_value-bar.page)
    check(maximum>0,"actual known record has scrollable long text")
    var target:=maximum*0.5;bar.value=target;await frames()
    check(not desk.launcher.disabled,"settled actual document exposes explicit mark action")
    for button in ui.bag.get_children():
        if button is Button and button.text=="资源用途核对":check(not desk.launcher.get_global_rect().intersects(button.get_global_rect()),"new launcher does not overlap resource-purpose action")
    var reading_before: Dictionary=ui.journal_catalog.profiles.duplicate(true)
    desk.launcher.pressed.emit();await frames()
    check(desk.window.visible and desk.window.get_ok_button().has_focus(),"real launcher opens with safe return focus")
    desk.save_button.pressed.emit();await frames()
    var document: Dictionary=ui.journal_current_document.duplicate(true)
    check(desk.model.records.has(document.key) and is_equal_approx(float(desk.model.records[document.key].offset),target),"real UI saves actual current scroll offset")
    check(FileAccess.file_exists(desk.model.path) and desk.description.text.contains("已保存"),"UI reports saved only after real verified write")
    check(ui.journal_catalog.profiles==reading_before,"saving position does not change read or starred state")
    check(FileAccess.get_file_as_bytes(world.world_save_path)==bytes and snapshot(world)==before,"saving reading mark preserves gameplay bytes and resources")
    var mark_bytes:=FileAccess.get_file_as_bytes(desk.model.path)
    var fresh:=STORE.new();fresh.configure(String(world.world_save_path))
    check(fresh.position(document,maximum,body.size.x,float(body.get_theme_font_size("normal_font_size"))).offset==target,"fresh reader instance can load mark produced by actual UI")
    desk.window.hide();bar.value=0;await frames();desk.open();desk.restore_button.pressed.emit();await frames()
    check(not desk.window.visible and is_equal_approx(bar.value,target),"explicit restore returns to journal at saved actual pixel offset")
    check(not ui.journal_restore_pending,"restore completes through original deferred generation guard")
    body.add_theme_font_size_override("normal_font_size",26);await frames();bar.value=0;desk.open();await frames()
    var expected: Dictionary=desk._position()
    check(expected.ok and expected.relative and desk.description.text.contains("原比例"),"different reading typography explains proportional restore")
    desk.restore_button.pressed.emit();await frames()
    check(is_equal_approx(bar.value,float(expected.offset)),"real reflow restores proportion within new scroll maximum")
    check(FileAccess.get_file_as_bytes(desk.model.path)==mark_bytes,"reading and restoring do not rewrite mark preferences")
    var failing:=FailingInstall.new();desk.model.persistence=failing
    bar.value=0;desk.open();desk.save_button.pressed.emit();await frames()
    check(desk.model.has_pending and desk.description.text.contains("未保存"),"real write failure is visible and retains pending intent")
    check(desk.save_button.disabled and not desk.retry_button.disabled and desk.remove_button.disabled,"pending operation cannot be silently discarded by new save or deletion")
    check(FileAccess.get_file_as_bytes(desk.model.path)==mark_bytes,"UI save failure preserves old mark bytes")
    failing.fail=false;desk.retry_button.pressed.emit();await frames()
    check(not desk.model.has_pending and desk.model.records[document.key].offset==0.0,"explicit retry commits intended offset once")
    var latest_mark:=FileAccess.get_file_as_bytes(desk.model.path)
    ui.reading_session_generation+=1;desk.remove_button.pressed.emit();await frames()
    check(FileAccess.get_file_as_bytes(desk.model.path)==latest_mark,"former reading generation cannot remove a newer session mark")
    desk.refresh_launcher();check(not desk.window.visible,"outdated document ownership closes mark window")
    desk.open();await frames();desk.remove_button.pressed.emit();await frames()
    check(not desk.model.records.has(document.key) and desk.restore_button.disabled,"explicit current-document removal disables restore without changing content")
    ui.bag.hide();await frames()
    check(not desk.window.visible and desk.launcher.disabled,"closing bag retires nested mark window and launcher ownership")
    check(ui.journal_catalog.profiles==reading_before and snapshot(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"entire real mark workflow leaves reading flags and gameplay exact")
    var preference_path: String=desk.model.path
    world._close_overlays();await frames();check(not world.player.ui_input_locked,"original overlay close releases player input")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"audio fully retires before native World exit")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(preference_path))
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with("journal_marks_world.json"):DirAccess.remove_absolute("user://"+name)
    print("JOURNAL_MARKS_WORLD checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
