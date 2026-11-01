extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func state(world: Node) -> String:
    return var_to_str([world.inventory_counts,world.currency_count,world.story_flags,world.build_system.serialize(),world.player.energy,world.player.hp,world.player.global_position])
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://thread_budget_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:await physics_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    check(world._save_world(),"actual saved World fixture")
    var before:=state(world);var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    world._toggle_backpack();var ui: Control=world.ui_shell
    ui.bag.get_node("ResourcePurposeButton").pressed.emit();await process_frame
    var source: Node=ui.get_node("ResourcePurposeWindow")
    check(source.visible,"actual bag opens public resource report")
    source.open_thread_budget();await process_frame
    var dialog: Node=source.thread_budget
    check(dialog.visible and world.active_overlay=="backpack" and world.player.ui_input_locked,"nested budget retains actual bag input ownership")
    check(dialog.available.has_focus() and dialog.available.item_count>0,"known actions are keyboard reachable")
    for unused in 8:dialog.append_action()
    check(dialog.sequence.size()==8,"eight planned actions are accepted")
    dialog.append_action();check(dialog.sequence.size()==8 and dialog.status.text.contains("八项"),"ninth action gives visible capacity feedback")
    dialog.planned.select(0);dialog.move_action(1)
    check(dialog.planned.get_selected_items()[0]==1,"reordering follows native selection")
    dialog.remove_action();check(dialog.sequence.size()==7,"selected action can be removed")
    dialog.reserve.button_pressed=true;dialog.reserve.toggled.emit(true)
    check(dialog.detail.text.contains("另留一次") and dialog.detail.text.contains("不计击中取线"),"reservation and arithmetic limitations are visible")
    dialog.refresh();check(dialog.sequence.size()==7,"refresh reevaluates current report without executing planned actions")
    check(state(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"all budgeting controls preserve gameplay and exact save bytes")
    source.hide();await process_frame
    check(not dialog.visible and dialog.sequence.is_empty() and dialog.detail.text.is_empty(),"closing parent retires transient sequence and detail")
    dialog.append_action();check(dialog.sequence.is_empty(),"hidden stale add cannot rebuild a closed plan")
    source.open(ui);source.open_thread_budget();await process_frame
    check(dialog.visible and dialog.sequence.is_empty() and not dialog.reserve.button_pressed,"reopen starts a fresh explicit budget")
    world._close_overlays();await process_frame
    check(not dialog.visible and not world.player.ui_input_locked,"closing backpack releases nested window and player input")
    check(state(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"closing cannot persist a budget as gameplay state")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio retirement")
    for suffix in ["",".tmp",".bak",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://thread_budget_world.json"+suffix))
    print("THREAD_BUDGET_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
