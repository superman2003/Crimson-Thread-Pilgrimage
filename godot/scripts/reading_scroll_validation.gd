extends SceneTree
## U05 controller reading on the real World UI: the right stick scrolls the
## reading pane of the topmost context only while an overlay or dialog is open.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const SCROLL := preload("res://scripts/reading_scroll.gd")
var checks := 0
var failures := 0
var world: Node
var ui: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func frames(count: int) -> void:
	for index in count:
		await process_frame

func bar_of(pane: Control) -> VScrollBar:
	return pane.get_v_scroll_bar()

func find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and String(child.text) == text:
			return child
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func stick(value: float, count: int) -> void:
	ui.reading_axis_override = value
	await frames(count)
	ui.reading_axis_override = 0.0
	await frames(1)

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	check(is_equal_approx(SCROLL.rescale(0.1, 0.2), 0.0) and is_equal_approx(SCROLL.rescale(0.6, 0.2), 0.5) and is_equal_approx(SCROLL.rescale(-1.0, 0.2), -1.0), "stick rescales outside the deadzone")
	check(SCROLL.rescale(NAN, 0.2) == 0.0 and SCROLL.rescale(0.9, NAN) > 0.0, "non-finite stick or deadzone values are inert")
	if Input.get_connected_joypads().is_empty():
		check(SCROLL.stick_axis(0.2) == 0.0, "no connected pad reads as no scroll")
	world = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://reading_scroll.json"
	root.add_child(world)
	await READY.wait_for(world)
	await frames(6)
	ui = world.ui_shell
	ui.reading_axis_override = 0.0
	# Gameplay: no overlay, nothing scrolls and the player is not driven.
	var start: Vector2 = world.player.global_position
	ui.reading_axis_override = 1.0
	await frames(8)
	ui.reading_axis_override = 0.0
	check(SCROLL.target(ui) == null or world.active_overlay == "", "no overlay is open during play")
	check(world.player.global_position.distance_to(start) < 2.0, "right stick during play does not move the player")
	# Journal body in the backpack.
	world._toggle_backpack()
	ui.bag_category = "旅记"
	ui.refresh_inventory()
	await frames(4)
	var longest: Dictionary = {}
	for document in ui.journal_documents:
		if String(document.text).length() > String(longest.get("text", "")).length():
			longest = document
	check(not longest.is_empty(), "World supplies a journal document")
	ui._show_journal_record(longest.entry)
	await frames(6)
	var body: RichTextLabel = ui.bag_description
	check(SCROLL.scrollable(body), "the longest journal body overflows its pane")
	check(SCROLL.target(ui) == body, "backpack journal body is the reading target")
	var bar := bar_of(body)
	bar.value = 0.0
	await frames(2)
	await stick(1.0, 10)
	var after_down := bar.value
	check(after_down > 40.0, "stick down scrolls the journal body (%.0fpx)" % after_down)
	await stick(-0.5, 4)
	check(bar.value < after_down and bar.value >= 0.0, "stick up scrolls back, scaled by tilt")
	var held := bar.value
	await frames(6)
	check(is_equal_approx(bar.value, held), "released stick leaves the body where it is")
	await stick(1.0, 240)
	check(is_equal_approx(bar.value, bar.max_value - bar.page), "scrolling clamps at the end of the text")
	check(ui.journal_current_document.get("key") == longest.get("key"), "scrolling keeps the same document selected")
	# A dialog on top owns the stick; the page behind does not move.
	world._close_overlays()
	await frames(2)
	world._toggle_audio_settings()
	await frames(4)
	find_button(ui, "来源与许可").pressed.emit()
	await frames(6)
	var credits: Window = ui.find_child("CreditsReaderWindow", true, false)
	check(credits != null and credits.visible, "credits reader dialog opens")
	var pane := SCROLL.target(ui)
	check(pane != null and credits.is_ancestor_of(pane), "the open dialog's text is the reading target")
	if pane != null:
		var credit_bar: VScrollBar = pane.get_v_scroll_bar()
		var before: float = credit_bar.value
		await stick(1.0, 10)
		check(credit_bar.value > before, "stick scrolls the dialog's text")
	credits.hide()
	await frames(2)
	# Focus inside a list picks that list over the larger summary pane.
	world._close_overlays()
	await frames(2)
	world._toggle_build()
	await frames(4)
	var cart_button := find_button(ui, "多件制作清单")
	if cart_button != null and not cart_button.disabled:
		cart_button.pressed.emit()
		await frames(6)
		var cart: ConfirmationDialog = null
		for dialog in ui.find_children("*", "ConfirmationDialog", true, false):
			if dialog.visible:
				cart = dialog
		check(cart != null, "bulk craft dialog opens")
		if cart != null:
			var list: ScrollContainer = cart.find_children("*", "ScrollContainer", true, false)[0]
			check(SCROLL.scrollable(list), "bulk craft list overflows")
			var first: Control = list.find_children("*", "CheckButton", true, false)[0]
			first.grab_focus()
			await frames(2)
			check(SCROLL.target(ui) == list, "focus inside the list makes it the reading target")
			var top := list.scroll_vertical
			await stick(1.0, 10)
			check(list.scroll_vertical > top, "stick scrolls the focused list")
			# A gentle tilt below one pixel per frame still adds up. Start from the
			# top: a slow runner's longer frames can scroll the list to its end above.
			list.scroll_vertical = 0
			await frames(1)
			top = list.scroll_vertical
			for index in 10:
				SCROLL.scroll(ui, 0.4)
			check(list.scroll_vertical - top >= 3, "sub-pixel stick motion accumulates (%d px)" % (list.scroll_vertical - top))
			cart.hide()
	else:
		check(false, "bulk craft launcher is available in a new journey")
	world._close_overlays()
	await frames(2)
	# A dialog the level owns (ending desk pattern) with a focused native list.
	world._toggle_backpack()
	await frames(4)
	var owned := AcceptDialog.new()
	owned.name = "FixtureLevelList"
	world.add_child(owned)
	var items := ItemList.new()
	items.custom_minimum_size = Vector2(320, 200)
	for index in 60:
		items.add_item("条目 %d" % index)
	owned.add_child(items)
	owned.popup_centered(Vector2i(360, 300))
	await frames(4)
	items.grab_focus()
	await frames(2)
	check(not ui.is_ancestor_of(owned) and SCROLL.context(ui) == owned, "a visible dialog under the level is the reading context")
	check(SCROLL.scrollable(items) and SCROLL.target(ui) == items, "an overflowing focused ItemList is the reading target")
	var item_bar: VScrollBar = items.get_v_scroll_bar()
	var item_top := item_bar.value
	await stick(1.0, 10)
	check(item_bar.value > item_top, "stick scrolls the level-owned list")
	owned.hide()
	owned.queue_free()
	world._close_overlays()
	await frames(2)
	world.queue_free()
	await frames(3)
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("reading_scroll.json"):
			DirAccess.remove_absolute("user://" + name)
	print("READING_SCROLL checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
