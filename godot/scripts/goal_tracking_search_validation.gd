extends SceneTree
const MODEL := preload("res://scripts/goal_desk_model.gd")
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(text)
func keys(rows: Array) -> Array:return rows.map(func(row):return row.key)
func run() -> void:
    var model:=MODEL.new();model.configure("tracking_search")
    var rows: Array=[{"key":"quest:a","title":"修复泵房","text":"寻找铜管","complete":false,"entry":{"secret":"未来镜塔"}},
        {"key":"quest:b","title":"归还姓名","text":"交还名牌","complete":true},
        {"key":"main:c","title":"抵达钟龛","text":"安坐并补绘","complete":false}]
    var snapshot:=rows.duplicate(true)
    check(MODEL.filter_rows(rows,"",3,model.state).is_empty(),"tracked-only mode starts empty")
    check(model.change("pin","quest:a",rows).ok and model.change("pin","quest:b",rows).ok,"known goals can be tracked")
    check(model.change("note","quest:a",rows,"先到 COPPER 旧桥").ok,"current-save note is persisted")
    check(keys(MODEL.filter_rows(rows,"",3,model.state))==["quest:a","quest:b"],"tracked-only mode includes both unfinished and completed tracked goals")
    check(keys(MODEL.filter_rows(rows,"copper",3,model.state))==["quest:a"],"personal notes participate in case-insensitive tracked search")
    check(keys(MODEL.filter_rows(rows,"泵房 copper",0,model.state))==["quest:a"],"search tokens may span disclosed objective text and personal note")
    check(keys(MODEL.filter_rows(rows,"",1,model.state))==["quest:a","main:c"] and keys(MODEL.filter_rows(rows,"",2,model.state))==["quest:b"],"existing completion modes remain independent of tracking")
    check(MODEL.filter_rows(rows,"未来镜塔",0,model.state).is_empty(),"hidden backing record fields never enter search")
    var before:=model.state.duplicate(true)
    MODEL.filter_rows(rows,"copper",3,model.state)
    check(model.state==before and rows==snapshot,"search changes neither preferences nor story records")
    var restored:=MODEL.new();restored.configure("tracking_search")
    check(keys(MODEL.filter_rows(rows,"旧桥",3,restored.state))==["quest:a"],"real disk reload restores searchable notes")
    var other:=MODEL.new();other.configure("another_save")
    check(MODEL.filter_rows(rows,"旧桥",0,other.state).is_empty(),"another save cannot search this save's notes")
    check(model.change("remove","quest:a",rows).ok and MODEL.filter_rows(rows,"copper",0,model.state).is_empty(),"untracking removes that note from search")
    var untrusted: Dictionary={"pins":["quest:b"],"notes":{"quest:a":"stale hidden note","quest:b":false,"main:c":"untracked note"}}
    check(MODEL.filter_rows(rows,"stale",0,untrusted).is_empty() and MODEL.filter_rows(rows,"untracked",0,untrusted).is_empty(),"untracked stale notes never become search results")
    check(MODEL.filter_rows(rows,"",3,{"pins":true,"notes":[]}).is_empty(),"malformed preference containers safely produce no tracked rows")
    before=model.state.duplicate(true);model.store.writer=func(_data):return ERR_CANT_CREATE
    check(not model.change("pin","main:c",rows).ok and model.state==before,"failed tracking save cannot affect filtering")
    check(MODEL.filter_rows(rows,"copper",0).is_empty(),"legacy three-argument callers do not inherit another model's notes")
    print("GOAL_TRACKING_SEARCH checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
