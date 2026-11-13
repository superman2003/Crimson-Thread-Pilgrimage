extends CanvasLayer
## Short banner for a newly earned achievement. It has its own label so the
## game's toast line, which tests and players read for other news, is untouched.
const TYPE := preload("res://scripts/ui_type_scale.gd")
const SECONDS := 4.0
var label: Label
var left := 0.0

static func show_on(host: Node, names: Array) -> void:
    if names.is_empty() or not is_instance_valid(host) or not host.is_inside_tree():return
    var notice:=host.get_node_or_null("AchievementNotice")
    if notice==null:
        notice=new();notice.name="AchievementNotice";notice.layer=55;host.add_child(notice)
    notice.present(names)

func _ready() -> void:
    label=Label.new();label.name="Text";label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    label.offset_left=-420;label.offset_right=-20;label.offset_top=150;label.offset_bottom=178
    label.add_theme_font_size_override("font_size",TYPE.TITLE);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(label)

func present(names: Array) -> void:
    label.text="成就 · "+" · ".join(names)
    label.modulate.a=1.0;left=SECONDS;set_process(true)

func _process(delta: float) -> void:
    left-=delta
    label.modulate.a=clampf(left,0.0,1.0)
    if left<=0.0:queue_free()
