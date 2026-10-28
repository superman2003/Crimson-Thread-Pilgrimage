extends Node
## Adapt existing native settings forms; reuse the journey frame/font policy.
const POLICY:=preload("res://scripts/journey_window_layout.gd")
var host_ref: WeakRef
var viewport_ref: WeakRef
var shell_ref: WeakRef
var column_ref: WeakRef
var body: ScrollContainer
var preferred:=Vector2i(720,620)
var last_context: Array=[]
var queued:=false
var elapsed:=0.0
var applications:=0
static func install(host: AcceptDialog,column: Control,dimensions: Vector2i) -> Node:
    var existing:=host.get_node_or_null("SettingsDialogLayout")
    if existing!=null:return existing
    var adapter:=new();adapter.name="SettingsDialogLayout";adapter.preferred=dimensions
    adapter.host_ref=weakref(host);adapter.column_ref=weakref(column)
    var outer: Viewport=host.get_parent().get_viewport()
    adapter.viewport_ref=weakref(outer)
    var ancestor: Node=host.get_parent()
    while ancestor!=null:
        if ancestor.has_method("get_accessibility"):adapter.shell_ref=weakref(ancestor);break
        ancestor=ancestor.get_parent()
    var old_parent:=column.get_parent()
    if old_parent is ScrollContainer:
        adapter.body=old_parent
        column.custom_minimum_size.x=maxf(column.custom_minimum_size.x,old_parent.custom_minimum_size.x)
    else:
        adapter.body=ScrollContainer.new();adapter.body.name="SettingsDialogScroll";host.add_child(adapter.body)
        column.reparent(adapter.body)
    adapter.body.custom_minimum_size=Vector2.ZERO
    adapter.body.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    adapter.body.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    adapter.body.follow_focus=true
    adapter._body_font_baseline(column)
    host.add_child(adapter)
    return adapter
func _ready() -> void:
    var host:=window();var viewport:=outer_viewport();var column:=content()
    if host==null or viewport==null or column==null:return
    host.about_to_popup.connect(request)
    host.visibility_changed.connect(_visibility)
    host.size_changed.connect(_window_size_changed)
    host.gui_focus_changed.connect(_focus_changed)
    viewport.size_changed.connect(request)
    column.child_entered_tree.connect(_content_added)
    request()
func window() -> AcceptDialog:
    var node: Variant=host_ref.get_ref() if host_ref!=null else null
    return node if is_instance_valid(node) and not node.is_queued_for_deletion() else null
func outer_viewport() -> Viewport:
    var node: Variant=viewport_ref.get_ref() if viewport_ref!=null else null
    return node if is_instance_valid(node) else null
func content() -> Control:
    var node: Variant=column_ref.get_ref() if column_ref!=null else null
    return node if is_instance_valid(node) else null
func reading() -> int:
    var shell: Variant=shell_ref.get_ref() if shell_ref!=null else null
    return POLICY.reading_size(shell.get_accessibility("subtitle_size",21)) if is_instance_valid(shell) else 21
func request() -> void:
    if queued or not is_inside_tree():return
    queued=true;call_deferred("fit")
func _visibility() -> void:
    if window()!=null and window().visible:request()
    else:last_context.clear()
func _content_added(_child: Node) -> void:
    last_context.clear();request()
func _process(delta: float) -> void:
    var host:=window()
    if host==null or not host.visible:return
    elapsed+=delta
    if elapsed<0.1:return
    elapsed=0.0
    var viewport:=outer_viewport()
    if viewport!=null and [viewport.get_visible_rect(),reading()]!=last_context:request()
func fit() -> void:
    queued=false
    var host:=window();var viewport:=outer_viewport();var column:=content()
    if host==null or viewport==null or column==null or not host.visible:return
    var context: Array=[viewport.get_visible_rect(),reading()]
    if context==last_context:return
    var view:=POLICY.frame(viewport.get_visible_rect(),preferred)
    if not view.ok:return
    var position_before:=Vector2i(body.scroll_horizontal,body.scroll_vertical)
    var size_before: Vector2i=host.size
    body.custom_minimum_size=Vector2.ZERO
    host.min_size=Vector2i(200,140)
    _body_font_baseline(column)
    POLICY.apply_reading(column,context[1])
    POLICY.apply_reading(host.get_ok_button(),context[1])
    var confirm:=host as ConfirmationDialog
    if confirm!=null:POLICY.apply_reading(confirm.get_cancel_button(),context[1])
    host.size=view.rect.size;host.position=view.rect.position
    _window_size_changed()
    last_context=context;applications+=1
    body.set_deferred("scroll_horizontal",position_before.x)
    body.set_deferred("scroll_vertical",position_before.y)
    if size_before!=host.size:call_deferred("_reveal_focus")
func _window_size_changed() -> void:
    var host:=window()
    if host==null or not is_instance_valid(body):return
    # Native confirmation buttons remain outside the scroll area.
    body.custom_minimum_size=Vector2(maxi(80,host.size.x-36),maxi(50,host.size.y-96))
func _focus_changed(control: Control) -> void:
    if control!=null and is_instance_valid(body) and body.is_ancestor_of(control):call_deferred("_reveal_focus")
func _reveal_focus() -> void:
    var host:=window()
    if host==null or not host.visible or not is_instance_valid(body):return
    var focus:=host.gui_get_focus_owner()
    if focus!=null and body.is_ancestor_of(focus):body.ensure_control_visible(focus)
func _exit_tree() -> void:
    var viewport:=outer_viewport();var host:=window();var column:=content()
    if viewport!=null and viewport.size_changed.is_connected(request):viewport.size_changed.disconnect(request)
    if column!=null and column.child_entered_tree.is_connected(_content_added):column.child_entered_tree.disconnect(_content_added)
    if host!=null:
        if host.about_to_popup.is_connected(request):host.about_to_popup.disconnect(request)
        if host.visibility_changed.is_connected(_visibility):host.visibility_changed.disconnect(_visibility)
        if host.size_changed.is_connected(_window_size_changed):host.size_changed.disconnect(_window_size_changed)
        if host.gui_focus_changed.is_connected(_focus_changed):host.gui_focus_changed.disconnect(_focus_changed)

func _body_font_baseline(column: Control) -> void:
    # Body paragraphs use the reading baseline, while authored small legends
    # retain their explicit font hierarchy. Never overwrite captured bases.
    var pending: Array[Node]=[column]
    while not pending.is_empty():
        var node: Node=pending.pop_back();pending.append_array(node.get_children())
        if node is Label and not node.has_theme_font_size_override("font_size") and not node.has_meta("journey_layout_original_font_size"):
            node.add_theme_font_size_override("font_size",21)
