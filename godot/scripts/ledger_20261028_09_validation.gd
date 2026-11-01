extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_09 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const CHECKLIST:=preload("res://scripts/map_known_checklist.gd")
func run() -> void:
    var rows: Array=[{"key":"SECRET_ID","title":"高桥","region_name":"苔庭","floor_name":"上层","kind":"room","point":Vector2(9999,8888),"detail":"已经补绘的桥"},{"key":"pin:PRIVATE","title":"钟龛","region_name":"苔庭","floor_name":"底层","kind":"pin","detail":"已知落脚处"}]
    var original:=rows.duplicate(true)
    var snapshot:=CHECKLIST.snapshot(rows)
    check(snapshot.rows.size()==2 and snapshot.checked.is_empty(),"snapshot starts unchecked with visible entries only")
    var text:=CHECKLIST.document(snapshot,true)
    check(not text.contains("SECRET_ID") and not text.contains("PRIVATE") and not text.contains("9999") and not text.contains("8888"),"export projects public labels without IDs or coordinates")
    check(text.contains("上层") and text.contains("底层") and text.contains("苔庭"),"export groups region and authored floor")
    CHECKLIST.toggle(snapshot,PackedInt32Array([0,1]))
    check(snapshot.checked.size()==2 and CHECKLIST.document(snapshot).count("[x]")==2,"multi-select toggles checklist rows")
    CHECKLIST.toggle(snapshot,PackedInt32Array([0,-1,99]))
    check(snapshot.checked==[1],"uncheck works and out-of-bounds indices ignored")
    check(not CHECKLIST.document(snapshot).contains("已经补绘的桥"),"public details are optional")
    check(CHECKLIST.document(snapshot,true).contains("已经补绘的桥"),"details included only on explicit option")
    check(CHECKLIST.snapshot(rows+[rows[0]]).rows.size()==2,"duplicate public identities deduplicated")
    check(CHECKLIST.snapshot([{ "title":"坏行","kind":"unknown"}]).rows.is_empty(),"unsupported or incomplete rows excluded")
    check(CHECKLIST.document(CHECKLIST.snapshot([])).contains("没有可生成"),"empty directory produces explicit empty report")
    check(rows==original,"manual checklist never edits knowledge or original directory")
    var huge: Array=[]
    for i in 1030:huge.append({"key":str(i),"title":"地点"+str(i),"region_name":"庭","kind":"room"})
    var bounded:=CHECKLIST.snapshot(huge)
    check(bounded.rows.size()==1024 and bounded.omitted==6,"large export bounded without silent truncation")
    check(CHECKLIST.document(bounded).contains("另有6处"),"truncation described")
    check(CHECKLIST.clean("  甲\n乙\t丙  ").contains("甲"),"public label cleaning retains readable title")
    check(CHECKLIST.document(snapshot).contains("不提供玩家定位"),"checklist has no implied navigation capability")
    var dialog:=preload("res://scripts/map_directory_dialog.gd").new();root.add_child(dialog)
    dialog.visible_rows=rows.duplicate(true);dialog.popup_centered();dialog.open_checklist()
    check(dialog.checklist_rows.item_count==2 and dialog.checklist.visible,"native checklist opens public snapshot")
    dialog.checklist_rows.select(0,false)
    CHECKLIST.toggle(dialog.checklist_data,dialog.checklist_rows.get_selected_items());dialog._render_checklist()
    check(dialog.checklist_text.text.contains("[x]"),"native checklist reflects manual selection")
    dialog.hide()
    check(not dialog.checklist.visible and dialog.checklist_data.is_empty(),"closing map directory clears child checklist")
    dialog.free();finish()
