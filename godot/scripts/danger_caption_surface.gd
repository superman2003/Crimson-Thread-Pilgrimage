extends RefCounted
## Region-owned presentation. No enemies, world state or input are retained.
var panel: PanelContainer
var labels: Array[Label]=[]
var style: StyleBoxFlat
var font_size := -1
var contrast: Variant=null
func clear() -> void:
    if is_instance_valid(panel):
        panel.hide()
        if panel.get_parent()!=null:panel.get_parent().remove_child(panel)
        panel.queue_free()
    panel=null;labels=[];style=null;font_size=-1;contrast=null
func install(host: Control) -> Dictionary:
    if not is_instance_valid(host) or host.is_queued_for_deletion():clear();return {}
    if is_instance_valid(panel) and not panel.is_queued_for_deletion() and panel.get_parent()==host:return {"panel":panel,"labels":labels}
    clear()
    panel=PanelContainer.new();panel.name="DangerCaptionPanel";panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.z_index=100
    panel.theme=host.theme;panel.position=Vector2(430,88);panel.size=Vector2(420,0);host.add_child(panel)
    var column:=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(column)
    for unused in 3:
        var label:=Label.new();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.custom_minimum_size.x=410
        label.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(label);labels.append(label)
    panel.hide()
    return {"panel":panel,"labels":labels}
func hide() -> void:
    if is_instance_valid(panel):panel.hide()
    for label in labels:
        if is_instance_valid(label):label.text="";label.hide()
func apply(preferences: Dictionary) -> void:
    if not is_instance_valid(panel) or panel.is_queued_for_deletion():return
    var next_contrast: bool=preferences.get("danger_caption_contrast",true)==true
    if style==null:
        style=StyleBoxFlat.new();style.content_margin_top=5;style.content_margin_bottom=5
        panel.add_theme_stylebox_override("panel",style)
    if contrast!=next_contrast:
        contrast=next_contrast
        style.bg_color=Color(0.02,0.025,0.03,0.95 if next_contrast else 0.72)
    var next_size:=clampi(int(preferences.get("subtitle_size",21)),17,26)
    if font_size!=next_size:
        font_size=next_size
        for label in labels:
            if is_instance_valid(label):label.add_theme_font_size_override("font_size",font_size)
