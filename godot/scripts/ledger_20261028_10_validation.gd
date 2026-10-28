extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_10 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const BROWSER:=preload("res://scripts/resource_purpose_browser.gd")
func name_for(id: String) -> String:return {"copper":"碎铜","salt":"盐屑"}.get(id,"未知材料")
class Level extends Node:
    var active_overlay:="backpack"
    func _item_display_name(id: String) -> String:return {"copper":"碎铜","salt":"盐屑"}.get(id,"材料")
class UI extends Control:
    var level: Node
    var bag: Control
func run() -> void:
    var report: Dictionary={"ok":true,"rows":[{"id":"currency","name":"松脂","count":10,"purpose":"交易"},{"id":"thread","name":"绯线","count":20,"purpose":"施术"},{"id":"copper","name":"碎铜","count":2,"purpose":"补给材料"}],"uses":[{"id":"PRIVATE_TOOL","name":"补钩","kind":"补给","currency":8,"materials":{"copper":{"required":3,"owned":2}},"ready":false},{"id":"PRIVATE_RECIPE","name":"盐线铭饰","kind":"制作","currency":5,"materials":{"salt":{"required":2,"owned":0}},"ready":false},{"name":"针术","kind":"施放","thread":10,"ready":true},{"name":"已做改制","kind":"制作","currency":99,"materials":{"copper":{"required":99,"owned":2}},"ready":false,"complete":true}]}
    var before:=report.duplicate(true)
    var rows:=BROWSER.browse(report,name_for)
    check(rows.size()==4,"zero-stock material appears only because unlocked costs already named it")
    var zero: Dictionary=rows.filter(func(row):return row.id=="salt")[0]
    check(zero.count==0 and zero.short_uses==1 and zero.largest_shortfall==2,"known zero-stock shortage is measurable")
    check(BROWSER.browse(report,name_for,"",2).size()==2,"shortage scope selects only resource-specific deficits")
    check(BROWSER.browse(report,name_for,"",1).size()==1,"ready scope requires actually ready known use")
    check(BROWSER.browse(report,name_for,"针术").size()==1,"search includes public use names")
    check(BROWSER.browse(report,name_for,"PRIVATE").is_empty(),"private IDs never enter search index")
    check(BROWSER.browse(report,name_for,"盐线 制作").size()==2,"multi-token public-use search includes both contributing resources")
    check(BROWSER.browse(report,name_for,"",0,1)[0].id=="salt","quantity sort puts zero stock first")
    check(BROWSER.browse(report,name_for,"",0,2)[0].id=="salt","shortage sort uses maximum single known deficit")
    var copper: Dictionary=rows.filter(func(row):return row.id=="copper")[0]
    check(copper.pending_uses==1 and copper.largest_shortfall==1,"completed recipe excluded from pending deficits")
    check(BROWSER.summary(copper).contains("独立核对"),"summary does not sum alternative recipe costs")
    check(report==before,"browser never mutates inventory or unlocked uses")
    check(BROWSER.browse({"ok":false},name_for).is_empty(),"unreadable report has no invented resource rows")
    var invalid:=report.duplicate(true);invalid.rows[0].count=true
    check(not BROWSER.public_rows(invalid,name_for).any(func(row):return row.id=="currency"),"boolean count rejected")
    var unused:=report.duplicate(true);unused.rows.append({"id":"unused","name":"旧材料","count":3,"purpose":"旧说明"})
    check(BROWSER.browse(unused,name_for,"",3).size()==1,"no-known-pending-use filter does not claim future uselessness")
    rows[0].count=900
    check(report==before,"returned rows detached from source ledger")
    report["reason"]="只核对公开用途。"
    var ui:=UI.new();var level:=Level.new();root.add_child(level);root.add_child(ui);ui.level=level
    ui.bag=Control.new();ui.add_child(ui.bag)
    var dialog:=preload("res://scripts/resource_purpose_dialog.gd").new();ui.add_child(dialog)
    dialog.host=weakref(ui);dialog.report=report;dialog.render_resources()
    check(dialog.resources.item_count==4,"native browser includes known zero-stock material")
    dialog.scope.select(2);dialog.render_resources()
    check(dialog.resources.item_count==2,"native shortage scope filters resource list")
    dialog.query.text="盐线";dialog.render_resources()
    check(dialog.resources.item_count==1 and dialog.selected=="salt","combined native query and shortage scope retain public material")
    dialog.query.text="PRIVATE";dialog.render_resources()
    check(dialog.resources.item_count==0 and dialog.selected.is_empty() and dialog.detail.text.contains("没有符合"),"empty native search clears stale detail")
    ui.free();level.free();finish()
