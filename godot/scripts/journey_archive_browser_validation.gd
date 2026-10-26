extends SceneTree
const WORLD := preload("res://scripts/world_state.gd")
const HISTORY := preload("res://scripts/journey_history.gd")
const DETAIL := preload("res://scripts/journey_archive_detail.gd")
const BROWSER := preload("res://scripts/journey_history_browser.gd")
const UI := preload("res://scripts/pilgrimage_interface.gd")
const PATH := "user://archive_browser_contract.json"
var checks:=0
var failures:=0
var requests: Array=[]
var detail_requests: Array=[]

class Runtime extends Node:
    var world_save_path: String
    func get_journey_history() -> Dictionary:return HISTORY.summaries(world_save_path)
    func get_journey_history_page(offset: int,limit: int) -> Dictionary:return HISTORY.summaries(world_save_path,offset,limit)
    func get_journey_archive_detail(file: String,sha: String) -> Dictionary:return DETAIL.inspect(world_save_path,file,sha)

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func put(path: String,text: String) -> void:
    var file:=FileAccess.open(path,FileAccess.WRITE)
    file.store_string(text)
    file.close()
func clean() -> void:
    for file in DirAccess.get_files_at("user://"):
        if file.begins_with(PATH.get_file()):DirAccess.remove_absolute("user://"+file)
func archive(index: int) -> String:return PATH+".previous.earlier_%02d" % index
func known_world() -> Dictionary:
    var world:=WORLD.new()
    world.capture_global({"current_region":"demo_ch01_moss_bell_court","currency":77,
        "story_flags":{"quest_bring_names_started":true},"inventory_counts":{"testimony_01":1},
        "build_state":{"crest":"crimson","equipped_families":{"tool":["shard"],"thread_skill":["cleave"]}}})
    world.capture_region("demo_ch01_moss_bell_court",{"visited_rooms":{"first":true,"unvisited":false},"bell_count":2})
    return world.data
func query(offset: int,limit: int) -> Dictionary:
    requests.append([offset,limit])
    return HISTORY.summaries(PATH,offset,limit)
func inspect(file: String,sha: String) -> Dictionary:
    detail_requests.append([file,sha])
    return DETAIL.inspect(PATH,file,sha)
