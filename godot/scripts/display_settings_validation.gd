extends SceneTree
const MODEL:=preload("res://scripts/display_preferences.gd")
const DESK:=preload("res://scripts/display_dialog.gd")
var checks:=0
var failures:=0
var mode:=DisplayServer.WINDOW_MODE_WINDOWED
var mode_calls: Array[int]=[]
var vsync_calls: Array[bool]=[]
var cap_calls: Array[int]=[]
var assist_calls: Array[String]=[]
var written: Array[Dictionary]=[]
var refuse_write:=false
class Shell extends Control:
    var settings:=Control.new()
    func _ready() -> void:add_child(settings)
    func _button(parent: Node,text: String,point: Vector2,dimensions: Vector2,callback: Callable) -> Button:
        var button:=Button.new();button.text=text;button.position=point;button.size=dimensions
        parent.add_child(button);button.pressed.connect(callback);return button
    func register_text_entry_window(_window: Window) -> void:pass
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func fixture(saved: Dictionary={}):
    var model:=MODEL.new()
    model.window_mode=func():return mode
    model.set_window_mode=func(value: int):mode_calls.append(value);mode=value
    model.set_vsync=func(on: bool):vsync_calls.append(on)
    model.set_fps_cap=func(value: int):cap_calls.append(value)
    model.set_colour_assist=func(value: String):assist_calls.append(value)
    if not saved.is_empty():
        var seed:=preload("res://scripts/journey_desk_store.gd").new()
        seed.configure("display","installation");seed.write(saved)
    model.initialize()
    model.store.writer=func(data: Dictionary):
        if refuse_write:return ERR_FILE_CANT_WRITE
        written.append(data.duplicate(true));return OK
    return model
func clear() -> void:
    var store:=preload("res://scripts/journey_desk_store.gd").new()
    store.configure("display","installation")
    if FileAccess.file_exists(store.path):DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
    mode=DisplayServer.WINDOW_MODE_WINDOWED;mode_calls.clear();vsync_calls.clear();cap_calls.clear();assist_calls.clear();written.clear()
