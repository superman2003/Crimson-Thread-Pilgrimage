extends SceneTree
## N05: the main line is traceable in the journal before any choice, and the
## chosen ending visibly changes every region's main shrine. Chosen through the
## real ending gate; each scene stands on walkable floor, is noticed once, is
## listed in the journal, and survives a restart.
const ROUTES := preload("res://scripts/world_routes.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const WORLD := preload("res://scripts/world_state.gd")
const SAVE := "user://ending_aftermath_validation.json"
const CROWN := "demo_ch06_silent_crown_core"
const COURT := "demo_ch01_moss_bell_court"
var scene: Node
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func tick(count: int = 1) -> void:
	for unused in count:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS " + label)

func clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".previous"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func boot(resume: bool) -> void:
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = resume
	scene.world_save_path = SAVE
	root.add_child(scene)
	current_scene = scene
	await READY.wait_for(scene)
	await tick(4)
	scene.player.debug_invulnerable = true

func retire() -> void:
	scene._close_overlays()
	AUDIO.retire_tree(scene)
	scene.queue_free()
	await tick(6)

func travel(region: String) -> void:
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
	scene._travel_world(ROUTES.config_path(region), Vector2(config.player_start[0], config.player_start[1]))
	await tick(12)
	scene.player.debug_invulnerable = true

func aftermath() -> Node2D:
	var node: Node = scene.get_node_or_null("EndingAftermath")
	return node if node is Node2D else null

func main_step(index: int) -> Dictionary:
	return scene.world_narrative.evaluate_progress(scene.inventory_counts, scene.story_flags).main_line.steps[index]

## Drop the player just above the scene: it must land on floor right there.
func stands_on_floor(node: Node2D) -> bool:
	scene.player.global_position = node.global_position + Vector2(0, -60)
	scene.player.set("velocity", Vector2.ZERO)
	for frame in 90:
		await tick(1)
		if scene.player.is_on_floor():
			break
	return scene.player.is_on_floor() and absf(scene.player.global_position.y - node.global_position.y) < 48.0

func run() -> void:
	clean()
	await boot(false)
	var narrative: RefCounted = scene.world_narrative

	# --- Before the choice: the main line is the first journal record. ---
	scene.ui_shell.bag_category = "旅记"
	scene.ui_shell.refresh_inventory()
	await tick(2)
	var first: Button = null
	for child in scene.ui_shell.bag_grid.get_children():
		if child is Button:
			first = child
			break
	check(first != null and String(first.text).begins_with("失声契约") and String(first.text).contains("主线"), "the journal opens on the main line")
	check(String(scene.ui_shell.bag_description.text).contains("五区守门者：已击败 0 / 5") and String(scene.ui_shell.bag_description.text).contains("证词：已取得 0 / 6"), "the main line counts guardians and testimonies")
	for index in range(1, 4):
		scene.story_flags["boss_down_ch%02d" % index] = true
	check(String(main_step(0).label).contains("已击败 3 / 5") and not String(main_step(0).label).contains("断弦温室") and not bool(main_step(0).complete), "guardians are counted without naming unreached regions")
	check(aftermath() == null and narrative.aftermath_scene(COURT, scene.story_flags).is_empty(), "no shrine changes before an ending is chosen")

	# --- Choose 断冠 at the real gate behind the crown. ---
	for index in range(1, 7):
		scene.story_flags["boss_down_ch%02d" % index] = true
	await travel(CROWN)
	scene._spawn_ending_gates()
	await tick(2)
	var gate: Area2D = null
	for child in scene.get_children():
		if child is Area2D and String(child.get_meta("kind", "")) == "ending_gate" and String(child.get_meta("ending", "")) == "ending_b":
			gate = child
	check(gate != null, "the 断冠 gate stands behind the crown")
	scene.player.global_position = gate.global_position
	await tick(4)
	scene._activate_ending_gate(gate)
	await tick(4)
	check(String(scene.story_flags.get("ending_chosen", "")) == "ending_b", "the gate commits 断冠")
	var here := aftermath()
	check(here != null and here.look == "barrier", "the crown shrine changes the moment the ending is chosen")
	check(bool(main_step(3).complete) and String(main_step(3).label).contains("断冠"), "the main line records the choice")
	check(await stands_on_floor(here), "the crown aftermath stands on walkable floor")
	check(bool(scene.story_flags.get("aftermath_seen_ch06_silent_crown_core", false)) and String(scene.lore_banner_label.text).contains("无声王冠 · ") and String(scene.lore_banner_label.text).contains("钟壳裂开"), "coming near shows what changed in the story banner")
	check(String(scene.toast_label.text).contains("按 F") and scene.lore_banner_label.visible, "the shrine prompt does not cover it")
	scene.lore_banner_label.text = ""
	scene.player.global_position += Vector2(10, 0)
	await tick(10)
	check(not String(scene.lore_banner_label.text).contains("钟壳裂开"), "the notice does not repeat")

	# --- Every other region shows the same ending, on its own floor. ---
	for region in ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road"]:
		await travel(region)
		var node := aftermath()
		var expected: Dictionary = narrative.aftermath_scene(region, scene.story_flags)
		check(node != null and node.look == "barrier" and String(expected.get("ending", "")) == "ending_b", region + " shows the 断冠 change at its shrine")
		if node != null:
			check(await stands_on_floor(node), region + " aftermath stands on walkable floor")
	check(bool(scene.story_flags.get("aftermath_seen_ch05_obsidian_pilgrim_road", false)), "the last region visited was noticed too")

	# --- The journal lists every region's change under the chosen ending. ---
	scene.story_flags.erase("aftermath_seen_ch03_saltwhite_archive")
	var rows: Array = []
	for ending in narrative.evaluate_progress(scene.inventory_counts, scene.story_flags).endings:
		if bool(ending.get("chosen", false)):
			rows = ending.get("aftermath_rows", [])
			scene.ui_shell._show_journal_record(ending.merged({"record_kind": "ending"}))
	check(rows.size() == 6, "the chosen ending lists all six regions")
	var text := String(scene.ui_shell.bag_description.text)
	check(text.contains("各地变化") and text.contains("● 铸雨渠") and text.contains("○ 盐白书库：回到那里的钟龛看看"), "seen changes are told, unseen ones say where to look")

	# --- A restart keeps the ending's world. ---
	scene.story_flags["aftermath_seen_ch03_saltwhite_archive"] = true
	await travel(COURT)
	check(scene._save_world(), "the world saves")
	await retire()
	await boot(true)
	var again := aftermath()
	check(String(scene.config.get("id", "")) == COURT and again != null and again.look == "barrier", "after a restart the court shrine still shows 断冠")
	check(bool(scene.story_flags.get("aftermath_seen_ch01_moss_bell_court", false)), "seen changes stay seen")

	# --- The other endings change the same shrines differently. ---
	for pair in [["ending_a", "bells", "小钟又按时响了"], ["ending_c", "names", "轮值牌"]]:
		var flags := {"ending_chosen": pair[0], pair[0] + "_done": true, "boss_down_ch06": true}
		var variant: Dictionary = narrative.aftermath_scene(COURT, flags)
		check(String(variant.get("look", "")) == pair[1] and String(variant.get("line", "")).contains(pair[2]), "%s gives the court its own change" % pair[0])
	await retire()
	clean()
	check(await AUDIO.drain(self), "the fixture releases playback")
	print("ENDING_AFTERMATH checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
