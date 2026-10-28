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
    return {"currency":world.currency_count,"inventory":world.inventory_counts.duplicate(true),"flags":world.story_flags.duplicate(true),"build":world.build_system.serialize().duplicate(true),"hp":world.player.hp,"energy":world.player.energy,"position":world.player.global_position}
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://journal_find_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:
        await physics_frame
        await process_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    check(world._save_world(),"fixture captures real World save before reader traversal")
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    var before:=snapshot(world)
    var ui: Control=world.ui_shell
    var dialog: Window=ui.bag.get_node("JournalDocumentFind")
    check(dialog.launcher.disabled,"page find is unavailable outside a selected journal record")
    world._toggle_backpack();ui.bag_category="旅记";ui.refresh_inventory();await frames()
    var chosen: Dictionary={}
    for document in ui.journal_documents:
        if String(document.text).length()>String(chosen.get("text","")).length():chosen=document
    check(not chosen.is_empty(),"World supplies an already-disclosed journal document")
    if chosen.is_empty():quit(1);return
    ui._show_journal_record(chosen.entry);await frames()
    var body: RichTextLabel=ui.bag_description
    var bar:=body.get_v_scroll_bar();bar.value=maxf(0,bar.max_value-bar.page)*0.4;await frames()
    var offset:=bar.value;var original:=body.text
    var read_before: Dictionary=ui.journal_catalog.profiles.duplicate(true)
    check(not dialog.launcher.disabled,"actual journal selection enables literal reader action")
    check(ui.journal_tools.position.x+ui.journal_tools.size.x<=704,"expanded toolbar stays within its left-side column")
    check(not dialog.launcher.get_rect().intersects(ui.journal_sort.get_rect()),"find action has separate native toolbar geometry")
    dialog.launcher.pressed.emit();await frames()
    check(dialog.visible and dialog.query.has_focus() and ui.is_text_entry_focused(),"actual native query owns typing focus and registered-modal input protection")
    check(dialog.editor.text==original.replace("\r\n","\n").replace("\r","\n") and not dialog.editor.editable,"new reader exposes exactly selected public body as read-only plain text")
    var term: String="。" if original.contains("。") else original.strip_edges().substr(0,1)
    dialog.query.text=term;dialog.query.text_changed.emit(term);await frames()
    check(not dialog.report.matches.is_empty() and dialog.editor.get_selected_text()==term,"real TextEdit selects actual known-document literal")
    var initial: int=dialog.selected
    dialog.next.pressed.emit();await frames()
    check(dialog.selected==(initial+1)%dialog.report.matches.size(),"actual next action follows bounded match sequence")
    dialog.previous.pressed.emit();await frames()
    check(dialog.selected==initial,"actual previous action reverses match navigation")
    check(body.text==original and is_equal_approx(bar.value,offset),"modal search does not move original reading position or edit original body")
    var letter:=InputEventKey.new();letter.physical_keycode=KEY_B;letter.keycode=KEY_B;letter.unicode=98;letter.pressed=true
    dialog.query.grab_focus();ui._input(letter)
    check(world.active_overlay=="backpack","typing action letters cannot open the build screen behind native reader")
    Input.action_press("map");world._process(0.0);Input.action_release("map")
    check(world.active_overlay=="backpack","polled map action cannot steal input from the registered native query")
    dialog.query.text="未公开秘密987";dialog.query.text_changed.emit(dialog.query.text);await frames()
    check(dialog.report.matches.is_empty() and dialog.next.disabled and dialog.preview.text.is_empty(),"no-match result does not inspect undisclosed journal entries or retain old preview")
    dialog.hide();dialog.canceled.emit();await frames()
    check(not dialog.visible and dialog.editor.text.is_empty() and dialog.source.is_empty(),"closing reader clears detached content and selection")
    check(is_equal_approx(bar.value,offset) and ui.journal_current_document.key==chosen.key,"closing returns to same original document and scroll")
    dialog.open();await frames()
    ui.journal_search.text="未公开秘密987";ui.journal_search.text_changed.emit(ui.journal_search.text);await frames()
    check(ui.journal_current_document.is_empty() and not dialog.visible and dialog.launcher.disabled,"actual across-record filter retires a now-unavailable selected source")
    ui.journal_search.text="";ui.journal_search.text_changed.emit("");await frames()
    dialog.open();await frames()
    ui.bag_category="材料";ui.refresh_inventory();await frames()
    check(not ui.journal_tools.visible and not dialog.visible,"ordinary inventory category switch hides the new reader with original tools")
    check(snapshot(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"entire search/navigation/typing/filter flow preserves gameplay and exact saved bytes")
    check(ui.journal_catalog.profiles==read_before,"literal finding changes neither explicit read marks nor starred records")
    world._close_overlays();await frames();check(not world.player.ui_input_locked,"original overlay close releases gameplay input")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"native World audio finishes retirement before exit")
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with("journal_find_world.json"):DirAccess.remove_absolute("user://"+name)
    print("JOURNAL_FIND_WORLD checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