func run() -> void:
    for bad in [null,4,{},{"fullscreen":true,"vsync":true},{"fullscreen":1,"vsync":true,"fps_cap":60},
            {"fullscreen":true,"vsync":true,"fps_cap":45},{"fullscreen":true,"vsync":true,"fps_cap":60.5},
            {"fullscreen":true,"vsync":true,"fps_cap":"60"},{"fullscreen":true,"vsync":true,"fps_cap":60,"extra":1}]:
        check(not MODEL.valid(bad),"malformed display record rejected")
    check(MODEL.valid({"fullscreen":true,"vsync":false,"fps_cap":60.0}),"JSON numbers accepted for the cap")
    check(MODEL.clean({"fullscreen":true,"vsync":false,"fps_cap":60}).colour_assist=="off","a record from before the colour assist reads as off")
    for bad in [{"fullscreen":true,"vsync":true,"fps_cap":60,"colour_assist":"sepia"},{"fullscreen":true,"vsync":true,"fps_cap":60,"colour_assist":2}]:
        check(not MODEL.valid(bad),"unknown colour assist rejected")
    for good in MODEL.ASSISTS:
        check(MODEL.valid({"fullscreen":false,"vsync":true,"fps_cap":0,"colour_assist":good}),"colour assist accepted: "+good)
    clear()
    var model=fixture()
    check(mode_calls.is_empty() and vsync_calls.is_empty() and cap_calls.is_empty(),"first launch leaves the window untouched")
    check(model.values==MODEL.DEFAULTS,"defaults: windowed, vsync on, no cap")
    var result: Dictionary=model.change("fullscreen",true)
    check(result.ok and mode==DisplayServer.WINDOW_MODE_FULLSCREEN and mode_calls.size()==1,"fullscreen applies at once")
    check(written.size()==1 and written[0].payload.fullscreen==true,"change is saved")
    model.change("fps_cap",60)
    check(cap_calls.back()==60 and mode_calls.size()==1,"cap applies without touching an unchanged window mode")
    check(model.change("colour_assist","deutan").ok and assist_calls.back()=="deutan" and written.back().payload.colour_assist=="deutan","colour assist applies and is saved")
    check(not model.change("colour_assist","sepia").ok and assist_calls.back()=="deutan","unknown colour assist refused")
    model.change("vsync",false)
    check(vsync_calls.back()==false,"vsync applies")
    check(not model.change("fps_cap",45).ok and model.values.fps_cap==60 and cap_calls.back()==60,"unsupported cap refused")
    check(not model.change("brightness",1).ok,"unknown key refused")
    refuse_write=true
    result=model.change("fullscreen",false)
    check(not result.ok and result.get("applied",false) and mode==DisplayServer.WINDOW_MODE_WINDOWED,"failed save still applies and says so")
    refuse_write=false
    check(model.save().ok and not model.dirty,"retry saves the pending change")
    var calls:=mode_calls.size();model.initialize()
    check(mode_calls.size()==calls,"repeated initialize does not reapply")
    # A maximised window is not fullscreen and must not be forced back to a plain window.
    clear();mode=DisplayServer.WINDOW_MODE_MAXIMIZED
    model=fixture({"fullscreen":false,"vsync":true,"fps_cap":0})
    check(mode_calls.is_empty() and mode==DisplayServer.WINDOW_MODE_MAXIMIZED,"maximised window kept when fullscreen is off")
    clear()
    model=fixture({"fullscreen":true,"vsync":false,"fps_cap":120})
    check(mode==DisplayServer.WINDOW_MODE_FULLSCREEN and vsync_calls==[false] and cap_calls==[120],"saved choices restored at launch")
    clear()
    model=fixture({"fullscreen":true,"vsync":false,"fps_cap":999})
    check(mode_calls.is_empty() and model.values==MODEL.DEFAULTS and not model.store.writable,"invalid file ignored and preserved")
    check(not model.change("fullscreen",true).ok,"invalid file is never overwritten")
    clear()
    # Dialog: built on first open, mirrors the model, closes with the page.
    model=fixture()
    var shell:=Shell.new();root.add_child(shell);await process_frame
    var desk:=DESK.new();desk.name="DisplayDesk";shell.add_child(desk);desk.setup(shell,model)
    var launcher:=shell.settings.get_node("DisplaySettingsButton") as Button
    check(launcher!=null and launcher.text=="显示" and not is_instance_valid(desk.window),"launcher exists, window not built yet")
    launcher.pressed.emit();await process_frame
    check(is_instance_valid(desk.window) and desk.window.visible,"launcher opens the window")
    check(desk.cap.item_count==MODEL.CAPS.size() and desk.cap.get_item_text(0)=="不限","cap choices listed")
    check(desk.assist.item_count==MODEL.ASSISTS.size() and desk.assist.selected==0,"colour assist choices listed, off by default")
    desk.assist.select(1);desk.assist.item_selected.emit(1);await process_frame
    check(model.values.colour_assist=="protan" and assist_calls.back()=="protan","assist choice drives the model")
    desk.fullscreen.button_pressed=true;await process_frame
    check(model.values.fullscreen and mode==DisplayServer.WINDOW_MODE_FULLSCREEN,"toggle drives the model")
    desk.cap.select(2);desk.cap.item_selected.emit(2);await process_frame
    check(model.values.fps_cap==60 and desk.status.text=="显示设置已保存。","cap choice saved and reported")
    shell.settings.visible=false;await process_frame
    check(not desk.window.visible,"window closes with the settings page")
    var before:=mode_calls.size();desk.fullscreen.toggled.emit(false)
    check(mode_calls.size()==before,"hidden window cannot change the display")
    shell.queue_free();await process_frame
    clear()
    print("DISPLAY_SETTINGS checks=%d failures=%d" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
