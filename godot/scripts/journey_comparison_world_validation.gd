extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const STATE:=preload("res://scripts/world_state.gd")
const PATH:="user://journey_comparison_world.json"
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames() -> void:
    for unused in 4:await process_frame
func gameplay(world: Node) -> Dictionary:
    return {"currency":world.currency_count,"inventory":world.inventory_counts.duplicate(true),"flags":world.story_flags.duplicate(true),"build":world.build_system.serialize().duplicate(true),"hp":world.player.hp,"energy":world.player.energy,"position":world.player.global_position}
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path=PATH;root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:
        await physics_frame
        await process_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    check(world._save_world(),"fixture saves actual current World through original transaction")
    var primary_bytes:=FileAccess.get_file_as_bytes(PATH)
    var primary:=STATE.new();check(primary.read(PATH),"fixture current source is a real validated world record")
    var saved_currency:=int(primary.data.currency)
    var archive:=STATE.new();archive.data=primary.data.duplicate(true)
    archive.data.currency=7
    check(archive.write(PATH+".previous"),"fixture preserves distinct real same-slot archive")
    var archive_bytes:=FileAccess.get_file_as_bytes(PATH+".previous")
    var before:=gameplay(world)
    var ui: Control=world.ui_shell
    world._toggle_audio_settings();ui.journey_history_button.pressed.emit();await frames()
    var browser: AcceptDialog=ui.journey_history_dialog
    check(browser.visible and browser.compare_query.is_valid(),"real settings entry wires optional current-save comparison callback")
    check(browser.compare_button.disabled,"opening real browser does not select or restore an archive implicitly")
    var selected:=-1
    for index in browser.rows.size():
        if browser.rows[index].file==PATH.get_file()+".previous":selected=index
    check(selected>=0,"actual history enumerator supplies intended preserved identity")
    if selected>=0:
        browser.entries.select(selected);browser.entries.item_selected.emit(selected);await frames()
        check(not browser.compare_button.disabled,"real archive selection enables comparison")
        browser.compare_button.grab_focus()
        check(browser.compare_button.has_focus(),"new comparison action is keyboard focusable")
        browser.compare_button.pressed.emit();await frames()
        check(browser.detail_text.text.contains("碎钱：7 → %d" % saved_currency),"real UI compares archive with current saved amount")
        check(browser.detail_text.text.contains("未保存的实时变化不在其中"),"comparison scope is explicit in player-facing text")
        check(not browser.detail_text.text.contains("res://") and not browser.detail_text.text.contains("collected_ids"),"rendered comparison exposes no save schema or source paths")
        check(gameplay(world)==before,"comparison leaves live resources, flags, equipment and position exact")
        check(FileAccess.get_file_as_bytes(PATH)==primary_bytes and FileAccess.get_file_as_bytes(PATH+".previous")==archive_bytes,"actual browser comparison preserves both source bytes")
        world.currency_count=saved_currency+11
        browser.compare_button.pressed.emit();await frames()
        check(browser.detail_text.text.contains("碎钱：7 → %d" % saved_currency) and world.currency_count==saved_currency+11,"unsaved live currency is neither installed nor mistaken for saved progress")
        world.currency_count=before.currency
        var changed:=FileAccess.open(PATH+".previous",FileAccess.WRITE);changed.store_string("changed by fixture writer");changed.close()
        var changed_bytes:=FileAccess.get_file_as_bytes(PATH+".previous")
        browser.compare_button.pressed.emit();await frames()
        check(browser.detail_text.text.contains("已变化"),"actual callback refuses changed archive identity")
        check(FileAccess.get_file_as_bytes(PATH+".previous")==changed_bytes and FileAccess.get_file_as_bytes(PATH)==primary_bytes,"failure preserves changed source and valid primary bytes")
        browser.request_page(0);await frames()
        var broken_index:=-1
        for index in browser.rows.size():
            if browser.rows[index].file==PATH.get_file()+".previous":broken_index=index
        check(broken_index>=0,"damaged archive stays listed rather than deleted or hidden")
        if broken_index>=0:
            browser.select_entry(broken_index);await frames()
            check(browser.compare_button.disabled and browser.detail_text.text.contains("无法读取"),"damaged archive has readable explanation and no comparison action")
    browser.get_ok_button().pressed.emit();browser.hide();await frames()
    check(not ui.is_browsing_journey_history(),"closing comparison returns to existing settings ownership")
    check(gameplay(world)==before and FileAccess.get_file_as_bytes(PATH)==primary_bytes,"closing reader does not save, recover or apply either record")
    world._close_overlays();await frames()
    check(not world.player.ui_input_locked,"settings close releases player input through original owner")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio retires before fixture exit")
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with(PATH.get_file()):DirAccess.remove_absolute("user://"+name)
    print("JOURNEY_COMPARISON_WORLD checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
