extends SceneTree
## U04: large rooms are charted one screen-sized section at a time.
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")
const PINS := preload("res://scripts/map_player_pins.gd")
const SAVE := "user://survey_room_segments_validation.json"
const SHAFT := "bell_stair_well"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	_check_rules()
	await _check_world()
	print("SURVEY_ROOM_SEGMENTS checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_rules() -> void:
	var small := {"id": "small", "layout_rect": [0, 0, 1800, 1000]}
	var shaft := {"id": "shaft", "layout_rect": [100, 200, 470, 2534]}
	var hall := {"id": "hall", "layout_rect": [0, 0, 1600, 2026]}
	check(JOURNAL.segments(small).is_empty(), "a room up to 1.5 screens each way is charted whole")
	var cells := JOURNAL.segments(shaft)
	check(cells.size() == 4, "a 2534-tall shaft is noted in four sections")
	var cover := cells[0]
	for cell in cells: cover = cover.merge(cell)
	check(cover.is_equal_approx(Rect2(100, 200, 470, 2534)), "sections exactly cover the room")
	check(JOURNAL.segments(hall).size() == 6, "a 1600x2026 hall is noted as 2x3 sections")
	var flags := {}
	JOURNAL.region(flags, "r").owned = true
	JOURNAL.visit_at(flags, "r", shaft, Vector2(300, 250))
	var journal := JOURNAL.region(flags, "r")
	check(journal.pending.has("shaft@0") and not journal.pending.has("shaft"), "walking the top of a shaft notes only its top section")
	check(not JOURNAL.charted(flags, "r", "shaft"), "a noted section is not charted before resting")
	JOURNAL.grant_quill(flags)
	check(JOURNAL.rest(flags) == 1, "a rest charts the noted section")
	check(JOURNAL.charted(flags, "r", "shaft") and not JOURNAL.charted_whole(flags, "r", shaft), "the shaft is partly on the map")
	var parts := JOURNAL.charted_parts(flags, "r", shaft)
	check(parts.size() == 1 and parts[0].is_equal_approx(cells[0]), "only the explored section is charted")
	check(JOURNAL.charted_at(flags, "r", shaft, Vector2(300, 300)) and not JOURNAL.charted_at(flags, "r", shaft, Vector2(300, 2600)), "points answer by their own section")
	JOURNAL.visit_at(flags, "r", small, Vector2(10, 10))
	check(JOURNAL.region(flags, "r").pending.has("small"), "small rooms keep whole-room notes")
	for cell in cells: JOURNAL.visit_at(flags, "r", shaft, cell.get_center())
	JOURNAL.rest(flags)
	check(JOURNAL.charted_whole(flags, "r", shaft) and JOURNAL.charted_parts(flags, "r", shaft).size() == 1, "every section charted draws the whole room once")
	check(JOURNAL.charted_room_count(flags, "r") == 2, "the room count counts a sectioned room once")
	var legacy := {}
	JOURNAL.region(legacy, "r").owned = true
	JOURNAL.region(legacy, "r").charted["shaft"] = true
	check(JOURNAL.charted_whole(legacy, "r", shaft), "older saves that charted the whole room keep it whole")
	JOURNAL.visit_at(legacy, "r", shaft, Vector2(300, 2600))
	check(JOURNAL.region(legacy, "r").pending.is_empty(), "a charted room takes no new section notes")
	var malformed := {JOURNAL.KEY: {"r": {"owned": true, "charted": {"shaft@0": "yes", 5: true}}}}
	var before := var_to_str(malformed)
	check(JOURNAL.charted_parts(malformed, "r", shaft).is_empty() and not JOURNAL.charted_at(malformed, "r", shaft, Vector2(300, 300)), "malformed notes chart nothing")
	check(var_to_str(malformed) == before, "reading sections never repairs a save")

func _check_world() -> void:
	var scene: Node = load("res://scenes/World.tscn").instantiate()
	scene.world_save_path = SAVE
	scene.world_resume = false
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	scene.set_process(false)
	scene.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	var id := String(scene.config.id)
	var room := {}
	for value in scene.config.get("map_rooms", []):
		if String(value.get("id", "")) == SHAFT: room = value
	check(not room.is_empty(), "the moss bell court still has its bell stair well")
	if room.is_empty():
		scene.queue_free()
		return
	var cells := JOURNAL.segments(room)
	check(cells.size() == 4, "the bell stair well is a four-section shaft")
	var points: Array[Vector2] = []
	for cell in cells: points.append(_own_point(scene, cell))
	check(points.all(func(p: Vector2): return p.is_finite()), "each section has ground owned by the shaft itself")
	JOURNAL.region(scene.story_flags, id).owned = true
	JOURNAL.grant_quill(scene.story_flags)
	scene.player.global_position = points[0]
	scene._update_room_visit()
	var journal := JOURNAL.region(scene.story_flags, id)
	check(journal.pending.has(SHAFT + "@0") and not journal.pending.has(SHAFT), "the live room tracker notes the section the player stands in")
	JOURNAL.rest(scene.story_flags)
	var outside := points[2]
	check(PINS.allowed(scene.story_flags, id, scene.config, points[0]) and not PINS.allowed(scene.story_flags, id, scene.config, outside), "player pins go only on the charted section")
	check(not KNOWLEDGE.visible(scene.story_flags, id, scene.config, Rect2(outside, Vector2.ONE)), "features in an uncharted section stay hidden")
	var drawn := await _sections_drawn(scene)
	check(drawn.sections == 1 and drawn.charted, "the survey map inks one section of the shaft")
	check(absf(drawn.height_ratio - 0.25) < 0.01, "the inked section is a quarter of the shaft's height")
	scene.player.global_position = points[3]
	scene._update_room_visit()
	JOURNAL.rest(scene.story_flags)
	drawn = await _sections_drawn(scene)
	check(drawn.sections == 2, "walking the bottom adds the bottom section")
	for point in points:
		scene.player.global_position = point
		scene._update_room_visit()
	JOURNAL.rest(scene.story_flags)
	drawn = await _sections_drawn(scene)
	check(drawn.sections == 0 and drawn.charted and absf(drawn.height_ratio - 1.0) < 0.01, "a fully walked shaft is inked whole")
	scene.queue_free()
	await process_frame

## A point of the section that the live room lookup assigns to the shaft (not a
## nested pocket), on the section's grid so the probe is deterministic.
func _own_point(scene: Node, cell: Rect2) -> Vector2:
	for row in range(1, 8):
		for col in range(1, 4):
			var point := cell.position + cell.size * Vector2(col / 4.0, row / 8.0)
			if String(scene._room_for_position(point).get("id", "")) == SHAFT: return point
	return Vector2.INF

func _sections_drawn(scene: Node) -> Dictionary:
	scene._close_overlays()
	await process_frame
	scene._toggle_map()
	await process_frame
	var outline: Control = scene.map_draw_root.get_node_or_null("SurveyRoom_" + SHAFT)
	var surface = scene.map_draw_root.get_node_or_null("SurveySilhouette")
	var result := {"sections": -1, "charted": false, "height_ratio": 0.0}
	if outline == null or surface == null: return result
	result.sections = int(outline.get_meta("charted_sections", -1))
	result.charted = bool(outline.get_meta("charted", false))
	# Inked height inside the shaft's own column, over the shaft's map height.
	var inked := 0.0
	var column := Rect2(outline.position, outline.size)
	for rect: Rect2 in surface.charted_rooms:
		if column.grow(0.5).encloses(rect) and absf(rect.size.x - column.size.x) < 0.5: inked += rect.size.y
	result.height_ratio = inked / column.size.y if column.size.y > 0 else 0.0
	scene._close_overlays()
	return result
