extends SceneTree
const MODEL:=preload("res://scripts/thread_action_budget.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func fixture() -> Dictionary:
    return {"ok":true,"rows":[{"id":"thread","count":30,"maximum":99}],"uses":[{"id":"skill_needle","name":"已知线术","thread":8},{"id":"heal","name":"当前疗伤","thread":12},{"id":"recipe_hidden","name":"材料制作","currency":2}]}
func run() -> void:
    var source:=fixture();var original:=var_to_str(source)
    var result:=MODEL.preview(source,["skill_needle","skill_needle"],true)
    check(result.ok and result.supported and result.reserve==12 and result.remaining==2,"two known casts preserve separately reserved heal")
    check(result.required==28 and result.deficit==0,"shared resource cost is cumulative rather than independently affordable")
    result=MODEL.preview(source,["skill_needle","skill_needle","skill_needle"],true)
    check(not result.supported and result.first_short==2 and result.deficit==6,"first unsupported action and total deficit are explicit")
    check(result.rows[2].before==2 and result.rows[2].after==2,"unsupported action does not consume a fictional negative balance")
    result=MODEL.preview(source,["skill_needle","skill_needle","skill_needle","heal"],true)
    check(result.rows[3].state.contains("前序不足") and result.rows[3].after==2,"subsequent actions remain unevaluated after first shortfall")
    check(MODEL.preview(source,["heal","heal"],false).remaining==6,"repeated healing means separate repeated costs")
    check(MODEL.preview(source,[],false).required==0,"empty action plan reserves nothing by default")
    check(MODEL.preview(source,[],true).remaining==18,"empty plan may explicitly reserve one current heal")
    check(not MODEL.preview(source,["skill_unknown"],false).ok,"unknown actions cannot appear in a public budget")
    check(not MODEL.preview(source,["recipe_hidden"],false).ok,"material transactions never enter thread arithmetic")
    var eight: Array=[]
    for unused in MODEL.LIMIT:eight.append("skill_needle")
    check(MODEL.preview(source,eight,false).ok,"eight-item plan is supported as a bounded arithmetic request")
    eight.append("heal");check(not MODEL.preview(source,eight,false).ok,"ninth action is rejected without truncation")
    var bad:=fixture();bad.rows[0].count=true
    check(not MODEL.preview(bad,[],false).ok,"boolean balance is not a number")
    bad=fixture();bad.rows[0].count=-1
    check(not MODEL.preview(bad,[],false).ok,"negative energy is not clamped into a valid budget")
    bad=fixture();bad.rows[0].count=100
    check(not MODEL.preview(bad,[],false).ok,"energy above maximum is rejected")
    bad=fixture();bad.rows.append(bad.rows[0].duplicate())
    check(not MODEL.preview(bad,[],false).ok,"ambiguous thread balances cannot pick a convenient one")
    bad=fixture();bad.uses.append(bad.uses[0].duplicate())
    check(not MODEL.preview(bad,[],false).ok,"duplicate action identities cannot choose an arbitrary price")
    bad=fixture();bad.uses[0].thread=1.5
    check(not MODEL.catalog(bad).has("skill_needle"),"fractional action cost is not silently rounded")
    bad=fixture();bad.uses.remove_at(1)
    check(not MODEL.preview(bad,[],true).ok,"missing current heal quote refuses invented reservation")
    bad=fixture();bad.rows[0].count=3
    result=MODEL.preview(bad,["skill_needle"],true)
    check(result.reservation_short and not result.supported and result.remaining==0,"insufficient reservation is visible before casts")
    bad=fixture();bad.uses[0].thread=0
    check(MODEL.preview(bad,["skill_needle"],false).remaining==30,"known free action stays bounded but consumes no energy")
    result=MODEL.preview(source,["skill_needle"],false);result.rows[0].name="changed"
    check(var_to_str(source)==original,"every preview leaves report and public action names unchanged")
    check(MODEL.describe(MODEL.preview(source,["skill_needle"],true)).contains("不计击中取线"),"text discloses lack of incoming energy simulation")
    check(not MODEL.preview({"ok":false},[],false).ok,"invalid report has no public budget")
    print("THREAD_BUDGET checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
