extends SceneTree
## T03: region UI rebuilds must not shape text outside the tree (~4 ms per
## control). Deterministic: record each text control's text at the moment it
## enters the tree; production helpers and dialogs must still be blank then.
var checks := 0
var failures := 0
var entered: Array[Dictionary] = []

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func observe(node: Node) -> void:
    var text := ""
    if node is OptionButton:
        text = str(node.item_count)
    elif node is Label or node is Button:
        text = node.text
    elif node is LineEdit:
        text = node.placeholder_text
    elif node is AcceptDialog:
        text = node.dialog_text  # title and buttons start with engine defaults
    entered.append({"node": node, "text": text})

func entry_for(node: Node) -> Dictionary:
    for item in entered:
        if is_instance_valid(item.node) and item.node == node: return item
    return {}

func run() -> void:
    var world: Node = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://ui_text_order_validation.json"
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    var ui: Node = world.ui_shell
    var host := Control.new()
    host.visible = false
    ui.add_child(host)
    host.child_entered_tree.connect(observe)
    var label: Label = ui._label(host, "主音量", Vector2(10, 10), Vector2(140, 30), 16)
    var title: Label = ui._label(host, "阅读、画面与手柄", Vector2(10, 40), Vector2(440, 26), 20)
    var button: Button = ui._button(host, "恢复当前槽备份", Vector2(10, 80), Vector2(137, 30), func(): pass)
    check(entry_for(label).get("text", "x") == "" and label.text == "主音量", "body label joins the tree before its text is set")
    check(entry_for(title).get("text", "x") == "" and title.text == "阅读、画面与手柄", "display label joins the tree before its text is set")
    check(entry_for(button).get("text", "x") == "" and button.text == "恢复当前槽备份", "inscribed button joins the tree before its text is set")
    check(label.get_theme_font_size("font_size") == 16 and button.get_theme_font_size("font_size") == 17, "helper styles still apply")
    check(ui.inscription_mark("settings") == ui.inscription_mark("settings") and ui.inscription_mark("settings") is Texture2D, "inscribed title artwork is loaded once and shared")
    host.free()

    # Rarely opened windows are not laid out on every region arrival (they
    # cost 20–40 ms each there); they are built when first opened.
    var purpose: Node = ui.get_node("ResourcePurposeWindow")
    var finder: Node = ui.bag.get_node("JournalDocumentFind")
    var output: Node = ui.get_node("AudioOutputDesk")
    check(purpose.resources == null and purpose.get_child_count(false) == 0, "resource purpose window has no content until opened")
    check(finder.editor == null and finder.get_child_count(false) == 0, "journal page-find window has no content until opened")
    check(output.window == null and ui.settings.get_node_or_null("AudioOutputDeviceButton") != null, "audio output window is not built until opened; its launcher is")
    world._toggle_backpack()
    await process_frame
    ui.bag.get_node("ResourcePurposeButton").pressed.emit()
    await process_frame
    check(is_instance_valid(purpose.resources) and purpose.visible and purpose.resources.item_count > 0, "resource purpose window builds and fills on first open")
    purpose.hide()
    world._close_overlays()
    world._toggle_audio_settings()
    await process_frame
    output.open()
    await process_frame
    check(is_instance_valid(output.window) and output.window.visible and output.options.item_count > 0, "audio output window builds and lists devices on first open")
    output.window.hide()
    world._close_overlays()
    await process_frame
    # The bag's journal tools join the tree before their texts and items.
    var observe_all := func(node: Node): observe(node)
    node_added.connect(observe_all)
    var old_bag: Control = ui.bag
    ui._build_bag()
    node_added.disconnect(observe_all)
    check(entry_for(ui.journal_search).get("text", "x") == "" and not ui.journal_search.placeholder_text.is_empty(), "journal search joins the tree before its placeholder")
    check(entry_for(ui.journal_unread).get("text", "x") == "" and ui.journal_unread.text == "仅未读", "journal filter toggle joins the tree before its text")
    check(entry_for(ui.journal_sort).get("text", "x") == "0" and ui.journal_sort.item_count == 3, "journal sort menu joins the tree before its items")
    ui.bag.free()
    ui.bag = old_bag

    # Region-owned dialogs and the pin toolbar, rebuilt by the real setup calls.
    world.child_entered_tree.connect(observe)
    for dialog_name in ["MapPurchaseDialog", "DeathRecallDialog"]:
        var old: Node = world.get_node_or_null(dialog_name)
        if old != null: old.free()
    preload("res://scripts/cartography_runtime.gd").setup(world)
    preload("res://scripts/death_recall.gd").setup(world)
    var shop: AcceptDialog = world.get_node_or_null("MapPurchaseDialog")
    check(shop != null and entry_for(shop).get("text", "x") == "" and not shop.dialog_text.is_empty(), "map seller dialog joins the tree before its texts")
    var recall: AcceptDialog = null
    for item in entered:
        if is_instance_valid(item.node) and item.node is ConfirmationDialog and item.node != shop: recall = item.node
    check(recall != null and entry_for(recall).get("text", "x") == "" and not recall.title.is_empty(), "recall dialog joins the tree before its texts")
    world.child_entered_tree.disconnect(observe)
    var toolbar: Node = world.map_panel.get_node_or_null("PlayerPinToolbar")
    if toolbar != null: toolbar.free()
    var status_old: Node = world.map_panel.get_node_or_null("PlayerPinStatus")
    if status_old != null: status_old.free()
    world.map_panel.child_entered_tree.connect(observe)
    world.map_panel.child_entered_tree.connect(func(node: Node):
        if node.name == "PlayerPinToolbar": node.child_entered_tree.connect(observe))
    preload("res://scripts/map_player_pins_runtime.gd").setup(world)
    var kinds: Node = world.map_panel.get_node_or_null("PlayerPinToolbar/PinKind")
    var status: Label = world.map_panel.get_node_or_null("PlayerPinStatus")
    check(kinds != null and entry_for(kinds).get("text", "x") == "0" and kinds.item_count == 3, "pin kind menu joins the tree before its items")
    check(status != null and entry_for(status).get("text", "x") == "" and not status.text.is_empty(), "pin status joins the tree before its text")
    # Practice-target captions (region build jobs) join the tree before text.
    var captions: Array = []
    var watch_captions := func(node: Node):
        if node is Label and node.get_parent() != null and node.get_parent().has_method("configure"): captions.append({"node": node, "text": node.text})
    node_added.connect(watch_captions)
    var before_children := world.get_child_count()
    world._spawn_seal_practice_targets()
    world._spawn_tool_practice_targets()
    node_added.disconnect(watch_captions)
    check(captions.size() >= 2 and captions.all(func(item): return item.text == "" and not item.node.text.is_empty()), "practice target captions join the tree before their text (%d)" % captions.size())
    for index in range(world.get_child_count() - 1, before_children - 1, -1): world.get_child(index).free()
    world.queue_free()
    await process_frame
    for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_text_order_validation.json" + suffix))
    print("UI_TEXT_ORDER checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
