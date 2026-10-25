extends SceneTree
const INDEX = preload("res://scripts/map_directory.gd")
const RUNTIME = preload("res://scripts/map_directory_runtime.gd")
const JOURNAL = preload("res://scripts/pilgrimage_cartography.gd")
const KNOWLEDGE = preload("res://scripts/survey_map_knowledge.gd")
const ROUTES = preload("res://scripts/world_routes.gd")
const ATLAS = preload("res://scripts/world_atlas.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)

func run() -> void:
    var config := {"id":"test","chapter_name":"已知庭院","map_rooms":[
        {"id":"first","name":"安坐厅","kind":"ordinary","layout_rect":[0,0,400,300]},
        {"id":"later","name":"未补绘工房","kind":"ordinary","layout_rect":[400,0,400,300]},
        {"id":"secret","name":"绝密井987","kind":"secret","layout_rect":[0,300,400,300]}],
        "connections":[{"from":"first","to":"later","shortcut_id":"side"},{"from":"first","to":"secret"}],
        "interactives":[{"id":"lever","kind":"lever","position":[200,200],"shortcut_id":"side"}],
        "hazards":[{"id":"spike","name":"已见尖刺","rect":[10,10,20,20]},{"id":"hidden","name":"绝密机关","rect":[10,320,20,20]}],
        "locked_gates":[{"id":"dash","required_ability":"thread_dash","rect":[100,20,20,100]}]}
    var flags := {JOURNAL.KEY:{"test":{"owned":true,"charted":{"first":true},"pending":{}}}}
    var original := flags.duplicate(true)
    var rows: Array = INDEX.records({"test":config},flags,{}, {})
    check(rows.size() == 4 and rows.any(func(row):return row.kind == "gate"), "known room and observed hazard gate and shortcut enter the index")
    check(flags == original, "indexing never normalizes or mutates caller journals")
    check(INDEX.search(rows,"绝密").is_empty() and INDEX.search(rows,"未补绘工房").is_empty(), "unseen room names stay absent from results and neighbor details")
    check(INDEX.search(rows,"安坐厅 已知庭院").size() >= 1, "room and region names support combined public search")
    check(INDEX.search(rows,"","hazard").size() == 1 and INDEX.search(rows,"","shortcut").size() == 1, "marker kinds remain independently filterable")
    var shortcuts: Array = KNOWLEDGE.shortcut_records(config,flags,"test",{})
    check(not shortcuts[0].tooltip.contains("未补绘工房") and shortcuts[0].tooltip.contains("未补绘邻室"), "ordinary map shortcut tooltip also withholds an uncharted neighbor name")
    var closed := flags.duplicate(true);closed[JOURNAL.KEY].test.owned = false
    check(INDEX.records({"test":config},closed,{},{}).is_empty(), "unowned paper exposes no index")
    closed[JOURNAL.KEY].test.owned = 1
    check(INDEX.records({"test":config},closed,{},{}).is_empty(), "integer ownership cannot impersonate a bought map")
    flags[JOURNAL.KEY].test.charted.secret = true
    check(not INDEX.search(INDEX.records({"test":config},flags,{},{}),"绝密井987").is_empty(), "a secret becomes searchable only after its actual chart note exists")
    var hall := {"id":"hall","name":"长廊","layout_rect":[0,0,4000,800]}
    var sections := JOURNAL.segments(hall)
    var partial := {JOURNAL.KEY:{"large":{"owned":true,"charted":{JOURNAL.segment_key("hall",0):true},"pending":{}}}}
    var partial_rows: Array = INDEX.records({"large":{"chapter_name":"大房间","map_rooms":[hall]}},partial,{}, {})
    check(partial_rows.size() == 1 and sections[0].has_point(partial_rows[0].point), "large room lookup frames a charted section rather than its uncharted center")

    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_resume=false;main.world_save_path="user://map_directory_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    var current:=String(main.config.id)
    var room: Dictionary=main.config.map_rooms[0]
    JOURNAL.region(main.story_flags,current).owned=true;JOURNAL.region(main.story_flags,current).charted[String(room.id)]=true
    var remote:=""
    for id in ROUTES.cached_chapters():
        if String(id)==current:continue
        var other:=ATLAS.configuration(String(id))
        if other.get("map_rooms",[]).is_empty():continue
        remote=String(id);JOURNAL.region(main.story_flags,remote).owned=true;JOURNAL.region(main.story_flags,remote).charted[String(other.map_rooms[0].id)]=true;break
    check(not remote.is_empty(), "fixture has a genuinely different regional map configuration")
    main._toggle_map();main.world_map_view=true;main._refresh_map_overlay()
    main.world_map_view=false;main._refresh_map_overlay()
    var before_flags: Dictionary=main.story_flags.duplicate(true)
    var before_inventory: Dictionary=main.inventory_counts.duplicate(true)
    var before_position: Vector2=main.player.global_position
    var before_money:=int(main.currency_count)
    main.world_save_blocked=true
    var button: Button=main.map_panel.get_node("MapDirectoryButton")
    button.pressed.emit()
    var dialog: AcceptDialog=main.map_panel.get_node("MapDirectoryDialog")
    await process_frame
    check(dialog.visible and dialog.rows.size() > 0 and dialog.search.has_focus(), "production map button opens the searchable directory even when writes are blocked")
    check(Rect2(Vector2.ZERO,main.map_panel.size).encloses(button.get_rect()), "directory action fits the reserved map footer")
    check(main.ui_shell.is_text_entry_focused(), "registered popup viewport exposes actual text entry focus to global polling")
    Input.action_press("inventory");main._process(0.0);Input.action_release("inventory")
    check(main.active_overlay == "map" and dialog.visible, "typing in the native map dialog cannot trigger the inventory shortcut")
    var remote_row: Dictionary={}
    for entry in dialog.rows:
        if entry.region==remote and entry.kind=="room":remote_row=entry;break
    var tampered:=remote_row.duplicate(true);tampered.point=Vector2.INF
    check(not remote_row.is_empty() and RUNTIME.focus(main,tampered).get("ok",false), "directory framing reconstructs a known point instead of trusting supplied coordinates")
    check(main.world_map_view and main.survey_map_view.zoom>=2.0, "cross-region selection frames the world map only")
    check(main.player.global_position==before_position and main.currency_count==before_money and main.inventory_counts==before_inventory and main.story_flags==before_flags, "viewing a known directory entry moves no player and changes no wallet inventory or normalized journal")
    JOURNAL.region(main.story_flags,remote).charted.clear()
    check(not RUNTIME.focus(main,remote_row).get("ok",false), "a stale directory entry is rejected after knowledge changes")
    var old_callback: Callable=button.pressed.get_connections()[0].callable
    main._close_overlays()
    check(not dialog.visible, "closing the map also dismisses the directory popup")
    var retirement:=preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main);main.free();await process_frame
    preload("res://scripts/audio_director.gd")._stream_cache.clear();preload("res://scripts/audio_director.gd")._npc_voice_cache.clear()
    check(await retirement.drain(self), "fixture finishes actual audio ownership before exit")
    old_callback.call()
    check(true,"late directory callback tolerates a freed map owner")
    if failures.is_empty():print("MAP_DIRECTORY checks=%d failures=0" % checks)
    else:
        for item in failures:push_error(item)
    quit(0 if failures.is_empty() else 1)
