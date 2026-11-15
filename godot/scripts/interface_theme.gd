extends RefCounted
## Shared widget builders and the interface theme: labels, styles, buttons, panels, frames, wells and icons.
## Moved out of pilgrimage_interface.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CHROME := preload("res://scripts/pilgrimage_chrome.gd")
const INSCRIBED_BUTTON := preload("res://scripts/pilgrimage_button.gd")
const TYPE := preload("res://scripts/ui_type_scale.gd")

static func label(ui: Node, parent: Node, text: String, position_value: Vector2, size_value: Vector2, font_size: int, tint: Color) -> Label:
    var label:=Label.new()
    label.position=position_value
    label.size=size_value
    label.add_theme_font_size_override("font_size",font_size)
    if font_size>=20:
        label.add_theme_font_override("font",ui.display_font())
    label.add_theme_color_override("font_shadow_color",Color(0,0,0,.7))
    label.add_theme_constant_override("shadow_offset_y",1)
    label.add_theme_color_override("font_color",tint)
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    label.text=text
    return label


static func style(ui: Node, tint: Color, border: Color, width: int=1) -> StyleBoxFlat:
    var style:=StyleBoxFlat.new()
    style.bg_color=tint
    # Native borders stay clear; etched strokes are drawn once by the button.
    style.border_color=Color(0,0,0,0)
    style.set_border_width_all(width)
    style.set_corner_radius_all(0)
    style.corner_detail=1
    style.content_margin_top=4
    style.content_margin_bottom=4
    style.content_margin_left=10
    style.content_margin_right=10
    return style


static func meter_style(ui: Node, tint: Color) -> StyleBoxFlat:
    var result: StyleBoxFlat = ui._style(tint,tint,0)
    result.content_margin_left=0
    result.content_margin_right=0
    result.content_margin_top=0
    result.content_margin_bottom=0
    result.set_corner_radius_all(2)
    return result


static func tab_style(ui: Node, selected: bool) -> StyleBoxFlat:
    var result: StyleBoxFlat = ui._style(Color(0,0,0,0),ui.RED if selected else Color("43504a"),0)
    result.border_width_bottom=2 if selected else 1
    result.set_corner_radius_all(0)
    return result


static func button(ui: Node, parent: Node, text: String, position_value: Vector2, size_value: Vector2, action: Callable) -> Button:
    var button = INSCRIBED_BUTTON.new()
    button.position=position_value
    button.size=size_value
    button.add_theme_font_size_override("font_size",TYPE.ACTION)
    button.add_theme_color_override("font_color",ui.IVORY)
    button.add_theme_stylebox_override("normal",ui._style(Color(.01,.025,.028,.35),Color("61553f")))
    button.add_theme_stylebox_override("hover",ui._style(Color(.18,.06,.055,.25),ui.RED))
    button.add_theme_stylebox_override("focus",ui._style(Color(0,0,0,0),ui.GOLD,2))
    button.add_theme_stylebox_override("pressed",ui._style(Color(.25,.07,.06,.3),ui.RED,2))
    button.add_theme_color_override("font_disabled_color",ui.MUTED.darkened(0.3))
    button.add_theme_stylebox_override("disabled",ui._style(Color("182025"),Color("303c3d")))
    button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    button.focus_mode=Control.FOCUS_ALL
    button.pressed.connect(action)
    parent.add_child(button)
    button.text=text
    return button


static func panel(ui: Node, parent: Node, title: String, position_value: Vector2, size_value: Vector2) -> ColorRect:
    var root:=ColorRect.new()
    root.position=position_value
    root.size=size_value
    root.color=Color(0,0,0,0)
    root.z_index=10
    root.visible=false
    parent.add_child(root)
    ui.frame(root)
    var marks := {"契印与构筑":["seal","行装与构筑"],"巡礼行囊":["inventory","器物与旧物"],"设置与无障碍":["settings","声音与无障碍"]}
    if marks.has(title):
        var mark: Array=marks[title]
        var title_mark: TextureRect = ui._icon(root,ui.inscription_mark(String(mark[0])),Vector2(26,5),Vector2(166,82))
        title_mark.name="InscribedTitle"
        var subtitle: Label = ui._label(root,String(mark[1]),Vector2(198,24),Vector2(310,28),18,ui.GOLD)
        subtitle.name="InscriptionSubtitle"
        subtitle.add_theme_font_override("font",ui.display_font())
        ui._label(root,"绯线巡礼  /  归途手札",Vector2(200,58),Vector2(380,20),11,ui.MUTED)
    elif not title.is_empty():
        ui._label(root,title,Vector2(34,16),Vector2(size_value.x*0.65,44),30)
    ui._button(root,"返回",Vector2(size_value.x-91,24),Vector2(62,34),func():ui.level._close_overlays())
    return root


static func frame(ui: Node, control: Control) -> void:
    control.z_index=10
    var chrome = CHROME.new()
    chrome.kind="dialogue" if control==ui.dialogue else "frame"
    chrome.size=control.size
    chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE
    control.add_child(chrome)
    control.move_child(chrome,0)


