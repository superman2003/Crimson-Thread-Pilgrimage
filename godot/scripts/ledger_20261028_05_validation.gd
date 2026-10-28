extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_05 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const PLAN:=preload("res://scripts/exchange_stock_plan.gd")
var affordable:=4
var calls: Array=[]
func quote(amount: int) -> Dictionary:
    calls.append(amount)
    return {"ok":amount<=affordable,"reason":"材料不足","counts":{"in":20-amount*3,"out":2+amount},"money":100-amount*8}
func run() -> void:
    var result:=PLAN.plan(2,5,1,quote)
    check(result.ok and result.amount==3 and result.after==5,"choose only the deficit rather than maximum affordable")
    check(result.shortfall==0 and result.surplus==0,"exact target has no shortage or surplus")
    check(PLAN.plan(2,20,1,quote).amount==4,"limited wallet returns affordable partial amount")
    check(PLAN.plan(2,20,1,quote).shortfall==14,"partial result exposes unmet stock target")
    affordable=20
    check(PLAN.plan(0,100,1,quote).amount==10,"per-operation ten-batch bound retained")
    var overshoot:=PLAN.plan(0,5,2,quote)
    check(overshoot.amount==3 and overshoot.surplus==1,"indivisible output gain rounds up and explains surplus")
    calls.clear();check(not PLAN.plan(5,5,1,quote).ok and calls.is_empty(),"satisfied target performs no quote or payment")
    check(PLAN.plan(5,3,1,quote).satisfied,"over-target inventory needs no exchange")
    for invalid in [true,-1,0.5,NAN,INF,1000000]:check(not PLAN.plan(invalid,5,1,quote).ok,"invalid inventory rejected")
    check(not PLAN.plan(0,5,0,quote).ok,"zero output gain rejected")
    affordable=0
    check(not PLAN.plan(0,5,1,quote).ok,"unaffordable plan stays non-actionable")
    affordable=4
    var before: Dictionary={"in":20,"out":2};var saved:=before.duplicate(true)
    var receipt:=PLAN.balance({"input":"in","output":"out"},before,100,quote(3),func(id: String):return "源材料" if id=="in" else "目标材料")
    check(receipt.contains("20 → 11") and receipt.contains("2 → 5") and receipt.contains("100 → 76"),"receipt uses canonical post-trade quantities")
    check(before==saved,"balance report never pays resources")
    check(PLAN.balance({},before,100,{"ok":false},Callable()).contains("暂不可"),"invalid receipt not invented")
    finish()
