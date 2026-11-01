extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_08 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const REVIEW:=preload("res://scripts/goal_watchlist_review.gd")
const MODEL:=preload("res://scripts/goal_desk_model.gd")
func run() -> void:
    var model:=MODEL.new();model.configure("goal_cleanup")
    model.state={"pins":["quest:a","quest:b","quest:hidden"],"notes":{"quest:a":"旧备注","quest:b":"保留","quest:hidden":"不可见"},"hud":true}
    var known: Array=[{"key":"quest:a","title":"已完成","complete":true,"entry":{}},{"key":"quest:b","title":"继续寻找","complete":false,"entry":{"steps":[{"label":"已走过","complete":true},{"label":"已公开的下一步","complete":false,"private_target":"SECRET"}]}}]
    var before:=model.state.duplicate(true)
    var hint:=REVIEW.next_hint(known[1])
    check(hint.contains("1/2") and hint.contains("下一步") and not hint.contains("SECRET"),"HUD uses public labels and completion count only")
    check(REVIEW.hud_lines(model.state,known).size()==4,"unknown tracked target is omitted without leaking private identity")
    var quote:=REVIEW.quote(model.state,known)
    check(quote.ok and quote.keys==["quest:a"],"only visible completed pin selected for retirement")
    check(quote.candidate.pins==["quest:b","quest:hidden"],"unfinished and unavailable pins preserved")
    check(not quote.candidate.notes.has("quest:a") and quote.candidate.notes["quest:b"]=="保留","only retired note removed")
    check(model.state==before,"preview never removes pin")
    check(not REVIEW.apply(model,known,"wrong").ok and model.state==before,"stale fingerprint cannot alter tracking")
    model.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    check(not REVIEW.apply(model,known,quote.fingerprint).ok and model.state==before,"failed write cannot publish cleanup")
    model.store.writer=Callable()
    check(REVIEW.apply(model,known,quote.fingerprint).ok,"confirmed cleanup writes actual auxiliary record")
    var restored:=MODEL.new();restored.configure("goal_cleanup")
    check(restored.state==model.state,"cleanup persists and reloads without affecting gameplay progress")
    check(not REVIEW.quote(model.state,known).ok,"repeat cleanup cannot remove remaining goals")
    var changing:=before.duplicate(true);changing.notes["quest:b"]="新备注"
    check(REVIEW.quote(changing,known).fingerprint!=quote.fingerprint,"note changes invalidate prior review")
    check(REVIEW.next_hint({"entry":{"guidance":"回钟龛"}})=="回钟龛","no unfinished steps falls back to public guidance")
    check(REVIEW.next_hint({}).contains("旅记"),"missing public steps have safe generic guidance")
    check(REVIEW.hud_lines({"pins":[]},known).is_empty(),"no pins produces no HUD rows")
    finish()
