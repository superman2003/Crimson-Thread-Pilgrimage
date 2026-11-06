extends SceneTree
const GROUP := preload("res://scripts/map_group_framing.gd")
const VIEW := preload("res://scripts/survey_map_view.gd")
const DIALOG := preload("res://scripts/map_directory_dialog.gd")
const FLOORS := preload("res://scripts/map_floor_labels.gd")
const RUNTIME := preload("res://scripts/map_directory_runtime.gd")
const INDEX := preload("res://scripts/map_directory.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
const PINS := preload("res://scripts/map_player_pins_runtime.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func row(key: String, region: String, point: Vector2, floor_id: String = "middle") -> Dictionary:
    return {"key":key,"kind":"room","region":region,"region_name":region,"floor_id":floor_id,
        "floor_key":FLOORS.key(region,floor_id),"floor_name":floor_id,"title":key,"detail":"已补绘","point":point}
func rows() -> Array:
    return [row("moss_a","moss",Vector2(100,100)),row("moss_b","moss",Vector2(300,200)),
        row("moss_upper","moss",Vector2(500,100),"upper"),row("rain_a","rain",Vector2(700,400))]
func state(view: Control) -> Array:
    return [view.zoom,view.content.position,view.content.scale,view.dragging,view.keyboard_pan,view.stick_pan]
func model_checks() -> void:
    var current:=rows()
    var before:=current.duplicate(true)
    var resolved:=GROUP.resolve(current,{"keys":["moss_b","moss_a"],"point":Vector2.INF,"bounds":Rect2(-999,-999,9999,9999)})
    check(resolved.ok and resolved.rows[0].point==Vector2(300,200),"group targets are reconstructed from current public identities, not supplied positions")
    check(resolved.rows[1].key=="moss_a","requested identity order is stable")
    check(current==before,"resolving never mutates directory rows")
    resolved.rows[0].point=Vector2.ZERO
    check(current==before,"resolved records do not expose shared mutable public state")
    for invalid in [null,false,1,"key",{},[],[false],[1],[""],["x\n"],["x".repeat(257)],["moss_a","moss_a"],["moss_a","unseen"]]:
        check(not GROUP.resolve(current,{"keys":invalid}).ok,"malformed, duplicate or stale request rejected: "+str(invalid))
    var excess: Array=[]
    for i in GROUP.MAX_TARGETS+1:excess.append("key"+str(i))
    check(not GROUP.resolve(current,{"keys":excess}).ok,"oversized requests cannot scan an unbounded selection")
    var ambiguous:=current.duplicate(true);ambiguous.append(current[0].duplicate())
    check(not GROUP.resolve(ambiguous,{"keys":["moss_a"]}).ok,"duplicate current identities cannot choose an arbitrary position")
    for invalid in [Vector2.INF,Vector2(NAN,0),null,"position"]:
        var broken:=current.duplicate(true);broken[0].point=invalid
        check(not GROUP.resolve(broken,{"keys":["moss_a"]}).ok,"invalid public anchor is rejected: "+str(invalid))
    check(not GROUP.needs_world([current[0],current[1]],"moss"),"a local layer keeps its regional view")
    check(GROUP.needs_world([current[0],current[3]],"moss"),"cross-region filtered results require the overview")
    var paper:=Rect2(0,0,1000,600)
    var identity:=func(_region: String,point: Vector2):return point
    var framed:=GROUP.projected_bounds([current[0],current[1]],identity,paper)
    check(framed.ok and framed.bounds.encloses(Rect2(100,100,200,100)),"all selected public anchors are enclosed")
    check(not framed.bounds.has_point(current[2].point),"the unselected upper layer does not enlarge a middle-layer frame")
    check(GROUP.projected_bounds([row("edge","moss",Vector2(1,1))],identity,paper).bounds.position==Vector2.ZERO,"single-edge framing uses a finite clipped margin")
    for invalid in [Vector2.INF,Vector2(-1,1),Vector2(1001,100),"wrong"]:
        var bad_project:=func(_region: String,_point: Vector2):return invalid
        check(not GROUP.projected_bounds([current[0]],bad_project,paper).ok,"invalid projected anchor is rejected: "+str(invalid))
    check(not GROUP.projected_bounds([],identity,paper).ok and not GROUP.projected_bounds(current,Callable(),paper).ok,"empty groups and missing projector cannot produce a frame")
    var hall:={"id":"hall","name":"贯层长井","floor_id":"link","floor_name":"贯层通道","layout_rect":[0,0,4000,800]}
    var config:={"chapter_name":"试验","map_rooms":[hall]}
    var flags:={JOURNAL.KEY:{"test":{"owned":true,"charted":{JOURNAL.segment_key("hall",0):true},"pending":{}}}}
    var public: Array=INDEX.records({"test":config},flags,{},{})
    check(public.size()==1,"partly charted room supplies one known section anchor")
    framed=GROUP.projected_bounds(public,identity,Rect2(0,0,5000,1000))
    check(framed.ok and framed.bounds.end.x<1000,"framing does not expand to the uncharted 4000px room extent")

func camera_checks() -> void:
    var view:=VIEW.new();view.size=Vector2(1000,600);root.add_child(view)
    var content:=Control.new();content.size=view.size;view.add_child(content);view.content=content
    view.set_view(1)
    view.dragging=true;view.keyboard_pan=Vector2.ONE;view.stick_pan=Vector2.ONE
    check(view.frame_bounds(Rect2(250,150,200,100)),"map camera frames a valid group")
    check(view.zoom>1 and view.zoom<=4 and content.scale==Vector2.ONE*view.zoom,"fit retains the original zoom range and scale relationship")
    var visible:=Rect2(Vector2.ZERO,view.size)
    check(visible.encloses(Rect2(content.position+Vector2(250,150)*view.zoom,Vector2(200,100)*view.zoom)),"all framed anchors are inside the clipped viewport")
    check(not view.dragging and view.keyboard_pan==Vector2.ZERO and view.stick_pan==Vector2.ZERO,"framing cancels stale drag and held navigation")
    var saved:=state(view)
    view.set_view(2);view.reset();view.set_view(1)
    check(is_equal_approx(view.zoom,saved[0]) and content.position.is_equal_approx(saved[1]),"existing per-view camera memory preserves a framed group")
    for invalid in [Rect2(),Rect2(-1,0,10,10),Rect2(990,590,20,20),Rect2(NAN,0,10,10),Rect2(0,0,INF,10)]:
        saved=state(view);check(not view.frame_bounds(invalid) and state(view)==saved,"rejected bounds preserve exact camera state")
    for padding in [NAN,INF,-1.0,600.0]:
        saved=state(view);check(not view.frame_bounds(Rect2(20,20,50,50),padding) and state(view)==saved,"invalid padding cannot corrupt camera state")
    check(view.frame_bounds(Rect2(0,0,1000,600)) and view.zoom==1,"whole-paper selection respects the minimum zoom")
    check(view.frame_bounds(Rect2(0,0,2,2)) and view.zoom==4,"single small target respects the maximum zoom")
    view.queue_free()

func dialog_checks() -> void:
    # The production shell registers controller UI actions on startup.
    var shell:=preload("res://scripts/pilgrimage_interface.gd").new()
    shell._bind_ui_navigation()
    shell.free()
    var picker:=DIALOG.new();root.add_child(picker)
    var calls: Array=[]
    picker.open(rows(),func(_record):return {"ok":true},func(request):calls.append(request);return {"ok":true})
    check(not picker.frame_button.disabled,"production group action is enabled for non-empty public rows")
    var target:=FLOORS.key("moss","middle")
    for i in picker.floors.item_count:
        if picker.floors.get_item_metadata(i)==target:picker.floors.select(i)
    picker._refresh()
    check(picker.visible_rows.size()==2,"authored floor filter yields exactly its two public records")
    picker.frame_button.grab_focus()
    await process_frame
    check(Rect2(Vector2.ZERO,Vector2(picker.size)).encloses(picker.frame_button.get_global_rect()),"new group action remains inside the native dialog")
    var press:=InputEventJoypadButton.new();press.button_index=JOY_BUTTON_A;press.pressed=true
    picker.push_input(press)
    var release: InputEventJoypadButton=press.duplicate();release.pressed=false;picker.push_input(release)
    await process_frame
    check(calls.size()==1 and calls[0]=={"keys":["moss_a","moss_b"]} and not picker.visible,"actual controller accept dispatches precisely the visible floor identities and closes on success")
    picker.open(rows(),func(_record):return {"ok":true},func(request):calls.append(request);return {"ok":true})
    await process_frame
    check(picker.locate_button.find_valid_focus_neighbor(SIDE_RIGHT)==picker.frame_button,"native directional focus reaches the new action from the existing locate button")
    picker.frame_button.grab_focus()
    var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;picker.push_input(key)
    var key_release: InputEventKey=key.duplicate();key_release.pressed=false;picker.push_input(key_release)
    await process_frame
    check(calls.size()==2 and calls[1].keys.size()==4 and not picker.visible,"native keyboard accept frames the current complete filter")
    picker.open(rows(),func(_record):return {"ok":true},func(_request):return {"ok":false,"reason":"记录已变化，请重新筛选。"})
    picker.frame_button.pressed.emit()
    check(picker.visible and picker.detail.text.contains("记录已变化"),"failed live revalidation stays open with a readable reason")
    picker.search.text="不存在的地点987";picker.search.text_changed.emit(picker.search.text)
    check(picker.frame_button.disabled,"empty search cannot activate an old group")
    picker.open(rows(),func(_record):return {"ok":true})
    check(picker.frame_button.disabled,"legacy two-argument opens cannot reuse a previous group callback")
    picker.free()

func world_checks() -> void:
    root.process_mode=Node.PROCESS_MODE_DISABLED
    var main: Node=load("res://scenes/World.tscn").instantiate();main.world_resume=false;main.world_save_path="user://map_group_framing.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    var local:=String(main.config.id)
    var local_rooms: Array=main.config.map_rooms
    var chart:=JOURNAL.region(main.story_flags,local);chart.owned=true
    for i in 2:chart.charted[String(local_rooms[i].id)]=true
    var remote:="demo_ch02_rain_foundry_canal"
    var other:=ATLAS.configuration(remote);var other_chart:=JOURNAL.region(main.story_flags,remote);other_chart.owned=true;other_chart.charted[String(other.map_rooms[0].id)]=true
    main._toggle_map();main.world_map_view=false;main._refresh_map_overlay();main.world_save_blocked=true
    var flags: Dictionary=main.story_flags.duplicate(true);var items: Dictionary=main.inventory_counts.duplicate(true);var money: int=main.currency_count;var position: Vector2=main.player.global_position
    var bytes:=FileAccess.get_file_as_bytes(main.world_save_path)
    var public: Array=RUNTIME.rows(main)
    var locals: Array=public.filter(func(entry):return entry.region==local and entry.kind=="room")
    var keys: Array=locals.map(func(entry):return entry.key)
    check(keys.size()>=2,"real directory exposes the two explicitly charted local rooms")
    var result:=RUNTIME.focus_group(main,{"keys":keys,"bounds":Rect2(-999,-999,9999,9999)})
    check(result.ok and not main.world_map_view,"local multi-target framing keeps the regional projection even when saves are blocked")
    RUNTIME.open(main)
    var actual: AcceptDialog=main.map_panel.get_node("MapDirectoryDialog")
    for i in actual.regions.item_count:
        if actual.regions.get_item_metadata(i)==local:actual.regions.select(i)
    actual.kinds.select(1);actual._rebuild_floors();actual._refresh()
    check(actual.visible and not actual.frame_button.disabled,"actual production directory wires the group callback")
    actual.frame_button.pressed.emit()
    check(not actual.visible and not main.world_map_view,"production button frames the filtered regional group and returns to its map")
    var late_callback: Callable=actual.frame_group
    var remote_rows: Array=public.filter(func(entry):return entry.region==remote and entry.kind=="room")
    keys=[locals[0].key,remote_rows[0].key]
    result=RUNTIME.focus_group(main,{"keys":keys})
    check(result.ok and result.count==2 and main.world_map_view,"mixed known regions frame the world overview without travel")
    for entry in [locals[0],remote_rows[0]]:
        var point: Vector2=PINS.project(main,entry.region,entry.point)
        var screen: Vector2=main.map_draw_root.position+point*main.survey_map_view.zoom
        check(Rect2(Vector2.ZERO,main.survey_map_view.size).grow(0.01).has_point(screen),"actual world projection retains each selected anchor inside the viewport")
    check(main.story_flags==flags and main.inventory_counts==items and main.currency_count==money and main.player.global_position==position,"framing preserves knowledge, inventory, money and physical player position")
    check(FileAccess.get_file_as_bytes(main.world_save_path)==bytes,"read-only group framing never writes the journey")
    other_chart.charted.clear()
    var camera_before:=state(main.survey_map_view)
    check(not RUNTIME.focus_group(main,{"keys":keys}).ok and state(main.survey_map_view)==camera_before,"one stale target rejects the entire group before changing the camera")
    main._close_overlays()
    check(not RUNTIME.focus_group(main,{"keys":[locals[0].key]}).ok,"closed map cannot execute a delayed group request")
    RETIREMENT.retire_tree(main);main.free();await process_frame
    preload("res://scripts/audio_director.gd")._stream_cache.clear();preload("res://scripts/audio_director.gd")._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"world fixture releases its actual audio ownership")
    check(not late_callback.call({"keys":keys}).ok,"late callback safely rejects a freed map owner")
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with("map_group_framing"):DirAccess.remove_absolute("user://"+name)

func run() -> void:
    model_checks()
    camera_checks()
    await dialog_checks()
    await world_checks()
    for failure in failures:printerr("FAIL: "+failure)
    print("MAP_GROUP_FRAMING checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
