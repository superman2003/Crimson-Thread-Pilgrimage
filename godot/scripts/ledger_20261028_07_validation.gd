extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_07 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const OVERVIEW:=preload("res://scripts/save_slot_overview.gd")
const INSPECT:=preload("res://scripts/save_inspector.gd")
const STATE:=preload("res://scripts/world_state.gd")
const COORD:=preload("res://scripts/world_coordinates.gd")
class Level extends Node:
    var world_slot:=1
    var snapshots: Array=[]
    var calls:=0
    func get_save_slots() -> Array:return snapshots.duplicate(true)
    func quote_save_operation(action: String,index: int) -> Dictionary:
        return {"ok":true,"primary":snapshots[index-1],"backup":snapshots[index-1].get("backup",{}),"fingerprint":str(index)+action}
    func perform_save_operation(_action: String,_index: int,_fingerprint: String) -> Dictionary:
        calls+=1;return {"ok":true}
class UI extends Control:
    var level: Node
    func register_text_entry_window(_window: Window) -> void:pass
func run() -> void:
    var state:=STATE.new();var data:=state.fresh_data()
    data.current_region="demo_ch01_moss_bell_court";data.world_location=COORD.location(data.current_region,Vector2.ZERO)
    data.regions[data.current_region]=STATE.fresh_region()
    check(state.write_candidate(data,"user://slot_overview.json"),"write real native snapshot fixture")
    var actual:=INSPECT.inspect("user://slot_overview.json")
    var before:=FileAccess.get_file_as_bytes("user://slot_overview.json")
    var snapshots: Array=[actual.merged({"slot":1,"backup":actual.duplicate(true)}),{"slot":2,"exists":true,"valid":false,"error":"损坏","backup":actual.duplicate(true)},{"slot":3,"exists":false,"valid":false,"backup":{}}]
    var rows:=OVERVIEW.rows(snapshots,1)
    check(rows.size()==3 and rows[0].current,"all three slots appear with current marker")
    check(rows[0].state=="主档可读" and rows[1].state.contains("有可读备份"),"readability and recoverable backup distinguished")
    check(rows[2].state=="空槽","empty slot remains distinct from unreadable file")
    check(OVERVIEW.relationship(actual,actual).contains("指纹相同"),"identical snapshots identified by digest")
    var changed:=actual.duplicate(true);changed.sha="different";changed.modified=int(actual.modified)+10
    check(OVERVIEW.relationship(actual,changed).contains("晚于"),"mtime reported without claiming advancement")
    check(OVERVIEW.relationship(actual,changed).contains("不能判断"),"timestamp boundary explained")
    check(OVERVIEW.relationship({},changed).contains("均可读取"),"missing primary never compared as zero progress")
    var text:=OVERVIEW.describe(rows[1],INSPECT.describe)
    check(text.contains("损坏") and text.contains("尚未保存当前内存"),"read error and disk-vs-memory boundary preserved")
    check(FileAccess.get_file_as_bytes("user://slot_overview.json")==before,"overview leaves exact native save bytes untouched")
    check(OVERVIEW.rows(snapshots+[snapshots[0]],1).size()==3,"duplicate slots rejected")
    check(OVERVIEW.rows([{ "slot":true},{"slot":4}],1).is_empty(),"invalid slot identities rejected")
    rows[0].primary.currency=999
    check(snapshots[0].currency==actual.currency,"overview returns detached snapshots")
    check(OVERVIEW.describe({},Callable()).contains("请选择"),"empty selection clears details")
    var ui:=UI.new();var level:=Level.new();root.add_child(level);root.add_child(ui);ui.level=level;level.snapshots=snapshots
    var dialog:=preload("res://scripts/save_desk.gd").new();ui.add_child(dialog);dialog.setup(ui);dialog.open(1,"switch");dialog.open_overview()
    check(dialog.overview_list.item_count==3 and dialog.overview.visible,"native overview displays all slots")
    dialog.overview_list.select(1);dialog._overview_selection()
    check(dialog.overview_detail.text.contains("损坏"),"native overview preserves unreadable-file explanation")
    dialog._overview_action("recover")
    check(dialog.slot==2 and dialog.action=="recover" and not dialog.overview.visible,"overview routes selected slot to original recovery review")
    check(level.calls==0 and dialog.visible,"overview navigation never restores or switches automatically")
    check(FileAccess.get_file_as_bytes("user://slot_overview.json")==before,"native navigation preserves actual fixture bytes")
    ui.free();level.free();finish()
