extends SceneTree
## T02: what the real World does with saves it cannot load as they are. A damaged
## save says whether its backup can bring the journey back, and the restore
## button does; a build naming equipment this version lacks is rebuilt from
## story progress instead of pausing autosave; a save in a region this version
## no longer routes resumes at the route start; old v1 / v2 files load and keep
## saving; starting new journeys never overwrites an earlier preserved one.
const WORLD := preload("res://scripts/world_state.gd")
const BUILD := preload("res://scripts/build_system.gd")
const MAIN := preload("res://scripts/main_level.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const SAVE := "user://save_recovery_validation.json"
const START := "demo_ch01_moss_bell_court"
const RAIN := "demo_ch02_rain_foundry_canal"
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
	var dir := DirAccess.open("user://")
	for name in dir.get_files():
		if name.begins_with(SAVE.get_file()):
			dir.remove(name)

func write_raw(text: String, path: String = SAVE) -> void:
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(text)
	handle.close()

func preserved(label: String) -> Array:
	var found: Array = []
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with(SAVE.get_file() + "." + label + "_"):
			found.append("user://" + name)
	return found

## A mid-journey save: 司铸 repaired, a combat charm worn, a trained skill, a loadout.
func journey(currency: int = 140) -> Dictionary:
	var build := BUILD.new()
	# The smith's badge repair grants 司铸 together with the trip nails.
	for event in ["repair_bell", "tool_mine_found", "charm_shell_found", "skill_ward_learned"]:
		build.unlock_event(event)
	build.switch_crest("bell")
	build.select_tool("mine", 0)
	build.equip_family_slot("shell", "combat_accessory", 0)
	build.state.skill_levels["ward"] = 1
	build.save_loadout("守钟")
	var world := WORLD.new()
	world.capture_global({"currency": currency, "story_flags": {"seal_bell_repaired": true, "tool_mine_found": true, "charm_shell_found": true, "skill_ward_learned": true},
		"inventory_counts": {"moss_chitin": 2}, "build_state": build.serialize(), "current_region": START, "entry": [600, 3000]})
	world.capture_region(RAIN, {"visited_rooms": {"upper_sluice": true}, "boss_defeated": true, "checkpoint": [1830, 3340]})
	return world.data

func boot() -> Node:
	var scene: Node = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = true
	scene.world_save_path = SAVE
	root.add_child(scene)
	current_scene = scene
	await READY.wait_for(scene)
	await tick(4)
	return scene

func retire(scene: Node) -> void:
	scene._close_overlays()
	AUDIO.retire_tree(scene)
	scene.queue_free()
	await tick(6)

func run() -> void:
	clean()
	await damaged_with_backup()
	clean()
	await damaged_without_backup()
	clean()
	await unknown_build_entries()
	clean()
	await removed_region()
	clean()
	await old_versions()
	clean()
	new_journeys()
	clean()
	check(await AUDIO.drain(self), "the fixture releases playback")
	print("SAVE_RECOVERY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func damaged_with_backup() -> void:
	write_raw(JSON.stringify(journey()), SAVE + ".bak")
	write_raw("{\"version\": 3, \"currency\": ")
	var scene := await boot()
	check(String(scene.world_initial_error).contains("找到可用备份") and String(scene.world_initial_error).contains("140 碎钱") and String(scene.world_initial_error).contains("恢复当前槽备份"), "a damaged save names its usable backup and where to restore it")
	check(not scene._save_world() and FileAccess.get_file_as_string(SAVE) == "{\"version\": 3, \"currency\": ", "the damaged file is never overwritten")
	check(scene.restore_save_backup(), "the settings restore button accepts the backup")
	await tick(2)
	var restored: Node = current_scene
	await READY.wait_for(restored)
	await tick(4)
	check(restored != scene and restored.currency_count == 140 and restored.build_system.state.crest == "bell" and restored.build_system.state.passives.has("shell"), "the restored journey has its shards, crest and charm back")
	check(restored.world_state.get_region(RAIN).boss_defeated and restored.world_initial_error.is_empty(), "other regions' progress comes back and no warning remains")
	check(preserved("before_restore").size() == 1 and FileAccess.get_file_as_string(preserved("before_restore")[0]) == "{\"version\": 3, \"currency\": ", "the damaged original is kept byte for byte")
	check(restored._save_world(), "autosave works again after the restore")
	await retire(restored)

func damaged_without_backup() -> void:
	write_raw("not json")
	write_raw("also not json", SAVE + ".bak")
	var scene := await boot()
	check(String(scene.world_initial_error).contains("备份也无法读取") and FileAccess.get_file_as_string(SAVE) == "not json", "with no usable backup the message says so and the file stays")
	await retire(scene)

func unknown_build_entries() -> void:
	var data := journey()
	# Names a later or renamed version would write: an unknown charm (also worn and
	# in a loadout) and an unknown crest mechanism.
	data.build_state.unlocked_passives.append("wayfinder")
	data.build_state.equipped_families.travel_accessory[0] = "wayfinder"
	data.build_state.loadouts["旧方案"] = data.build_state.loadouts["守钟"].duplicate(true)
	data.build_state.loadouts["旧方案"].equipped_families.travel_accessory[0] = "wayfinder"
	data.build_state.mechanisms.append("lantern")
	var original := JSON.stringify(data)
	write_raw(original)
	check(not BUILD.new().restore(data.build_state).ok, "fixture: this build is rejected as it stands")
	var scene := await boot()
	var build: RefCounted = scene.build_system
	check(not scene.world_save_blocked, "autosave keeps running")
	check(String(scene.world_initial_error).contains("按剧情进度重建构筑") and String(scene.world_initial_error).contains("wayfinder"), "the player is told the build was rebuilt and what could not be kept")
	check(build.state.unlocked_crests.has("bell") and build.state.crest == "bell" and build.state.mechanisms.has("bell"), "the repaired crest and its mechanism come back")
	check(build.state.passives.has("shell") and int(build.state.skill_levels.ward) == 1, "the worn charm and the trained direction are kept")
	check(build.state.loadouts.has("守钟") and not build.state.loadouts.has("旧方案"), "a valid loadout is kept, one naming the unknown charm is dropped")
	check(not build.state.unlocked_passives.has("wayfinder") and not build.state.mechanisms.has("lantern"), "unknown entries are dropped")
	var copies := preserved("before_build_repair")
	check(copies.size() == 1 and FileAccess.get_file_as_string(copies[0]) == original, "the original save is kept byte for byte before any write")
	check(scene._save_world(), "the rebuilt journey saves")
	await retire(scene)
	var again := await boot()
	check(again.world_initial_error.is_empty() and again.build_system.state.passives.has("shell") and preserved("before_build_repair").size() == 1, "the next launch loads cleanly with no second repair")
	await retire(again)
	# A build from a newer game is not rebuilt: autosave stays paused and the file untouched.
	data.build_state = {"version": 4, "future_progress": "keep"}
	var future := JSON.stringify(data)
	write_raw(future)
	var newer := await boot()
	check(newer.world_save_blocked and not newer._save_world() and FileAccess.get_file_as_string(SAVE) == future and preserved("before_build_repair").size() == 1, "a newer game's build is left untouched and autosave stays paused")
	await retire(newer)

func removed_region() -> void:
	var data := journey()
	data.current_region = "demo_ch09_removed_region"
	data.entry = [5000, 4000]
	data.world_location = {}
	data.death_cache = {"region_id": "demo_ch09_removed_region", "position": [5000, 4000], "currency": 30}
	write_raw(JSON.stringify(data))
	var scene := await boot()
	check(String(scene.config.get("id", "")) == START and String(scene.world_initial_error).contains("从巡礼起点继续"), "a save in a removed region resumes at the route start and says why")
	check(scene.build_system.state.crest == "bell" and scene.world_state.get_region(RAIN).boss_defeated, "build and other regions' progress are kept")
	check(scene.currency_count == 140 + 30 and scene.world_state.data.death_cache.is_empty(), "an unreachable 归途结 returns its shards")
	check(scene._save_world(), "the journey saves again")
	var disk := WORLD.new()
	check(disk.read(SAVE) and String(disk.data.current_region) == START and int(disk.data.currency) == 170, "the save now points at a routed region")
	await retire(scene)

func old_versions() -> void:
	# A v1 world file: no build, death cache or campaign coordinates.
	write_raw(JSON.stringify({"version": 1, "inventory_counts": {"moss_chitin": 1}, "currency": 55, "story_flags": {"seal_bell_repaired": true},
		"regions": {}, "current_region": START, "entry": [600, 3000], "hp": 4, "energy": 60}))
	var scene := await boot()
	check(not scene.world_save_blocked and scene.world_initial_error.is_empty() and scene.currency_count == 55, "a v1 save loads with its shards")
	check(scene.build_system.state.unlocked_crests.has("bell"), "a v1 save's story flags grant their crest")
	check(scene._save_world(), "a v1 save keeps saving")
	await retire(scene)
	# A v2 build (two fixed slots, no families) inside a v2 world file.
	var data := journey(88)
	var old_build: Dictionary = data.build_state.duplicate(true)
	old_build.version = 2
	old_build.erase("equipped_families")
	for name in old_build.loadouts:
		old_build.loadouts[name].erase("equipped_families")
	data.version = 2
	data.erase("world_location")
	data.build_state = old_build
	write_raw(JSON.stringify(data))
	scene = await boot()
	check(not scene.world_save_blocked and scene.world_initial_error.is_empty(), "a v2 save with a v2 build loads without repair")
	check(scene.build_system.state.version == 3 and scene.build_system.state.passives.has("shell") and scene.currency_count == 88, "the v2 build migrates with its charm")
	check(scene._save_world(), "a v2 save keeps saving")
	await retire(scene)

func new_journeys() -> void:
	var subject := MAIN.new()
	subject.world_save_path = SAVE
	write_raw("journey A")
	check(subject._preserve_previous_journey() and FileAccess.get_file_as_string(SAVE + ".previous") == "journey A", "the first new journey keeps the old one as .previous")
	write_raw("journey B")
	check(subject._preserve_previous_journey() and FileAccess.get_file_as_string(SAVE + ".previous") == "journey B", "the second keeps the latest as .previous")
	var earlier := preserved("previous.earlier")
	check(earlier.size() == 1 and FileAccess.get_file_as_string(earlier[0]) == "journey A", "and the first abandoned journey is kept, not overwritten")
	subject.free()
