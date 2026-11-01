extends SceneTree
const MEASURE=preload("res://scripts/stick_calibration.gd")
const DIALOG=preload("res://scripts/controller_comfort_dialog.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func finish_measurement(model: RefCounted) -> void:
    for unused in 31:model.sample(2,[.12,.0,.0,.0],.1)
func run() -> void:
    var model:=MEASURE.new();model.start(2);var session:int=model.session
    finish_measurement(model)
    check(model.result.ok and model.recommendation(2,session).deadzone>=.16,"native measurement recommended")
    check(model.recommendation(1,session).is_empty(),"other device cannot consume")
    model.start(2)
    check(model.recommendation(2,session).is_empty(),"old generation cannot consume")
    finish_measurement(model)
    check(model.recommendation(2,session).is_empty(),"old quote still rejected after new completion")
    check(not model.recommendation(2,model.session).is_empty(),"current generation usable")
    model.cancel("focus")
    check(model.recommendation(2,model.session).is_empty(),"cancel clears completed suggestion")
    model.start(2);model.sample(3,[0,0,0,0],.1)
    check(not model.active and not model.result.ok,"different source cancels measurement")
    model.start(2);model.sample(2,[0,0,0,0],.5)
    check(not model.active,"long interruption cancels")
    var dialog:=DIALOG.new();root.add_child(dialog)
    dialog.calibration.start(2);finish_measurement(dialog.calibration)
    dialog.measurement_session=dialog.calibration.session
    dialog.stage_button.disabled=false
    dialog._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(not dialog.calibration.result.ok and dialog.stage_button.disabled,"real dialog focus loss clears suggestion")
    dialog.calibration.start(2);finish_measurement(dialog.calibration)
    dialog._connection_changed(2,true)
    check(not dialog.calibration.result.ok,"same id reconnect invalidates completed suggestion")
    dialog.calibration.start(2);dialog._connection_changed(2,false)
    check(not dialog.calibration.active,"active disconnect cancelled")
    dialog.free()
    print("RELIABILITY_R04 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
