extends SceneTree
const PLAN := preload("res://scripts/expedition_plan.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures.append(message)
func run() -> void:
    var known: Array=[]
    for index in 7:known.append({"key":"room:known:"+str(index),"title":"已知"+str(index)})
    var plan:=PLAN.new();plan.configure("expedition_unit")
    for index in 6:check(plan.command("add",known[index].key,known).ok,"known stop appends to plan")
    check(not plan.command("add",known[6].key,known).ok and not plan.command("add","room:hidden:0",known).ok,"capacity and unknown-stop guards")
    check(plan.command("up",known[3].key,known).ok and plan.state.stops[2]==known[3].key,"reorder changes the saved itinerary")
    check(plan.command("start","",known).ok and plan.next_stop(known).key==known[0].key,"start publishes the first unfinished stop")
    check(plan.command("done",known[0].key,known).ok and plan.next_stop(known).key==known[1].key,"marking advances only auxiliary itinerary state")
    check(plan.next_stop([]).get("unavailable",false),"lost map knowledge withholds old location names")
    var loaded:=PLAN.new();loaded.configure("expedition_unit")
    check(loaded.state==plan.state,"actual disk restore retains order checkmarks and active state")
    var before:=plan.state.duplicate(true);plan.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    check(not plan.command("pause","",known).ok and plan.state==before,"failed plan save preserves the published itinerary")
    var config:={"connections":[{"from":"a","to":"b","bidirectional":true},{"from":"b","to":"c","required_ability":"dash","bidirectional":false},{"from":"c","to":"d","shortcut_id":"lever","bidirectional":true}]}
    check(PLAN.path(config,["a","b","c","d"],"a","d",{},{}).is_empty(),"missing abilities block preview paths")
    check(PLAN.path(config,["a","b","c","d"],"a","d",{"dash":true},{"lever":true}).is_empty(),"boolean inventory is not a learned ability")
    check(PLAN.path(config,["a","b","c","d"],"a","d",{"dash":1},{"lever":1}).is_empty(),"numeric shortcut cannot impersonate an opened lever")
    check(PLAN.path(config,["a","b","c","d"],"a","d",{"dash":1},{"lever":true})==["a","b","c","d"],"ability and opened shortcut unlock the directed known chain")
    check(PLAN.path(config,["a","b","c","d"],"d","a",{"dash":1},{"lever":true}).is_empty(),"one-way drops are never reversed")
    check(PLAN.path(config,["a","c","d"],"a","d",{"dash":1},{"lever":true}).is_empty(),"uncharted intermediate room cannot bridge a plan")
    config.locked_gates=[{"from":"a","to":"b","required_ability":"hook"}]
    check(PLAN.path(config,["a","b"],"a","b",{},{}).is_empty(),"separately authored gates also block a preview")

    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_resume=false;main.world_save_path="user://expedition_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    var journal:=preload("res://scripts/pilgrimage_cartography.gd")
    var region:=String(main.config.id)
    journal.region(main.story_flags,region).owned=true
    for room in main.config.map_rooms.slice(0,3):journal.region(main.story_flags,region).charted[String(room.id)]=true
    main._toggle_map()
    var desk: Node=main.ui_shell.get_node("ExpeditionDesk")
    main.map_panel.get_node("ExpeditionDeskButton").pressed.emit();await process_frame
    check(desk.window.visible and not desk.visible_rows.is_empty(),"real map menu exposes a usable itinerary desk")
    var flags: Dictionary=main.story_flags.duplicate(true)
    var inventory: Dictionary=main.inventory_counts.duplicate(true)
    var position: Vector2=main.player.global_position
    desk.act("add");desk.act("start")
    check(desk.plan.state.stops.size()==1 and desk.plan.state.active,"real add and start buttons persist the plan")
    check(desk.detail.text.contains("罗盘"),"preview obeys the existing compass rule")
    desk.selected_from_plan=true;desk.plan_key=String(desk.plan.state.stops[0]);desk.view_selected()
    check(not desk.window.visible and main.player.global_position==position,"viewing the stop moves only map view")
    check(main.story_flags==flags and main.inventory_counts==inventory,"planning and viewing publish no exploration knowledge or inventory")
    desk.open();main._close_overlays();check(not desk.window.visible,"closing map also dismisses the planner")
    var retirement:=preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main);main.free();await process_frame
    check(await retirement.drain(self),"fixture retires actual audio ownership")
    for failure in failures:push_error(failure)
    if failures.is_empty():print("EXPEDITION_DESK checks=%d failures=0" % checks)
    quit(0 if failures.is_empty() else 1)
