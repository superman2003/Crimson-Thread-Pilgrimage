extends SceneTree
const BRIDGE:=preload("res://scripts/itinerary_handoff.gd")
const PLAN:=preload("res://scripts/expedition_plan.gd")
const DOMAIN:=preload("res://journey/fieldwork/itinerary/model.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func fixture(count: int=4) -> Dictionary:
    var graph:={"nodes":[],"edges":[],"source":"a0","region":"fixture","include_blocked":false,"undirected":false}
    var known: Array=[]
    for index in count:
        var id:="a"+str(index)
        graph.nodes.append({"id":id,"name":"untrusted candidate label","kind":"room","point":[index*100,0]})
        known.append({"key":"room:fixture:"+id,"room_id":id,"kind":"room","region":"fixture","region_name":"Known region","title":"Public room "+str(index)})
        if index>0:
            graph.edges.append({"from":"a"+str(index-1),"to":id,"open":true,"reason":"known"})
            graph.edges.append({"from":id,"to":"a"+str(index-1),"open":true,"reason":"known"})
    return {"known":known,"payload":{"graph":graph,"start":"a0","stops":["a3","a1","a2"],"return":false,"speed":250.0,"dwell":20.0,"budget":600.0,"method":"exact","skip_unreachable":false}}
func run() -> void:
    var f:=fixture();var plan:=PLAN.new();plan.configure("handoff-native")
    check(DOMAIN.validate(f.payload),"actual analysis domain accepts native fixture")
    check(plan.command("add",f.known[1].key,f.known).ok,"original route command persists baseline")
    check(plan.command("done",f.known[1].key,f.known).ok,"baseline carries checked progress")
    var before:=plan.state.duplicate(true);var bytes:=FileAccess.get_file_as_bytes(plan.store.path)
    var view:=BRIDGE.quote(f.payload,f.known,plan,"fixture","slot-a")
    check(view.ok and view.candidate.stops==[f.known[1].key,f.known[2].key,f.known[3].key],"adopts actual solver order rather than requested order")
    check(not view.candidate.active and view.candidate.done.is_empty() and view.candidate.deferred.is_empty(),"replacement pauses and resets local progress")
    check(plan.state==before and FileAccess.get_file_as_bytes(plan.store.path)==bytes,"quote cannot modify route or file")
    check(not BRIDGE.describe(view).contains("untrusted") and BRIDGE.describe(view).contains("Public room"),"preview trusts live directory names not imported labels")
    check(not BRIDGE.describe(view).contains("room:fixture"),"preview does not expose internal route keys")
    var unknown: Array=f.known.slice(0,2)
    var hidden:=BRIDGE.quote(f.payload,unknown,plan,"fixture","slot-a")
    check(not hidden.ok and not BRIDGE.describe(hidden).contains("a3"),"unmapped target is rejected without disclosing raw ID")
    check(not BRIDGE.quote(f.payload,f.known,plan,"other","slot-a").ok,"cross-region candidate rejected")
    check(not BRIDGE.quote({},f.known,plan,"fixture","slot-a").ok,"malformed record rejected before solver")
    var invalid: Dictionary=f.payload.duplicate(true);invalid.speed=NAN
    check(not BRIDGE.quote(invalid,f.known,plan,"fixture","slot-a").ok,"invalid analysis scalar rejected")
    var too_many:=fixture(8);too_many.payload.stops=["a1","a2","a3","a4","a5","a6","a7"]
    check(not BRIDGE.quote(too_many.payload,too_many.known,plan,"fixture","slot-a").ok,"actual HUD limit enforced without silently dropping seventh target")
    too_many.payload.stops.pop_back();too_many.payload["return"]=true
    check(not BRIDGE.quote(too_many.payload,too_many.known,plan,"fixture","slot-a").ok,"return leg also consumes a real slot")
    var returned: Dictionary=f.payload.duplicate(true);returned["return"]=true
    var return_view:=BRIDGE.quote(returned,f.known,plan,"fixture","slot-a")
    check(return_view.ok and return_view.candidate.stops[-1]==f.known[0].key,"explicit return home becomes final unique stop")
    check(not BRIDGE.quote(returned,f.known.slice(1),plan,"fixture","slot-a").ok,"return home requires mapped source")
    var empty: Dictionary=f.payload.duplicate(true);empty.stops=[]
    check(not BRIDGE.quote(empty,f.known,plan,"fixture","slot-a").ok,"empty schedule cannot erase current route")
    var broken: Dictionary=f.payload.duplicate(true);broken.graph.edges=[]
    check(not BRIDGE.quote(broken,f.known,plan,"fixture","slot-a").ok,"unreachable solution cannot replace existing route")
    var changed:=view.duplicate(true);changed.candidate.stops.reverse()
    check(not BRIDGE.apply(f.payload,f.known,plan,"fixture","slot-a",changed).ok and plan.state==before,"forged pending order rejected")
    check(not BRIDGE.apply(f.payload,f.known,plan,"fixture","slot-b",view).ok,"changed slot invalidates confirmation")
    check(plan.command("reset","",f.known).ok,"original planner may change while preview is open")
    check(not BRIDGE.apply(f.payload,f.known,plan,"fixture","slot-a",view).ok,"changed live route invalidates pending handoff")
    view=BRIDGE.quote(f.payload,f.known,plan,"fixture","slot-a");before=plan.state.duplicate(true);bytes=FileAccess.get_file_as_bytes(plan.store.path)
    plan.store.writer=func(_data: Dictionary):return ERR_CANT_CREATE
    check(not BRIDGE.apply(f.payload,f.known,plan,"fixture","slot-a",view).ok,"injected persistence failure reaches caller")
    check(plan.state==before and FileAccess.get_file_as_bytes(plan.store.path)==bytes,"failed save preserves actual bytes and published route")
    plan.store.writer=Callable()
    var lock:=ProjectSettings.globalize_path(plan.store.path+".route_writer_lock")
    DirAccess.make_dir_absolute(lock)
    check(not BRIDGE.apply(f.payload,f.known,plan,"fixture","slot-a",view).ok and plan.state==before,"busy canonical route writer retains pending state")
    DirAccess.remove_absolute(lock)
    var rival:=PLAN.new();rival.configure("handoff-native")
    check(rival.command("add",f.known[2].key,f.known).ok,"separate instance publishes new canonical state")
    check(not BRIDGE.apply(f.payload,f.known,plan,"fixture","slot-a",view).ok,"stale instance cannot overwrite changed disk route")
    check(FileAccess.get_file_as_bytes(plan.store.path)!=bytes and plan.state==before,"external update remains intact after stale refusal")
    plan.configure("handoff-native");view=BRIDGE.quote(f.payload,f.known,plan,"fixture","slot-a")
    check(BRIDGE.apply(f.payload,f.known,plan,"fixture","slot-a",view).ok,"fresh reconfirmed handoff commits once")
    var loaded:=PLAN.new();loaded.configure("handoff-native")
    check(loaded.state==plan.state and loaded.state==view.candidate,"fresh process model restores exact adopted paused order")
    check(not BRIDGE.apply(f.payload,f.known,plan,"fixture","slot-a",view).ok,"old confirmation is consumed by route revision")
    check(plan.command("start","",f.known).ok and plan.next_stop(f.known).key==f.known[1].key,"original HUD start and next-stop behavior preserved")
    print("ITINERARY_HANDOFF checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
