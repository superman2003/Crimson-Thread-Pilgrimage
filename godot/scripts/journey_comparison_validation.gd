extends SceneTree
const COMPARE:=preload("res://scripts/journey_archive_comparison.gd")
const STATE:=preload("res://scripts/world_state.gd")
const BROWSER:=preload("res://scripts/journey_history_browser.gd")
const DETAIL:=preload("res://scripts/journey_archive_detail.gd")
const PATH:="user://journey_comparison_contract.json"
const REGION:="demo_ch01_moss_bell_court"
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames() -> void:
    for unused in 3:await process_frame
func run() -> void:
    var old:=STATE.new();var current:=STATE.new()
    check(old.capture_global({"current_region":REGION}) and current.capture_global({"current_region":REGION}),"fixtures retain valid world-coordinate identity")
    old.data.currency=77;current.data.currency=52
    old.data.hp=2.5;current.data.hp=3.75
    old.data.inventory_counts={"silk_wall_grip":1,"testimony_01":2,"obsolete_private_id":3}
    current.data.inventory_counts={"thread_dash":1,"testimony_01":1,"obsolete_private_id":0}
    old.data.regions[REGION]=STATE.fresh_region();current.data.regions[REGION]=STATE.fresh_region()
    old.data.regions[REGION].visited_rooms={"common":true,"old_secret":true,"ignored":false}
    current.data.regions[REGION].visited_rooms={"common":true,"current_secret":true}
    old.data.regions[REGION].opened_shortcuts={"old_door":true}
    current.data.regions[REGION].opened_shortcuts={"current_door":true}
    current.data.regions[REGION].boss_defeated=true
    old.data.build_state={"crest":"crimson","equipped_families":{"tool":["",false,"unknown_internal_item"]}}
    var old_before:=old.data.duplicate(true);var current_before:=current.data.duplicate(true)
    var report:=COMPARE.project(old.data,current.data)
    var text:=DETAIL.text(report)
    check(report.ok and text.contains("碎钱：77 → 52（当前少25）"),"comparison direction is old archive to current saved record")
    check(text.contains("已访房间：共同1 / 仅旧旅途1 / 仅当前1"),"equal counts still disclose different visited identities without location names")
    check(text.contains("已开捷径：共同0 / 仅旧旅途1 / 仅当前1"),"different shortcuts are not misrepresented as equal progress")
    check(text.contains("守门者：未败 → 已败"),"boss record change is explicit")
    check(not text.contains("old_secret") and not text.contains("current_secret") and not text.contains("current_door"),"comparison never exports hidden room or door identifiers")
    check(text.contains("旧记录未说明；不推定为空槽") and text.contains("无法识别的旧装备"),"legacy or unknown equipment is not silently migrated to empty or leaked as IDs")
    check(not text.contains("unknown_internal_item") and not text.contains("double_thread_jump"),"unknown equipment and unowned ability identifiers stay private")
    check(text.contains("保存时生命：2.5 → 3.75"),"fractional saved measurements are not truncated to integers")
    check(text.contains("2 → 1（当前少1）") and text.contains("另有"),"held named item counts and unrecognized-item limitation are explicit")
    check(not text.contains("obsolete_private_id") and not text.contains("testimony_02"),"inventory comparison lists neither private legacy IDs nor unheld item IDs")
    check(old.data==old_before and current.data==current_before,"projection leaves both borrowed snapshots exact")
    check(not COMPARE.project({},current.data).ok and not COMPARE.project(old.data,{}).ok,"unreadable snapshot is never treated as zero progress")
    var with_ending:=current.data.duplicate(true);with_ending.story_flags={"ending_a_done":true}
    check(DETAIL.text(COMPARE.project(old.data,with_ending)).contains("尚未作出选择 → 重鸣"),"legacy ending flags compare only choices already made")
    check(not text.contains("断冠") and not text.contains("改写"),"unchosen endings are not enumerated in comparison")
    var identical:=DETAIL.text(COMPARE.project(current.data,current.data))
    check(identical.contains("碎钱：52 → 52（相同）") and identical.contains("数量相同不表示"),"same record includes explicit comparison limitation")
    check(old.write(PATH+".previous") and current.write(PATH),"native fixtures write two real valid world records")
    var hash:=FileAccess.get_sha256(PATH+".previous")
    var bytes_before:=FileAccess.get_file_as_bytes(PATH)
    var archive_before:=FileAccess.get_file_as_bytes(PATH+".previous")
    var files_before:=DirAccess.get_files_at("user://")
    report=COMPARE.inspect(PATH,PATH.get_file()+".previous",hash)
    check(report.ok and DETAIL.text(report).contains("77 → 52"),"production file path reads same-slot archive and actual primary")
    check(FileAccess.get_file_as_bytes(PATH)==bytes_before and FileAccess.get_file_as_bytes(PATH+".previous")==archive_before,"reading never rewrites either file")
    check(DirAccess.get_files_at("user://")==files_before,"comparison does not produce backups, temporary files or recovery sidecars")
    var legacy:=old.data.duplicate(true);legacy.version=1
    legacy.erase("build_state");legacy.erase("death_cache");legacy.erase("world_location")
    var legacy_name:=PATH.get_file()+".previous.earlier_legacy"
    var legacy_file:=FileAccess.open("user://"+legacy_name,FileAccess.WRITE);legacy_file.store_string(JSON.stringify(legacy));legacy_file.close()
    var legacy_bytes:=FileAccess.get_file_as_bytes("user://"+legacy_name)
    check(COMPARE.inspect(PATH,legacy_name,FileAccess.get_sha256("user://"+legacy_name)).ok,"valid legacy schema can be read through existing in-memory migration")
    check(FileAccess.get_file_as_bytes("user://"+legacy_name)==legacy_bytes,"comparing legacy schema never writes migrated data back to disk")
    for name in ["../"+PATH.get_file()+".previous",PATH.get_file(),"another.json.previous",PATH.get_file()+".previous.earlier_x.tmp"]:
        check(not COMPARE.inspect(PATH,name,hash).ok,"only current-slot archive identities may be compared")
    check(not COMPARE.inspect(PATH,PATH.get_file()+".previous","bad").ok,"missing identity refuses query")
    check(not COMPARE.inspect(PATH,PATH.get_file()+".previous","0".repeat(64)).ok,"stale archive hash refuses changed source")
    var browser:=BROWSER.new();root.add_child(browser)
    var row:={"file":PATH.get_file()+".previous","sha256":hash,"valid":true,"modified":0,"region_name":"苔钟庭"}
    var query:=func(_offset: int,_limit: int):return {"entries":[row],"total":1,"has_more":false}
    var detail:=func(name: String,identity: String):return DETAIL.inspect(PATH,name,identity)
    browser.open(query,detail);await frames();browser.select_entry(0)
    check(browser.compare_button.disabled,"legacy two-callback callers retain detail but cannot invent comparison")
    browser.open(query,detail,func(name: String,identity: String):return COMPARE.inspect(PATH,name,identity));await frames()
    check(browser.compare_button.disabled,"a fresh page requires selecting the actual archive")
    browser.select_entry(0);check(not browser.compare_button.disabled,"valid archive with current comparison callback enables explicit action")
    browser.compare_button.pressed.emit();await frames()
    check(browser.detail_text.text.contains("旧旅途 → 当前已保存旅途") and browser.detail_text.text.contains("77 → 52"),"real browser renders current saved comparison")
    browser.request_page(0);check(browser.compare_button.disabled,"page refresh invalidates old selected identity")
    browser.select_entry(0)
    browser.compare_query=func(_name: String,_identity: String):return "malformed result"
    browser.compare_selected();check(browser.detail_text.text.contains("暂不可用"),"malformed comparison callback has a readable error instead of a crash")
    browser.compare_query=func(_name: String,_identity: String):
        browser.open(query,detail)
        return {"ok":true,"reason":"STALE_COMPARISON","sections":[]}
    browser.select_entry(0);browser.compare_selected();await frames()
    check(not browser.detail_text.text.contains("STALE_COMPARISON") and not browser.loading,"reopened browser rejects stale comparison callback")
    browser.open(query,detail,func(_name: String,_identity: String):
        browser.hide()
        return {"ok":true,"reason":"CLOSED_COMPARISON","sections":[]})
    await frames();browser.select_entry(0);browser.compare_selected();await frames()
    check(not browser.visible and not browser.detail_text.text.contains("CLOSED_COMPARISON"),"closing browser during callback cannot publish obsolete result")
    browser.compare_selected();check(not browser.visible,"hidden browser cannot initiate comparison")
    browser.queue_free();await frames()
    var broken:=FileAccess.open(PATH,FileAccess.WRITE);broken.store_string("broken primary");broken.close()
    var broken_bytes:=FileAccess.get_file_as_bytes(PATH)
    report=COMPARE.inspect(PATH,PATH.get_file()+".previous",hash)
    check(not report.ok and String(report.reason).contains("当前已保存旅途"),"damaged primary does not fall back to archive, zero state or backup")
    check(FileAccess.get_file_as_bytes(PATH)==broken_bytes,"damaged primary evidence is preserved byte for byte")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
    check(not COMPARE.inspect(PATH,PATH.get_file()+".previous",hash).ok,"missing primary has explicit non-comparable result")
    var broken_archive:=FileAccess.open(PATH+".previous",FileAccess.WRITE);broken_archive.store_string("bad archive");broken_archive.close()
    var damaged_hash:=FileAccess.get_sha256(PATH+".previous")
    check(not COMPARE.inspect(PATH,PATH.get_file()+".previous",damaged_hash).ok,"damaged archive is refused even with matching source identity")
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with(PATH.get_file()):DirAccess.remove_absolute("user://"+name)
    print("JOURNEY_COMPARISON checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
