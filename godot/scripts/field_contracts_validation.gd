extends SceneTree
const CONTRACTS := preload("res://scripts/field_contracts.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures.append(message)
func run() -> void:
    var catalog:=CONTRACTS.contracts()
    check(catalog.size()==12,"six regions have separate survey and combat contracts")
    var regions:={};var ids:={}
    for contract in catalog:
        check(not ids.has(contract.id) and contract.reward_amount==1 and contract.objectives.size() in [2,3],"canonical contract identity reward and objective budget")
        ids[contract.id]=true;regions[contract.region]=int(regions.get(contract.region,0))+1
    check(regions.size()==6 and regions.values().all(func(value):return value==2),"each region has exactly two authored contracts")
    catalog[0].reward_amount=999
    check(CONTRACTS.contracts()[0].reward_amount==1,"catalog callers cannot mutate canonical reward amounts")
    check(not CONTRACTS.marked({"flag":1},"flag") and CONTRACTS.marked({"flag":true},"flag"),"only true booleans prove saved objectives")
    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_resume=false;main.world_save_path="user://field_contracts_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    var shrine: Area2D
    for child in main.get_children():
        if child is Area2D and child.get_meta("kind","")=="save_point":shrine=child;break
    main.player.global_position=shrine.global_position
    main._toggle_build()
    await process_frame
    var desk: Node=main.ui_shell.get_node("FieldContractDesk")
    main.ui_shell.build_panel.get_node("FieldContractButton").pressed.emit();await process_frame
    check(desk.window.visible and desk.rows.size()==2 and desk.query.has_focus(),"actual board visible=%s rows=%d query_focus=%s" % [desk.window.visible,desk.rows.size(),desk.query.has_focus()])
    var hidden:=JSON.stringify(CONTRACTS.entries(main))
    check(not hidden.contains("铸雨渠") and not hidden.contains("moss_descent"),"board withholds future regions and raw unseen target identities")
    var first: Dictionary=CONTRACTS.contracts()[0]
    var id:=String(first.id)
    var accept:=CONTRACTS.quote(main,id,"accept")
    check(accept.ok and not main.story_flags.has(CONTRACTS.flag(id,"accepted")),"accept quote is read-only")
    var hp: int=main.player.hp;var energy: int=main.player.energy
    check(CONTRACTS.perform(main,id,"accept",accept.fingerprint).ok,"accept commits the canonical contract")
    var goal_rows: Array=main.ui_shell.get_node("GoalDesk").rows()
    check(goal_rows.any(func(row):return row.key=="quest:contract_"+id),"accepted contract joins the existing tracked-goal source")
    check(not CONTRACTS.quote(main,id,"claim").ok,"missing actual exploration records cannot claim a permit")
    for objective in first.objectives:main.visited_rooms[String(objective.target)]=true
    var quote:=CONTRACTS.quote(main,id,"claim")
    check(quote.ok and quote.counts[first.reward_item]==1,"canonical completed objectives produce one private permit candidate")
    var flags: Dictionary=main.story_flags.duplicate(true);var counts: Dictionary=main.inventory_counts.duplicate(true);var world: Dictionary=main.world_state.data.duplicate(true)
    var disk:=FileAccess.get_file_as_bytes(main.world_save_path)
    main.world_save_failure_injected_for_validation=true
    check(not CONTRACTS.perform(main,id,"claim",quote.fingerprint).ok and main.story_flags==flags and main.inventory_counts==counts and main.world_state.data==world,"failed persistence publishes no reward flags inventory or world snapshot")
    check(FileAccess.get_file_as_bytes(main.world_save_path)==disk,"failed reward write leaves the exact existing checkpoint intact")
    main.world_save_failure_injected_for_validation=false
    check(CONTRACTS.perform(main,id,"claim",quote.fingerprint).ok and int(main.inventory_counts[first.reward_item])==1,"retry commits permit and claimed flag together")
    check(not CONTRACTS.quote(main,id,"claim").ok,"repeated and stale claims cannot mint another permit")
    var loaded:=preload("res://scripts/world_state.gd").new()
    check(loaded.read(main.world_save_path) and loaded.data.inventory_counts[first.reward_item]==1 and loaded.data.story_flags[CONTRACTS.flag(id,"claimed")],"actual disk reload proves same-checkpoint reward and once-only settlement")
    check(main.player.hp==hp and main.player.energy==energy,"acceptance and rewards never refill live resources")
    var combat: Dictionary=CONTRACTS.contracts()[1]
    accept=CONTRACTS.quote(main,String(combat.id),"accept");CONTRACTS.perform(main,String(combat.id),"accept",accept.fingerprint)
    for objective in combat.objectives:main.story_flags["journal_enemy_"+String(objective.target)]=true
    quote=CONTRACTS.quote(main,String(combat.id),"claim")
    main.currency_count+=1
    check(not CONTRACTS.perform(main,String(combat.id),"claim",quote.fingerprint).ok,"wallet changes after preview require a fresh confirmation")
    main.currency_count-=1
    main.player.global_position+=Vector2(1000,0)
    check(not CONTRACTS.quote(main,String(combat.id),"claim").ok,"leaving the actual shrine revokes a previously valid operation")
    main._close_overlays();check(not desk.window.visible,"closing build dismisses both board and confirmation")
    var retirement:=preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main);main.free();await process_frame
    check(await retirement.drain(self),"fixture retires actual audio before exit")
    for failure in failures:push_error(failure)
    if failures.is_empty():print("FIELD_CONTRACTS checks=%d failures=0" % checks)
    quit(0 if failures.is_empty() else 1)
