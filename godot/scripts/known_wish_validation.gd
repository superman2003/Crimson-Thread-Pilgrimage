extends SceneTree
const MODEL:=preload("res://scripts/known_wish_manifest.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func config() -> Dictionary:
    return {"id":"visited_region","name":"已到地区","npcs":[{"id":"person_a","name":"已询问人物","position":[9876,5432],"private_note":"secret_gate","dialogue_topics":{"quest":{"item":"token","accept_flag":"asked_a","complete_flag":"done_a","consume":false,"reward":"unknown_reward"}}},{"id":"person_b","name":"另一个人物","dialogue_topics":{"quest":{"item":"token","accept_flag":"asked_b","complete_flag":"done_b","consume":true}}}]}
func collect(data: Dictionary,stock: Dictionary,flags: Dictionary) -> Dictionary:
    return MODEL.collect([data],stock,flags,func(_id: String):return "已询问信物")
func run() -> void:
    var data:=config();var stock:={"token":1};var flags:={"asked_a":true}
    var original:=var_to_str([data,stock,flags])
    var report:=collect(data,stock,flags)
    check(report.ok and report.rows.size()==1 and report.rows[0].npc=="已询问人物","asked gate projects only known person's request")
    check(not var_to_str(report).contains("secret_gate") and not var_to_str(report).contains("9876") and not var_to_str(report).contains("unknown_reward"),"public rows omit private notes coordinates and undisclosed reward")
    check(collect(data,stock,{}).rows.is_empty(),"unasked NPC requests stay undisclosed")
    check(collect(data,stock,{"asked_a":"true"}).rows.is_empty(),"truthy string is not accepted knowledge")
    check(collect(data,stock,{"done_b":true}).rows[0].complete,"completed request is known even if older accept flag is absent")
    check(report.rows[0].ready and report.rows[0].stock==1 and not report.rows[0].consume,"show-only request preserves its requirement semantics")
    var both:=collect(data,stock,{"asked_a":true,"asked_b":true})
    var amounts:=MODEL.requirements(both.rows)
    check(amounts.size()==1 and amounts[0].consume==1 and amounts[0].show==1,"shared item requirements distinguish showing and consuming")
    check(amounts[0].required==1 and amounts[0].deficit==0,"show-first then consume can reuse one held token")
    amounts=MODEL.requirements(both.rows,true)
    check(amounts[0].required==2 and amounts[0].deficit==1,"explicit preserved proof reserves an additional item")
    var completed:=collect(data,stock,{"asked_a":true,"asked_b":true,"done_b":true})
    check(MODEL.requirements(completed.rows)[0].consume==0,"already completed consumption is never charged again")
    check(MODEL.browse(completed).size()==1 and MODEL.browse(completed,"",3).size()==1,"pending and complete filters have distinct rows")
    check(MODEL.browse(both,"已询问人物 信物",1).size()==1,"public multi-token ready filter searches person and item labels")
    check(MODEL.browse(both,"person_a").is_empty() and MODEL.browse(both,"secret_gate").is_empty(),"private identities and notes cannot drive public search")
    check(MODEL.browse(both,"",0,"elsewhere").is_empty(),"region filter cannot cross its selected known scope")
    var detached:=MODEL.browse(both);detached[0].npc="changed"
    check(both.rows[0].npc!="changed","filtered rows cannot mutate canonical projection")
    var invalid:=collect(data,{"token":true},flags)
    check(not invalid.rows[0].stock_valid and not invalid.rows[0].ready,"boolean stock is unknown rather than one")
    check(MODEL.requirements(invalid.rows)[0].deficit==-1,"invalid stock never invents a numeric shortfall")
    check(MODEL.detail(invalid.rows[0]).contains("暂不可读取"),"invalid stock has explicit readable feedback")
    check(MODEL.browse(collect(data,{},flags),"",2).size()==1,"zero held items remain visible as a pending missing requirement")
    check(not collect(data,{"token":-1},flags).rows[0].stock_valid,"negative stock is rejected")
    check(not collect(data,{"token":1.5},flags).rows[0].stock_valid,"fractional stock is not a delivery token")
    var malformed:=config();malformed.npcs[0].dialogue_topics.quest.consume=1
    check(not collect(malformed,stock,flags).ok,"malformed consume policy refuses a partial known manifest")
    malformed=config();malformed.npcs.append(malformed.npcs[0].duplicate(true))
    check(not collect(malformed,stock,flags).ok,"duplicate known NPC record cannot double a requirement")
    var unnamed:=MODEL.collect([data],stock,flags,Callable())
    check(unnamed.rows[0].item_name=="已询问的信物","missing name resolver never exposes a private item key")
    check(MODEL.totals(both.rows,false).contains("先出示后消耗"),"aggregate text states its ordering assumption")
    check(MODEL.totals(both.rows,true).contains("另留一份"),"preservation option has explicit text")
    check(MODEL.requirements([]).is_empty() and MODEL.totals([],false).contains("没有未完成"),"empty visible scope does not claim undiscovered requirements")
    var excessive:=config();excessive.npcs=[]
    for index in MODEL.MAX_ROWS+1:
        var copy: Dictionary=data.npcs[0].duplicate(true);copy.id="person_"+str(index);excessive.npcs.append(copy)
    check(not collect(excessive,stock,flags).ok,"over-cap known requests reject rather than present a truncated complete manifest")
    check(MODEL.collect([data],stock,flags,func(id: String):return id).rows[0].item_name=="已询问的信物","a raw item ID fallback cannot leak into readable labels")
    check(var_to_str([data,stock,flags])==original,"all projections and budgets preserve source inventory flags and authored data")
    print("KNOWN_WISH checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
