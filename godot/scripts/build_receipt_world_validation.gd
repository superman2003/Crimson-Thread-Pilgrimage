extends SceneTree
## Actual settings-to-credits entry and read-only scan lifecycle.
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const INSPECT:=preload("res://scripts/build_receipt_inspector.gd")
var checks:=0
var failures:=0
var copied:=""
var folder:="user://build_receipt_fixture"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func snapshot(world: Node) -> Dictionary:
    return {"wallet":world.currency_count,"inventory":world.inventory_counts.duplicate(true),
        "flags":world.story_flags.duplicate(true),"build":world.build_system.serialize().duplicate(true),
        "hp":world.player.hp,"energy":world.player.energy,"position":world.player.global_position}
func fixture() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    var file:=FileAccess.open(folder.path_join("payload.bin"),FileAccess.WRITE)
    file.store_buffer("fixture ".repeat(131072).to_utf8_buffer());file.close()
    var path:=folder.path_join("payload.bin")
    var data:={"schema_version":1,"source_commit":"a".repeat(40),"source_dirty":false,"target":"linux", "engine":"4.6.1.fixture","qualification":"test candidate","validation":["declared fixture only"],"files":{"payload.bin":{"bytes":FileAccess.get_file_as_bytes(path).size(),"sha256":FileAccess.get_sha256(path)}}}
    file=FileAccess.open(folder.path_join(INSPECT.MANIFEST),FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
func settle(dialog: Node) -> void:
    for unused in 100:
        if not dialog.model.working:break
        await process_frame
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://build_receipt_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:await physics_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    check(world._save_world(),"establish exact saved gameplay fixture")
    var before:=snapshot(world)
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    world._toggle_audio_settings()
    var ui: Control=world.ui_shell
    var desk: Node=ui.get_node("CreditsReader")
    ui.settings.get_node("CreditsReaderButton").pressed.emit();await process_frame
    var launch: Button
    for button in desk.window.find_children("*","Button",true,false):
        if button.text=="发行构建与核对":launch=button
    check(launch!=null and launch.is_visible_in_tree(),"actual credits navigation exposes receipt entry")
    if launch==null:RETIRE.retire_tree(world);world.queue_free();await process_frame;quit(1);return
    desk.bottom();await process_frame
    var source: String=desk.selected
    var text: String=desk.reader.text
    var scroll: float=desk.reader.get_v_scroll_bar().value
    launch.grab_focus();check(launch.has_focus(),"receipt launcher is keyboard reachable")
    launch.pressed.emit();await process_frame
    var dialog: Node=desk.build_receipt
    check(dialog.visible and world.active_overlay=="settings" and world.player.ui_input_locked,"nested receipt retains actual settings ownership")
    check(dialog.model.metadata.is_empty() and not dialog.model.report().passed,"editor executable has no invented release manifest")
    check(not dialog.status.text.is_empty(),"missing adjacent manifest has readable feedback")
    fixture();dialog.root_override=ProjectSettings.globalize_path(folder);dialog.reload_manifest()
    var manifest_bytes:=FileAccess.get_file_as_bytes(folder.path_join(INSPECT.MANIFEST))
    var payload_bytes:=FileAccess.get_file_as_bytes(folder.path_join("payload.bin"))
    check(dialog.details.text.contains("a".repeat(40)) and dialog.details.text.contains("当前引擎"),"actual dialog shows source identity and actual engine separately")
    check(dialog.details.text.contains("不是本机重新执行"),"declared validation labels cannot be mistaken for locally rerun tests")
    check(not dialog.model.report().passed and not dialog.start_button.disabled and dialog.stop_button.disabled,"metadata-only state offers explicit start")
    dialog.start_button.pressed.emit()
    check(dialog.model.working and dialog.start_button.disabled and not dialog.stop_button.disabled,"real start signal begins incremental verification")
    dialog.stop_button.pressed.emit()
    check(dialog.model.cancelled and not dialog.model.report().passed and dialog.status.text.contains("停止"),"real stop signal cannot imply complete pass")
    dialog.start_button.pressed.emit();await settle(dialog)
    check(dialog.model.report().passed and dialog.status.text.contains("全部一致"),"native frame loop completes and displays actual matching files")
    check(FileAccess.get_file_as_bytes(folder.path_join(INSPECT.MANIFEST))==manifest_bytes and FileAccess.get_file_as_bytes(folder.path_join("payload.bin"))==payload_bytes,"inspection preserves actual manifest and payload bytes")
    dialog.clipboard_writer=func(value: String):copied=value
    dialog.copy_summary()
    check(copied.contains("a".repeat(40)) and copied.contains("已完成") and not copied.contains(dialog.root_override),"copy action receives bounded build summary without absolute fixture directory")
    var file:=FileAccess.open(folder.path_join("payload.bin"),FileAccess.WRITE);file.store_string("broken");file.close()
    dialog.start_scan();await settle(dialog)
    check(not dialog.model.report().passed and dialog.details.text.contains("大小不符"),"actual UI displays changed-file mismatch")
    fixture();dialog.reload_manifest();dialog.start_scan()
    desk.window.hide();await process_frame
    check(not dialog.visible and not dialog.model.working and not dialog.model.report().passed,"closing credits stops its child without publishing partial pass")
    dialog.start_scan();check(not dialog.model.working,"stale hidden start callback does not read files")
    desk.open();await process_frame
    check(desk.selected==source and desk.reader.text==text,"child reader leaves selected source and body unchanged")
    check(absf(desk.reader.get_v_scroll_bar().value-scroll)<2.0,"original source scroll position survives child lifecycle")
    launch.pressed.emit();await process_frame;dialog.start_scan()
    world._close_overlays();await process_frame
    check(not dialog.visible and not dialog.model.working and not world.player.ui_input_locked,"closing settings retires all nested reading and restores player input")
    copied="";dialog.copy_summary();check(copied.is_empty(),"hidden stale copy cannot expose previous receipt")
    check(snapshot(world)==before,"receipt controls preserve gameplay resources, flags, build and position")
    check(FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"receipt controls preserve exact gameplay save bytes")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World retirement releases audio")
    for name in [INSPECT.MANIFEST,"payload.bin"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
    for suffix in ["",".tmp",".bak",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://build_receipt_world.json"+suffix))
    print("BUILD_RECEIPT_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
