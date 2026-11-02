extends SceneTree
## U02/U06 controller reachability on the real World UI. From each page's and
## each launcher-opened dialog's own initial focus, a breadth-first walk over
## d-pad neighbours (the same find_valid_focus_neighbor the viewport uses for
## ui_up/down/left/right) must reach every visible, enabled, focusable control.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const BRIDGE := preload("res://scripts/dialog_focus_bridge.gd")
const PAGES := ["backpack", "build", "map", "settings"]
const SKIP_LAUNCHERS := ["返回", "关闭", "返回游戏"]
var checks := 0
var failures := 0
var world: Node
var dialogs := 0

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

func interactive(control: Control) -> bool:
	if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton:
		return not control.disabled
	# Read-only RichTextLabel bodies are reported separately, not required.
	return control is LineEdit or control is TextEdit or control is Range or control is ItemList or control is Tree or control is TabBar

func collect(node: Node, out: Array, into_windows: bool) -> Array:
	for child in node.get_children():
		if child is Window and not into_windows:
			continue
		if child is Window and not child.visible:
			continue
		if child is Control and interactive(child):
			out.append(child)
		collect(child, out, into_windows)
	return out

func reach(start: Control) -> Dictionary:
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var control: Control = queue.pop_front()
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var next: Control = control.find_valid_focus_neighbor(side)
			if next != null and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

func open_page(page: String) -> void:
	world._close_overlays()
	await frames(2)
	match page:
		"backpack": world._toggle_backpack()
		"build": world._toggle_build()
		"map": world._toggle_map()
		"settings": world._toggle_audio_settings()
	await frames(4)

