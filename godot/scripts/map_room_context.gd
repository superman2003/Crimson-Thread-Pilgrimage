extends RefCounted
## One fixed caption for mouse hover and controller/keyboard room focus.
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")

static func setup(level: Node) -> void:
    var caption:=level.map_panel.get_node_or_null("MapRoomContext") as Label
    if caption==null:
        caption=Label.new()
        caption.name="MapRoomContext"
        caption.position=Vector2(34,55)
        caption.size=Vector2(1108,20)
        caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
        caption.clip_text=true
        caption.add_theme_font_size_override("font_size",13)
        level.map_panel.add_child(caption)
    caption.text="悬停／方向键选择房间：查看上下层邻室；邻接不表示道路已开放。"

static func bind_room(level: Node, outline: Control, config: Dictionary, region: String, room: String) -> void:
    var description:=KNOWLEDGE.room_context(config,level.story_flags,region,room)
    outline.tooltip_text=description
    outline.focus_mode=Control.FOCUS_ALL
    var reference: WeakRef=weakref(level.map_panel.get_node_or_null("MapRoomContext"))
    outline.mouse_entered.connect(func():show_context(reference,description))
    outline.focus_entered.connect(func():show_context(reference,description))

static func show_context(reference: WeakRef, description: String) -> void:
    var caption:=reference.get_ref() as Label
    if not is_instance_valid(caption) or caption.is_queued_for_deletion():return
    caption.text=description.get_slice("\n",0)
    caption.tooltip_text=description
