extends SceneTree
## U01: on the four main pages (and the backpack journal view) every visible
## text uses the shared type scale
## and fits the control it is drawn in. Production World pages at 1280x720.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const TYPE := preload("res://scripts/ui_type_scale.gd")
const UI := preload("res://scripts/pilgrimage_interface.gd")
const FIXTURE := preload("res://scripts/build_slots_ui_validation.gd")
const PAGES := ["backpack", "journal", "build", "map", "settings"]
## The page overlays themselves; the HUD behind a page is not part of it.
const ROOTS := {"backpack": "BackpackOverlay", "journal": "BackpackOverlay", "build": "BuildOverlay", "map": "CourtMapOverlay", "settings": "AudioSettingsOverlay"}
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
		# An OptionButton also draws its dropdown arrow inside the same box.
		if control is OptionButton:
			var arrow: Texture2D = control.get_theme_icon("arrow")
			padding += (arrow.get_width() if arrow != null else 0.0) + control.get_theme_constant("arrow_margin")
	return width + padding > control.size.x + 1.0

func audit(name: String, page_root: Node) -> void:
	var off_scale: Array = []
	var clipped: Array = []
	var seen := {}
	for control in texts(page_root, []):
		var size := size_of(control)
		seen[size] = int(seen.get(size, 0)) + 1
		if not TYPE.SCALE.has(size):
			off_scale.append(describe(control))
		if overflows(control):
			clipped.append(describe(control))
	report[name] = {"sizes": seen, "off_scale": off_scale, "clipped": clipped}
	check(not seen.is_empty(), "%s shows text" % name)
	check(off_scale.is_empty(), "%s uses only the shared type scale (off: %s)" % [name, off_scale])
	check(clipped.is_empty(), "%s text fits its controls (clipped: %s)" % [name, clipped])

func entry(id: String, title: String, family: String) -> Dictionary:
	return {"id": id, "name": title, "slot_family": family, "unlocked": true, "description": "已知装备说明", "cost": 1}

func slot(family: String, index: int, allowed: Array) -> Dictionary:
	return {"id": family + str(index), "family": family, "index": index, "compatible": allowed, "unlocked": true, "equipped_id": ""}

## The shrine workbench equipment page, opened at a workstation on the shared
## build-slot fixture (the World build page outside a shrine has no catalog).
func equipment_page() -> void:
	var runtime := FIXTURE.MockRuntime.new()
	runtime.player = FIXTURE.MockPlayer.new()
	runtime.add_child(runtime.player)
	runtime.build_system = FIXTURE.MockBuild.new()
	runtime.world_narrative = FIXTURE.MockNarrative.new()
	var skills := [entry("cleave", "裂斩", "thread_skill"), entry("needle", "丝针", "thread_skill")]
	var tools := [entry("shard", "碎片", "tool"), entry("mine", "线雷", "tool")]
	runtime.build_system.snapshot = {"at_workstation": true, "slots_used": 0, "slots_total": 3,
		"skills": skills, "tools": tools, "passive_options": [], "crests": [],
		"slot_layout": {"thread_skill": [slot("thread_skill", 0, ["cleave", "needle"])], "tool": [slot("tool", 0, ["shard", "mine"])],
			"combat_accessory": [slot("combat_accessory", 0, ["mender"])], "travel_accessory": [slot("travel_accessory", 0, ["wayfinder"])]},
		"slot_families": {"thread_skill": {"id": "thread_skill", "name": "绯线技", "options": skills},
			"tool": {"id": "tool", "name": "战具", "options": tools},
			"combat_accessory": {"id": "combat_accessory", "name": "战斗铭饰", "options": [entry("mender", "愈线铭饰", "combat_accessory")]},
			"travel_accessory": {"id": "travel_accessory", "name": "行旅铭饰", "options": [entry("wayfinder", "引路铭饰", "travel_accessory")]}}}
	root.add_child(runtime)
	var ui := UI.new()
	ui.accessibility_path = "user://page_type_scale_fixture.cfg"
	runtime.add_child(ui)
	ui.bind(runtime)
	ui.set_process(false)
	for category in ["技能", "战具"]:
		ui.build_panel.show()
		ui.build_category = category
		ui.refresh_build()
		await frames(3)
		audit("equipment " + category, ui.build_panel)
	runtime.queue_free()
	await frames(2)
	if FileAccess.file_exists("user://page_type_scale_fixture.cfg"):
		DirAccess.remove_absolute("user://page_type_scale_fixture.cfg")

func open_page(page: String) -> void:
	world._close_overlays()
	await frames(2)
	match page:
		"backpack": world._toggle_backpack()
		"journal":
			# The backpack's journal view: filters, search, sort and read marks.
			world._toggle_backpack()
			await frames(2)
			world.ui_shell.bag_category = "旅记"
			world.ui_shell.refresh_inventory()
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
	# The map pin selector's prompt at its widest count, arrow included.
	await open_page("map")
	var pin_list := world.find_child("PinList", true, false) as OptionButton
	check(pin_list != null and pin_list.item_count > 0, "map pin selector is built")
	if pin_list != null and pin_list.item_count > 0:
		var limit: int = preload("res://scripts/map_player_pins.gd").LIMIT
		var prompt := pin_list.get_item_text(0)
		pin_list.set_item_text(0, "图钉 %d / %d" % [limit, limit])
		pin_list.select(0)
		check(not overflows(pin_list), "a full pin selector prompt fits beside its arrow (%s)" % describe(pin_list))
		pin_list.set_item_text(0, prompt)
	# The journal/item reading body follows the reading size (U05).
	var ui: Control = world.ui_shell
	var body_sizes := {}
	for reading in [17, 21, 26]:
		ui.accessibility["subtitle_size"] = reading
		ui._apply_accessibility()
		body_sizes[reading] = ui.bag_description.get_theme_font_size("normal_font_size")
	report["journal_body_reading"] = body_sizes
	check(body_sizes[21] == TYPE.ACTION, "journal body keeps its authored size at the default reading size (%d)" % body_sizes[21])
	check(body_sizes[17] < body_sizes[21] and body_sizes[21] < body_sizes[26], "journal body follows the reading size (%s)" % body_sizes)
	ui.accessibility["subtitle_size"] = 21
	ui._apply_accessibility()
	world._close_overlays()
	await frames(2)
	world.queue_free()
	await frames(3)
	await equipment_page()
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
