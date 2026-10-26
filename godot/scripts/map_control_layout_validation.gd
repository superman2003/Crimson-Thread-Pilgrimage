extends SceneTree
const LAYOUT:=preload("res://scripts/map_control_layout.gd")
const PINS:=preload("res://scripts/map_player_pins_runtime.gd")
const VIEW:=preload("res://scripts/survey_map_view.gd")
const UI:=preload("res://scripts/pilgrimage_interface.gd")
const COORD:=preload("res://scripts/world_coordinates.gd")
var checks:=0
var failures:=0

class Runtime extends Node:
    var world_mode:=true
    var world_loading:=false
    var active_overlay:="map"
    var ui_shell: Control
    var map_panel: ColorRect
    var survey_map_view: Control
    var map_draw_root: Control
    var map_text: Label
    var story_flags: Dictionary={}
    var notices: Array[String]=[]
    func _toast(message: String) -> void:notices.append(message)

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func make_runtime() -> Node:
    var world:=Runtime.new()
    root.add_child(world)
    var ui:=UI.new()
    ui.theme=Theme.new()
    ui.theme.default_font=UI.FONT
    ui.theme.default_font_size=18
    ui._install_theme(ui.theme)
    world.ui_shell=ui
    world.add_child(ui)
    world.map_panel=ColorRect.new()
    world.map_panel.position=Vector2(52,54)
    world.map_panel.size=Vector2(1176,640)
    ui.add_child(world.map_panel)
    world.survey_map_view=VIEW.new()
    world.survey_map_view.position=Vector2(34,78)
    world.survey_map_view.size=Vector2(1108,504)
    world.map_panel.add_child(world.survey_map_view)
    world.map_draw_root=Control.new()
    world.map_draw_root.size=Vector2(1108,504)
    world.survey_map_view.content=world.map_draw_root
    world.survey_map_view.add_child(world.map_draw_root)
    world.map_text=Label.new()
    world.map_text.add_theme_font_size_override("font_size",14)
    world.map_text.text="苔钟庭 · 探索 1/20\n目标：循着已知线索回访\n路线：钟龛 → 旧工房\n危险：留意落点\n自定义地图键返回"
    world.map_text.position=Vector2(34,600)
    world.map_text.size=Vector2(965,24)
    world.map_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    world.map_panel.add_child(world.map_text)
    for index in 4:
        var button:=ui._button(world.map_panel,["−","+","复位","返回"][index],Vector2([946,984,1022,1080][index],18),Vector2([34,34,50,62][index],34),func():pass)
        button.name=["ZoomOut","ZoomIn","Reset","Return"][index]
    PINS.setup(world)
    var directory:=ui._button(world.map_panel,"已知地点目录",Vector2(1008,585),Vector2(134,32),func():pass)
    directory.name="MapDirectoryButton"
    directory.add_theme_font_size_override("font_size",13)
    var expedition:=ui._button(world.map_panel,"多站行程",Vector2(860,585),Vector2(134,32),func():pass)
    expedition.name="ExpeditionDeskButton"
    expedition.add_theme_font_size_override("font_size",13)
    return world

func controls(world: Node) -> Array[Control]:
    var result: Array[Control]=[]
    for name in ["ZoomOut","ZoomIn","Reset","Return","MapDirectoryButton","ExpeditionDeskButton",LAYOUT.HELP_BUTTON]:
        var node:=world.map_panel.get_node_or_null(name) as Control
        if node!=null:result.append(node)
    for node in world.map_panel.get_node("PlayerPinToolbar").get_children():
        if node is Control:result.append(node)
    return result
func check_bounds(world: Node) -> void:
    var values:=controls(world)
    check(values.size()==13,"all original zoom, pin and directory/itinerary controls plus legend access remain present")
    for index in values.size():
        var node:=values[index]
        check(world.map_panel.get_global_rect().encloses(node.get_global_rect()),"map control remains inside the logical panel: "+String(node.name))
        check(not world.survey_map_view.get_global_rect().intersects(node.get_global_rect()),"control never intercepts clicks inside the map canvas: "+String(node.name))
        for other in range(index+1,values.size()):
            check(not node.get_global_rect().intersects(values[other].get_global_rect()),"interactive controls do not overlap: %s/%s" % [node.name,values[other].name])
    var status:=world.map_panel.get_node("PlayerPinStatus") as Label
    check(world.map_panel.get_global_rect().encloses(status.get_global_rect()),"pin status stays within the map panel")
    check(world.map_panel.get_global_rect().encloses(world.map_text.get_global_rect()),"multiline explanation preview stays within the map panel; full content is available in legend reader")
    for node in values:
        check(not status.get_global_rect().intersects(node.get_global_rect()),"pin status does not print behind buttons")
        check(not world.map_text.get_global_rect().intersects(node.get_global_rect()),"map explanation preview does not print behind buttons")

