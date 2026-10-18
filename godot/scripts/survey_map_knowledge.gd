extends RefCounted
## Pure knowledge and map-marker rules shared by regional and world maps.
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")

static func owner_room(config: Dictionary, area: Rect2) -> Dictionary:
	var center := area.get_center()
	var best: Dictionary = {}
	var best_area := INF
	for room in config.get("map_rooms", []):
		var rect: Rect2 = _room_rect(room)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0: continue
		# The whole feature must belong to a room. A center-only lookup leaks
		# features that straddle a nested room boundary.
		if rect.encloses(area) and rect.get_area() < best_area:
			best = room
			best_area = rect.get_area()
	return best

static func visible(flags: Dictionary, region_id: String, config: Dictionary, area: Rect2) -> bool:
	if not JOURNAL.owned(flags, region_id): return false
	var room := owner_room(config, area)
	return not room.is_empty() and JOURNAL.charted(flags, region_id, String(room.get("id", "")))

static func gate_open(gate: Dictionary, inventory: Dictionary, flags: Dictionary) -> bool:
	var ability := String(gate.get("required_ability", ""))
	if ability.is_empty(): return false
	var action := String(gate.get("requires_action", ""))
	if not action.is_empty():
		var unlock_id := String(gate.get("permanent_action_unlock_id", gate.get("id", "")))
		return not unlock_id.is_empty() and bool(flags.get("action_gate_" + unlock_id, false))
	return int(inventory.get(ability, 0)) > 0

static func marker_text(gate: Dictionary, inventory: Dictionary, flags: Dictionary) -> String:
	return "▢" if gate_open(gate, inventory, flags) else "▣"

static func marker_records(config: Dictionary, flags: Dictionary, region_id: String, inventory: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for hazard in config.get("hazards", []):
		var rect := _data_rect(hazard)
		if visible(flags, region_id, config, rect):
			var room := owner_room(config, rect)
			records.append({"kind":"hazard", "id":String(hazard.get("id", "")), "rect":rect, "room_id":String(room.id), "text":"!", "tooltip":String(hazard.get("name", "危险"))})
	for gate in config.get("locked_gates", []):
		var rect := _data_rect(gate)
		if visible(flags, region_id, config, rect):
			var room := owner_room(config, rect)
			records.append({"kind":"gate", "id":String(gate.get("id", "")), "rect":rect, "room_id":String(room.id), "text":marker_text(gate, inventory, flags), "tooltip":String(gate.get("required_ability_name", gate.get("required_ability", "能力门")))})
	return records

## Lever shortcuts are dynamic doors: the map shows whether each charted lever
## has been pulled, and names the two rooms it joins.
static func shortcut_records(config: Dictionary, flags: Dictionary, region_id: String, opened: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var names := {}
	for room in config.get("map_rooms", []): names[String(room.get("id", ""))] = String(room.get("name", room.get("id", "")))
	for lever in config.get("interactives", []):
		var shortcut := String(lever.get("shortcut_id", ""))
		if shortcut.is_empty() or String(lever.get("kind", "")) != "lever": continue
		var position: Array = lever.get("position", [])
		if position.size() < 2: continue
		var rect := Rect2(float(position[0]) - 8.0, float(position[1]) - 8.0, 16.0, 16.0)
		if not visible(flags, region_id, config, rect): continue
		var joins := ""
		for connection in config.get("connections", []):
			if connection is Dictionary and String(connection.get("shortcut_id", "")) == shortcut:
				joins = "%s ⇄ %s" % [names.get(String(connection.get("from", "")), connection.get("from", "")), names.get(String(connection.get("to", "")), connection.get("to", ""))]
		var is_open := opened.has(shortcut)
		var room := owner_room(config, rect)
		records.append({"kind":"shortcut", "id":shortcut, "rect":rect, "room_id":String(room.get("id", "")), "open":is_open,
			"text":"⇆" if is_open else "⊣", "tooltip":("捷径已接通：" if is_open else "捷径未接通，拉杆在此：") + joins})
	return records

static func _room_rect(room: Dictionary) -> Rect2:
	var value: Array = room.get("layout_rect", room.get("play_rect", []))
	return Rect2(value[0], value[1], value[2], value[3]) if value.size() >= 4 else Rect2()

static func _data_rect(data: Dictionary) -> Rect2:
	var value: Array = data.get("rect", [])
	return Rect2(value[0], value[1], value[2], value[3]) if value.size() >= 4 else Rect2()
