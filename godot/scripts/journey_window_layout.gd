extends RefCounted
## Window chrome stays reachable; the body scrolls instead of growing offscreen.
const HORIZONTAL_MARGIN := 12
const VERTICAL_MARGIN := 36
const BASE_READING_SIZE := 21.0

static func frame(viewport: Rect2, preferred: Vector2i) -> Dictionary:
    if not viewport.position.is_finite() or not viewport.size.is_finite() or preferred.x<=0 or preferred.y<=0:return {"ok":false}
    var available:=Vector2i(floor(viewport.size.x),floor(viewport.size.y))
    var budget:=available-Vector2i(HORIZONTAL_MARGIN*2,VERTICAL_MARGIN*2)
    if budget.x<200 or budget.y<120:return {"ok":false}
    var dimensions:=Vector2i(mini(preferred.x,budget.x),mini(preferred.y,budget.y))
    var origin:=Vector2i(floor(viewport.position.x),floor(viewport.position.y))+(available-dimensions)/2
    return {"ok":true,"rect":Rect2i(origin,dimensions)}

static func reading_size(value: Variant) -> int:
    if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return 21
    return clampi(int(value),17,26)

static func scaled_font(base: int, reading: Variant) -> int:
    return clampi(int(round(maxi(base,1)*reading_size(reading)/BASE_READING_SIZE)),12,42)

static func apply_reading(root: Control, reading: Variant) -> void:
    if not is_instance_valid(root):return
    var pending: Array[Node]=[root]
    var changes: Array=[]
    while not pending.is_empty():
        var node: Node=pending.pop_back()
        pending.append_array(node.get_children())
        if not node is Control:continue
        var fields: Array[String]=[]
        if node is RichTextLabel:fields.assign(["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"])
        elif node is Label or node is Button or node is LineEdit or node is ItemList or node is TextEdit:fields.assign(["font_size"])
        for field in fields:
            var tag:="journey_layout_original_"+field
            if not node.has_meta(tag):node.set_meta(tag,node.get_theme_font_size(field))
            var base: Variant=node.get_meta(tag)
            if base is int and base>0:changes.append([node,field,scaled_font(base,reading)])
    # Capture inherited bases before changing a parent: scaling cannot compound.
    for change in changes:
        var control: Control=change[0]
        control.add_theme_font_size_override(change[1],change[2])