func run() -> void:
    clean()
    model_checks()
    await browser_checks()
    await production_shell_checks()
    clean()
    print("JOURNEY_ARCHIVE_BROWSER checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func model_checks() -> void:
    var data:=known_world()
    var before:=data.duplicate(true)
    var model:=DETAIL.project(data)
    var text:=DETAIL.text(model)
    check(model.ok and data==before,"projection never mutates the caller's archive")
    check(text.contains("苔钟庭") and text.contains("已访1间") and text.contains("钟龛2次"),"only actual visited rooms and authored region names are summarized")
    check(text.contains("缝名契印") and not text.contains("shard") and not text.contains("cleave"),"equipment uses authored names, not internal IDs")
    check(not text.contains("断弦温室") and not text.contains("改写"),"unvisited regions and unchosen endings are absent")
    check(not text.contains("grant_flags") and not model.has("data") and not model.has("story_flags"),"display projection exposes no raw save or reward flags")
    var legacy:=data.duplicate(true)
    legacy.build_state={"crest":true,"equipped_families":{"tool":"bad","thread_skill":[true,{}]}}
    check(DETAIL.text(DETAIL.project(legacy)).contains("旧版本"),"unknown legacy build shapes remain browsable without attempted migration")
    legacy.build_state={"crest":"crimson","equipped_families":{"tool":["unknown_secret"]}}
    check(not DETAIL.text(DETAIL.project(legacy)).contains("unknown_secret"),"unknown saved equipment identifiers never leak raw strings")
    for choice in ["ending_a","ending_b","ending_c"]:
        var chosen:=data.duplicate(true)
        chosen.story_flags={choice+"_done":true}
        var chosen_text:=DETAIL.text(DETAIL.project(chosen))
        check(chosen_text.contains({"ending_a":"重鸣","ending_b":"断冠","ending_c":"改写"}[choice]),"only the selected legacy ending is summarized")
    var file:=archive(0)
    put(file,JSON.stringify(data))
    var bytes:=FileAccess.get_file_as_bytes(file)
    var sha:=FileAccess.get_sha256(file)
    var detail:=DETAIL.inspect(PATH,file.get_file(),sha)
    check(detail.ok and detail.sha256==sha,"exact archive selected from list can be inspected")
    check(FileAccess.get_file_as_bytes(file)==bytes,"detail inspection preserves every archive byte")
    check(not FileAccess.file_exists(PATH) and not FileAccess.file_exists(PATH+".bak"),"inspection never creates an active save or backup")
    for name in ["../"+file.get_file(),"/tmp/"+file.get_file(),PATH.get_file(),PATH.get_file()+".bak",file.get_file()+".tmp",file.get_file()+".pending","other.previous"]:
        check(not DETAIL.inspect(PATH,name,sha).ok,"reject traversal, other slots, primary, backup and sidecars: "+name)
    for hash in ["","abc","g".repeat(64),"0".repeat(63),"0".repeat(65)]:
        check(not DETAIL.inspect(PATH,file.get_file(),hash).ok,"malformed identity cannot be used as an unchecked detail request")
    put(file,JSON.stringify(known_world()).replace('77','78'))
    check(not DETAIL.inspect(PATH,file.get_file(),sha).ok,"external save replacement invalidates the previously selected row")
    put(file,"damaged")
    check(not DETAIL.inspect(PATH,file.get_file(),FileAccess.get_sha256(file)).ok,"damaged archive cannot be projected even with current identity")
    check(FileAccess.get_file_as_string(file)=="damaged","damaged bytes remain available for recovery outside browser")
    put(file," ".repeat(WORLD.MAX_BYTES+1))
    check(not DETAIL.inspect(PATH,file.get_file(),FileAccess.get_sha256(file)).ok,"oversized archives are rejected before World parsing")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
    for index in 27:put(archive(index),JSON.stringify(data))
    var pages: Array=[]
    for offset in [0,12,24]:
        var page:=HISTORY.summaries(PATH,offset,12)
        check(page.total==27 and page.offset==offset,"pagination retains the total without including active or other-slot saves")
        check(page.entries.size()==(3 if offset==24 else 12),"last archive page has exact remaining rows")
        for row in page.entries:
            check(not pages.has(row.file),"each archived file occurs once across stable pages")
            pages.append(row.file)
            var original:=FileAccess.get_file_as_bytes(PATH.get_base_dir().path_join(row.file))
            check(DETAIL.inspect(PATH,row.file,row.sha256).ok,"all page rows retain the exact identity for detail lookup")
            check(FileAccess.get_file_as_bytes(PATH.get_base_dir().path_join(row.file))==original,"multi-page browsing leaves every inspected archive unchanged")
    check(pages.size()==27,"all records beyond the former first-page limit are reachable")

func browser_checks() -> void:
    var browser:=BROWSER.new()
    root.add_child(browser)
    browser.open(query,inspect)
    check(browser.visible and browser.entries.item_count==12,"native browser opens the first page")
    check(browser.get_ok_button().has_focus(),"initial keyboard/controller confirmation returns safely to settings")
    check(browser.previous.disabled and not browser.next.disabled,"first page exposes only valid page directions")
    check(browser.summary_text.text.contains("苔钟庭") and not browser.summary_text.bbcode_enabled and not browser.detail_text.bbcode_enabled,"native readers show Chinese plain text without interpreting saved markup")
    var count:=requests.size()
    await process_frame
    await process_frame
    check(requests.size()==count and detail_requests.is_empty(),"idle frames do not reread archives or trigger transactions")
    browser.entries.select(0)
    browser.entries.item_selected.emit(0)
    check(detail_requests.size()==1 and browser.detail_text.text.contains("归档时的装备"),"native selection requests only the selected archive's known detail")
    browser.next.pressed.emit()
    check(browser.offset==12 and browser.entries.item_count==12 and not browser.previous.disabled,"next page loads its own bounded window")
    check(browser.detail_text.text.contains("选择左侧"),"page change retires a former file's detail")
    browser.next.pressed.emit()
    check(browser.offset==24 and browser.entries.item_count==3 and browser.next.disabled,"native last page stops next navigation")
    browser.previous.pressed.emit()
    check(browser.offset==12,"previous page returns to the preceding stable window")
    var row: Dictionary=browser.rows[0]
    var path:=PATH.get_base_dir().path_join(String(row.file))
    put(path,JSON.stringify(known_world()).replace('77','79'))
    browser.select_entry(0)
    check(browser.detail_text.text.contains("已变化"),"stale native selection explains that refresh is necessary")
    browser.refresh_button.pressed.emit()
    browser.select_entry(0)
    check(browser.detail_text.text.contains("归档时的装备"),"explicit refresh obtains the changed archive's new identity")
    count=detail_requests.size()
    browser.select_entry(-1)
    browser.select_entry(999)
    check(detail_requests.size()==count,"invalid selection does not attempt a file read")
    browser.open(func(_offset: int,_limit: int):return {"entries":[],"total":0,"shown":0},inspect)
    check(browser.entries.item_count==0 and browser.previous.disabled and browser.next.disabled and browser.summary_text.text.contains("还没有"),"empty history clears old rows/details and disables paging")
    browser.open(func(_offset: int,_limit: int):return {"entries":[],"total":0,"shown":0,"error":"目录不可读"},inspect)
    check(browser.summary_text.text.contains("目录不可读"),"directory error is visible rather than silently treated as success")
    browser.open(func(_offset: int,_limit: int):return {"entries":[{"file":"broken","valid":false,"error":"损坏"}],"total":1,"shown":1},inspect)
    count=detail_requests.size()
    browser.select_entry(0)
    check(browser.detail_text.text.contains("损坏") and detail_requests.size()==count,"invalid summary never triggers detail parsing")
    browser.open(func(_offset: int,_limit: int):return {"entries":[{"valid":false}],"offset":240,"total":500,"has_more":true},inspect)
    check(browser.next.disabled and browser.summary_text.text.contains("浏览上限"),"bounded scan limit cannot loop indefinitely on the last supported page")
    browser.free()
    await process_frame

func production_shell_checks() -> void:
    var runtime:=Runtime.new()
    runtime.world_save_path=PATH
    root.add_child(runtime)
    var ui:=UI.new()
    root.add_child(ui)
    ui.level=runtime
    ui.journey_history_button=Button.new()
    ui.add_child(ui.journey_history_button)
    ui._show_journey_history()
    check(ui.journey_history_dialog.visible and ui.is_browsing_journey_history(),"actual production shell opens its existing input-isolated history entry")
    check(ui.journey_history_text==ui.journey_history_dialog.get("summary_text"),"existing shell reader reference is the new native browser summary")
    check(ui.journey_history_text.text.contains("苔钟庭"),"production entry reads current slot archives through actual runtime-style callbacks")
    ui.journey_history_dialog.call("select_entry",0)
    check(ui.journey_history_dialog.get("detail_text").text.contains("归档时的装备"),"production shell detail callback stays read-only and selected-file specific")
    ui.journey_history_dialog.hide()
    ui.journey_history_dialog.canceled.emit()
    check(ui.is_browsing_journey_history(),"same-frame Escape capture survives replacement browser")
    await process_frame
    check(not ui.is_browsing_journey_history(),"capture releases on the next frame")
    ui.free()
    runtime.free()
    await process_frame
