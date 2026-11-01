extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    var model:=preload("res://scripts/stick_calibration.gd").new()
    model.start(7)
    for index in 32:model.sample(7,[0.12,-0.08,0.02,0.0],0.1)
    check(model.result.get("ok",false),"three seconds of neutral samples completes")
    check(is_equal_approx(model.result.get("deadzone",0.0),0.16),"recommendation covers peak plus margin")
    var original:=model.result.duplicate(true)
    model.sample(7,[1,1,1,1],0.1)
    check(model.result==original,"completed measurement stays immutable")
    model.start(7);model.sample(8,[0,0,0,0],0.1)
    check(not model.active and not model.result.ok,"device switch invalidates measurement")
    for bad in [[0,0,0],[NAN,0,0,0],[0.56,0,0,0],[true,0,0,0]]:
        model.start(7);model.sample(7,bad,0.1)
        check(not model.active and not model.result.ok,"invalid or pushed axis rejects sampling")
    model.start(7);model.sample(7,[0,0,0,0],0.5)
    check(not model.result.ok,"long frame cannot manufacture neutral duration")
    var dialog:=preload("res://scripts/controller_comfort_dialog.gd").new()
    root.add_child(dialog)
    dialog.open({},func(_value):return {"ok":true})
    await process_frame
    # Mirror _start_measurement: the dialog only accepts its own measurement round.
    dialog.calibration.start(7);dialog.measurement_session=dialog.calibration.session
    for index in 32:dialog.calibration.sample(7,[0.12,0,0,0],0.1)
    dialog.device_picker.add_item("fixture");dialog.device_picker.set_item_metadata(0,7);dialog.device_picker.select(0)
    var before: Dictionary=dialog.baseline.duplicate(true)
    dialog._stage_measurement()
    check(dialog.candidate.controller_deadzone==0.16 and dialog.baseline==before,"recommendation only stages candidate")
    await capture("calibration")
    dialog.hide()
    check(not dialog.calibration.active and not dialog.calibration.result.ok,"closing discards measurement")
    dialog.queue_free()
    await process_frame
    print("UPGRADE_G01 checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func capture(label: String) -> void:
    var directory:=OS.get_environment("UPGRADE_CAPTURE_DIR")
    if directory.is_empty() or DisplayServer.get_name()=="headless":return
    DirAccess.make_dir_recursive_absolute(directory)
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(directory.path_join(label+".png"))