func run() -> void:
    await layout_checks()
    await legend_checks()
    await lifetime_checks()
    print("MAP_CONTROL_LAYOUT checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func layout_checks() -> void:
    var world:=make_runtime()
    await process_frame
    var pin_edit: Control=world.map_panel.get_node("PlayerPinToolbar/PinEdit")
    check(pin_edit.get_global_rect().intersects(world.map_panel.get_node("ZoomOut").get_global_rect()),"fixture reproduces the real old top-toolbar collision before applying the fix")
    var manifest:=COORD.manifest().duplicate(true)
    var original_flags: Dictionary=world.story_flags.duplicate(true)
    LAYOUT.apply(world)
    await process_frame
    await process_frame
    check_bounds(world)
    check(world.map_draw_root.size==LAYOUT.VIEW.size and world.survey_map_view.size==LAYOUT.VIEW.size,"map camera and coordinate presentation use the same available canvas extent")
    check(COORD.manifest()==manifest and world.story_flags==original_flags,"layout never mutates authored world bounds, discovery, rooms or pins")
    world.survey_map_view.magnify(2.0)
    world.map_draw_root.position=Vector2(-150,-100)
    var position: Vector2=world.map_draw_root.position
    var zoom: float=world.survey_map_view.zoom
    var count: int=world.map_panel.get_child_count()
    for index in 20:LAYOUT.apply(world)
    check(world.map_draw_root.position==position and world.survey_map_view.zoom==zoom,"idempotent layout does not reset current pan/zoom")
    check(world.map_panel.get_child_count()==count,"repeated setup never accumulates help buttons")
    world.ui_shell.scale=Vector2(0.75,0.75)
    await process_frame
    check_bounds(world)
    world.ui_shell.scale=Vector2(1.25,1.25)
    await process_frame
    check_bounds(world)
    world.free()
    await process_frame

func legend_checks() -> void:
    var world:=make_runtime()
    LAYOUT.apply(world)
    await process_frame
    var button:=world.map_panel.get_node(LAYOUT.HELP_BUTTON) as Button
    var original:=String(world.map_text.text)
    var status:=world.map_panel.get_node("PlayerPinStatus") as Label
    status.text="已选长名称图钉："+"旧工房回访线索".repeat(20)
    button.pressed.emit()
    var window:=world.map_panel.get_node(LAYOUT.HELP_WINDOW) as AcceptDialog
    var text:=window.get_node("LegendText") as RichTextLabel
    check(window.visible and window.get_ok_button().has_focus(),"native keyboard/controller legend opens with return focused")
    check(text.text.contains(original) and text.text.contains(status.text),"full multiline route/danger/controls and untruncated pin status remain readable")
    check(text.scroll_active and not text.bbcode_enabled,"long explanations scroll as literal text instead of injected markup")
    check(text.get_theme_color("default_color")==world.ui_shell.IVORY,"legend uses the production shell's ivory body color")
    check(world.ui_shell.has_modal_window(),"existing input isolation recognizes the new native legend")
    check(not world.survey_map_view.navigation_available(),"map camera ignores controller/keyboard navigation behind the exclusive legend")
    window.hide()
    window.canceled.emit()
    check(button.has_focus(),"closing explanation returns focus to its source control")
    check(world.ui_shell.has_modal_window(),"same-frame close input cannot escape into gameplay")
    await process_frame
    check(not world.ui_shell.has_modal_window(),"input guard releases after the close frame")
    world.map_text.text="更新的地图说明"
    button.pressed.emit()
    check(text.text.contains("更新的地图说明") and not text.text.contains(original),"reopen reads current view text rather than a stale region legend")
    world.map_panel.hide()
    check(not window.visible,"closing parent map also dismisses its legend")
    button.pressed.emit()
    check(not window.visible,"hidden map cannot reopen a native modal from a retained callback")
    world.map_panel.show()
    world.world_loading=true
    button.pressed.emit()
    check(not window.visible,"transition/loading state cannot open an obsolete legend")
    world.world_loading=false
    world.map_text.text=""
    button.pressed.emit()
    check(text.text.contains("尚无额外说明"),"empty legend provides an explicit readable state")
    world.free()
    await process_frame

func lifetime_checks() -> void:
    var callbacks: Array[Callable]=[]
    var references: Array[WeakRef]=[]
    for index in 15:
        var world:=make_runtime()
        references.append(weakref(world))
        LAYOUT.apply(world)
        var button:=world.map_panel.get_node(LAYOUT.HELP_BUTTON) as Button
        callbacks.append(button.pressed.get_connections()[0].callable)
        button.pressed.emit()
        if index%2==0:world.free()
        else:world.queue_free()
    await process_frame
    await process_frame
    for callback in callbacks:callback.call()
    for reference in references:check(reference.get_ref()==null,"legend callbacks never retain a destroyed region owner")
    check(callbacks.all(func(callback):return callback.is_valid()),"weak dispatch callables remain valid after their retired maps are gone")
