extends SceneTree
## U01: on the four main pages every visible text uses the shared type scale
## and fits the control it is drawn in. Production World pages at 1280x720.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const TYPE := preload("res://scripts/ui_type_scale.gd")
const PAGES := ["backpack", "build", "map", "settings"]
## The page overlays themselves; the HUD behind a page is not part of it.
const ROOTS := {"backpack": "BackpackOverlay", "build": "BuildOverlay", "map": "CourtMapOverlay", "settings": "AudioSettingsOverlay"}
var checks := 0
var failures: Array[String] = []
var world: Node
var report := {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func frames(count: int) -> void:
	for index in count:
		await process_frame

func texts(node: Node, out: Array) -> Array:
	for child in node.get_children():
		if child is Window or (child is CanvasItem and not child.is_visible_in_tree()):
			continue
		if child is RichTextLabel and not String(child.get_parsed_text()).strip_edges().is_empty():
			out.append(child)
		elif (child is Label or child is Button) and not String(child.text).strip_edges().is_empty():
			out.append(child)
		texts(child, out)
	return out

func size_of(control: Control) -> int:
	return control.get_theme_font_size("normal_font_size") if control is RichTextLabel else control.get_theme_font_size("font_size")

func describe(control: Control) -> String:
	var text := String(control.get_parsed_text() if control is RichTextLabel else control.text).replace("\n", " ")
	return "%s '%s' (%d) at %s" % [control.get_class(), text.left(16), size_of(control), String(control.get_path()).get_slice("/", -1)]

## Single-line labels and buttons must show their whole text.
func overflows(control: Control) -> bool:
	if control is RichTextLabel:
		return false
	if control is Label and (control.autowrap_mode != TextServer.AUTOWRAP_OFF or control.text.contains("\n")):
		return false
	if control is Button and control.text.contains("\n"):
		return false
	var font: Font = control.get_theme_font("font")
	var width := font.get_string_size(String(control.text), HORIZONTAL_ALIGNMENT_LEFT, -1, size_of(control)).x
	var padding := 0.0
	if control is Button:
		var style: StyleBox = control.get_theme_stylebox("normal")
		padding = style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT) if style != null else 0.0
		if control.icon != null:
			padding += control.icon.get_width()
	return width + padding > control.size.x + 1.0

func open_page(page: String) -> void:
	world._close_overlays()
	await frames(2)
	match page:
		"backpack": world._toggle_backpack()
		"build": world._toggle_build()
		"map": world._toggle_map()
		"settings": world._toggle_audio_settings()
	await frames(6)

func run() -> void:
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://page_type_scale.json"
	root.add_child(world)
	await READY.wait_for(world)
	await frames(6)
	for page in PAGES:
		await open_page(page)
		var off_scale: Array = []
		var clipped: Array = []
		var seen := {}
		var page_root: Node = world.find_child(String(ROOTS[page]), true, false)
		check(page_root != null and page_root.is_visible_in_tree(), "%s page overlay is open" % page)
		if page_root == null:
			continue
		for control in texts(page_root, []):
			var size := size_of(control)
			seen[size] = int(seen.get(size, 0)) + 1
			if not TYPE.SCALE.has(size):
				off_scale.append(describe(control))
			if overflows(control):
				clipped.append(describe(control))
		report[page] = {"sizes": seen, "off_scale": off_scale, "clipped": clipped}
		check(not seen.is_empty(), "%s page shows text" % page)
		check(off_scale.is_empty(), "%s page uses only the shared type scale (off: %s)" % [page, off_scale])
		check(clipped.is_empty(), "%s page text fits its controls (clipped: %s)" % [page, clipped])
	world._close_overlays()
	await frames(2)
	world.queue_free()
	await frames(3)
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("page_type_scale.json"):
			DirAccess.remove_absolute("user://" + name)
	print("PAGE_TYPE_SCALE_REPORT ", JSON.stringify(report))
	if failures.is_empty():
		print("PAGE_TYPE_SCALE_PASS checks=%d" % checks)
	else:
		for label in failures:
			push_error(label)
		print("PAGE_TYPE_SCALE_FAIL failures=%d checks=%d" % [failures.size(), checks])
	call_deferred("quit", 0 if failures.is_empty() else 1)
