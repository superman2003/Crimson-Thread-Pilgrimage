extends SceneTree
const PINS := preload("res://scripts/map_player_pins.gd")
const RUNTIME := preload("res://scripts/map_player_pins_runtime.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
var checks:=0
var failures:=0
const A:="pin_relocation_a"
const B:="pin_relocation_b"
class Loader extends RefCounted:
    var phase:="idle"
    var shutting_down:=false
class Player extends Node2D:
    var hp:=5
class UI extends Control:
    var assist:=true
    func get_accessibility(_key: String,_fallback: Variant) -> bool:return assist
class Level extends Node:
    var world_mode:=true
    var world_map_view:=false
    var active_overlay:="map"
    var world_loading:=false
    var chapter_transitioning:=false
    var world_save_blocked:=false
    var world_loader:=Loader.new()
    var build_system: RefCounted
    var player: Node2D
    var ui_shell: Control
    var map_panel: Control
    var config: Dictionary
    var story_flags: Dictionary
    var reject_save:=false
    var saves:=0
    var last_toast:=""
    func _save_world() -> bool:
        saves+=1
        if reject_save:return false
        var file:=FileAccess.open("user://pin_relocation_commit.json",FileAccess.WRITE)
        if file==null:return false
        file.store_string(JSON.stringify(story_flags));file.close();return true
    func _refresh_map_overlay() -> void:pass
    func _toast(message: String) -> void:last_toast=message
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(text)
func config() -> Dictionary:
    return {"id":A,"map_rooms":[{"id":"hall","layout_rect":[0,0,1000,600]},{"id":"secret","hidden":true,"layout_rect":[100,100,100,100]}]}
func flags() -> Dictionary:
    var value: Dictionary={"wallet_marker":73}
    JOURNAL.region(value,A).owned=true;JOURNAL.region(value,A).charted.hall=true
    JOURNAL.region(value,B).owned=true;JOURNAL.region(value,B).charted.hall=true
    value[PINS.KEY]=[{"id":1,"region_id":A,"room_id":"hall","kind":"return","label":"保留的名称","position":[60,60]},{"id":2,"region_id":A,"room_id":"hall","kind":"warning","position":[300,300]}]
    return value
func run() -> void:
    var maps:={A:config(),B:config()}
    var original:=flags();var before:=original.duplicate(true)
    var expected: Dictionary=PINS.records(original,maps)[0]
    var result: Dictionary=PINS.relocate(original,maps,1,A,Vector2(400,400),expected)
    check(result.ok and original==before,"relocation returns a detached candidate without altering story or resources")
    check(result.records[0].id==1 and result.records[0].label==expected.label and result.records[0].kind==expected.kind,"identity name and type survive relocation")
    check(result.records[0].position==[400.0,400.0] and result.records[1].position==[300.0,300.0],"only the selected pin position changes")
    check(PINS.relocate(original,maps,1,B,Vector2(500,400),expected).ok,"known charted destination in another region is accepted by the pure model")
    for point in [Vector2(150,150),Vector2(1000,300),Vector2(NAN,0),Vector2(INF,0)]:
        check(not PINS.relocate(original,maps,1,A,point,expected).ok,"unknown nested rooms boundaries and invalid points cannot receive a moved pin")
    check(not PINS.relocate(original,maps,1,A,Vector2(298,300),expected).ok,"moving cannot overlap another pin")
    check(PINS.relocate(original,maps,1,A,Vector2(60,60),expected).ok,"the pin does not collide with its own current position")
    check(not PINS.relocate(original,maps,1,"unknown_region",Vector2(60,60),expected).ok,"unknown destination regions are rejected")
    check(not PINS.relocate(original,maps,99,A,Vector2(400,400),expected).ok,"missing source identity cannot be recreated")
    check(not PINS.relocate(original,maps,1,A,Vector2(400,400),{}).ok,"relocation requires an explicit source snapshot")
    var stale:=expected.duplicate(true);stale.label="changed"
    check(not PINS.relocate(original,maps,1,A,Vector2(400,400),stale).ok,"changed source content invalidates the editor snapshot")
    var unknown:=original.duplicate(true);unknown[JOURNAL.KEY][A].charted={}
    check(not PINS.relocate(unknown,maps,1,B,Vector2(400,400),expected).ok,"a no-longer-known source cannot be moved to expose it")
    var full:=flags();full[PINS.KEY]=[]
    for i in 12:full[PINS.KEY].append({"id":i+1,"region_id":A,"room_id":"hall","kind":"goal","position":[40+i*40,500]})
    var source: Dictionary=PINS.records(full,maps)[0]
    var moved: Dictionary=PINS.relocate(full,maps,1,A,Vector2(800,500),source)
    check(moved.ok and moved.records.size()==12,"moving works at capacity without allocating a thirteenth pin")
    full[PINS.KEY]=JSON.parse_string(JSON.stringify(moved.records))
    check(PINS.records(full,maps)[0].position==[800.0,500.0],"ordinary save serialization preserves the moved coordinates")
    await _native()
    print("MAP_PIN_RELOCATION checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
func _native() -> void:
    ROUTES.manifest_generation()
    var level:=Level.new();root.add_child(level);level.config=config();level.story_flags=flags()
    var ui:=UI.new();level.add_child(ui);level.ui_shell=ui
    level.map_panel=Control.new();level.add_child(level.map_panel)
    var toolbar:=Control.new();toolbar.name="PlayerPinToolbar";level.map_panel.add_child(toolbar)
    var list:=OptionButton.new();list.name="PinList";list.add_item("图钉1",1);toolbar.add_child(list)
    var status:=Label.new();status.name="PlayerPinStatus";level.map_panel.add_child(status)
    var player:=Player.new();level.add_child(player);level.player=player;player.position=Vector2(400,400)
    RUNTIME.edit_selected(level)
    var popup: ConfirmationDialog=level.map_panel.get_node("PinEditor")
    check(not popup.get_node("Fields/PinMoveToCurrent").button_pressed,"native editor defaults to keeping the original position")
    popup.get_node("Fields/PinMoveToCurrent").button_pressed=true
    popup.get_node("Fields/PinLabel").text="迁移后名称"
    popup.confirmed.emit()
    check(not popup.visible and level.story_flags[PINS.KEY][0].position==[400.0,400.0] and level.story_flags[PINS.KEY][0].label=="迁移后名称","native confirmation commits movement and text together")
    var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://pin_relocation_commit.json"))
    check(saved[PINS.KEY][0].position==[400.0,400.0] and saved.wallet_marker==73,"actual file contains the moved pin without changing unrelated state")
    await process_frame
    player.position=Vector2(500,400);RUNTIME.edit_selected(level);popup=level.map_panel.get_node("PinEditor")
    popup.get_node("Fields/PinMoveToCurrent").button_pressed=true
    var before:=level.story_flags.duplicate(true);level.reject_save=true;popup.confirmed.emit()
    check(popup.visible and level.story_flags==before and popup.get_node("Fields/PinEditorStatus").text.contains("撤回"),"native save failure rolls back position and keeps the editor retryable")
    level.reject_save=false;popup.confirmed.emit()
    check(not popup.visible and level.story_flags[PINS.KEY][0].position==[500.0,400.0],"same confirmed source snapshot can retry after transient save failure")
    await process_frame
    player.position=Vector2(600,400);RUNTIME.edit_selected(level);popup=level.map_panel.get_node("PinEditor");popup.get_node("Fields/PinMoveToCurrent").button_pressed=true
    before=level.story_flags.duplicate(true);ui.assist=false;popup.confirmed.emit()
    check(popup.visible and level.story_flags==before and popup.get_node("Fields/PinEditorStatus").text.contains("定位"),"losing position permission before confirmation rejects the move")
    popup.hide();await process_frame
    RUNTIME.edit_selected(level);popup=level.map_panel.get_node("PinEditor")
    check(popup.get_node("Fields/PinMoveToCurrent").disabled,"without compass or navigation aid the relocation control is disabled")
    popup.hide();await process_frame;ui.assist=true
    RUNTIME.edit_selected(level);popup=level.map_panel.get_node("PinEditor");popup.get_node("Fields/PinMoveToCurrent").button_pressed=true
    player.position+=Vector2(20,0);before=level.story_flags.duplicate(true);popup.confirmed.emit()
    check(popup.visible and level.story_flags==before,"changed player position requires a fresh editor review")
    level.map_panel.hide();await process_frame
    check(not is_instance_valid(popup) or not popup.visible,"closing the map retires its relocation confirmation")
    level.free();await process_frame
