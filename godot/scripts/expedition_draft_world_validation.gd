extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const JOURNAL:=preload("res://scripts/pilgrimage_cartography.gd")
const PLAN:=preload("res://scripts/expedition_plan.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames() -> void:
    for unused in 4:await process_frame
func press(window: Window, caption: String) -> bool:
    for node in window.find_children("*","Button",true,false):
        if node.text==caption:node.pressed.emit();return true
    return false
func snapshot(world: Node) -> Dictionary:
    return {"wallet":world.currency_count,"inventory":world.inventory_counts.duplicate(true),"flags":world.story_flags.duplicate(true),"build":world.build_system.serialize().duplicate(true),"position":world.player.global_position,"hp":world.player.hp,"energy":world.player.energy}
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://expedition_draft_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:
        await physics_frame
        await process_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    # Explicit map-knowledge fixture, not a claim of natural discovery.
    var region:=String(world.config.id);JOURNAL.region(world.story_flags,region).owned=true
    for room in world.config.map_rooms.slice(0,3):JOURNAL.region(world.story_flags,region).charted[String(room.id)]=true
    check(world._save_world(),"fixture saves charted starting knowledge through original World transaction")
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path);var before:=snapshot(world)
    world._toggle_map()
    var desk: Node=world.ui_shell.get_node("ExpeditionDesk")
    world.map_panel.get_node("ExpeditionDeskButton").pressed.emit();await frames()
    check(desk.known.size()>=2,"actual directory supplies at least two public stations")
    if desk.known.size()<2:quit(1);return
    var first: String=desk.known[0].key;var second: String=desk.known[1].key
    for key in [first,second]:desk.catalog_key=key;desk.act("add")
    desk.plan.command("done",first,desk.known);desk.plan.command("defer",second,desk.known)
    var plan_before: Dictionary=desk.plan.state.duplicate(true)
    check(press(desk.window,"具名行程草案"),"actual planner exposes new library action")
    await frames()
    var dialog: Window=desk.window.get_node("ExpeditionDraftLibrary")
    check(dialog.visible and dialog.name_input.has_focus(),"real nested library opens with name-entry focus")
    dialog.name_input.text="苔庭巡查";press(dialog,"保存当前站序为新草案");await frames()
    check(dialog.model.drafts["苔庭巡查"]==[first,second],"actual UI stores named public station order")
    check(desk.plan.state==plan_before,"saving draft does not reset or resume current itinerary")
    var library_bytes:=FileAccess.get_file_as_bytes(dialog.model.path)
    desk.plan.command("remove",first,desk.known)
    var modified: Dictionary=desk.plan.state.duplicate(true)
    press(dialog,"预览并确认载入");await frames()
    check(dialog.confirm.visible and dialog.confirm.get_cancel_button().has_focus(),"restoration shows informed confirmation with safe cancel focus")
    check(dialog.confirm.dialog_text.contains("清除") and dialog.confirm.dialog_text.contains("暂停"),"confirmation explains resetting auxiliary progress and pausing")
    dialog.confirm.canceled.emit();dialog.confirm.confirmed.emit();await frames()
    check(desk.plan.state==modified and dialog.pending.is_empty(),"canceled confirmation cannot be replayed by stale signal")
    press(dialog,"预览并确认载入");desk.plan.command("defer",second,desk.known)
    var changed: Dictionary=desk.plan.state.duplicate(true)
    dialog.confirm.confirmed.emit();await frames()
    check(desk.plan.state==changed and dialog.status.text.contains("变化"),"live itinerary change invalidates previous confirmation")
    press(dialog,"预览并确认载入")
    desk.plan.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    dialog.confirm.confirmed.emit();await frames()
    check(desk.plan.state==changed and dialog.status.text.contains("失败"),"real itinerary persistence failure keeps exact prior live state")
    check(FileAccess.get_file_as_bytes(dialog.model.path)==library_bytes,"failed restore never rewrites its source library")
    desk.plan.store.writer=Callable();press(dialog,"预览并确认载入");dialog.confirm.confirmed.emit();await frames()
    check(desk.plan.state.stops==[first,second] and not desk.plan.state.active and desk.plan.state.done.is_empty() and desk.plan.state.deferred.is_empty(),"fresh confirmed restore replaces order while paused with clean auxiliary progress")
    var reloaded:=PLAN.new();reloaded.configure(String(world.world_save_path))
    check(reloaded.state==desk.plan.state,"actual itinerary file contains confirmed new paused order")
    check(snapshot(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"library workflow changes neither gameplay record nor resources or position")
    press(dialog,"删除所选草案");dialog.confirm.canceled.emit();await frames()
    check(dialog.model.drafts.has("苔庭巡查"),"canceling deletion keeps named order")
    var path: String=dialog.model.path;var plan_path: String=desk.plan.store.path
    world._close_overlays();await frames()
    check(not dialog.visible and dialog.pending.is_empty() and not world.player.ui_input_locked,"map close retires nested confirmation and releases original input lock")
    dialog.save_new();check(FileAccess.get_file_as_bytes(path)==library_bytes,"hidden library rejects stale write callbacks")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"real World audio fully retires")
    for file in [path,plan_path,"user://expedition_draft_world.json","user://expedition_draft_world.json.bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    print("EXPEDITION_DRAFT_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
