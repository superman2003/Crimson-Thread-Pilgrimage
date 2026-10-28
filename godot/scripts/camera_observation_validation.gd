extends SceneTree
const POLICY:=preload("res://scripts/camera_observation_preferences.gd")
const FOCUS:=preload("res://scripts/camera_focus.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func run() -> void:
    check(POLICY.normalize({})==POLICY.DEFAULTS,"missing legacy preferences preserve defaults")
    var input:={"observation_mode":1,"observation_delay":0.6,"observation_distance":0.5,"foreign":true}
    var normalized:=POLICY.normalize(input)
    check(normalized.size()==3 and not normalized.has("foreign"),"explicit observation ownership")
    check(input.foreign and input.observation_delay==0.6,"normalization never changes caller")
    check(POLICY.strength({},0.0)==0.0,"legacy zero automatic retains original no observation")
    check(is_equal_approx(POLICY.strength({},0.25),0.25),"legacy scaled manual motion")
    check(POLICY.strength(input,0.0)==0.5,"independent observation survives zero automatic")
    check(POLICY.strength({"observation_mode":2},1.0)==0.0,"disabled manual never follows automatic")
    check(POLICY.strength({"observation_mode":1},NAN)==1.0,"independent preference handles bad automatic")
    check(POLICY.strength({},NAN)==0.0,"legacy nonfinite automatic cannot move camera")
    for value in [true,"1",null,NAN,INF,0.5,-1,3,{}]:
        check(POLICY.normalize({"observation_mode":value}).observation_mode==0,"invalid mode uses original rule")
    for value in [true,"0.5",null,NAN,INF,{}]:
        check(POLICY.normalize({"observation_delay":value,"observation_distance":value})==POLICY.DEFAULTS,"malformed scalar leaves safe default")
    check(POLICY.normalize({"observation_delay":-1.0,"observation_distance":4.0}).observation_delay==0.15,"delay lower bound")
    check(POLICY.normalize({"observation_delay":4.0,"observation_distance":-1.0}).observation_distance==0.25,"distance lower bound")
    check(POLICY.normalize({"observation_delay":4.0}).observation_delay==1.0,"delay upper bound")
    var stage:=Node2D.new();root.add_child(stage)
    var camera:=Camera2D.new();stage.add_child(camera)
    var focus:=FOCUS.new();check(focus.configure(camera,Rect2(0,0,4000,2400)),"real camera region configured")
    var zoom:=camera.zoom
    check(focus.update(camera,0.2,-1,true,1.0,0.6)==0,"custom delay waits")
    check(focus.update(camera,0.2,-1,true,1.0,0.6)==0,"second sample still waits")
    check(focus.update(camera,0.2,-1,true,1.0,0.6)==-150,"third sample starts bounded observation")
    check(focus.update(camera,0.2,1,true,0.5,0.6)==0,"changing direction resets wait")
    check(focus.update(camera,0.2,1,true,0.5,0.6)==0,"new direction waits independently")
    check(focus.update(camera,0.2,1,true,0.5,0.6)==75,"distance scaled without automatic motion")
    focus.push_lock("event",Rect2(0,0,2000,2000),10,false,true)
    check(focus.update(camera,1.0,1,true,1.0,0.15)==0,"event forbids custom downward look")
    check(focus.update(camera,1.0,-1,true,1.0,0.15)==-150,"event leaves allowed direction available")
    check(focus.update(camera,1.0,-1,false,1.0,0.15)==0,"airborne or menu eligibility always wins")
    focus.remove_lock("event")
    check(focus.update(camera,1.0,1,true,1.0,1.0)==150,"release event enables explicit next observation")
    check(focus.update(camera,1.0,0,true,1.0,0.15)==0,"neutral resets observation")
    check(focus.update(camera,1.0,-1,true,0.0,0.15)==0,"disabled mode cannot retain old offset")
    check(focus.update(camera,NAN,-1,true,1.0,NAN)==0,"nonfinite time cannot advance hold")
    check(camera.zoom==zoom and stage.position==Vector2.ZERO,"configuration preserves transform and zoom")
    stage.queue_free();await process_frame
    print("CAMERA_OBSERVATION checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
