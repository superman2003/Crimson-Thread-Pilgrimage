extends SceneTree
const MODEL := preload("res://scripts/goal_desk_model.gd")
const STORE := preload("res://scripts/journey_desk_store.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures.append(message)
func run() -> void:
    var model:=MODEL.new();model.configure("goal_unit")
    var rows: Array=[]
    for index in 4:rows.append({"key":"quest:"+str(index),"title":"目标 "+str(index),"text":"已知步骤 copper","complete":index==3,"hidden":"secret987"})
    check(MODEL.filter_rows(rows,"secret987",0).is_empty(),"private fields never enter goal search")
    check(MODEL.filter_rows(rows,"目标 copper",1).size()==3 and MODEL.filter_rows(rows,"",2).size()==1,"public multi-token search intersects completion filters")
    for index in 3:check(model.change("pin",rows[index].key,rows).ok,"known goal can be pinned")
    check(not model.change("pin",rows[3].key,rows).ok,"fourth pin cannot exceed HUD budget")
    check(not model.change("pin","quest:unknown",rows).ok,"unknown identity cannot become a public pin")
    check(model.change("first",rows[2].key,rows).ok and model.state.pins[0]==rows[2].key,"primary pin moves ahead of other goals")
    check(model.change("note",rows[2].key,rows,"注".repeat(200)).ok and String(model.state.notes[rows[2].key]).length()==160,"notes have a bounded persisted length")
    var restored:=MODEL.new();restored.configure("goal_unit")
    check(restored.state==model.state,"new instance restores actual disk pins order and notes")
    var isolated:=MODEL.new();isolated.configure("other_slot")
    check(isolated.state.pins.is_empty(),"save paths isolate goal preferences")
    var before:=model.state.duplicate(true)
    model.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    check(not model.change("remove",rows[0].key,rows).ok and model.state==before,"failed auxiliary save leaves published state intact")
    model.restore({"pins":[true,{},"quest:","quest:one","quest:one","main:two"],"notes":{"quest:one":true},"hud":1})
    check(model.state.pins==["quest:one","main:two"] and model.state.hud and model.state.notes.is_empty(),"malformed persisted fields are ignored without coercing booleans or duplicate identities")
    var invalid:=STORE.new();invalid.configure("invalid_goal","unit")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(invalid.path.get_base_dir()))
    var file:=FileAccess.open(invalid.path,FileAccess.WRITE);file.store_string('{"version":9,"payload":{}}');file.close()
    var raw:=FileAccess.get_file_as_bytes(invalid.path)
    check(invalid.read().is_empty() and not invalid.write({}) and FileAccess.get_file_as_bytes(invalid.path)==raw,"future auxiliary records remain byte-preserved and read-only")

    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_resume=false;main.world_save_path="user://goal_desk_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    var ui: Control=main.ui_shell
    var desk: Node=ui.get_node("GoalDesk")
    var flags: Dictionary=main.story_flags.duplicate(true)
    var inventory: Dictionary=main.inventory_counts.duplicate(true)
    var wallet: int=main.currency_count
    main._toggle_backpack();ui.bag.get_node("GoalDeskButton").pressed.emit()
    await process_frame
    check(desk.window.visible and desk.visible_rows.size()>0 and desk.query.has_focus(),"production menu opens a usable known-goal workbench")
    check(ui.is_text_entry_focused(),"native goal window owns the global shortcut barrier")
    flags=main.story_flags.duplicate(true)
    inventory=main.inventory_counts.duplicate(true)
    wallet=main.currency_count
    desk.act("pin")
    check(desk.model.state.pins.size()==1 and desk.first_button.disabled==false,"production actions pin a canonical goal")
    desk.note.text="先返回钟龛";desk.note_button.pressed.emit()
    check(desk.model.state.notes.get(desk.selected)=="先返回钟龛","production note control persists only auxiliary text")
    check(main.story_flags==flags and main.inventory_counts==inventory and main.currency_count==wallet,"tracking and notes alter no progression wallet or inventory")
    desk.window.hide();main._close_overlays();desk._process(0.6)
    check(desk.hud.visible and desk.hud.text.contains("追踪目标"),"tracked goals appear during exploration")
    main._toggle_backpack();desk.open()
    Input.action_press("map");main._process(0.0);Input.action_release("map")
    check(main.active_overlay=="backpack" and desk.window.visible,"polled map shortcut cannot steal a goal dialog's focus")
    desk.query.text="不存在987";desk.refresh()
    check(desk.visible_rows.is_empty() and desk.pin_button.disabled and desk.note_button.disabled,"empty filters clear stale actions")
    main._close_overlays()
    check(not desk.window.visible,"closing backpack also closes its workbench")
    var retirement:=preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main);main.free();await process_frame
    check(await retirement.drain(self),"fixture retires owned audio before exit")
    for failure in failures:push_error(failure)
    if failures.is_empty():print("GOAL_DESK checks=%d failures=0" % checks)
    quit(0 if failures.is_empty() else 1)
