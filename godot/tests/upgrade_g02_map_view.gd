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
    var view:=preload("res://scripts/survey_map_view.gd").new()
    var content:=Control.new();content.size=Vector2(800,600)
    view.content=content;view.size=Vector2(800,600);view.add_child(content);root.add_child(view)
    await process_frame
    view.set_view(0);view.magnify(2,Vector2(200,150))
    check(content.position.is_equal_approx(Vector2(-200,-150)),"zoom preserves cursor anchor")
    var expected:=content.position
    view.set_view(1)
    check(view.zoom==1.0 and content.position==Vector2.ZERO,"new view starts at overview")
    view.magnify(3);view.set_view(0)
    check(view.zoom==2.0 and content.position.is_equal_approx(expected),"regional view remembers independent focus")
    var pinch:=InputEventMagnifyGesture.new();pinch.factor=1.25;pinch.position=Vector2(200,150)
    view._gui_input(pinch)
    check(view.zoom==2.5,"trackpad pinch reaches real viewport")
    var editor:=LineEdit.new();root.add_child(editor);editor.grab_focus()
    await process_frame
    check(not view.navigation_available(),"text editor owns keyboard input")
    view.keyboard_pan=Vector2.ONE;view._process(0.1)
    check(view.keyboard_pan==Vector2.ZERO,"blocked navigation clears held keys")
    editor.release_focus();editor.queue_free()
    view.magnify(NAN);check(view.zoom==2.5,"invalid zoom is ignored")
    view.content.size=Vector2(50,50);view.clamp_pan()
    check(content.position.is_finite(),"small content does not invert clamp bounds")
    view.reset();check(view.zoom==1 and not view.view_memory.has(0),"reset erases current remembered view")
    for index in 20:view.set_view(index)
    check(view.view_memory.size()<=view.MAX_REMEMBERED_VIEWS,"view memory is bounded")
    view.queue_free();await process_frame
    print("UPGRADE_G02 checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
