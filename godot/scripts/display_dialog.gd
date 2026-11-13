extends Node
const TYPE := preload("res://scripts/ui_type_scale.gd")
const MODEL := preload("res://scripts/display_preferences.gd")
## Settings-owned window for fullscreen, vertical sync and the frame cap.
## The page is rebuilt on every region arrival; the model lives for the whole
## run so the saved window mode is applied once, at launch.
static var shared: RefCounted
var ui: Control
var model: RefCounted
var window: AcceptDialog
var fullscreen: CheckButton
var vsync: CheckButton
var cap: OptionButton
var assist: OptionButton
var status: Label

static func install(shell: Control) -> void:
    if shell.has_node("DisplayDesk"):return
    if shared==null:
        shared=MODEL.new()
        var root: Window=shell.get_tree().root
        shared.set_colour_assist=func(mode: String):preload("res://scripts/colour_assist.gd").apply(root,mode)
        shared.initialize()
    var desk:=new();desk.name="DisplayDesk";shell.add_child(desk);desk.setup(shell,shared)

func setup(shell: Control, preferences: RefCounted) -> void:
    ui=shell;model=preferences
    # The header and rows 298/332 are full; sit beside the remap reset button.
    var launcher: Button=ui._button(ui.settings,"显示",Vector2(688,381),Vector2(104,28),open)
    launcher.name="DisplaySettingsButton";launcher.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.settings.visibility_changed.connect(func():
        if is_instance_valid(window) and not ui.settings.is_visible_in_tree():window.hide())

func ensure_window() -> void:
    if is_instance_valid(window):return
    window=AcceptDialog.new();window.title="显示";window.min_size=Vector2i(420,308)
    ui.settings.add_child(window);ui.register_text_entry_window(window)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);window.add_child(column)
    fullscreen=CheckButton.new();fullscreen.text="全屏";fullscreen.custom_minimum_size=Vector2(380,36)
    fullscreen.toggled.connect(func(on: bool):_change("fullscreen",on));column.add_child(fullscreen)
    vsync=CheckButton.new();vsync.text="垂直同步";vsync.custom_minimum_size=Vector2(380,36)
    vsync.toggled.connect(func(on: bool):_change("vsync",on));column.add_child(vsync)
    var row:=HBoxContainer.new();column.add_child(row)
    var caption:=Label.new();caption.text="帧率上限";caption.custom_minimum_size=Vector2(190,36);row.add_child(caption)
    cap=OptionButton.new();cap.custom_minimum_size=Vector2(190,36);row.add_child(cap)
    for value in MODEL.CAPS:
        cap.add_item("不限" if value==0 else str(value));cap.set_item_metadata(cap.item_count-1,value)
    cap.item_selected.connect(func(index: int):_change("fps_cap",int(cap.get_item_metadata(index))))
    var assist_row:=HBoxContainer.new();column.add_child(assist_row)
    var assist_caption:=Label.new();assist_caption.text="色觉辅助";assist_caption.custom_minimum_size=Vector2(190,36);assist_row.add_child(assist_caption)
    assist=OptionButton.new();assist.custom_minimum_size=Vector2(190,36);assist_row.add_child(assist)
    for entry in [["off","关闭"],["protan","红色弱"],["deutan","绿色弱"]]:
        assist.add_item(entry[1]);assist.set_item_metadata(assist.item_count-1,entry[0])
    assist.item_selected.connect(func(index: int):_change("colour_assist",String(assist.get_item_metadata(index))))
    status=Label.new();status.custom_minimum_size=Vector2(380,28);column.add_child(status)
    preload("res://scripts/settings_dialog_layout.gd").install(window,column,Vector2i(420,348))

func open() -> void:
    if not ui.settings.is_visible_in_tree():return
    ensure_window();refresh();window.popup_centered();fullscreen.grab_focus()

func refresh() -> void:
    if not is_instance_valid(window):return
    fullscreen.set_pressed_no_signal(bool(model.values.fullscreen))
    vsync.set_pressed_no_signal(bool(model.values.vsync))
    cap.select(maxi(MODEL.CAPS.find(int(model.values.fps_cap)),0))
    assist.select(maxi(MODEL.ASSISTS.find(String(model.values.colour_assist)),0))
    status.text=String(model.notice)

func _change(key: String, value: Variant) -> void:
    if not is_instance_valid(window) or not window.visible or not ui.settings.is_visible_in_tree():return
    var result: Dictionary=model.change(key,value)
    refresh();status.text=String(result.reason)
