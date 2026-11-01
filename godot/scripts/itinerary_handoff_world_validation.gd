extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const DOMAIN:=preload("res://journey/fieldwork/itinerary/model.gd")
const DIRECTORY:=preload("res://scripts/map_directory_runtime.gd")
const CARTOGRAPHY:=preload("res://scripts/pilgrimage_cartography.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://itinerary_handoff_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    world.set_process(false);world.set_physics_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var region:=String(world.config.id);var room_ids: Array=[]
    var chart: Dictionary=CARTOGRAPHY.region(world.story_flags,region);chart.owned=true
    for room in world.config.map_rooms.slice(0,3):
        chart.charted[String(room.id)]=true;world.visited_rooms[String(room.id)]=true;room_ids.append(String(room.id))
    await physics_frame;await physics_frame
    world._toggle_audio_settings();await process_frame
    var workbench: Node=root.get_node("JourneyWorkbench");workbench.open();workbench.context.update()
    var feature: RefCounted=workbench.features.i_itinerary
    var payload:=DOMAIN.capture(workbench.context.snapshot());payload.start=room_ids[0];payload.stops=room_ids.slice(1)
    # Choose known connected nodes from the actual captured graph, not invented map rows.
    check(DOMAIN.validate(payload),"real World produces valid itinerary source")
    var matrix:=DOMAIN.matrix(payload);var solution:=DOMAIN.solve(payload,matrix)
    check(solution.ok,"actual authored visited room graph has usable candidate")
    feature.draft=payload;feature.tab="editor";workbench.selected="i_itinerary";workbench.refresh();await process_frame
    var entry:=workbench.content.find_child("ItineraryHandoffButton",true,false) as Button
    check(entry!=null and entry.is_visible_in_tree(),"actual candidate editor exposes handoff entry")
    check(world._save_world(),"save exact gameplay baseline before auxiliary handoff")
    var disk:=FileAccess.get_file_as_bytes(world.world_save_path)
    var before:=var_to_str([world.story_flags,world.inventory_counts,world.currency_count,world.player.global_position,world.build_system.serialize()])
    var desk: Node=world.ui_shell.get_node("ExpeditionDesk")
    var live_known:=DIRECTORY.rows(world)
    check(desk.plan.command("add",String(live_known[0].key),live_known).ok,"persist original live itinerary before replacement")
    var original: Dictionary=desk.plan.state.duplicate(true)
    var listener_count: int=workbench.dialog.visibility_changed.get_connections().size()
    entry.pressed.emit();await process_frame
    var dialog: Node=workbench.dialog.get_node("ItineraryHandoff")
    check(dialog.visible and dialog.get_cancel_button().has_focus(),"actual child defaults to preserving original route")
    check(dialog.pending.ok and not dialog.detail.text.contains("room:"),"live canonical directory previews public ordered stops")
    check(desk.plan.state==original,"opening candidate preview changes no itinerary")
    dialog.get_cancel_button().pressed.emit();await process_frame
    check(desk.plan.state==original,"native cancel keeps original live state")
    check(workbench.dialog.visibility_changed.get_connections().size()==listener_count,"cancel disconnects parent callback")
    entry.pressed.emit();await process_frame;dialog=workbench.dialog.get_node("ItineraryHandoff")
    var expected: Dictionary=dialog.pending.candidate.duplicate(true)
    desk.plan.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    var auxiliary_before:=FileAccess.get_file_as_bytes(desk.plan.store.path)
    dialog.apply()
    check(desk.plan.state==original and (dialog.status.text.contains("未") or dialog.status.text.contains("失败")),"failed route save remains explicit in actual dialog")
    check(FileAccess.get_file_as_bytes(desk.plan.store.path)==auxiliary_before,"failed UI handoff preserves route file bytes")
    desk.plan.store.writer=Callable();dialog.hide();await process_frame
    entry.pressed.emit();await process_frame;dialog=workbench.dialog.get_node("ItineraryHandoff")
    var original_path: String=world.world_save_path;world.world_save_path="user://other_handoff_slot.json";dialog.apply()
    check(desk.plan.state==original and dialog.status.text.contains("改变"),"slot switch after preview cannot retarget current plan")
    world.world_save_path=original_path;dialog.hide();await process_frame
    entry.pressed.emit();await process_frame;dialog=workbench.dialog.get_node("ItineraryHandoff");dialog.apply()
    check(desk.plan.state==expected and not desk.plan.state.active,"confirmed handoff publishes only exact paused station order")
    check(dialog.get_ok_button().disabled,"successful confirmation cannot repeat from same button")
    check(not desk.hud.visible,"adoption does not silently start tracking")
    check(FileAccess.get_file_as_bytes(world.world_save_path)==disk,"actual game save bytes unchanged by auxiliary route adoption")
    check(var_to_str([world.story_flags,world.inventory_counts,world.currency_count,world.player.global_position,world.build_system.serialize()])==before,"no exploration knowledge rewards resources or player movement granted")
    dialog.hide();workbench.close();world._toggle_map();desk.open();await process_frame
    check(desk.itinerary.item_count==expected.stops.size(),"original real map window immediately shows adopted itinerary")
    check(desk.plan.command("start","",DIRECTORY.rows(world)).ok,"user may explicitly start in original planner")
    world._close_overlays();desk._refresh_hud();await process_frame
    check(desk.hud.visible and not desk.hud.text.contains("room:"),"original HUD tracks first public adopted station")
    world._toggle_audio_settings();workbench.open();workbench.selected="i_itinerary";feature.draft=payload;feature.tab="editor";workbench.refresh();await process_frame
    workbench.content.find_child("ItineraryHandoffButton",true,false).pressed.emit();await process_frame
    dialog=workbench.dialog.get_node("ItineraryHandoff");workbench.close();await process_frame
    check(not is_instance_valid(dialog) or not dialog.visible,"closing workbench retires pending handoff")
    check(workbench.dialog.visibility_changed.get_connections().size()==listener_count,"parent close releases every child listener")
    workbench.open()
    for index in 12:
        var cycle: Node=preload("res://scripts/itinerary_handoff_dialog.gd").open_for(world,workbench.dialog,payload)
        cycle.hide();await process_frame
    check(workbench.dialog.visibility_changed.get_connections().size()==listener_count,"repeated real open/close cycles do not accumulate callbacks")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio ownership retired")
    print("ITINERARY_HANDOFF_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
