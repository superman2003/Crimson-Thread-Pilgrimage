extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_01 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const MODEL:=preload("res://scripts/combat_review_analysis.gd")
const LEDGER:=preload("res://scripts/combat_ledger.gd")
const DESK:=preload("res://scripts/combat_desk.gd")
class UI extends Control:
    var bag: Control
    func register_text_entry_window(_window: Window) -> void:pass
func record(region: String, crest: String, seconds: float, incoming: int=0) -> Dictionary:
    return LEDGER.sanitize({"region":region,"title":region,"crest":crest,"seconds":seconds,"incoming":incoming,"outgoing":12,"guards":2,"perfect":1,"heals":2,"interruptions":1,"date":"today","reason":"主动结束"})
func run() -> void:
    var a:=record("庭","针",30,3);var b:=record("庭","针",60,2);var c:=record("渠","针",30,1);var d:=record("庭","盐",30,1)
    var history: Array=[a,b,c,d,{},true]
    var before:=history.duplicate(true)
    check(MODEL.select(history,a,0).size()==4,"invalid observations rejected")
    check(MODEL.select(history,a,1).size()==3,"region scope excludes another region")
    check(MODEL.select(history,a,2).size()==2,"crest scope excludes another crest")
    check(MODEL.select(history,{},1).is_empty(),"missing anchor never widens scope")
    check(MODEL.select(history,a,3).is_empty(),"invalid scope rejected")
    var totals:=MODEL.summarize([a,b])
    check(totals.incoming==5 and totals.outgoing==24 and totals.observations==2,"raw counts aggregated")
    check(is_equal_approx(totals.damage_per_minute,16.0),"rate weighted by exposure rather than averaging rates")
    check(is_equal_approx(totals.perfect_share,50.0),"guard share uses guards as denominator")
    check(is_equal_approx(totals.heal_completion,200.0/3.0),"completion denominator includes interruptions")
    var zero:=record("庭","针",0,100)
    check(MODEL.summarize([zero]).damage_per_minute==null,"zero exposure has no rate")
    check(MODEL.summarize([a,zero]).incoming_per_minute==6.0,"zero exposure counts do not inflate timed rates")
    check(MODEL.summarize([]).heal_completion==null,"no heal attempts has no completion percentage")
    check(MODEL.comparable(history,a).size()==1,"comparison excludes selected observation and other setups")
    var detached:=MODEL.select(history,a,2);detached[0].incoming=999
    check(history==before,"analysis never mutates saved observations")
    check(MODEL.report(history,a,2).contains("不含战具"),"report states damage measurement boundary")
    var ui:=UI.new();root.add_child(ui);ui.bag=Control.new();ui.add_child(ui.bag)
    var desk:=DESK.new();ui.add_child(desk);desk.set_process(false);desk.ui=ui;desk.ledger.history=[a,b,c,d]
    desk._build();desk.refresh()
    check(desk.analysis_scope.item_count==3 and desk.comparison.item_count==2,"native menu offers scopes and comparable baseline")
    desk.analysis_scope.select(2);desk._analysis()
    check(desk.analysis.text.contains("2次观察"),"native analysis uses selected scope")
    desk.comparison.select(1);desk._comparison()
    check(desk.detail.text.contains("指定同地区同契印"),"native explicit baseline updates detail")
    desk.refresh()
    check(desk.comparison.selected==1 and desk.detail.text.contains("指定同地区同契印"),"periodic refresh preserves selected comparison baseline")
    for button in desk.window.find_children("*","Button",true,false):
        if button.text=="比较较早一条":button.pressed.emit();break
    check(desk.comparison_baseline.is_empty() and desk.compare and desk.detail.text.contains("与较早所选"),"switching to adjacent comparison clears explicit baseline")
    desk.query.text="absent";desk.refresh()
    check(desk.visible_records.is_empty() and desk.comparison.disabled,"empty search clears comparison")
    ui.free();finish()
