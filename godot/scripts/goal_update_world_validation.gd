extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
class NarrativeProbe extends "res://scripts/world_narrative.gd":
    var calls:=0
    func evaluate_progress(inventory: Dictionary,flags: Dictionary={}) -> Dictionary:
        calls+=1
        return super.evaluate_progress(inventory,flags)
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func state(world: Node) -> String:
    return var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.hp,world.player.energy,world.player.global_position])
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://goal_update_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:await physics_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var ui: Control=world.ui_shell
    var desk: Node=ui.get_node("GoalDesk");desk.set_process(false)
    var probe:=NarrativeProbe.new();world.world_narrative=probe
    check(world._save_world(),"actual World fixture establishes immutable gameplay save")
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    var before:=state(world)
    var original_flags: Dictionary=world.story_flags.duplicate(true)
    desk.model.state.hud=false;desk.model.state.pins=[]
    probe.calls=0
    for unused in 20:desk._process(0.5)
    check(probe.calls==0,"hidden workbench and disabled HUD perform zero actual narrative evaluations")
    desk._refresh_hud();check(probe.calls==0 and not desk.hud.visible,"explicit disabled HUD refresh is also dormant")
    desk.model.state.hud=true
    for unused in 20:desk._process(0.5)
    check(probe.calls==0,"empty enabled watchlist does not evaluate invisible goal content")
    var known: Array=desk.rows()
    check(not known.is_empty(),"actual canonical narrative has a public goal")
    desk.model.state.pins=[known[0].key];desk.update_budget.reset();probe.calls=0
    desk._process(0)
    check(probe.calls==1 and desk.hud.visible,"pinned visible HUD wakes immediately with one real narrative evaluation")
    desk._process(0.25);check(probe.calls==1,"visible HUD respects shared half-second interval")
    desk._process(0.25);check(probe.calls==2,"next HUD update is one evaluation instead of a duplicate pair")
    probe.calls=0;world._toggle_backpack();probe.calls=0
    desk._process(0)
    check(not desk.hud.visible and probe.calls==0,"overlay hides HUD immediately without evaluating narrative")
    var launch:=ui.bag.get_node("GoalDeskButton") as Button
    launch.pressed.emit()
    check(desk.window.visible and probe.calls==1,"real workbench open evaluates once and reuses its rows for HUD")
    var auxiliary_path: String=desk.model.store.path
    probe.calls=0;desk._process(0.1)
    check(probe.calls==0,"explicit open prevents same-frame periodic duplicate read")
    desk._process(0.4)
    check(probe.calls==1,"visible workbench reuses one periodic snapshot for rendering and hidden HUD")
    probe.calls=0
    var cached_before:=var_to_str(desk.visible_snapshot)
    for index in 20:
        desk.query.text="输入筛选"+str(index);desk.query.text_changed.emit(desk.query.text)
    check(probe.calls==0,"typing twenty search updates reuses visible public snapshot without narrative reevaluation")
    check(desk.visible_rows.is_empty() and var_to_str(desk.visible_snapshot)==cached_before,"search result filtering neither mutates snapshot nor invents a matching goal")
    desk.query.clear();desk.query.text_changed.emit("")
    desk.mode.select(1);desk.mode.item_selected.emit(1)
    desk.mode.select(0);desk.mode.item_selected.emit(0)
    check(probe.calls==0 and not desk.visible_rows.is_empty(),"mode and clear callbacks reuse cached rows while preserving live selection")
    desk._process(0.5)
    check(probe.calls==1,"continuous filtering does not postpone the next authoritative periodic read")
    var old_count: int=desk.visible_rows.size()
    world.story_flags["quest_bring_names_started"]=true
    probe.calls=0;desk._process(0.5)
    var added: Array=desk.visible_rows.filter(func(row):return row.key=="quest:bring_names_home")
    check(probe.calls==1 and added.size()==1 and desk.visible_rows.size()>=old_count,"actual changed narrative reaches visible workbench within original interval using one evaluation")
    world.story_flags=original_flags.duplicate(true)
    probe.calls=0;desk.refresh()
    check(probe.calls==1,"explicit filter refresh also has one authoritative narrative read")
    probe.calls=0;desk.act("hud",false)
    check(probe.calls==1 and not desk.model.state.hud,"actual HUD preference action shares quote/render rows")
    var preference_bytes:=FileAccess.get_file_as_bytes(auxiliary_path)
    probe.calls=0
    for unused in 5:desk._process(0.5)
    check(probe.calls==5,"active workbench maintains periodic progress even with HUD disabled")
    check(FileAccess.get_file_as_bytes(auxiliary_path)==preference_bytes,"periodic updates do not rewrite tracking preferences")
    desk.window.hide();desk._process(0);probe.calls=0
    for unused in 20:desk._process(0.5)
    check(probe.calls==0,"closing last consumer stops actual background narrative work")
    check(desk.visible_snapshot.is_empty() and not desk.snapshot_ready,"closing workbench releases cached goal data")
    desk.open();world.story_flags["quest_bring_names_started"]=true;world.story_flags["quest_bring_names_complete"]=true;desk.refresh()
    desk.model.state.pins=["quest:bring_names_home"];desk.model.state.notes={"quest:bring_names_home":"仅追踪备注"}
    desk.ask_cleanup();probe.calls=0;desk._apply_cleanup()
    check(probe.calls==1 and desk.model.state.pins.is_empty(),"confirmed completed-goal cleanup reuses one fresh authoritative snapshot")
    world.story_flags=original_flags.duplicate(true)
    desk.window.hide();world._close_overlays()
    probe.calls=0;desk.model.state.pins=[known[0].key];desk.model.state.hud=true;desk.update_budget.reset();desk._process(0)
    check(probe.calls==1 and desk.hud.visible,"gameplay HUD resumes with fresh data after overlay closes")
    world.world_loading=true;probe.calls=0;desk._process(0.5)
    check(probe.calls==0 and not desk.hud.visible,"loading publication boundary suspends content reads and stale HUD")
    world.world_loading=false;desk._process(0)
    check(probe.calls==1 and desk.hud.visible,"completed loading boundary wakes one new snapshot")
    check(state(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"all scheduling changes preserve resources progress position and exact gameplay save bytes")
    var hud_ref: WeakRef=weakref(desk.hud);var window_ref: WeakRef=weakref(desk.window)
    desk.queue_free();await process_frame;await process_frame
    check(hud_ref.get_ref()==null and window_ref.get_ref()==null,"component retirement frees its separately parented HUD and window")
    check(state(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"component retirement cannot mutate gameplay")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio retirement")
    for path in [auxiliary_path,"user://goal_update_world.json"]:
        for suffix in ["",".tmp",".bak",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
    print("GOAL_UPDATE_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
