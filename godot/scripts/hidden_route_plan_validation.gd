extends SceneTree

const WorldRoutes := preload("res://scripts/world_routes.gd")
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
	# After map_room_overrides merge, World guides must still show W04 markers.
	var chapters: Dictionary = routes.get("chapters", {})
	for entry in plan:
		var region_id := String(entry.get("region_id", ""))
		var clue_id := String(entry.get("clue_room_id", ""))
		var hidden_id := String(entry.get("hidden_room_id", ""))
		var chapter_path := "res://data/%s.json" % region_id
		if not FileAccess.file_exists(chapter_path):
			continue
		var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chapter_path))
		var overlay: Dictionary = chapters.get(region_id, {})
		var override_by_id: Dictionary = {}
		for room_override in overlay.get("map_room_overrides", []):
			override_by_id[String(room_override.get("id", ""))] = room_override
		for pair in [[clue_id, "可见线索"], [hidden_id, "安全离开"]]:
			var room_id := String(pair[0])
			var marker := String(pair[1])
			var authored := ""
			for room in chapter.get("map_rooms", []):
				if String(room.get("id", "")) == room_id:
					authored = String(room.get("guide", ""))
					break
			var override_guide := ""
			if override_by_id.has(room_id):
				override_guide = String(override_by_id[room_id].get("guide", ""))
			var live := authored if override_guide.is_empty() else WorldRoutes._preserve_hidden_route_guide(authored, override_guide)
			# Prefer authored override text when already merged in data.
			if not override_guide.is_empty():
				live = WorldRoutes._preserve_hidden_route_guide(authored, override_guide)
			checks += 1
			if live.find(marker) < 0:
				failures += 1
				push_error("%s live guide after overrides missing %s" % [room_id, marker])
	print("HIDDEN_ROUTE_PLAN_VALIDATION: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
