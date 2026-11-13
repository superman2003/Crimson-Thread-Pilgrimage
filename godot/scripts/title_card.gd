extends CanvasLayer
## Launch title shown over the loaded world: continue, start over, or quit.
## Only a player launching the game sees it. Validations instantiate World
## themselves, and a headless run has nobody to press a button.
const TYPE := preload("res://scripts/ui_type_scale.gd")
static var shown := false
signal chosen(action: String)
var level: Node
var buttons := {}
var kept_audio_mode := Node.PROCESS_MODE_INHERIT

static func wanted(world: Node, display: String, arguments: PackedStringArray) -> bool:
    if shown or display=="headless":return false
    for argument in arguments:
        if argument in ["--skip-title","--new-game","--script","-s"] or argument.begins_with("--save-slot=") or argument.begins_with("--quit-after"):
            return false
    return world.is_inside_tree() and world.get_tree().current_scene==world

## Called by World once its first region is published.
static func present(world: Node, has_journey: bool) -> Node:
    var arguments:=OS.get_cmdline_args();arguments.append_array(OS.get_cmdline_user_args())
    if not wanted(world,DisplayServer.get_name(),arguments):return null
    return open(world,has_journey)

static func open(world: Node, has_journey: bool) -> Node:
    shown=true
    var card:=new();card.setup(world,has_journey);world.add_child(card)
    card.hold()
    return card

func setup(world: Node, has_journey: bool) -> void:
    level=world;name="TitleCard";layer=60;process_mode=Node.PROCESS_MODE_ALWAYS
    var shade:=ColorRect.new();shade.name="Shade";shade.color=Color(0.03,0.02,0.03,0.9)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
    var centre:=CenterContainer.new();centre.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(centre)
    # Same frame and typeface as the in-game pages.
    var shell: Variant=world.get("ui_shell")
    if shell is Control and is_instance_valid(shell) and shell.theme!=null:centre.theme=shell.theme
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16);centre.add_child(column)
    var heading:=Label.new();heading.name="Heading";heading.text="绯线巡礼";heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size",TYPE.BANNER);column.add_child(heading)
    var gap:=Control.new();gap.custom_minimum_size=Vector2(0,16);column.add_child(gap)
    for entry in [["continue","继续旅途" if has_journey else "开始旅途"],["new","新旅途"],["rush","首领连战"],["achievements","成就"],["quit","退出"]]:
        # A first launch has nothing to replace.
        if entry[0]=="new" and not has_journey:continue
        if entry[0]=="rush" and not preload("res://scripts/boss_rush.gd").available():continue
        var action:=String(entry[0])
        var button:=Button.new();button.text=entry[1];button.custom_minimum_size=Vector2(280,44)
        button.add_theme_font_size_override("font_size",TYPE.TITLE)
        button.pressed.connect(func():choose(action))
        column.add_child(button);buttons[action]=button
    buttons["continue"].call_deferred("grab_focus")

## The world waits behind the card: enemies cannot reach a player who has not
## pressed anything yet. Music keeps playing.
func hold() -> void:
    var director: Variant=level.get("audio_director")
    if director is Node and is_instance_valid(director):
        kept_audio_mode=director.process_mode;director.process_mode=Node.PROCESS_MODE_ALWAYS
    get_tree().paused=true

func release() -> void:
    get_tree().paused=false
    var director: Variant=level.get("audio_director")
    if director is Node and is_instance_valid(director):director.process_mode=kept_audio_mode

func choose(action: String) -> void:
    if is_queued_for_deletion():return
    if action=="quit":
        chosen.emit(action);get_tree().quit();return
    if action=="achievements":
        show_achievements();return
    release()
    if action=="rush":
        chosen.emit(action);queue_free()
        preload("res://scripts/boss_rush.gd").new().begin(level)
        return
    if action=="new":
        # Same confirmation and backup as F9; cancelling returns to the journey.
        var dialog: Variant=level.get("new_journey_dialog")
        if dialog is ConfirmationDialog and is_instance_valid(dialog):
            dialog.popup_centered();level.set("active_overlay","new_journey")
            if level.has_method("_sync_ui_input_lock"):level.call("_sync_ui_input_lock")
    chosen.emit(action);queue_free()

## Earned and unearned alike; the world stays held behind the card.
func show_achievements() -> void:
    var window:=get_node_or_null("Achievements") as AcceptDialog
    if window==null:
        window=AcceptDialog.new();window.name="Achievements";window.title="成就";window.min_size=Vector2i(460,420)
        window.process_mode=Node.PROCESS_MODE_ALWAYS;add_child(window)
        var list:=ItemList.new();list.name="List";list.custom_minimum_size=Vector2(420,340);window.add_child(list)
        window.visibility_changed.connect(func():
            if not window.visible and buttons.has("achievements"):buttons["achievements"].grab_focus())
    var list:=window.get_node("List") as ItemList
    list.clear()
    var record:=preload("res://scripts/achievements.gd").new()
    for row in record.rows():
        list.add_item(("● " if row.earned else "○ ")+String(row.name)+"　"+String(row.goal))
        list.set_item_disabled(list.item_count-1,not row.earned)
    window.popup_centered();list.grab_focus()