static func well(ui: Node, parent: Control, point: Vector2, dimensions: Vector2) -> void:
    var well = CHROME.new()
    well.kind="well"
    well.position=point
    well.size=dimensions
    well.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(well)
    parent.move_child(well,1)


static func fit_viewport(ui: Node) -> void:
    var available = ui.get_viewport_rect().size
    var factor:=minf(available.x/1280.0,available.y/720.0)
    ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
    ui.size=Vector2(1280,720)
    ui.scale=Vector2.ONE*factor
    ui.position=(available-Vector2(1280,720)*factor)*0.5
    if ui.modal_shade!=null:
        ui.modal_shade.position=-ui.position/factor
        ui.modal_shade.size=available/factor


static func install_theme(ui: Node, target: Theme) -> void:
    target.set_color("font_color","Label",ui.IVORY)
    target.set_color("font_color","Button",ui.IVORY)
    target.set_color("default_color","RichTextLabel",ui.IVORY)
    target.set_color("title_color","Window",ui.IVORY)
    target.set_font("title_font","Window",ui.display_font())
    for state in ["embedded_border","embedded_unfocused_border"]:
        # Keep the engine's title/close-button margins and hit geometry.
        var window_style := ThemeDB.get_default_theme().get_stylebox(state,"Window").duplicate() as StyleBoxFlat
        if window_style != null:
            window_style.bg_color = Color("101f20")
            window_style.border_color = Color("101f20")
            window_style.shadow_color = Color(ui.GOLD,0.5)
            window_style.shadow_size = 1
            target.set_stylebox(state,"Window",window_style)
    target.set_font_size("font_size","Button",17)
    target.set_color("font_hover_color","Button",ui.IVORY)
    target.set_color("font_pressed_color","Button",ui.IVORY)
    target.set_color("font_focus_color","Button",ui.IVORY)
    target.set_color("font_disabled_color","Button",ui.MUTED.darkened(0.3))
    # Native dialog buttons share the shell's ink/copper palette. Unlike the
    # inscribed buttons they have no drawn chrome, so their focus border must
    # live in the style itself rather than the transparent _style default.
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        var background := Color("101f20")
        var border = ui.GOLD.darkened(0.4)
        if state == "hover" or state == "pressed":
            background = Color("302220")
            border = ui.RED
        elif state == "disabled":
            background = Color("182025")
            border = Color("303c3d")
        elif state == "focus":
            background = Color(0,0,0,0)
            border = ui.GOLD
        var button_style: StyleBoxFlat = ui._style(background,border,2 if state == "focus" else 1)
        button_style.border_color = border
        target.set_stylebox(state,"Button",button_style)
        # Theme lookup tries this theme's Button entry before the engine's
        # CheckButton one, so pin settings toggles to their default chrome.
        target.set_stylebox(state,"CheckButton",ThemeDB.get_default_theme().get_stylebox(state,"CheckButton"))
    target.set_stylebox("panel","TooltipPanel",ui._style(Color("152229"),ui.GOLD))
    target.set_color("font_color","TooltipLabel",ui.IVORY)
    target.set_font_size("font_size","TooltipLabel",16)
    target.set_stylebox("scroll","VScrollBar",ui._style(Color("162027"),Color("162027"),0))
    target.set_stylebox("grabber","VScrollBar",ui._style(Color("706951"),Color("706951"),0))
    target.set_stylebox("grabber_highlight","VScrollBar",ui._style(ui.GOLD,ui.GOLD,0))
    target.set_stylebox("grabber_pressed","VScrollBar",ui._style(ui.RED,ui.RED,0))
    target.set_stylebox("slider","HSlider",ui._style(Color("26353a"),Color("4a5148")))
    target.set_stylebox("grabber_area","HSlider",ui._style(ui.GOLD,ui.GOLD,0))
    target.set_stylebox("grabber_area_highlight","HSlider",ui._style(ui.IVORY,ui.IVORY,0))
    target.set_stylebox("panel","AcceptDialog",ui._style(Color("10191f"),ui.GOLD,2))
    target.set_font("font","OptionButton",ui.display_font())
    target.set_font_size("font_size","OptionButton",16)
    target.set_color("font_color","OptionButton",ui.IVORY)
    target.set_stylebox("normal","OptionButton",ui._style(Color("101f20"),Color("61553f")))
    target.set_stylebox("hover","OptionButton",ui._style(Color("2c2522"),ui.RED))
    target.set_stylebox("pressed","OptionButton",ui._style(Color("302220"),ui.RED))
    target.set_stylebox("focus","OptionButton",ui._style(Color(0,0,0,0),ui.RED,1))
    target.set_stylebox("panel","PopupMenu",ui._style(Color("0b1c1e"),ui.GOLD))
    target.set_stylebox("hover","PopupMenu",ui._style(Color("302220"),ui.RED))
    target.set_color("font_color","PopupMenu",ui.IVORY)
    target.set_font("font","PopupMenu",ui.display_font())


static func icon(ui: Node, parent: Node, asset: Texture2D, position_value: Vector2, size_value: Vector2) -> TextureRect:
    var icon:=TextureRect.new()
    icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    icon.texture=asset
    icon.position=position_value
    icon.size=size_value
    icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(icon)
    return icon
