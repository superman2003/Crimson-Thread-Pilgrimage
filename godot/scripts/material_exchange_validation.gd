extends SceneTree
const MARKET := preload("res://scripts/material_exchange.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func run() -> void:
    var recipes:=MARKET.recipes();check(recipes.size()==12,"twelve canonical material routes")
    for row in recipes:check(row.input_amount==3 and row.output_amount==1 and row.currency==8,"each operation strictly decreases material potential and currency")
    recipes[0].output_amount=999;check(MARKET.recipes()[0].output_amount==1,"callers cannot edit canonical rates")
    var main: Node=load("res://scenes/World.tscn").instantiate();main.world_resume=false;main.world_save_path="user://material_exchange_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    for child in main.get_children():
        if child is Area2D and child.get_meta("kind","")=="save_point":main.player.global_position=child.global_position;break
    await physics_frame;await physics_frame;await process_frame
    main._toggle_build();await process_frame
    var desk: Node=main.ui_shell.get_node("MaterialExchangeDesk")
    main.ui_shell.build_panel.get_node("MaterialExchangeButton").pressed.emit();await process_frame
    check(desk.window.visible and desk.rows.is_empty(),"actual market hides unvisited neighbor materials")
    var row: Dictionary=MARKET.recipes()[1];var id:=String(row.id)
    check(main.world_state.capture_region(String(row.target_region),{}),"fixture records an actual visited neighbor region")
    desk.open();check(desk.rows.size()==1,"known adjacent material becomes visible")
    check(not MARKET.quote(main,id,1).ok,"source-region permit gates exchange")
    main.inventory_counts[row.requires_item]=1;main.inventory_counts[row.input]=30;main.inventory_counts[row.output]=0;main.currency_count=100
    for bad in [0,11,-1,1.5,true,"1",NAN,INF]:check(not MARKET.quote(main,id,bad).ok,"invalid batch count is rejected before mutation")
    var counts: Dictionary=main.inventory_counts.duplicate(true);var flags: Dictionary=main.story_flags.duplicate(true)
    var quote:=MARKET.quote(main,id,2)
    check(quote.ok and quote.counts[row.input]==24 and quote.counts[row.output]==2 and quote.money==84 and main.inventory_counts==counts,"two-batch preview has canonical costs and remains read-only")
    desk.amount.value=2;desk.ask();check(desk.confirm.visible and not desk.pending.is_empty(),"actual board uses an explicit native confirmation")
    var disk:=FileAccess.get_file_as_bytes(main.world_save_path);var world: Dictionary=main.world_state.data.duplicate(true)
    main.world_save_failure_injected_for_validation=true
    check(not MARKET.perform(main,id,2,quote.fingerprint).ok and main.inventory_counts==counts and main.currency_count==100 and main.story_flags==flags and main.world_state.data==world,"failed write publishes no materials currency flags or world candidate")
    check(FileAccess.get_file_as_bytes(main.world_save_path)==disk,"failed exchange leaves the real disk checkpoint intact")
    main.world_save_failure_injected_for_validation=false
    check(MARKET.perform(main,id,2,quote.fingerprint).ok and main.inventory_counts[row.input]==24 and main.inventory_counts[row.output]==2 and main.currency_count==84,"successful trade spends and grants in one durable commit")
    check(main.inventory_counts[row.requires_item]==1,"permit remains owned")
    var saved:=preload("res://scripts/world_state.gd").new()
    check(saved.read(main.world_save_path) and saved.data.inventory_counts[row.output]==2 and saved.data.currency==84,"actual reload sees matching output and payment")
    check(not MARKET.perform(main,id,2,quote.fingerprint).ok,"stale confirmation cannot repeat a previous quote")
    var before: Dictionary=main.inventory_counts.duplicate(true)
    main.inventory_counts[row.input]=2;check(not MARKET.quote(main,id,1).ok,"insufficient materials fail")
    main.inventory_counts=before.duplicate(true);main.inventory_counts[row.output]=999999;check(not MARKET.quote(main,id,1).ok,"output overflow fails")
    main.inventory_counts=before.duplicate(true);quote=MARKET.quote(main,id,1);main.player.global_position+=Vector2(1000,0)
    check(not MARKET.perform(main,id,1,quote.fingerprint).ok,"leaving the shrine revokes the operation")
    main._close_overlays();check(not desk.window.visible and not desk.confirm.visible,"overlay close revokes nested confirmation")
    var audio:=preload("res://scripts/audio_retirement.gd");audio.retire_tree(main);main.free();await process_frame;check(await audio.drain(self),"audio exits cleanly")
    for failure in failures:push_error(failure)
    print("MATERIAL_EXCHANGE checks=%d failures=%d" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