func windows(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Window:
			out.append(child)
		out.append_array(windows(child))
	return out

func pad(window: Window, button: JoyButton, count: int) -> void:
	for step in count:
		var press := InputEventJoypadButton.new()
		press.button_index = button
		press.pressed = true
		window.push_input(press)
		var lift: InputEventJoypadButton = press.duplicate()
		lift.pressed = false
		window.push_input(lift)
		await frames(2)

func dialog_reach(dialog: AcceptDialog, label: String) -> void:
	var start: Control = dialog.gui_get_focus_owner()
	var content: Array = collect(dialog, [], false)
	var row: Array = BRIDGE.row_buttons(dialog)
	check(start != null, label + " opens with a focused control")
	if start == null:
		return
	var seen := reach(start)
	var missing: Array = content.filter(func(control): return not seen.has(control))
	check(missing.is_empty(), label + " d-pad reaches all %d content controls from %s (missing %s)" % [content.size(), start.name, ", ".join(missing.map(func(control): return String(control.get("text") if control.get("text") != null and String(control.get("text")) != "" else control.get_class())))])
	for button in row:
		check(seen.has(button), label + " d-pad reaches its %s button" % String(button.text))

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	world = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://dialog_dpad_focus.json"
	root.add_child(world)
	await READY.wait_for(world)
	await frames(6)
	var ui: Control = world.ui_shell
	for page in PAGES:
		await open_page(page)
		var controls: Array = collect(ui, [], false)
		var start: Control = ui.get_viewport().gui_get_focus_owner()
		check(start != null, page + " page opens with controller focus")
		if start == null:
			continue
		var seen := reach(start)
		var missing: Array = controls.filter(func(control): return not seen.has(control))
		check(missing.is_empty(), page + " page d-pad reaches all %d controls (missing %s)" % [controls.size(), ", ".join(missing.map(func(control): return String(control.get("text") if control.get("text") != null else control.name)))])
	# Settings row: the danger-caption launcher sits right of the comfort button.
	await open_page("settings")
	var comfort: Control = ui.settings.get_node("ControllerComfortButton")
	var danger: Control = ui.find_child("DangerCaptionButton", true, false)
	check(comfort.find_valid_focus_neighbor(SIDE_RIGHT) == danger and danger.find_valid_focus_neighbor(SIDE_LEFT) == comfort, "comfort and danger-caption launchers are d-pad neighbours")
	# Every dialog a page launcher opens.
	var seen_dialogs := {}
	for page in PAGES:
		await open_page(page)
		var launchers: Array = collect(ui, [], false).filter(func(control): return control is Button and not (control is OptionButton or control is CheckBox or control is CheckButton) and String(control.text) not in SKIP_LAUNCHERS)
		for launcher in launchers:
			if not is_instance_valid(launcher) or launcher.disabled:
				continue
			if not launcher.is_visible_in_tree():
				await open_page(page)
				if not launcher.is_visible_in_tree():
					continue
			var before := {}
			for window in windows(ui):
				before[window] = window.visible
			launcher.pressed.emit()
			await frames(4)
			# Layout adapters refit on a 0.1s timer; check the settled dialog.
			await create_timer(0.25).timeout
			await frames(2)
			for window in windows(ui):
				if window is AcceptDialog and window.visible and not before.get(window, false) and not seen_dialogs.has(window):
					seen_dialogs[window] = true
					dialogs += 1
					check(window.has_meta("dialog_focus_bridge"), "%s dialog '%s' is bridged" % [page, String(launcher.text)])
					dialog_reach(window, "%s dialog '%s'" % [page, String(launcher.text)])
			for window in windows(ui):
				if window.visible:
					window.hide()
			await frames(2)
	check(dialogs >= 15, "launcher sweep opened at least fifteen dialogs (%d)" % dialogs)
	# Dialogs owned by the level rather than the shell are bridged as well,
	# including ones created after startup (the map pin editor pattern).
	for name in ["MapPurchaseDialog"]:
		var owned: Node = world.find_child(name, true, false)
		check(owned != null and owned.has_meta("dialog_focus_bridge"), "level-owned %s is bridged" % name)
	await open_page("map")
	var editor := ConfirmationDialog.new()
	editor.name = "FixturePinEditor"
	world.map_panel.add_child(editor)
	var fields := VBoxContainer.new()
	editor.add_child(fields)
	var field := LineEdit.new()
	fields.add_child(field)
	var choice := OptionButton.new()
	choice.add_item("A")
	fields.add_child(choice)
	editor.popup_centered(Vector2i(420, 240))
	editor.get_cancel_button().grab_focus()
	await frames(4)
	check(editor.has_meta("dialog_focus_bridge"), "a dialog added under the map panel later is bridged")
	dialog_reach(editor, "level-owned map dialog")
	editor.hide()
	editor.queue_free()
	await frames(2)
	# Real joypad input: the danger-caption dialog opens on its safe Cancel
	# button and d-pad up now enters the options instead of staying put.
	await open_page("settings")
	danger.pressed.emit()
	await frames(4)
	var caption: ConfirmationDialog = null
	for window in windows(ui):
		if window is ConfirmationDialog and window.visible:
			caption = window
	check(caption != null and caption.gui_get_focus_owner() == caption.get_cancel_button(), "danger-caption dialog still opens on its keep-settings button")
	if caption != null:
		var up := InputEventJoypadButton.new()
		up.button_index = JOY_BUTTON_DPAD_UP
		up.pressed = true
		caption.push_input(up)
		var release: InputEventJoypadButton = up.duplicate()
		release.pressed = false
		caption.push_input(release)
		await frames(2)
		var focus: Control = caption.gui_get_focus_owner()
		check(focus != null and not (focus in BRIDGE.row_buttons(caption)), "joypad d-pad up leaves the button row for an option (%s)" % (focus.get_class() if focus else "none"))
		var down := InputEventJoypadButton.new()
		down.button_index = JOY_BUTTON_DPAD_DOWN
		down.pressed = true
		for step in 6:
			caption.push_input(down)
			var lift: InputEventJoypadButton = down.duplicate()
			lift.pressed = false
			caption.push_input(lift)
			await frames(2)
		check(caption.gui_get_focus_owner() in BRIDGE.row_buttons(caption), "joypad d-pad down returns from the options to the button row")
		caption.hide()
	# Dialogs opened from other dialogs (profile transfer, craft dependencies,
	# map checklist) are created with the shell or level and bridged as well.
	var unbridged: Array = world.find_children("*", "AcceptDialog", true, false).filter(func(dialog): return not dialog.has_meta("dialog_focus_bridge"))
	check(unbridged.is_empty(), "every dialog under the World is bridged (missing %s)" % ", ".join(unbridged.map(func(dialog): return String(dialog.name))))
	# A chained list taller than its ScrollContainer scrolls with the focus.
	var tall := ConfirmationDialog.new()
	ui.add_child(tall)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 120)
	tall.add_child(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	for index in 12:
		var row_button := Button.new()
		row_button.text = "row %d" % index
		row_button.custom_minimum_size = Vector2(320, 36)
		rows.add_child(row_button)
	tall.popup_centered(Vector2i(420, 260))
	tall.get_cancel_button().grab_focus()
	await frames(4)
	# Up from the buttons lands on the lowest row, below the visible area.
	await pad(tall, JOY_BUTTON_DPAD_UP, 1)
	var deep: Control = tall.gui_get_focus_owner()
	check(deep == rows.get_child(rows.get_child_count() - 1), "joypad d-pad up enters a clipped list at its last row (%s)" % (deep.name if deep else "none"))
	if deep != null:
		check(scroll.scroll_vertical > 0 and scroll.get_global_rect().grow(1.0).encloses(deep.get_global_rect()), "the focused clipped row is scrolled into view (%d px)" % scroll.scroll_vertical)
	await pad(tall, JOY_BUTTON_DPAD_UP, 11)
	var first: Control = tall.gui_get_focus_owner()
	check(first == rows.get_child(0) and scroll.scroll_vertical == 0, "walking up to the first row scrolls back to the top (%d px)" % scroll.scroll_vertical)
	await pad(tall, JOY_BUTTON_DPAD_DOWN, 12)
	check(tall.gui_get_focus_owner() in BRIDGE.row_buttons(tall), "d-pad down past the last row returns to the button row")
	tall.hide()
	tall.queue_free()
	# A native list keeps up/down for its own selection; past its last item
	# d-pad down still leaves it for the button row.
	var listed := ConfirmationDialog.new()
	ui.add_child(listed)
	var items := ItemList.new()
	items.custom_minimum_size = Vector2(320, 120)
	for index in 3:
		items.add_item("item %d" % index)
	listed.add_child(items)
	listed.popup_centered(Vector2i(400, 260))
	listed.get_cancel_button().grab_focus()
	await frames(4)
	await pad(listed, JOY_BUTTON_DPAD_UP, 1)
	check(listed.gui_get_focus_owner() == items, "d-pad up from the button row enters the list")
	await pad(listed, JOY_BUTTON_DPAD_DOWN, 4)
	check(listed.gui_get_focus_owner() in BRIDGE.row_buttons(listed), "d-pad down through the list's last item returns to the button row")
	listed.hide()
	listed.queue_free()
	world._close_overlays()
	await frames(2)
	world.queue_free()
	await frames(3)
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("dialog_dpad_focus.json"):
			DirAccess.remove_absolute("user://" + name)
	print("DIALOG_DPAD_FOCUS checks=%d dialogs=%d failures=%d" % [checks, dialogs, failures])
	quit(0 if failures == 0 else 1)
