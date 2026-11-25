extends SceneTree
const INDEX = preload("res://scripts/map_directory.gd")
const RUNTIME = preload("res://scripts/map_directory_runtime.gd")
const JOURNAL = preload("res://scripts/pilgrimage_cartography.gd")
const KNOWLEDGE = preload("res://scripts/survey_map_knowledge.gd")
const ROUTES = preload("res://scripts/world_routes.gd")
const ATLAS = preload("res://scripts/world_atlas.gd")
const PASSAGE := preload("res://scripts/world_passage.gd")
const PIN_VIEW := preload("res://scripts/map_player_pins_runtime.gd")
const LANGUAGE := preload("res://scripts/ui_language.gd")
const CHECKLIST := preload("res://scripts/map_known_checklist.gd")
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
    var regional_rows:=rows.duplicate(true)
    var remote_sample: Dictionary=rows[0].duplicate(true)
    remote_sample.merge({"key":"room:remote:first","region":"remote","region_name":"远方庭院"},true)
    regional_rows.append(remote_sample)
    check(INDEX.regions(regional_rows).size()==2 and INDEX.regions([]).is_empty(),"region choices derive only from known rows")
    check(INDEX.search(regional_rows,"","room","remote")==[remote_sample],"region and kind filters intersect")
    check(INDEX.search(regional_rows,"安坐厅","room","remote").size()==1 and INDEX.search(regional_rows,"","all","unseen").is_empty(),"region search neither broadens nor falls through to unknown maps")
    var picker:=preload("res://scripts/map_directory_dialog.gd").new()
    root.add_child(picker)
    var activations: Array=[]
    picker.open(regional_rows,func(row: Dictionary):activations.append(row.key);return {"ok":true})
    check(picker.regions.item_count==3 and picker.count.text.contains(str(regional_rows.size())),"production picker exposes known regions and result count")
    picker.list.select(regional_rows.size()-1);picker._refresh()
    check(picker.visible_rows[picker.list.get_selected_items()[0]].key==remote_sample.key,"unchanged filtering preserves selected entry identity")
    for index in picker.regions.item_count:
        if picker.regions.get_item_metadata(index)=="remote":picker.regions.select(index)
    picker._refresh()
    check(picker.list.item_count==1 and picker.visible_rows[0].region=="remote","production region control filters visible rows")
    picker.search.text="无结果987"
    picker.search.text_changed.emit(picker.search.text)
    check(picker.list.item_count==0 and picker.locate_button.disabled,"empty combined search disables locating stale selections")
    picker._locate_selected()
    check(activations.is_empty(),"empty results cannot invoke the view callback")
    picker.find_child("ClearSearch",true,false).pressed.emit();picker.list.item_activated.emit(0)
    check(activations==[remote_sample.key] and not picker.visible,"list activation locates exactly the selected known entry")
    picker.open([],func(_row: Dictionary):return {"ok":true})
    check(picker.regions.item_count==1 and picker.list.item_count==0,"reopening rebuilds choices without retaining prior region names")
    picker.free()
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

    check_partial_exit(hall, sections, partial)

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
    await check_world_exits(main)
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


func check_partial_exit(hall: Dictionary, sections: Array[Rect2], flags: Dictionary) -> void:
    var point := sections[-1].get_center()
    var portal := {"id": "end", "kind": "world_portal", "position": [point.x, point.y],
        "label": "古老通道", "target_config_id": "other", "target_portal_id": "undiscovered_mouth",
        "required_ability": "silk_wall_grip", "required_ability_name": "丝壁攀附"}
    var local_exit := portal.duplicate()
    local_exit.merge({"id": "local", "target_config_id": "large"}, true)
    var config := {"chapter_name": "大房间", "map_rooms": [hall], "interactives": [portal, local_exit]}
    var configs := {"large": config}
    var names := {"large": "大房间", "other": "铸雨渠"}
    var rows := INDEX.records(configs, flags, {}, {}, names)
    check(INDEX.search(rows, "", "exit").is_empty(), "another charted hall section cannot reveal the exit")
    JOURNAL.region(flags, "large").charted[JOURNAL.segment_key("hall", sections.size() - 1)] = true
    var before := flags.duplicate(true)
    rows = INDEX.search(INDEX.records(configs, flags, {}, {}, names), "铸雨渠", "exit")
    check(rows.size() == 1, "charted exit is searchable by its destination and omits local shortcuts")
    if rows.size() == 1:
        check(rows[0].point == point and rows[0].room_id == "hall", "exit resolves to the exact charted mouth")
        check(rows[0].detail.contains("暂不可通 · 丝壁攀附"), "missing ability appears on the departure side")
        check(rows[0].region == "large" and not str(rows[0]).contains("undiscovered_mouth"),
            "display exposes source position with the public destination name only")
    check(flags == before, "reading a charted exit leaves knowledge untouched")
    JOURNAL.region(flags, "large").owned = false
    check(INDEX.search(INDEX.records(configs, flags, {}, {}, names), "", "exit").is_empty(),
        "a surviving chart note on an unowned map does not expose the exit")


