extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const SOURCE:=preload("res://scripts/material_conversion_plan_source.gd")
const MODEL:=preload("res://scripts/material_conversion_plan.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error(label)

func frames() -> void:
    for index in 4:
        await process_frame

func settled(dialog: Node) -> void:
    for index in 200:
        if dialog.job==null:return
        await process_frame
    check(false,"bounded search must finish or cancel in200 UI frames")

func select_target(dialog: Node,id: String) -> void:
    for index in dialog.target.item_count:
        if dialog.target.get_item_metadata(index)==id:
            dialog.target.select(index)
            dialog.target.item_selected.emit(index)
            return
    check(false,"explicit known target must be present")

func snapshot(world: Node) -> String:
    return JSON.stringify([
        world.inventory_counts,world.currency_count,world.story_flags,
        world.world_state.data,world.build_system.serialize(),
        world.player.hp,world.player.energy,world.player.global_position
    ],"",true,true)

func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false
    world.world_save_path="user://conversion_plan_world.json"
    root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:
        check(false,"actual World readiness")
        quit(1)
        return
    world.set_process(false)
    world.set_physics_process(false)
    world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)
    for child in world.get_children():
        if child is Area2D and child.get_meta("kind","")=="save_point":
            world.player.global_position=child.global_position
            break
    await physics_frame
    await physics_frame
    world._toggle_build()
    await frames()
    var desk: Node=world.ui_shell.get_node("MaterialExchangeDesk")
    world.ui_shell.build_panel.get_node("MaterialExchangeButton").pressed.emit()
    await frames()
    var empty: Array=SOURCE.entries(world)
    check(empty.is_empty(),"no map knowledge or permit cannot reveal conversion opportunities")
    check(world.world_state.capture_region("demo_ch02_rain_foundry_canal",{}),"seed actual visited adjacent region")
    check(SOURCE.entries(world).is_empty(),"visited neighbor alone does not supply source permit")
    world.inventory_counts.pilgrim_permit_01=1
    var first: Array=SOURCE.entries(world)
    check(first.size()==1 and first[0].id=="exchange_01_02","one actual known pair and held source permit reveal only that opportunity")
    world.inventory_counts.pilgrim_permit_02=true
    check(SOURCE.entries(world).size()==1,"boolean permit cannot enable second region exchange")
    world.inventory_counts.pilgrim_permit_02=1
    check(world.world_state.capture_region("demo_ch03_saltwhite_archive",{}),"seed actual second visited region")
    world.inventory_counts.moss_chitin=9
    world.inventory_counts.wet_chitin=0
    world.inventory_counts.salt_crystal_shard=0
    world.currency_count=100
    check(SOURCE.entries(world).size()==3,"known ring exposes only three permitted directed exchanges")
    check(not SOURCE.snapshot(world).targets.has("pollen_wax"),"unknown next-region material is absent from public target choices")
    check(world._save_world(),"save exact canonical fixture state")
    var game_before:=snapshot(world)
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    var launcher:=desk.window.find_child("MaterialConversionPlanButton",true,false) as Button
    check(launcher!=null and launcher.is_visible_in_tree(),"actual material workbench exposes nested planning entry")
    launcher.pressed.emit()
    await frames()
    var dialog: Node=desk.window.get_node("MaterialConversionPlan")
    check(dialog.visible and dialog.target.has_focus(),"real child window opens with target selector focus")
    check(world.player.ui_input_locked,"nested readonly planning preserves actual build input lock")
    check(dialog.target.item_count==3,"selector contains only known material names")
    for index in dialog.target.item_count:
        check(not dialog.target.get_item_text(index).contains("chitin"),"public choices do not display raw material IDs")
    select_target(dialog,"salt_crystal_shard")
    dialog.required.value=1
    dialog.budget.value=32
    dialog.reserve.value=68
    dialog.start()
    check(dialog.job!=null and dialog.result.is_empty(),"compute creates a cancellable incremental job before publishing result")
    dialog.cancel_search()
    check(dialog.job==null and dialog.result.is_empty(),"explicit cancellation publishes no candidate")
    dialog.start()
    await settled(dialog)
    check(dialog.result.get("ok",false),"real UI finds canonical two-hop conversion")
    check(dialog.result.cost==32 and dialog.result.path.size()==2,"actual route uses three intermediate batches and one final batch")
    check(dialog.detail.text.contains("68") and dialog.detail.text.contains("32"),"actual wallet remainder is distinct from remaining spendable budget")
    check(dialog.detail.text.contains(world._item_display_name("moss_chitin")),"result displays actual public item names")
    check(not dialog.detail.text.contains("exchange_") and not dialog.detail.text.contains("moss_chitin"),"result does not expose internal recipe or material keys")
    check(dialog.detail.text.contains("真实钟龛"),"cross-region plan explicitly requires actual visits")
    check(snapshot(world)==game_before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"planning and cancellation preserve precise economy and game save bytes")
    dialog.reserve.value=69
    dialog.start()
    await settled(dialog)
    check(not dialog.result.get("ok",false),"wallet holdback prevents spending the final required currency")
    dialog.reserve.value=101
    dialog.start()
    check(dialog.job==null and dialog.status.text.contains("超过"),"invalid reserve is rejected before starting a job")
    dialog.reserve.value=68
    dialog.start()
    world.currency_count=99
    dialog._process(0.3)
    check(dialog.job==null and dialog.result.is_empty() and dialog.context.is_empty(),"live wallet change cancels work and removes old result")
    check(dialog.compute.disabled and dialog.status.text.contains("改变"),"stale display requires explicit source refresh")
    world.currency_count=100
    dialog.refresh_context()
    check(not dialog.context.is_empty() and dialog.result.is_empty(),"refresh reads a new snapshot without executing a trade")
    select_target(dialog,"salt_crystal_shard")
    dialog.budget.value=32
    dialog.reserve.value=68
    dialog.start()
    world.inventory_counts.erase("pilgrim_permit_02")
    dialog._process(0.3)
    check(dialog.context.is_empty() and dialog.job==null,"loss of proof invalidates in-flight multi-region plan")
    world.inventory_counts.pilgrim_permit_02=1
    dialog.refresh_context()
    select_target(dialog,"salt_crystal_shard")
    dialog.budget.value=32
    dialog.reserve.value=68
    dialog.start()
    var child_id: int=dialog.get_instance_id()
    desk.window.hide()
    await frames()
    check(not dialog.visible and dialog.job==null and dialog.context.is_empty(),"parent hide cancels and releases snapshot")
    desk.open()
    desk.open_conversion()
    await frames()
    check(desk.window.get_node("MaterialConversionPlan").get_instance_id()==child_id,"reopening reuses a single owned native planner")
    check(dialog.result.is_empty() and dialog.request.is_empty(),"reopen cannot resurrect an accepted or stale plan")
    var path_before: String=world.world_save_path
    world.world_save_path="user://different_conversion_slot.json"
    dialog._process(0.3)
    check(dialog.context.is_empty(),"slot identity change invalidates snapshot even with identical inventory")
    world.world_save_path=path_before
    dialog.refresh_context()
    world.world_loading=true
    dialog._process(0.3)
    check(dialog.context.is_empty(),"in-progress region loading never leaves a usable old plan")
    world.world_loading=false
    check(snapshot(world)==game_before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"invalidations and refreshes restore no resources and never rewrite game save")
    world._close_overlays()
    await frames()
    check(not dialog.visible and not world.player.ui_input_locked,"build owner closure retires planner and releases gameplay input")
    RETIRE.retire_tree(world)
    world.queue_free()
    await process_frame
    check(await RETIRE.drain(self),"actual World audio retirement")
    print("MATERIAL_CONVERSION_PLAN_WORLD checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
