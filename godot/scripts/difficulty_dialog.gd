extends Node
const TYPE := preload("res://scripts/ui_type_scale.gd")
const MODEL := preload("res://scripts/difficulty_setting.gd")
## Settings-owned window for this journey's difficulty. The page is rebuilt on
## every region arrival, so the choice is re-read from its record each time and
## re-applied whenever the level hands out a new player.
var ui: Control
var model := MODEL.new()
var window: AcceptDialog
var options: OptionButton
var status: Label
var applied_player: Node
var applied_tier := ""

static func install(shell: Control) -> void:
    if shell.has_node("DifficultyDesk"):return
    var desk:=new();desk.name="DifficultyDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell
    var path: Variant=ui.level.get("world_save_path") if is_instance_valid(ui.get("level")) else null
    model.attach(String(path) if path is String else "user://pilgrimage_world.json")
    var launcher: Button=ui._button(ui.settings,"难度",Vector2(576,381),Vector2(104,28),open)
    launcher.name="DifficultyButton";launcher.add_theme_font_size_override("font_size",TYPE.CONTROL)
    # The engine's automatic left/right pick jumps to the remap grid below and
    # leaves the middle launcher unreachable by d-pad; chain this row explicitly.
    var row: Array[Control]=[launcher]
    var display:=ui.settings.get_node_or_null("DisplaySettingsButton") as Control
    if display!=null:row.append(display)
    var reset: Variant=ui.get("reset_bindings_button")
    if reset is Control and is_instance_valid(reset):row.append(reset)
    for index in row.size()-1:
        row[index].focus_neighbor_right=row[index].get_path_to(row[index+1])
        row[index+1].focus_neighbor_left=row[index+1].get_path_to(row[index])
    ui.settings.visibility_changed.connect(func():
        if is_instance_valid(window) and not ui.settings.is_visible_in_tree():window.hide())

func _process(_delta: float) -> void:
    var player: Variant=ui.level.get("player") if is_instance_valid(ui) and is_instance_valid(ui.get("level")) else null
    if not player is Node or not is_instance_valid(player):return
    if player==applied_player and applied_tier==model.tier:return
    model.apply(player);applied_player=player;applied_tier=model.tier

func ensure_window() -> void:
    if is_instance_valid(window):return
    window=AcceptDialog.new();window.title="难度";window.min_size=Vector2i(420,200)
    ui.settings.add_child(window);ui.register_text_entry_window(window)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);window.add_child(column)
    options=OptionButton.new();options.custom_minimum_size=Vector2(380,36);column.add_child(options)
    for id in MODEL.ORDER:
        options.add_item(String(MODEL.TIERS[id].name));options.set_item_metadata(options.item_count-1,id)
    options.item_selected.connect(func(index: int):_choose(String(options.get_item_metadata(index))))
    status=Label.new();status.custom_minimum_size=Vector2(380,56);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status)
    preload("res://scripts/settings_dialog_layout.gd").install(window,column,Vector2i(420,240))

func open() -> void:
    if not ui.settings.is_visible_in_tree():return
    ensure_window();refresh();window.popup_centered();options.grab_focus()

func refresh() -> void:
    if not is_instance_valid(window):return
    options.select(maxi(MODEL.ORDER.find(model.tier),0))
    status.text=String(MODEL.TIERS[model.tier].note)

func _choose(id: String) -> void:
    if not is_instance_valid(window) or not window.visible or not ui.settings.is_visible_in_tree():return
    var result: Dictionary=model.choose(id)
    refresh()
    if not result.ok:status.text=String(result.reason)
