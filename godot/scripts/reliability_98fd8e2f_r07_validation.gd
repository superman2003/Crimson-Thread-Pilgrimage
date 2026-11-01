extends SceneTree
const BROWSER=preload("res://scripts/journey_history_browser.gd")
const VIEW=preload("res://scripts/archive_page_view.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var row:={"valid":true,"file":"save.previous.1","sha256":"a".repeat(64),"modified":1,"currency":5}
    var page:=VIEW.page({"entries":[null,7,row],"total":"wrong","offset":INF},0,12,240)
    check(page.entries.size()==3 and not page.entries[0].valid and page.entries[2].valid,"mixed rows isolated")
    check(page.total==0 and page.offset==0,"nonfinite and nonnumeric page metadata safe")
    check(VIEW.page(null,24,12,240).error.contains("刷新"),"callback failure explained")
    check(not VIEW.detail({"ok":true,"sections":7}).ok,"bad details safe")
    var browser:=BROWSER.new();root.add_child(browser)
    browser.open(func(_offset,_count):return {"entries":[null,row],"total":2},func(_file,_sha):return null)
    check(browser.entries.item_count==2 and not browser.loading,"real UI recovers malformed row")
    browser.select_entry(0);check(browser.detail_text.text.contains("格式"),"invalid row selectable as explanation")
    browser.select_entry(1);check(browser.detail_text.text.contains("不可用"),"missing detail safe")
    var first: Array=[true]
    browser.open(func(_offset,_count):
        if first[0]:
            first[0]=false
            browser.open(func(_a,_b):return {"entries":[],"total":0},Callable())
        return {"entries":[row],"total":1},Callable())
    check(browser.rows.is_empty(),"reentrant reopen discards old callback page")
    browser.request_page(-20);check(browser.offset==0,"negative requested offset safe")
    browser.free();await process_frame
    print("RELIABILITY_R07 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
