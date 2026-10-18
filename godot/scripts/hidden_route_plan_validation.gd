extends SceneTree

const WorldRoutes := preload("res://scripts/world_routes.gd")
const OverlayJob := preload("res://scripts/world_route_overlay_job.gd")
## W04: authored hidden routes need observable clues, safe exits, and optional rewards.
## Data-only checks against world_routes.hidden_route_plan and chapter JSON.
var checks := 0
var failures := 0

func _initialize() -> void:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_routes.json"))
	var plan: Array = routes.get("hidden_route_plan", [])
	checks += 1
	if plan.size() < 8:
		failures += 1
		push_error("hidden_route_plan covers at least one pocket per chapter plus ch06 vault")
	var seen_regions: Dictionary = {}
	for entry in plan:
		var region_id := String(entry.get("region_id", ""))
		var clue_id := String(entry.get("clue_room_id", ""))
		var hidden_id := String(entry.get("hidden_room_id", ""))
		var reward_id := String(entry.get("reward_id", ""))
		var reward_item := String(entry.get("reward_item", ""))
		var safe_exit := String(entry.get("safe_exit", ""))
		seen_regions[region_id] = true
		var chapter_path := "res://data/%s.json" % region_id
		checks += 1
		if not FileAccess.file_exists(chapter_path):
			failures += 1
			push_error("hidden route region missing chapter file " + region_id)
			continue
		var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chapter_path))
		var rooms: Dictionary = {}
		for room in chapter.get("map_rooms", []):
			rooms[String(room.id)] = room
		var platforms: Dictionary = {}
		for platform in chapter.get("platforms", []):
			var platform_key := String(platform.get("id", ""))
			if not platform_key.is_empty():
				platforms[platform_key] = true
		checks += 3
		if not rooms.has(clue_id):
			failures += 1
			push_error("clue room missing: " + clue_id)
		if not rooms.has(hidden_id):
			failures += 1
			push_error("hidden room missing: " + hidden_id)
		if safe_exit.is_empty():
			failures += 1
			push_error("safe exit empty for " + String(entry.get("id", "")))
		if rooms.has(clue_id):
			var clue_guide := String(rooms[clue_id].get("guide", ""))
			checks += 1
			if clue_guide.find("可见线索") < 0:
				failures += 1
				push_error("clue room lacks 可见线索: " + clue_id)
		if rooms.has(hidden_id):
			var hidden_guide := String(rooms[hidden_id].get("guide", ""))
			checks += 1
			if hidden_guide.find("安全离开") < 0:
				failures += 1
				push_error("hidden room lacks 安全离开: " + hidden_id)
		var reward_found := false
		for col in chapter.get("collectibles", []):
			if String(col.get("id", "")) == reward_id:
				reward_found = true
				checks += 3
				if String(col.get("reward_role", "")) != "optional_exploration":
					failures += 1
					push_error("reward is not optional_exploration: " + reward_id)
				if String(col.get("item_id", "")) != reward_item:
					failures += 1
					push_error("reward item mismatch for " + reward_id)
				if String(col.get("room_id", "")) != hidden_id:
					failures += 1
					push_error("reward not placed in hidden room: " + reward_id)
				var platform_id := String(col.get("platform_id", ""))
				checks += 1
				if platform_id.is_empty() or not platforms.has(platform_id):
					failures += 1
					push_error("reward platform missing in chapter: " + reward_id)
				# No raw currency dumps on hidden pockets.
				if col.has("currency") and int(col.get("currency", 0)) > 0:
					failures += 1
					push_error("hidden reward must not dump currency: " + reward_id)
				break
		checks += 1
		if not reward_found:
			failures += 1
			push_error("optional reward missing: " + reward_id)
	checks += 1
	if seen_regions.size() < 6:
		failures += 1
		push_error("hidden_route_plan must touch all six regions")
	# Live startup and region changes apply overrides through the incremental job.
	var chapters: Dictionary = routes.get("chapters", {})
	var guides_by_region: Dictionary = {}
	for entry in plan:
		var region_id := String(entry.get("region_id", ""))
		if guides_by_region.has(region_id):
			continue
		var chapter_path := "res://data/%s.json" % region_id
		if not FileAccess.file_exists(chapter_path):
			guides_by_region[region_id] = {}
			continue
		var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chapter_path))
		var overlay: Dictionary = chapters.get(region_id, {})
		var prepared := _finish_overlay_job(chapter.duplicate(true), overlay)
		var guides := {}
		for room in prepared.get("map_rooms", []):
			if room is Dictionary:
				guides[String(room.get("id", ""))] = String(room.get("guide", ""))
		guides_by_region[region_id] = guides
	for entry in plan:
		var region_id := String(entry.get("region_id", ""))
		var clue_id := String(entry.get("clue_room_id", ""))
		var hidden_id := String(entry.get("hidden_room_id", ""))
		var guides: Dictionary = guides_by_region.get(region_id, {})
		for pair in [[clue_id, "可见线索"], [hidden_id, "安全离开"]]:
			var room_id := String(pair[0])
			var marker := String(pair[1])
			var live := String(guides.get(room_id, ""))
			checks += 1
			if live.find(marker) < 0:
				failures += 1
				push_error("%s live guide after overlay job missing %s" % [room_id, marker])
	_check_stale_override_on_overlay_job()
	print("HIDDEN_ROUTE_PLAN_VALIDATION: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)


func _finish_overlay_job(config: Dictionary, overlay: Dictionary) -> Dictionary:
	var job = OverlayJob.new()
	job.begin(config, overlay, 1)
	var steps := 0
	while not job.done and steps < 200000:
		job.step(64, 8000)
		steps += 1
	checks += 1
	if not job.done or not job.error.is_empty():
		failures += 1
		push_error("route overlay job failed: " + job.error)
		return {}
	return job.result


## A stale override that drops W04 markers must still keep them on the production job.
func _check_stale_override_on_overlay_job() -> void:
	var authored := "走一步，停半拍。 可见线索：阅览廊上层书堆后透出盐灯缝。 安全离开：原路退回阅览廊。"
	var stale := "走一步，停半拍。 可见旧检修入口：「运书吊篮仓」。在门前按 K 钩住铜环，牵引检修闩。"
	var kept := "营火。 可见线索：营火头顶旗桥通向军墓碑林。 可见旧检修入口：「灯影相位练习工房」。"
	var plain_authored := "盲钟骑士守着营火。"
	var plain_override := "盲钟骑士守着营火。 可见旧检修入口：「练习工房」。"
	var config := {
		"world": {"width": 10, "height": 10},
		"map_rooms": [
			{"id": "stale_room", "guide": authored, "objective": "原目标"},
			{"id": "kept_room", "guide": "另一句。 可见线索：更长的原稿不该再贴一次。", "objective": "原目标"},
			{"id": "plain_room", "guide": plain_authored, "objective": "原目标"},
			{"id": "untouched", "guide": "不要动。", "objective": "原目标"},
		],
	}
	var overlay := {
		"map_room_overrides": [
			{"id": "stale_room", "guide": stale, "objective": "可选：运书吊篮仓。"},
			{"id": "kept_room", "guide": kept, "objective": "可选：练习工房。"},
			{"id": "plain_room", "guide": plain_override, "objective": "可选：练习工房。"},
		],
	}
	var result := _finish_overlay_job(config, overlay)
	if result.is_empty():
		return
	var by_id := {}
	for room in result.get("map_rooms", []):
		by_id[String(room.get("id", ""))] = room
	var stale_live := String(by_id["stale_room"].get("guide", ""))
	var expected := WorldRoutes._preserve_hidden_route_guide(authored, stale)
	checks += 1
	if stale_live != expected or stale_live.find("可见线索") < 0 or stale_live.find("安全离开") < 0 or stale_live.find("可见旧检修入口") < 0:
		failures += 1
		push_error("stale override job guide = " + stale_live)
	checks += 1
	if String(by_id["stale_room"].get("objective", "")) != "可选：运书吊篮仓。":
		failures += 1
		push_error("stale override job dropped non-guide merge")
	var kept_live := String(by_id["kept_room"].get("guide", ""))
	checks += 1
	if kept_live != kept or kept_live.find("可见线索") < 0 or kept_live.find("可见线索") != kept_live.rfind("可见线索"):
		failures += 1
		push_error("overlay job duplicated an existing marker: " + kept_live)
	var plain_live := String(by_id["plain_room"].get("guide", ""))
	checks += 1
	if plain_live != plain_override:
		failures += 1
		push_error("overlay job appended markers the authored room does not have: " + plain_live)
	checks += 1
	if String(by_id["untouched"].get("guide", "")) != "不要动。":
		failures += 1
		push_error("overlay job changed a room without an override")
	checks += 1
	if String(overlay["map_room_overrides"][0]["guide"]) != stale:
		failures += 1
		push_error("overlay job mutated the source override guide")
