extends SceneTree
## U01/U06: every dialog a page launcher opens fits the 1280x720 logical screen
## (stretch "expand" never shows less height) with its button row inside the
## window, at both the smallest and the largest reading size.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const PAGES := ["backpack", "build", "map", "settings"]
const SKIP_LAUNCHERS := ["返回", "关闭", "返回游戏"]
var checks := 0
var failures := 0
var world: Node
var dialogs := 0
var text_sizes := {}

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

func launchers(node: Node, out: Array) -> Array:
	for child in node.get_children():
		if child is Window:
			continue
		if child is Button and not (child is OptionButton or child is CheckBox or child is CheckButton) and child.is_visible_in_tree() and not child.disabled and String(child.text) not in SKIP_LAUNCHERS:
			out.append(child)
		launchers(child, out)
	return out

## Single-line labels and buttons whose text is wider than the control.
func clipped_text(node: Node, out: Array) -> Array:
	for child in node.get_children():
		if child is Window or (child is CanvasItem and not child.is_visible_in_tree()):
			continue
		if (child is Label or child is Button) and not String(child.text).strip_edges().is_empty() \
				and not String(child.text).contains("\n") and not (child is Label and child.autowrap_mode != TextServer.AUTOWRAP_OFF):
			var size: int = child.get_theme_font_size("font_size")
			var width: float = child.get_theme_font("font").get_string_size(String(child.text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if child is Button:
				var style: StyleBox = child.get_theme_stylebox("normal")
				if style != null:
					width += style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
				if child.icon != null:
					width += child.icon.get_width()
			if width > child.size.x + 1.0:
				out.append("%s '%s'" % [child.get_class(), String(child.text).left(20)])
		clipped_text(child, out)
	return out

## Largest font among the dialog's visible text, as the body a player reads.
func text_size(node: Node) -> int:
	var largest := 0
	for child in node.get_children():
		if child is Window or (child is CanvasItem and not child.is_visible_in_tree()):
			continue
		if child is RichTextLabel and not String(child.get_parsed_text()).strip_edges().is_empty():
			largest = maxi(largest, child.get_theme_font_size("normal_font_size"))
		elif child is Label and not String(child.text).strip_edges().is_empty():
			largest = maxi(largest, child.get_theme_font_size("font_size"))
		largest = maxi(largest, text_size(child))
	return largest

func windows(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Window:
			out.append(child)
		out.append_array(windows(child))
	return out

func open_page(page: String) -> void:
	world._close_overlays()
	await frames(2)
	match page:
		"backpack": world._toggle_backpack()
		"build": world._toggle_build()
		"map": world._toggle_map()
		"settings": world._toggle_audio_settings()
	await frames(4)

func sweep(reading: int) -> void:
	var ui: Control = world.ui_shell
	ui.accessibility["subtitle_size"] = reading
	ui._apply_accessibility()
	await frames(2)
	var screen: Rect2 = root.get_visible_rect()
	var seen := {}
	for page in PAGES:
		await open_page(page)
		for launcher in launchers(ui, []):
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
			await frames(5)
			for window in windows(ui):
				if window is AcceptDialog and window.visible and not before.get(window, false) and not seen.has(window):
					seen[window] = true
					dialogs += 1
					var rect := Rect2(Vector2(window.position), Vector2(window.size))
					var label := "reading %d %s dialog '%s'" % [reading, page, String(launcher.text)]
					text_sizes["%s:%s|%d" % [page, String(launcher.text), reading]] = text_size(window)
					var cut := clipped_text(window, [])
					check(cut.is_empty(), label + " shows its single-line texts whole (cut: %s)" % [cut])
					check(screen.encloses(rect), label + " fits the screen (%s in %s)" % [rect, screen])
					var inside := Rect2(Vector2.ZERO, Vector2(window.size))
					for button in window.get_ok_button().get_parent().get_children(true):
						if button is BaseButton and button.is_visible_in_tree():
							check(inside.encloses(button.get_global_rect()), label + " keeps its '%s' button inside the window" % String(button.text))
			for window in windows(ui):
				if window.visible:
					window.hide()
			await frames(2)

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	world = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://dialog_viewport_fit.json"
	root.add_child(world)
	await READY.wait_for(world)
	await frames(6)
	check(root.get_visible_rect().size == Vector2(1280, 720), "fixture uses the 1280x720 logical screen")
	for reading in [17, 26]:
		await sweep(reading)
	check(dialogs >= 30, "both sweeps opened the page dialogs (%d)" % dialogs)
	# U01/U05: the reading size reaches every page dialog, not only the forms
	# that already had a layout adapter.
	var compared := 0
	for key in text_sizes:
		if not String(key).ends_with("|17"):
			continue
		var name := String(key).trim_suffix("|17")
		if not text_sizes.has(name + "|26") or int(text_sizes[key]) <= 0:
			continue
		compared += 1
		check(int(text_sizes[name + "|26"]) > int(text_sizes[key]), "dialog '%s' text follows the reading size (%d at 17, %d at 26)" % [name, text_sizes[key], text_sizes[name + "|26"]])
	check(compared >= 15, "reading size compared on the page dialogs (%d)" % compared)
	print("DIALOG_READING_COMPARED %d" % compared)
	world._close_overlays()
	await frames(2)
	world.queue_free()
	await frames(3)
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("dialog_viewport_fit.json"):
			DirAccess.remove_absolute("user://" + name)
	print("DIALOG_VIEWPORT_FIT checks=%d dialogs=%d failures=%d" % [checks, dialogs, failures])
	quit(0 if failures == 0 else 1)
