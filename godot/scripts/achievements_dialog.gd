extends Node
const TYPE := preload("res://scripts/ui_type_scale.gd")
const RECORD := preload("res://scripts/achievements.gd")
## In-game entry to the achievement list, beside the difficulty launcher.
## Read-only: earning happens when the journey is saved.
var ui: Control
var window: AcceptDialog
var list: ItemList

static func install(shell: Control) -> void:
    if shell.has_node("AchievementsDesk"):return
    var desk:=new();desk.name="AchievementsDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell
    var launcher: Button=ui._button(ui.settings,"成就",Vector2(464,381),Vector2(104,28),open)
    launcher.name="AchievementsButton";launcher.add_theme_font_size_override("font_size",TYPE.CONTROL)
    # Join the explicit d-pad chain the difficulty launcher starts.
    var next:=ui.settings.get_node_or_null("DifficultyButton") as Control
    if next!=null:
        launcher.focus_neighbor_right=launcher.get_path_to(next)
        next.focus_neighbor_left=next.get_path_to(launcher)
    ui.settings.visibility_changed.connect(func():
        if is_instance_valid(window) and not ui.settings.is_visible_in_tree():window.hide())

func ensure_window() -> void:
    if is_instance_valid(window):return
    window=AcceptDialog.new();window.title="成就";window.min_size=Vector2i(460,420)
    ui.settings.add_child(window);ui.register_text_entry_window(window)
    var column:=VBoxContainer.new();window.add_child(column)
    list=ItemList.new();list.name="List";list.custom_minimum_size=Vector2(420,340);column.add_child(list)
    preload("res://scripts/settings_dialog_layout.gd").install(window,column,Vector2i(460,420))

func open() -> void:
    if not ui.settings.is_visible_in_tree():return
    ensure_window();RECORD.fill(list);window.popup_centered();list.grab_focus()
