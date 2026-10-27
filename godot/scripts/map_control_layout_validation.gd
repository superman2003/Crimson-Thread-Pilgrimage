extends SceneTree
const LAYOUT:=preload("res://scripts/map_control_layout.gd")
const PINS:=preload("res://scripts/map_player_pins_runtime.gd")
const VIEW:=preload("res://scripts/survey_map_view.gd")
const UI:=preload("res://scripts/pilgrimage_interface.gd")
const SURVEY:=preload("res://scripts/cartography_runtime.gd")
const ATLAS:=preload("res://scripts/world_atlas.gd")
const ROUTES:=preload("res://scripts/world_routes.gd")
const JOURNAL:=preload("res://scripts/pilgrimage_cartography.gd")
const STATE:=preload("res://scripts/world_state.gd")
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
    var config: Dictionary={}
    var player: Node2D
    var world_state: RefCounted=STATE.new()
    var inventory_counts: Dictionary={}
    var opened_shortcuts: Dictionary={}
    var chapter_terrain: Node
    var wish_panel: Control
    var build_system: RefCounted
    func _vec2(value: Array) -> Vector2:return Vector2(value[0],value[1])
    func _rect2(value: Array) -> Rect2:return Rect2(value[0],value[1],value[2],value[3])
    func _map_world_to_overlay(point: Vector2,bounds: Rect2,extent: Vector2) -> Vector2:
        return (point-bounds.position)/bounds.size*extent
    func _room_for_position(point: Vector2) -> Dictionary:
        for room in config.get("map_rooms",[]):
            if SURVEY.room_rect(room).has_point(point):return room
        return {}
    func player_world_position() -> Vector2:return COORD.to_world(String(config.id),player.position)
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
    world.player=Node2D.new()
    world.add_child(world.player)
    ui.add_child(world.map_panel)
    var background:=TextureRect.new()
    background.name="MapBackgroundArt"
    world.map_panel.add_child(background)
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
    await production_legend_checks()
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
    status.text=""
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

func assert_rendered_details(world: Node, message: String) -> void:
    var controls: Array[Node]=world.map_draw_root.find_children("*","Control",true,false)
    var details:=0
    for node in controls:
        if not node.is_visible_in_tree() or node.tooltip_text.strip_edges().is_empty():continue
        details+=1
        check(message.contains(node.tooltip_text.strip_edges()),"production renderer's known tooltip is readable: "+String(node.name))
    check(details>5,"real renderer provides multiple authored room/route/hazard explanations")
    check(message.contains(world.map_text.tooltip_text),"production long-form legend survives terse footer text")

func clear_map(world: Node) -> void:
    for child in world.map_draw_root.get_children():child.free()

func production_legend_checks() -> void:
    ROUTES._data()
    var world:=make_runtime()
    LAYOUT.apply(world)
    world.config=ATLAS.configuration("demo_ch01_moss_bell_court")
    check(not world.config.is_empty(),"production map configuration and route cache are available")
    var id:=String(world.config.id)
    JOURNAL.region(world.story_flags,id).owned=true
    JOURNAL.grant_quill(world.story_flags)
    var unknown_names: Array[String]=[]
    for room in world.config.map_rooms:
        if SURVEY.public_room(room):JOURNAL.visit(world.story_flags,id,String(room.id))
        else:unknown_names.append("SurveyRoom_"+String(room.id))
    JOURNAL.rest(world.story_flags)
    SURVEY.render(world)
    check(not world.map_text.text.contains("\n") and not world.map_text.tooltip_text.is_empty(),"real local renderer uses terse footer plus separate long-form tooltip")
    var flags: Dictionary=world.story_flags.duplicate(true)
    var previous_tooltip:=String(world.map_text.tooltip_text)
    var local_text:=LAYOUT.help_text(world)
    assert_rendered_details(world,local_text)
    check(world.story_flags==flags,"opening help does not chart rooms or mutate discovery")
    for name in unknown_names:
        check(not world.map_draw_root.has_node(name),"uncharted hidden room has no control for help to collect")
    # Duplicate tooltips are shown once, hidden/retired children never leak.
    var duplicate:=Label.new()
    duplicate.tooltip_text=world.map_text.tooltip_text
    world.map_draw_root.add_child(duplicate)
    var hidden:=Label.new()
    hidden.tooltip_text="SECRET_HIDDEN_TOOLTIP"
    hidden.hide()
    world.map_draw_root.add_child(hidden)
    var retired:=Label.new()
    retired.tooltip_text="SECRET_RETIRED_TOOLTIP"
    world.map_draw_root.add_child(retired)
    retired.queue_free()
    local_text=LAYOUT.help_text(world)
    check(local_text.count(world.map_text.tooltip_text)==1,"duplicate production explanations appear once")
    check(not local_text.contains("SECRET_"),"hidden and queued controls are excluded")
    var button:=world.map_panel.get_node(LAYOUT.HELP_BUTTON) as Button
    button.pressed.emit()
    var dialog:=world.map_panel.get_node(LAYOUT.HELP_WINDOW) as AcceptDialog
    check(dialog.get_node("LegendText").text==local_text,"native dialog consumes actual local renderer explanations")
    dialog.hide()
    # An unpurchased redraw must clear previous region details immediately.
    clear_map(world)
    JOURNAL.region(world.story_flags,id).owned=false
    SURVEY.render(world)
    check(world.map_text.tooltip_text.is_empty(),"unowned map render clears previous long-form tooltip")
    check(not LAYOUT.help_text(world).contains(previous_tooltip),"unowned help cannot retain the previous known-room summary")
    clear_map(world)
    JOURNAL.region(world.story_flags,id).owned=true
    for region in COORD.manifest().regions:
        JOURNAL.region(world.story_flags,String(region)).owned=true
    ATLAS.render(world)
    var atlas_text:=LAYOUT.help_text(world)
    check(not world.map_text.text.contains("\n") and atlas_text.contains("实线是实体钟管"),"actual atlas long-form transport explanation is readable")
    assert_rendered_details(world,atlas_text)
    check(not atlas_text.contains("SECRET_"),"switching to atlas discards previous view controls")
    button.pressed.emit()
    check(dialog.get_node("LegendText").text==atlas_text,"reopened native reader refreshes from actual atlas renderer")
    world.free()
    await process_frame
