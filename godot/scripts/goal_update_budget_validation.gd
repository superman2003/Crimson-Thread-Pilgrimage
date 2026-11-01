extends SceneTree
const BUDGET:=preload("res://scripts/goal_update_budget.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func run() -> void:
    var model:=BUDGET.new()
    check(not model.active and model.elapsed==0,"new consumer has no pending read debt")
    var calls:=0
    for unused in 120:
        if model.advance(0.5,false,false):calls+=1
    check(calls==0 and not model.active,"long hidden disabled periods issue no reads")
    check(model.advance(0,true,false),"visible workbench wakes immediately even with HUD off")
    check(not model.advance(0.2,true,false),"same consumer does not reread before half-second budget")
    check(model.advance(0.3,true,false),"visible workbench retains original half-second refresh bound")
    check(not model.advance(0,false,false) and not model.active,"suspension clears periodic active state")
    check(model.advance(0,false,true),"visible pinned HUD wakes without waiting for discarded idle time")
    model.observed()
    check(not model.advance(0.25,true,true),"explicit refresh resets next periodic read")
    check(model.advance(0.25,true,true),"two simultaneous consumers share one due read")
    model.observed()
    check(not model.advance(-1,true,true) and not model.advance(NAN,true,true) and not model.advance(INF,true,true),"invalid deltas do not advance a read or poison clock")
    check(model.elapsed==0 and model.advance(0.5,true,true),"valid time still works after rejected input")
    model.observed()
    check(model.advance(1000000,true,true),"long application stall permits one current read")
    check(not model.advance(0,true,true),"large delta does not accumulate a burst of catch-up evaluations")
    model.observed();calls=0
    for unused in 100:
        if model.advance(0.1,true,true):calls+=1
    check(calls==20,"active consumers share a bounded steady cadence")
    model.reset()
    check(not model.active and model.elapsed==0,"retirement resets all schedule state")
    check(not model.advance(0.5,false,false),"retired inactive consumer remains dormant")
    check(model.advance(0,false,true),"a newly restored live consumer gets fresh state")
    print("GOAL_UPDATE_BUDGET checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
