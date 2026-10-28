extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_02 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const REVIEW:=preload("res://scripts/practice_attempt_review.gd")
const CURRICULUM:=preload("res://scripts/practice_curriculum.gd")
func run() -> void:
    var model:=CURRICULUM.new();model.configure("split_review")
    model.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    check(model.start("thread_dash",{"thread_dash":1}).ok,"earned actual course starts")
    model.tick(0.5)
    check(not model.accept("other",1),"unrelated action rejected")
    check(model.accept("thread_dash",1),"first accepted action advances actual stage")
    check(not model.accept("thread_dash",1),"duplicate physics frame cannot fill next stage")
    model.tick(0.75);model.accept("thread_dash",2)
    model.finish(false,"离开练习范围")
    check(model.history.is_empty() and not model.pending.is_empty(),"write failure retains pending attempt without publication")
    var stages: Array=model.pending.stages
    check(stages.size()==2 and stages[0].accepted==1 and stages[1].accepted==1,"failed attempt preserves completed and partial steps")
    check(stages[0].seconds==0.5 and stages[1].seconds==0.75,"time attributed to active stage")
    check(not model.pending.complete,"partial course never reported completed")
    check(REVIEW.describe(model.pending).contains("已完成1/2步"),"review distinguishes completed stage from partial count")
    model.store.writer=Callable();check(model.retry(),"actual auxiliary write can be retried")
    var restored:=CURRICULUM.new();restored.configure("split_review")
    check(restored.history[0].stages==stages,"disk reload restores split details")
    restored.configure("split_review")
    check(restored.history.size()==1,"reconfiguration does not duplicate attempts")
    check(REVIEW.restore({}).is_empty() and REVIEW.describe({}).contains("旧记录"),"legacy record gets no invented stage progress")
    for invalid in [true,-1,1.5,NAN,INF]:
        check(REVIEW.restore({"stages":[{"label":"a","required":2,"accepted":invalid,"seconds":0.0}]}).is_empty(),"invalid accepted count rejected")
    check(REVIEW.restore({"stages":[{"label":"a","required":2,"accepted":3,"seconds":0.0}]}).is_empty(),"accepted count cannot exceed requirement")
    var before:=restored.history.duplicate(true)
    check(REVIEW.summary(restored.history,"thread_dash").contains("完成0次"),"failure does not affect completion time stats")
    check(REVIEW.summary(restored.history,"unknown").contains("暂无"),"unknown course has no imported history")
    check(restored.history==before,"review never changes stored attempt")
    var success:=CURRICULUM.new();success.configure("split_success")
    success.start("thread_dash",{"thread_dash":1});success.tick(0.25)
    success.accept("thread_dash",1);success.tick(0.5);success.accept("thread_dash",2);success.accept("thread_dash",3)
    check(success.history.size()==1 and success.history[0].complete,"real final accepted action completes course")
    check(success.history[0].stages.all(func(stage):return stage.accepted==stage.required),"completed attempt contains all stage counts")
    finish()
