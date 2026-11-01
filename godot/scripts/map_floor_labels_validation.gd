extends SceneTree
const FLOORS := preload("res://scripts/map_floor_labels.gd")
const INDEX := preload("res://scripts/map_directory.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const DIALOG := preload("res://scripts/map_directory_dialog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func room(id: String, floor_id: String, floor_name: String, x: float = 0) -> Dictionary:
    return {"id":id, "name":"房间"+id, "floor_id":floor_id, "floor_name":floor_name,
        "kind":"ordinary", "layout_rect":[x,0,300,250]}

func config() -> Dictionary:
    return {"id":"test", "chapter_name":"庭院", "map_rooms":[
        room("entry","middle","庭院中层"),
        room("stairs","link","贯层通道",300),
        room("secret","upper","秘密高层未见987",600)], "connections":[],
        "interactives":[], "hazards":[], "locked_gates":[]}

func run() -> void:
    schema_checks()
    selection_checks()
    knowledge_checks()
    authored_data_checks()
    await dialog_checks()
    print("MAP_FLOOR_LABELS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)

func schema_checks() -> void:
    check(FLOORS.floor_of({}).is_empty(), "legacy rooms remain explicitly unlabelled")
    check(FLOORS.floor_of(room("a","middle","中层")) == {"id":"middle","name":"中层"}, "authored label is retained")
    for bad in [true, 1, [], {}, null, "", " ", "Middle", "a:b", "汉字", "x\ny", "x".repeat(49)]:
        var sample := room("a","middle","中层")
        sample.floor_id = bad
        check(FLOORS.floor_of(sample).is_empty(), "invalid identifier rejected: "+str(bad))
    for bad in [true, 1, [], {}, null, "", " ", "中\n层", "中\t层", "中".repeat(49)]:
        var sample := room("a","middle","中层")
        sample.floor_name = bad
        check(FLOORS.floor_of(sample).is_empty(), "invalid label rejected: "+str(bad))
    var source := {"key":"room:r:a", "region":"r", "title":"A", "nested":{"id":1}}
    var original := source.duplicate(true)
    var annotated := FLOORS.annotate(source, room("a","middle","中层"))
    check(source == original, "annotating never changes its caller")
    annotated.nested.id = 2
    check(source.nested.id == 1, "annotated nested values have independent ownership")
    check(FLOORS.annotate(source, {}).floor_id == "", "legacy rows do not receive a guessed floor")
    check(FLOORS.caption(FLOORS.annotate(source, {})) == "未标注层位", "legacy semantics are visible to users")
    check(FLOORS.key("a:b", "c") != FLOORS.key("a", "b:c"), "region/floor keys cannot alias delimiters")

func public_rows() -> Array:
    var rows: Array = []
    for item in [["moss","middle","中层"],["moss","upper","高层"],["rain","middle","中层"],["moss","link","贯层通道"]]:
        var row := {"region":item[0],"region_name":"地区"+item[0],"key":item[0]+item[1],"title":"已知地点","kind":"room","detail":""}
        rows.append(FLOORS.annotate(row,room("a",item[1],item[2])))
    return rows

func selection_checks() -> void:
    var rows := public_rows()
    var before := rows.duplicate(true)
    var global := FLOORS.choices(rows)
    check(global.size() == 4, "same named floors remain region-specific")
    check(global.all(func(c):return String(c.name).begins_with("地区")), "global floor choices identify their region")
    var local := FLOORS.choices(rows,"moss")
    check(local.size() == 3, "regional scope omits remote choices")
    check(local.all(func(c):return not String(c.name).begins_with("地区")), "regional scope uses concise authored labels")
    check(FLOORS.choices(rows,"unseen").is_empty(), "unknown region does not fall back to the complete atlas")
    check(FLOORS.filter_rows(rows,FLOORS.key("rain","middle")).size()==1, "equal floor names cannot cross regions")
    check(FLOORS.filter_rows(rows,"invalid").is_empty(), "stale filter cannot broaden results")
    check(FLOORS.filter_rows(rows).size()==rows.size(), "empty filter means all public rows")
    var filtered := FLOORS.filter_rows(rows)
    filtered[0].title = "changed"
    check(rows == before, "filter results do not expose mutable caller rows")
    var duplicate := rows.duplicate(true)
    duplicate.append(rows[0])
    check(FLOORS.choices(duplicate).size()==4, "markers in the same floor do not duplicate choices")
    check(FLOORS.choices([null, 1, "invalid"]).is_empty(), "malformed non-row values are ignored")
    var legacy := FLOORS.annotate({"region":"moss","region_name":"庭院"},{})
    check(FLOORS.choices([legacy]).is_empty(), "unknown metadata is not offered as an authored layer")
    check(FLOORS.filter_rows([legacy]).size()==1, "unlabelled public records remain available in all-floor scope")

func knowledge_checks() -> void:
    var flags := {JOURNAL.KEY:{"test":{"owned":true,"charted":{"entry":true},"pending":{}}}}
    var before := flags.duplicate(true)
    var authored := config()
    var rows := INDEX.records({"test":authored},flags,{}, {})
    check(rows.size()==1 and rows[0].floor_name=="庭院中层", "known room inherits its authored floor")
    check(FLOORS.choices(rows).size()==1, "floor choices derive only from the public directory")
    check(INDEX.search(rows,"秘密高层未见987").is_empty(), "uncharted floor name is not searchable")
    check(INDEX.search(rows,"庭院中层").size()==1, "known floor names participate in existing text search")
    check(flags == before, "floor indexing never mutates cartography progress")
    flags[JOURNAL.KEY].test.charted.stairs = true
    rows = INDEX.records({"test":authored},flags,{}, {})
    check(FLOORS.choices(rows,"test").size()==2, "charted connecting rooms have an explicit through-floor choice")
    flags[JOURNAL.KEY].test.owned = false
    check(INDEX.records({"test":authored},flags,{},{}).is_empty(), "unowned paper exposes neither floor metadata nor room rows")
    flags[JOURNAL.KEY].test.owned = true
    flags[JOURNAL.KEY].test.charted.secret = true
    rows = INDEX.records({"test":authored},flags,{}, {})
    check(INDEX.search(rows,"秘密高层未见987").size()==1, "a floor name appears only after the corresponding chart note exists")

func authored_data_checks() -> void:
    var paths := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive",
        "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
    for path in paths:
        var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/"+path+".json"))
        var names: Dictionary = {}
        for entry in data.map_rooms:
            var floor := FLOORS.floor_of(entry)
            check(not floor.is_empty(), path+"/"+String(entry.id)+" has explicit authored metadata")
            if floor.is_empty():
                continue
            check(not names.has(floor.id) or names[floor.id] == floor.name, "one floor identity has one label per region")
            names[floor.id] = floor.name
        check(names.size() >= 3, "six-region authoring distinguishes at least three public semantics")

func dialog_checks() -> void:
    var dialog := DIALOG.new()
    root.add_child(dialog)
    var rows := public_rows()
    var calls: Array = []
    dialog.open(rows,func(row: Dictionary):calls.append(row.key);return {"ok":true})
    check(dialog.floors.item_count==5, "production picker exposes all public region/floor choices")
    var wanted := FLOORS.key("rain","middle")
    for index in dialog.floors.item_count:
        if dialog.floors.get_item_metadata(index)==wanted:
            dialog.floors.select(index)
    dialog._refresh()
    check(dialog.visible_rows.size()==1 and dialog.visible_rows[0].region=="rain", "native floor selector filters the actual list")
    check(dialog.list.get_item_text(0).contains("中层"), "native rows show floor semantics without opening details")
    check(dialog.detail.text.contains("层位：中层"), "selected detail retains the authored floor label")
    dialog._locate_selected()
    check(calls==["rainmiddle"], "filtered activation passes exactly the selected public record")
    dialog.open(rows,func(_row: Dictionary):return {"ok":true})
    check(dialog.floors.selected==0 and dialog.visible_rows.size()==4, "reopening resets stale floor constraints")
    for index in dialog.regions.item_count:
        if dialog.regions.get_item_metadata(index)=="moss":
            dialog.regions.select(index)
    dialog._rebuild_floors()
    dialog._refresh()
    check(dialog.floors.item_count==4 and dialog.visible_rows.size()==3, "region change rebuilds floor choices before filtering")
    dialog.open([],func(_row: Dictionary):return {"ok":true})
    check(dialog.floors.item_count==1 and dialog.visible_rows.is_empty(), "empty reopened directory forgets previous floor names")
    check(dialog.locate_button.disabled, "empty floor result cannot activate stale selection")
    dialog.free()
    await process_frame
