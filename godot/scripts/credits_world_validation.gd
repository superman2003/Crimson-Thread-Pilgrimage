extends SceneTree
## Actual World entry, settings ownership and gameplay-state isolation.
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func snapshot(world: Node) -> Dictionary:
    return {"wallet":world.currency_count,"inventory":world.inventory_counts.duplicate(true),
        "flags":world.story_flags.duplicate(true),"build":world.build_system.serialize().duplicate(true),
        "hp":world.player.hp,"energy":world.player.energy,"position":world.player.global_position}
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://credits_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World failed to become ready");quit(1);return
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    check(world._save_world(),"fixture establishes a real immutable gameplay save")
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    var before:=snapshot(world)
    world._toggle_audio_settings()
    var ui: Control=world.ui_shell
    check(ui.settings.visible and world.player.ui_input_locked,"settings owns input before opening source reader")
    var desk: Node=ui.get_node_or_null("CreditsReader")
    check(desk!=null,"actual World has one native credits component")
    if desk==null:RETIRE.retire_tree(world);world.queue_free();await process_frame;quit(1);return
    var button:=ui.settings.get_node("CreditsReaderButton") as Button
    check(button.is_visible_in_tree() and button.focus_mode==Control.FOCUS_ALL,"real source button is visible and focusable")
    button.grab_focus();check(button.has_focus(),"keyboard focus reaches actual source entry")
    button.pressed.emit();await process_frame
    check(desk.window.visible and desk.search.has_focus(),"actual settings launcher opens owned source reader")
    check(world.active_overlay=="settings" and world.player.ui_input_locked,"reader does not replace settings input ownership")
    check(desk.rows.size()>=2 and not desk.reader.text.is_empty(),"actual package source index and bytes are readable")
    var viewport:=ui.get_viewport_rect().size
    check(desk.window.size.x<=viewport.x and desk.window.size.y<=viewport.y,"reader remains within actual logical viewport")
    var entry: String=desk.selected
    var long_index:=0
    for index in desk.rows.size():
        if int(desk.rows[index].bytes)>int(desk.rows[long_index].bytes):long_index=index
    desk.show_document(long_index);await process_frame
    desk.bottom();await process_frame
    var bar: VScrollBar=desk.reader.get_v_scroll_bar()
    var offset:=bar.value
    check(offset>=0 and offset<=bar.max_value,"long source can scroll to a bounded native position")
    desk.show_document(0);await process_frame
    desk.show_document(long_index);await process_frame
    check(absf(bar.value-offset)<2.0,"switching sources restores in-window reading position")
    var generation: int=desk.generation
    desk.search.text="no-source-matches";desk.search.text_changed.emit(desk.search.text);await process_frame
    check(desk.rows.is_empty() and desk.selected.is_empty(),"actual search removes stale source selection")
    desk.restore_position(entry,generation)
    check(desk.rows.is_empty() and desk.reader.text.contains("没有符合"),"late restore cannot replace newer empty search")
    desk.clear_search();await process_frame
    check(desk.rows.size()>=2 and desk.search.has_focus(),"native clear provides a keyboard return to sources")
    for index in desk.groups.size():
        desk.category.select(index);desk.category.item_selected.emit(index);await process_frame
        check(not desk.rows.is_empty(),"each published category contains an actual bundled document")
    check(snapshot(world)==before,"source reading cannot change wallet, flags, build, health or position")
    check(FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"source reading cannot rewrite gameplay save bytes")
    world._close_overlays();await process_frame
    check(not desk.window.visible and desk.reader.text.is_empty(),"closing actual settings retires the reader")
    check(not world.player.ui_input_locked,"closing source settings restores gameplay input")
    desk.open();check(not desk.window.visible,"stale hidden callback cannot reopen actual settings reader")
    var remembered: String=desk.last_selected
    world._toggle_audio_settings();button.pressed.emit();await process_frame
    check(desk.selected==remembered,"reopening actual settings resumes the last verified source")
    world._close_overlays();await process_frame

    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio retires without leaks")
    for suffix in ["",".tmp",".bak",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://credits_world.json"+suffix))
    print("CREDITS_WORLD checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
