extends SceneTree
const INSPECT:=preload("res://scripts/save_inspector.gd")
const DESK:=preload("res://scripts/save_desk.gd")
const STATE:=preload("res://scripts/world_state.gd")
const COORD:=preload("res://scripts/world_coordinates.gd")
const PRIMARY:="user://save_difference_primary.json"
const A:="demo_ch01_moss_bell_court"
const B:="demo_ch02_rain_foundry_canal"
var checks:=0
var failures:=0
class Level extends Node:
    var world_slot:=1
    var calls:=0
    func quote_save_operation(action: String,index: int) -> Dictionary:
        var primary:=INSPECT.inspect(PRIMARY)
        var backup:=INSPECT.inspect(PRIMARY+".bak")
        return {"ok":backup.valid,"primary":primary,"backup":backup,"fingerprint":var_to_str([action,index,primary,backup]).sha256_text()}
    func perform_save_operation(_action: String,_index: int,_fingerprint: String) -> Dictionary:
        calls+=1;return {"ok":true}
class UI extends Control:
    var level: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(text)
func data(cash: int,full: bool) -> Dictionary:
    var result:=STATE.fresh_data();result.current_region=A;result.currency=cash;result.hp=5 if full else 3;result.energy=80 if full else 40
    result.world_location=COORD.location(A,Vector2.ZERO)
    result.inventory_counts={"moss_chitin":3,"thread_dash":1}
    if full:result.inventory_counts["echo_hook"]=1
    var region:=STATE.fresh_region();region.visited_rooms={"entry":true};region.boss_defeated=full
    if full:region.visited_rooms["hall"]=true
    result.regions[A]=region
    if full:
        var other:=STATE.fresh_region();other.visited_rooms={"entry":true};result.regions[B]=other
    result.story_flags={"not_a_public_summary":"future_secret"}
    return result
func put(path: String,value: Dictionary) -> void:
    var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func run() -> void:
    put(PRIMARY,data(69,true));put(PRIMARY+".bak",data(33,false))
    var before:=FileAccess.get_file_as_bytes(PRIMARY);var backup_before:=FileAccess.get_file_as_bytes(PRIMARY+".bak")
    var primary:=INSPECT.inspect(PRIMARY);var backup:=INSPECT.inspect(PRIMARY+".bak")
    check(primary.valid and backup.valid,"actual primary and backup snapshots pass production validation")
    check(primary.progress=={"items":3,"abilities":2,"visited":3,"bosses":1},"progress counts reflect only held items earned abilities and real visit/victory markers")
    var text:=INSPECT.compare(primary,backup)
    check(text.contains("碎钱：69 → 33（减少36）"),"recovery preview makes lost currency explicit")
    check(text.contains("已获永久能力：2 → 1（减少1）") and text.contains("已访房间：3 → 1（减少2）"),"recovery preview makes capability and visit differences explicit")
    check(text.contains("已败守门者：1 → 0（减少1）") and text.contains("当前生命：5 → 3"),"victory and live resource changes have the same primary-to-backup direction")
    check(not text.contains("future_secret") and not text.contains("not_a_public_summary"),"summary never dumps private story flags or hidden identifiers")
    check(text.contains("数量相同不代表"),"equal counts are not presented as identical story state")
    check(FileAccess.get_file_as_bytes(PRIMARY)==before and FileAccess.get_file_as_bytes(PRIMARY+".bak")==backup_before,"inspection and comparison never rewrite either file")
    var malformed:=data(1,false);malformed.inventory_counts={"thread_dash":true,"echo_hook":NAN,"item":0.5,"negative":-1,"inf":INF}
    check(INSPECT.progress(malformed).items==0 and INSPECT.progress(malformed).abilities==0,"invalid scalar counters cannot inflate summary quantities")
    var missing:=INSPECT.inspect("user://no_difference_save.json")
    check(not missing.exists and INSPECT.compare(missing,backup).contains("无法比较"),"missing primary does not invent zero-progress differences")
    var file:=FileAccess.open(PRIMARY,FileAccess.WRITE);file.store_string("damaged");file.close()
    var damaged:=INSPECT.inspect(PRIMARY)
    check(not damaged.valid and damaged.progress.is_empty() and INSPECT.compare(damaged,backup).contains("无法比较"),"damaged records retain explicit unreadable status without fabricated counts")
    check(FileAccess.get_file_as_string(PRIMARY)=="damaged","bad primary bytes remain untouched")
    put(PRIMARY,data(69,true))
    var ui:=UI.new();var level:=Level.new();root.add_child(level);root.add_child(ui);ui.level=level
    var dialog:=DESK.new();ui.add_child(dialog);dialog.setup(ui);dialog.open(2,"recover")
    check(dialog.description is RichTextLabel and dialog.description.scroll_active and not dialog.description.bbcode_enabled,"native recovery description supports bounded plain-text scrolling")
    check(dialog.description.text.contains("若恢复此备份") and dialog.description.text.contains("减少36"),"actual recovery dialog includes the production comparison")
    check(level.calls==0,"opening and reading a recovery preview performs no restore")
    dialog.hide();dialog.open(2,"switch")
    check(not dialog.description.text.contains("若恢复此备份"),"normal slot switching is not described as backup restoration")
    dialog.hide();dialog.open(2,"recover");put(PRIMARY+".bak",data(40,false));dialog.confirmed.emit()
    check(level.calls==0 and dialog.visible and dialog.description.text.contains("重新核对"),"changed backup identity requires another explicit confirmation")
    dialog.confirmed.emit()
    check(level.calls==1 and not dialog.visible,"unchanged reviewed snapshot reaches the existing restore action once")
    ui.free();level.free()
    print("SAVE_BACKUP_DIFFERENCE checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
