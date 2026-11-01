extends SceneTree
const MODEL := preload("res://scripts/practice_curriculum.gd")
const DESK := preload("res://scripts/practice_desk.gd")
var checks:=0
var failures:=0
class Level extends Node:
    var inventory_counts: Dictionary={}
    var build_panel: Control
    var player: Node
class UI extends Control:
    const REMAPPABLE_ACTIONS := ["dash","jump","attack","heal","skill"]
    var level: Node
    var build_panel: Control
    var construction_complete:=false
    func register_text_entry_window(_window: Window) -> void:pass
    func _short_binding(action: String) -> String:return action
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(text)
func run() -> void:
    var model:=MODEL.new();model.configure("practice_review_contract")
    var earned: Dictionary={"thread_dash":1}
    model.history=[{"course":"casting","complete":true,"seconds":4.2,"reason":"课程完成"},{"course":"casting","complete":false,"seconds":8.0,"reason":"主动结束"},{"course":"casting","complete":true,"seconds":6.0,"reason":"课程完成"},{"course":"thread_dash","complete":true,"seconds":2.0,"reason":"课程完成"}]
    var before:=model.history.duplicate(true)
    check(model.browse({}).size()==2,"locked ability titles stay outside the public course browser")
    check(model.browse({},"",2).size()==1 and model.browse({},"",1).size()==1,"completion filters operate on earned courses only")
    check(model.browse({},"突进").is_empty() and model.recent("thread_dash",{}).is_empty(),"historical future ability records do not reveal locked course details")
    check(model.browse(earned,"突进").size()==1,"earning an ability opens its searchable course")
    check(model.browse({"thread_dash":true},"突进").is_empty(),"boolean inventory cannot unlock a course search result")
    var recent:=model.recent("casting",{})
    check(recent.size()==3 and not recent[1].complete and recent[0].seconds==4.2,"recent review includes saved successes and interrupted attempts in order")
    check(is_equal_approx(model.best("casting"),4.2),"unfinished attempts do not change the personal best")
    recent[0].reason="changed"
    var browsed:=model.browse({});browsed[0].title="changed"
    check(model.history==before and not model.courses[0].title=="changed","browser and history views are detached from production state")
    check(model.recent("unknown",{}).is_empty() and model.recent("casting",{},0).size()==1,"review bounds and unknown IDs are safe")
    check(model.store.write({"history":model.history}),"save actual completed and interrupted history")
    var restored:=MODEL.new();restored.configure("practice_review_contract")
    check(restored.recent("casting",{}).size()==3 and restored.browse({},"",2).size()==1,"real auxiliary reload restores review and filters")
    var other:=MODEL.new();other.configure("another_practice_journey")
    check(other.recent("casting",{}).is_empty() and other.browse({},"",2).is_empty(),"another save has no imported training history")
    var ui:=UI.new();var level:=Level.new();root.add_child(level);root.add_child(ui);ui.level=level
    level.build_panel=Control.new();level.add_child(level.build_panel);ui.build_panel=level.build_panel
    var desk:=DESK.new();desk.ui=ui;desk.curriculum=model;ui.add_child(desk);desk.set_process(false);desk._build();desk.refresh()
    check(desk.available.size()==2 and desk.completion_filter.item_count==3,"actual course menu creates completion filters and available rows")
    desk.completion_filter.select(2);desk.completion_filter.item_selected.emit(2)
    check(desk.available.size()==1 and desk.detail.text.contains("最近已保存") and desk.detail.text.contains("主动结束"),"native selection shows bounded recent attempts for the selected course")
    desk.search.text="不存在的课程";desk.search.text_changed.emit(desk.search.text)
    check(desk.available.is_empty() and desk.selected.is_empty() and desk.start_button.disabled,"empty native filter clears stale selection and disables starting")
    desk.start_selected()
    check(model.active.is_empty() and desk.window.status.text.contains("先选择"),"direct activation cannot start an old hidden selection")
    desk.search.clear();desk.search.text_changed.emit("")
    check(not desk.start_button.disabled and desk.available.size()==1,"clearing the search restores a usable selection")
    desk.completion_filter.select(1);desk.completion_filter.item_selected.emit(1)
    check(desk.available.size()==1 and desk.available[0].id!="casting","native unfinished mode omits completed courses")
    check(model.history==before and model.pending.is_empty() and model.active.is_empty(),"reading and filtering grant no training result or reward")
    ui.free();level.free()
    print("PRACTICE_REVIEW checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