func check_world_exits(main: Node) -> void:
    var source := String(main.config.id)
    var rain := "demo_ch02_rain_foundry_canal"
    var archive := "demo_ch03_saltwhite_archive"
    var source_portal := ROUTES.cached_portal(source, "moss_rain_pipe")
    var rain_portal := ROUTES.cached_portal(rain, "rain_archive_riser")
    var archive_portal := ROUTES.cached_portal(archive, "archive_rain_riser")
    var latch := ROUTES.cached_portal(rain, "upgrade_obsidian_rain_return_b")
    main.story_flags = {}
    main._toggle_map()
    check(INDEX.search(RUNTIME.rows(main), "", "exit").is_empty(), "new journey directory has no exit rows")
    for entry in [[source, source_portal], [rain, rain_portal], [archive, archive_portal], [rain, latch]]:
        var journal := JOURNAL.region(main.story_flags, entry[0])
        journal.owned = true
        journal.charted[entry[1].room_id] = true
    main._refresh_map_overlay()
    var rain_key := "exit:" + rain + ":" + String(rain_portal.id)
    var reverse_key := "exit:" + archive + ":" + String(archive_portal.id)
    var latch_key := "exit:" + rain + ":" + String(latch.id)
    var exits := INDEX.search(RUNTIME.rows(main), "", "exit")
    var by_key := {}
    for row in exits:
        by_key[row.key] = row
    check(exits.size() == 4 and by_key.has(rain_key) and by_key.has(reverse_key) and by_key.has(latch_key),
        "charted production routes expose individual departure mouths")
    if not by_key.has(rain_key) or not by_key.has(reverse_key) or not by_key.has(latch_key):
        main._close_overlays()
        return
    check(by_key[rain_key].title.ends_with("盐白书库") and by_key[rain_key].detail.contains("丝壁攀附"),
        "from Rain Foundry the Brine Riser lists its destination and required ability")
    check(by_key[reverse_key].title.ends_with("铸雨渠") and by_key[reverse_key].detail.get_slice("\n", 1) == "已通",
        "the reverse mouth uses its own open state")
    check(by_key[latch_key].detail.contains("另一侧门闩"), "the cableway describes the far-side latch")
    check(by_key[latch_key].detail.contains("靠近入口后互动") and by_key[rain_key].detail.contains("靠近入口后互动"),
        "walking and interaction routes describe their actual entry methods")

    var button: Button = main.map_panel.get_node("MapDirectoryButton")
    button.pressed.emit()
    var dialog: AcceptDialog = main.map_panel.get_node("MapDirectoryDialog")
    for index in dialog.kinds.item_count:
        if dialog.kinds.get_item_text(index) == "跨区出口":
            dialog.kinds.select(index)
            dialog.kinds.item_selected.emit(index)
            break
    await process_frame
    check(dialog.visible and dialog.list.item_count == 4, "the actual exit filter shows just the four charted exits")
    dialog.search.text = "盐白书库"
    dialog.search.text_changed.emit(dialog.search.text)
    for index in dialog.visible_rows.size():
        if dialog.visible_rows[index].key == rain_key:
            dialog.list.select(index)
            dialog.list.item_selected.emit(index)
            break
    check(dialog.detail.text.contains("丝壁攀附"), "the selected known exit shows the locked condition in the live panel")
    check(CHECKLIST.snapshot(dialog.visible_rows).rows.any(func(row): return row.kind == "跨区出口"),
        "exits also appear when preparing the filtered travel checklist")
    var flags_before: Dictionary = main.story_flags.duplicate(true)
    var save_before := FileAccess.get_sha256(main.world_save_path)
    var position_before: Vector2 = main.player.global_position
    var save_state: Dictionary = main.world_state.data.duplicate(true)
    dialog.locate_button.pressed.emit()
    await process_frame
    var marker: Panel = main.map_draw_root.get_node_or_null("MapDirectoryExitFocus")
    var projected := PIN_VIEW.project(main, rain, by_key[rain_key].point)
    check(not dialog.visible and main.world_map_view and marker != null, "local map opens world overview and highlights the selected remote mouth")
    if marker != null:
        check((marker.position + marker.size * 0.5).is_equal_approx(projected), "highlight centers on the authored entry point")
    check(main.config.id == source and main.player.global_position == position_before
        and main.story_flags == flags_before and main.world_state.data == save_state
        and FileAccess.get_sha256(main.world_save_path) == save_before, "framing an exit is read-only even when saves are blocked")

    main.inventory_counts["silk_wall_grip"] = 1
    main.story_flags["world_shortcut_" + String(latch.requires_shortcut)] = true
    var unlocked := {}
    for row in INDEX.search(RUNTIME.rows(main), "", "exit"):
        unlocked[row.key] = row
    check(unlocked[rain_key].detail.get_slice("\n", 1) == "已通" and unlocked[latch_key].detail.get_slice("\n", 1) == "已通",
        "newly learned ability and opened latch update the directory")
    JOURNAL.region(main.story_flags, rain).charted.erase(rain_portal.room_id)
    check(not RUNTIME.focus(main, by_key[rain_key]).ok, "a stale exit cannot be located once its chart note is gone")

    for region in ROUTES.cached_chapters():
        var chart := JOURNAL.region(main.story_flags, region)
        chart.owned = true
        for portal in ROUTES.cached_chapters()[region].portals:
            if portal.get("kind") == "world_portal" and portal.get("target_config_id") != region:
                chart.charted[portal.room_id] = true
    var full := INDEX.search(RUNTIME.rows(main), "", "exit")
    var physical := 0
    for row in full:
        var portal_id: String = row.key.get_slice(":", 2)
        var link := PASSAGE.endpoint(row.region, portal_id)
        if not link.is_empty():
            physical += 1
    check(full.size() == 18 and physical == 10, "the six-region campaign indexes 18 directions including all ten walkable mouths")

    check(LANGUAGE.apply("en"), "English language catalogue can be applied")
    var english := INDEX.search(full, "saltwhite archive", "exit", rain)
    check(english.any(func(row): return row.key == rain_key), "English search matches a localized destination on the real map")
    for row in full:
        check(not preload("res://scripts/game_translation.gd").contains_han(LANGUAGE.text(row.title) + LANGUAGE.text(row.detail)),
            "route title and conditions translate for " + String(row.key))
    LANGUAGE.apply(LANGUAGE.SOURCE)
    main._close_overlays()
