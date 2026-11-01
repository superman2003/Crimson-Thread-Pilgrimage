extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func finish() -> void:
    print("LEDGER_20261028_03 checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)

const REVIEW:=preload("res://scripts/expedition_route_review.gd")
const PLAN:=preload("res://scripts/expedition_plan.gd")
func run() -> void:
    var rows: Array=[{"key":"room:r:a","title":"甲","region":"r","region_name":"庭","room_id":"a"},{"key":"room:r:b","title":"乙","region":"r","region_name":"庭","room_id":"b"},{"key":"room:s:c","title":"丙","region":"s","region_name":"渠","room_id":"c"}]
    var state: Dictionary={"stops":["room:r:a","room:r:b","room:s:c"],"done":[],"deferred":[]}
    var config: Dictionary={"connections":[{"from":"origin","to":"a","bidirectional":false},{"from":"a","to":"b","required_ability":"dash"}],"locked_gates":[]}
    var route:=func(a: String,b: String):return PLAN.path(config,["origin","a","b"],a,b,{"dash":1},{})
    var before:=state.duplicate(true)
    var legs:=REVIEW.collect(state,rows,"r","origin",true,route)
    check(legs.size()==3 and legs[0].rooms==["origin","a"],"first leg uses known current-room path")
    check(legs[1].rooms==["a","b"],"second leg begins at previous planned stop")
    check(legs[2].kind=="cross_region","cross-region gap is explicit")
    var no_position:=REVIEW.collect(state,rows,"r","origin",false,route)
    check(no_position[0].kind=="no_origin" and no_position[1].kind=="known_chain","without compass hide live origin but keep known-stop leg")
    var blocked:=func(a: String,b: String):return PLAN.path(config,["origin","a","b"],a,b,{}, {})
    check(REVIEW.collect(state,rows,"r","origin",true,blocked)[1].kind=="no_chain","real ability requirement blocks itinerary leg")
    check(PLAN.path(config,["origin","a","b"],"a","origin",{"dash":1},{}).is_empty(),"one-way route stays one-way")
    state.deferred=["room:r:a"]
    check(REVIEW.collect(state,rows,"r","origin",true,route)[1].kind=="known_chain","deferred station is skipped as an origin")
    state.stops=["room:r:secret","room:r:b"];state.deferred=[]
    var unknown:=REVIEW.collect(state,rows,"r","origin",true,route)
    check(unknown[0].kind=="unavailable" and unknown[1].kind=="no_origin","invisible stop breaks origin chain")
    var text:=REVIEW.describe(unknown,{"a":"甲","b":"乙","origin":"起点"})
    check(not text.contains("secret") and not text.contains("room:r"),"invisible identities never enter public report")
    check(REVIEW.describe([],{}).contains("尚无站点"),"empty itinerary explains next action")
    check(before.stops.size()==3 and rows[0].title=="甲","planning inputs detached")
    var distant:=REVIEW.collect({"stops":["room:s:c","room:s:d"]},rows+[{"key":"room:s:d","title":"丁","region":"s","region_name":"渠","room_id":"d"}],"r","origin",true,route)
    check(distant[1].kind=="other_region","other-region interior not inferred from current config")
    config.connections[1]["shortcut_id"]="lever"
    check(REVIEW.collect(before,rows,"r","origin",true,route)[1].kind=="no_chain","closed shortcut blocks route")
    config.connections[1].erase("shortcut_id");config.connections[1]["required_flag"]="story"
    check(REVIEW.collect(before,rows,"r","origin",true,route)[1].kind=="no_chain","story-conditioned edge stays conservative")
    config.connections[1].erase("required_flag")
    var partial:=func(a: String,b: String):return PLAN.path(config,["origin","a"],a,b,{"dash":1},{})
    check(REVIEW.collect(before,rows,"r","origin",true,partial)[1].kind=="no_chain","partially charted target cannot enter path callback graph")
    finish()
