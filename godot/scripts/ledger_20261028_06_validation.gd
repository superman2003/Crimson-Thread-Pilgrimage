extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_06 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const PLAN:=preload("res://scripts/craft_dependency_plan.gd")
func recipe(name: String, prerequisites: Array=[], artisan: String="smith") -> Dictionary:return {"name":name,"requires_crafted":prerequisites,"artisan":artisan}
func run() -> void:
    var recipes: Dictionary={"a":recipe("底扣"),"b":recipe("承力扣",["a"]),"c":recipe("加固扣",["b"]),"d":recipe("第二件",["a"])}
    var original:=recipes.duplicate(true)
    var result:=PLAN.plan(recipes,[],["c","d"],"smith")
    check(result.ok and result.total==4 and result.batches.size()==3,"shared prerequisite deduplicated and chain divided into stages")
    check(result.batches[0].ids==["a"],"first cart contains only actually eligible base dependency")
    check(result.batches[1].ids.has("b") and result.batches[1].ids.has("d"),"independent ready children share later cart")
    check(result.batches[2].ids==["c"],"child never batched with unfinished parent")
    check(PLAN.plan(recipes,["a"],["c"],"smith").batches[0].ids==["b"],"already crafted prerequisite skipped")
    check(not PLAN.plan(recipes,["a","b","c"],["c"],"smith").ok,"fully completed target does not create redundant cart")
    check(not PLAN.plan(recipes,[],["c","c"],"smith").ok,"duplicate requests rejected")
    recipes.a.requires_crafted=["c"]
    check(not PLAN.plan(recipes,[],["c"],"smith").ok,"cycle rejected without editing recipe graph")
    recipes=original.duplicate(true);recipes.a.artisan="other"
    check(not PLAN.plan(recipes,[],["c"],"smith").ok,"unmade prerequisite at another artisan blocks auto-plan")
    check(PLAN.plan(recipes,["a"],["c"],"smith").ok,"completed remote prerequisite does not block plan")
    recipes=original.duplicate(true);recipes.b.requires_crafted=["unknown"]
    check(not PLAN.plan(recipes,[],["c"],"smith").ok,"unknown dependency rejected")
    check(not PLAN.plan(original,[],[],"smith").ok,"empty goals rejected")
    var wide: Dictionary={};var parents: Array=[]
    for i in 10:wide[str(i)]=recipe(str(i));parents.append(str(i))
    wide["final"]=recipe("末阶",parents)
    var big:=PLAN.plan(wide,[],["final"],"smith")
    check(big.ok and big.batches.size()==3,"more than eight prerequisites split into legal carts")
    check(big.batches.all(func(batch):return batch.ids.size()<=8),"every staged cart obeys live cart limit")
    check(big.batches[-1].ids==["final"],"final remains after both prerequisite carts")
    var description:=PLAN.describe(result)
    check(description.contains("尚未制作") and description.contains("单独核价"),"preview explains future transactions")
    check(original.a.requires_crafted.is_empty(),"planner never changes actual crafting progress")
    var changed:=PLAN.plan(original,["a"],["c","d"],"smith")
    check(changed.fingerprint!=result.fingerprint,"craft completion invalidates old plan selection")
    finish()
