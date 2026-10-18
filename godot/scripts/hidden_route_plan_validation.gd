extends SceneTree
## W04: authored hidden routes need observable clues, safe exits, and optional rewards.
## Data-only checks against world_routes.hidden_route_plan and chapter JSON.

func _initialize() -> void:
	var failures := 0
	var checks := 0
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
			if clue_guide.find("可见线索") < 0 and clue_guide.find("通向") < 0 and clue_guide.find("通往") < 0 and clue_guide.find("可选") < 0 and clue_guide.find("旗桥") < 0 and clue_guide.find("坠入") < 0:
				failures += 1
				push_error("clue room lacks observable pointer text: " + clue_id)
		if rooms.has(hidden_id):
			var hidden_guide := String(rooms[hidden_id].get("guide", ""))
			checks += 1
			if hidden_guide.find("安全离开") < 0 and hidden_guide.find("可折回") < 0 and hidden_guide.find("撤离") < 0 and hidden_guide.find("退回") < 0 and hidden_guide.find("向东") < 0:
				failures += 1
				push_error("hidden room lacks safe-exit wording: " + hidden_id)
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
	print("HIDDEN_ROUTE_PLAN_VALIDATION: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
