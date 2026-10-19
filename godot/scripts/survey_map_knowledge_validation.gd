extends SceneTree
## Reusable component assertion plus focused knowledge-policy regression.
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://survey_map_knowledge_validation.json"
var checks := 0
var failures := 0

static func marker_assertions(host: Node, kind: String, region_id: String, marker_id: String, expected: bool) -> Array[String]:
	var prefix := "Survey" if kind == "local" else "World"
	var name := prefix + ("Hazard_" if marker_id.begins_with("hazard:") else "Gate_")
	var id := marker_id.trim_prefix("hazard:").trim_prefix("gate:")
	var node := host.get_node_or_null(NodePath(name + ("" if kind == "local" else region_id + "_") + id))
	var errors: Array[String] = []
	if expected != (node != null): errors.append("%s expected=%s actual=%s" % [name + id, expected, node != null])
	return errors

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var config := {"map_rooms":[
		{"id":"hall", "layout_rect":[0,0,1000,1000]},
		{"id":"inner", "kind":"secret", "layout_rect":[200,200,200,200]}],
		"hazards":[{"id":"h","rect":[220,220,20,20]}],
		"locked_gates":[{"id":"ability","rect":[20,20,30,30],"required_ability":"thread_dash"},
		{"id":"action","rect":[40,40,30,30],"required_ability":"thread_dash","requires_action":"thorn_downstrike","permanent_action_unlock_id":"permanent_break"}]}
	var flags: Dictionary = {}
	var inventory := {"thread_dash":1}
	check(not KNOWLEDGE.visible(flags,"r",config,Rect2(220,220,20,20)),"unpurchased feature hidden")
	JOURNAL.region(flags,"r").owned = true
	check(not KNOWLEDGE.visible(flags,"r",config,Rect2(220,220,20,20)),"purchased but uncharted feature hidden")
	JOURNAL.region(flags,"r").charted["hall"] = true
	check(KNOWLEDGE.owner_room(config,Rect2(220,220,20,20)).id == "inner","smallest containing room owns nested hazard")
	check(not KNOWLEDGE.visible(flags,"r",config,Rect2(220,220,20,20)),"outer room charting cannot leak nested secret")
	JOURNAL.region(flags,"r").charted["inner"] = true
	check(KNOWLEDGE.visible(flags,"r",config,Rect2(220,220,20,20)),"secret marker appears after its own charting")
	check(KNOWLEDGE.marker_text(config.locked_gates[0],inventory,flags)=="▢","ability gate follows ability inventory")
	check(KNOWLEDGE.marker_text(config.locked_gates[1],inventory,flags)=="▣","action gate ignores ability inventory")
	flags.action_gate_permanent_break = true
	check(KNOWLEDGE.marker_text(config.locked_gates[1],inventory,flags)=="▢","action gate follows permanent unlock id")
	check(not KNOWLEDGE.gate_open({"id":"x","requires_action":"pull"},inventory,flags),"cross-region action without unlock stays closed")
	config["interactives"] = [{"id":"lever","kind":"lever","position":[500,500],"shortcut_id":"loop"}]
	config["connections"] = [{"from":"hall","to":"inner","type":"shortcut","shortcut_id":"loop"}]
	config.map_rooms[0]["name"] = "大厅"
	config.map_rooms[1]["name"] = "暗间"
	var closed := KNOWLEDGE.shortcut_records(config,flags,"r",{})
	check(closed.size() == 1 and closed[0].text == "⊣" and not closed[0].open and String(closed[0].tooltip).contains("大厅") and String(closed[0].tooltip).contains("暗间"),"charted lever shows a closed shortcut naming both rooms")
	var opened := KNOWLEDGE.shortcut_records(config,flags,"r",{"loop":true})
	check(opened.size() == 1 and opened[0].text == "⇆" and opened[0].open,"pulled lever shows the shortcut as connected")
	check(KNOWLEDGE.shortcut_records(config,{},"r",{"loop":true}).is_empty(),"unpurchased map never reveals a shortcut")
	var pins := preload("res://scripts/map_player_pins_runtime.gd")
	var labels: Array[Label] = []
	for offset in [Vector2(0,0), Vector2(5,3), Vector2(-4,6), Vector2(300,0)]:
		var label := Label.new()
		label.text = "★12"
		label.add_theme_font_size_override("font_size", 19)
		label.set_meta("map_anchor", Vector2(400,300) + offset)
		label.position = (label.get_meta("map_anchor") as Vector2) - pins.LABEL_ORIGIN
		labels.append(label)
	pins.declutter(labels)
	var overlaps := 0
	for i in 3:
		for j in range(i + 1, 3):
			var wi: float = pins._text_width(labels[i])
			var wj: float = pins._text_width(labels[j])
			if Rect2(labels[i].position, Vector2(wi, 26)).intersects(Rect2(labels[j].position, Vector2(wj, 26))): overlaps += 1
	check(pins._text_width(labels[0]) > 20.0,"pin label text is measured with its real font")
	check(overlaps == 0 and int(labels[0].get_meta("cluster_size")) == 3,"three two-digit pins at almost the same point fan out without overlapping")
	var near := true
	for i in 3: near = near and (labels[i].position + pins.LABEL_ORIGIN).distance_to(labels[i].get_meta("map_anchor")) < 64.0
	check(near,"fanned pins stay within 64 px of their true anchor")
	check(int(labels[3].get_meta("cluster_size")) == 1 and labels[3].position == (labels[3].get_meta("map_anchor") as Vector2) - pins.LABEL_ORIGIN,"a lone pin keeps its exact projected position")
	for label in labels: label.free()
	# Adjacent groups (review case: anchors at x = 0, 23, 47, 70) must not collide after fanning out.
	var row: Array[Label] = []
	for x in [0.0, 23.0, 47.0, 70.0]:
		var pin := Label.new()
		pin.text = "★12"
		pin.add_theme_font_size_override("font_size", 19)
		pin.set_meta("map_anchor", Vector2(400.0 + x, 300.0))
		pin.position = (pin.get_meta("map_anchor") as Vector2) - pins.LABEL_ORIGIN
		row.append(pin)
	pins.declutter(row)
	var collisions := 0
	for i in row.size():
		for j in range(i + 1, row.size()):
			if Rect2(row[i].position, Vector2(pins._text_width(row[i]), 26)).intersects(Rect2(row[j].position, Vector2(pins._text_width(row[j]), 26))): collisions += 1
	check(collisions == 0, "neighbouring pin groups merge instead of overlapping after fanning out")
	for pin in row: pin.free()
	# Review case: the full 12 pins along a chain about 24 px apart, created in
	# alternating order, must stay readable and near their own pins.
	var chain: Array[Label] = []
	var order := [0, 11, 1, 10, 2, 9, 3, 8, 4, 7, 5, 6]
	for index in order:
		var link := Label.new()
		link.text = "★" + str(index + 1)
		link.add_theme_font_size_override("font_size", 19)
		link.set_meta("map_anchor", Vector2(300.0 + index * 24.0, 300.0))
		link.position = (link.get_meta("map_anchor") as Vector2) - pins.LABEL_ORIGIN
		chain.append(link)
	pins.declutter(chain)
	var chain_overlaps := 0
	var farthest := 0.0
	for i in chain.size():
		farthest = maxf(farthest, (chain[i].position + pins.LABEL_ORIGIN).distance_to(chain[i].get_meta("map_anchor")))
		for j in range(i + 1, chain.size()):
			if pins._label_rect(chain[i], chain[i].position).intersects(pins._label_rect(chain[j], chain[j].position)): chain_overlaps += 1
	check(chain_overlaps == 0, "twelve chained pins lay out without overlapping")
	check(farthest < 64.0, "every chained pin label stays within 64 px of its pin (farthest %.1f)" % farthest)
	for link in chain: link.free()
	# Review case: an irregular two-dimensional cluster of eight pins.
	var scatter: Array[Label] = []
	var points := [Vector2(156,3), Vector2(145,21), Vector2(124,4), Vector2(128,28), Vector2(123,82), Vector2(99,79), Vector2(70,46), Vector2(98,57)]
	for index in points.size():
		var dot := Label.new()
		dot.text = "★" + str(index + 4)
		dot.add_theme_font_size_override("font_size", 19)
		dot.set_meta("map_anchor", Vector2(300, 300) + points[index])
		dot.position = (dot.get_meta("map_anchor") as Vector2) - pins.LABEL_ORIGIN
		scatter.append(dot)
	pins.declutter(scatter)
	var scatter_overlaps := 0
	var scatter_far := 0.0
	for i in scatter.size():
		scatter_far = maxf(scatter_far, (scatter[i].position + pins.LABEL_ORIGIN).distance_to(scatter[i].get_meta("map_anchor")))
		for j in range(i + 1, scatter.size()):
			if pins._label_rect(scatter[i], scatter[i].position).intersects(pins._label_rect(scatter[j], scatter[j].position)): scatter_overlaps += 1
	check(scatter_overlaps == 0 and scatter_far < 64.0, "an irregular eight-pin cluster stays readable within 64 px (farthest %.1f, overlaps %d)" % [scatter_far, scatter_overlaps])
	for dot in scatter: dot.free()
	# Review case: all 12 pins on one room's grid, compressed by the regional
	# projection to a few pixels apart. Numbers may share a label but never overlap.
	var dense: Array[Label] = []
	for index in 12:
		var pin_label := Label.new()
		pin_label.text = "★" + str(index + 1)
		pin_label.add_theme_font_size_override("font_size", 19)
		pin_label.set_meta("pin_id", index + 1)
		pin_label.set_meta("map_anchor", Vector2(500 + (index % 4) * 4, 300 + int(index / 4) * 4))
		pin_label.position = (pin_label.get_meta("map_anchor") as Vector2) - pins.LABEL_ORIGIN
		dense.append(pin_label)
	pins.declutter(dense)
	var dense_overlaps := 0
	var dense_far := 0.0
	var shown := ""
	for i in dense.size():
		if not dense[i].visible: continue
		shown += " " + dense[i].text.replace("\n", " ") + " "
		# Measure against every pin this label shows, not only its own.
		for anchor in pins.represented(dense[i]):
			dense_far = maxf(dense_far, (dense[i].position + pins.LABEL_ORIGIN).distance_to(anchor))
		for j in range(i + 1, dense.size()):
			if dense[j].visible and pins._label_rect(dense[i], dense[i].position).intersects(pins._label_rect(dense[j], dense[j].position)): dense_overlaps += 1
	var all_shown := true
	for index in 12: all_shown = all_shown and shown.contains("★" + str(index + 1) + " ")
	check(dense_overlaps == 0, "twelve pins packed into a few pixels never overlap (overlaps %d)" % dense_overlaps)
	check(all_shown, "every packed pin number is still shown on some label")
	check(dense_far < 64.0, "packed labels stay within 64 px of their pins (farthest %.1f)" % dense_far)
	# Review case: forty pins over 126 x 72 px. Once no merge keeps every number
	# within the drift limit, labels must still merge rather than overlap.
	var crowd: Array[Label] = []
	for index in 40:
		var crowd_label := Label.new()
		crowd_label.text = "★" + str(index + 1)
		crowd_label.add_theme_font_size_override("font_size", 19)
		crowd_label.set_meta("pin_id", index + 1)
		crowd_label.set_meta("map_anchor", Vector2(500 + (index % 8) * 18, 300 + int(index / 8) * 18))
		crowd_label.position = (crowd_label.get_meta("map_anchor") as Vector2) - pins.LABEL_ORIGIN
		crowd.append(crowd_label)
	pins.declutter(crowd)
	var crowd_overlaps := 0
	var crowd_shown := ""
	for i in crowd.size():
		if not crowd[i].visible: continue
		crowd_shown += " " + crowd[i].text.replace("\n", " ") + " "
		for j in range(i + 1, crowd.size()):
			if crowd[j].visible and pins._label_rect(crowd[i], crowd[i].position).intersects(pins._label_rect(crowd[j], crowd[j].position)): crowd_overlaps += 1
	var crowd_all := true
	for index in 40: crowd_all = crowd_all and crowd_shown.contains("★" + str(index + 1) + " ")
	check(crowd_overlaps == 0 and crowd_all, "forty crowded pins never overlap and every number is shown (overlaps %d)" % crowd_overlaps)
	for crowd_label in crowd: crowd_label.free()
	var hidden := 0
	for pin_label in dense: hidden += 0 if pin_label.visible else 1
	check(hidden > 0, "the packed case really exercises joining (%d numbers joined)" % hidden)
	for pin_label in dense: pin_label.free()
	var spread: Array[Label] = []
	for index in 12:
		var spread_label := Label.new()
		spread_label.text = "★" + str(index + 1)
		spread_label.add_theme_font_size_override("font_size", 19)
		spread_label.set_meta("pin_id", index + 1)
		spread_label.set_meta("map_anchor", Vector2(700 + (index % 4) * 12, 300 + int(index / 4) * 12))
		spread_label.position = (spread_label.get_meta("map_anchor") as Vector2) - pins.LABEL_ORIGIN
		spread.append(spread_label)
	pins.declutter(spread)
	var spread_overlaps := 0
	var spread_far := 0.0
	for i in spread.size():
		if not spread[i].visible: continue
		for anchor in pins.represented(spread[i]):
			spread_far = maxf(spread_far, (spread[i].position + pins.LABEL_ORIGIN).distance_to(anchor))
		for j in range(i + 1, spread.size()):
			if spread[j].visible and pins._label_rect(spread[i], spread[i].position).intersects(pins._label_rect(spread[j], spread[j].position)): spread_overlaps += 1
	check(spread_overlaps == 0 and spread_far < 64.0, "twelve pins on a 12 px grid: no overlap, every number within 64 px of its pin (farthest %.1f)" % spread_far)
	for spread_label in spread: spread_label.free()
	# Regression: a dense group must never absorb the separate pin at x=215.
	var counterexample := [Vector2(7.233161,54.20648),Vector2(51.16418,21.96101),Vector2(56.01644,7.503717),Vector2(71.92576,13.78688),Vector2(72.44984,4.383442),Vector2(139.153,26.10359),Vector2(82.49238,10.31527),Vector2(101.0306,52.04563),Vector2(33.27414,77.93373),Vector2(30.8481,9.266716),Vector2(56.89198,21.40412),Vector2(214.9092,4.81169)]
	for use_project_font in [false, true]:
		var regression: Array[Label] = []
		for index in counterexample.size():
			var label := Label.new()
			label.text = "★" + str(index + 1)
			label.add_theme_font_size_override("font_size", 19)
			if use_project_font: label.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC.ttf"))
			label.set_meta("pin_id", index + 1)
			label.set_meta("map_anchor", counterexample[index])
			regression.append(label)
		pins.declutter(regression)
		var near_all := true
		var clear_all := true
		var numbers := " "
		for i in regression.size():
			if not regression[i].visible: continue
			numbers += regression[i].text.replace("\n", " ") + " "
			for anchor in pins.represented(regression[i]):
				near_all = near_all and (regression[i].position + pins.LABEL_ORIGIN).distance_to(anchor) <= pins.MAX_DRIFT + 0.01
			for j in range(i + 1, regression.size()):
				if regression[j].visible and pins._label_rect(regression[i], regression[i].position).intersects(pins._label_rect(regression[j], regression[j].position)): clear_all = false
		var complete := true
		for index in regression.size(): complete = complete and numbers.contains("★" + str(index + 1) + " ")
		check(near_all and clear_all and complete, "bounded pin merge keeps all twelve numbers readable and near every represented anchor (project_font=%s)" % use_project_font)
		for label in regression: label.free()
	var scene: Node = load("res://scenes/World.tscn").instantiate()
	scene.world_save_path = SAVE
	scene.world_resume = false
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	scene.set_process(false)
	scene.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	var region_id := String(scene.config.id)
	var room: Dictionary = scene.config.map_rooms[0]
	var room_rect: Rect2 = KNOWLEDGE._room_rect(room)
	var center: Vector2 = room_rect.get_center()
	var local_rect := Rect2(center - Vector2(5,5), Vector2(10,10))
	var hazard_id := "validation_hazard"
	var ability_gate_id := "validation_ability_gate"
	var action_gate_id := "validation_action_gate"
	scene.config.hazards.append({"id":hazard_id,"rect":[local_rect.position.x,local_rect.position.y,10,10],"name":"验证危险"})
	scene.config.locked_gates.append_array([
		{"id":ability_gate_id,"rect":[center.x-15,center.y-15,10,10],"required_ability":"thread_dash","required_ability_name":"绯线冲刺"},
		{"id":action_gate_id,"rect":[center.x+5,center.y-15,10,10],"required_ability":"thorn_downstrike","requires_action":"thorn_downstrike","permanent_action_unlock_id":"validation_permanent_break","required_ability_name":"断枝动作"}])
	var journal := JOURNAL.region(scene.story_flags,region_id)
	scene._refresh_map_overlay()
	check(scene.map_draw_root.get_node_or_null("SurveyHazard_"+hazard_id)==null,"real local component hides unpurchased hazard")
	journal.owned = true
	scene._refresh_map_overlay()
	check(scene.map_draw_root.get_node_or_null("SurveyHazard_"+hazard_id)==null,"real local component hides purchased but uncharted hazard")
	journal.charted[String(room.id)] = true
	scene._refresh_map_overlay()
	check(marker_assertions(scene.map_draw_root,"local",region_id,"hazard:"+hazard_id,true).is_empty(),"real local component emits charted hazard marker")
	var ability_marker: Label = scene.map_draw_root.get_node_or_null("SurveyGate_"+ability_gate_id)
	var action_marker: Label = scene.map_draw_root.get_node_or_null("SurveyGate_"+action_gate_id)
	check(ability_marker!=null and ability_marker.text=="▣","real local component renders locked ability gate")
	check(action_marker!=null and action_marker.text=="▣","real local component renders locked permanent action gate")
	scene.inventory_counts["thread_dash"] = 1
	scene.story_flags["action_gate_validation_permanent_break"] = true
	scene._refresh_map_overlay()
	ability_marker = scene.map_draw_root.get_node("SurveyGate_"+ability_gate_id)
	action_marker = scene.map_draw_root.get_node("SurveyGate_"+action_gate_id)
	check(ability_marker.text=="▢" and action_marker.text=="▢","real local component refreshes ability and permanent-action states")
	# The atlas owns a route-generation lease. Exercise its invalidation before
	# injecting current-generation marker fixtures, just as a real cache consumer
	# first calls configuration() before using the returned regional snapshot.
	var route_generation := ROUTES.cached_generation()
	ATLAS.route_generation = route_generation - 1
	ATLAS.configurations["validation_stale_region"] = {"stale": true}
	ATLAS.geometry["validation_stale_region"] = []
	ATLAS.room_contours["validation_stale_region:room"] = []
	var current_config := ATLAS.configuration(region_id)
	check(route_generation >= 0 and ATLAS.route_generation == route_generation and not current_config.is_empty(), "real atlas acquires the current route-generation lease")
	check(not ATLAS.configurations.has("validation_stale_region") and ATLAS.geometry.is_empty() and ATLAS.room_contours.is_empty(), "route-generation change clears stale configuration, terrain and contour caches")
	ATLAS.configurations[region_id] = scene.config
	check(ATLAS.configuration(region_id) == scene.config, "current-generation atlas fixture survives configuration lookup")
	var shortcut_id := "validation_shortcut"
	scene.config.interactives.append({"id":"validation_lever","kind":"lever","position":[center.x,center.y],"shortcut_id":shortcut_id})
	scene.config.connections.append({"from":String(room.id),"to":String(room.id),"type":"shortcut","shortcut_id":shortcut_id})
	scene._refresh_map_overlay()
	var local_shortcut: Label = scene.map_draw_root.get_node_or_null("SurveyShortcut_"+shortcut_id)
	check(local_shortcut != null and local_shortcut.text == "⊣","real local map marks the charted lever as an unconnected shortcut")
	scene.opened_shortcuts[shortcut_id] = true
	scene._refresh_map_overlay()
	local_shortcut = scene.map_draw_root.get_node_or_null("SurveyShortcut_"+shortcut_id)
	check(local_shortcut != null and local_shortcut.text == "⇆" and local_shortcut.tooltip_text.begins_with("捷径已接通"),"real local map shows the shortcut connected after the lever opens")
	check(scene.map_text.text.contains("捷径"),"map legend explains the shortcut symbol")
	scene.world_map_view = true
	scene._refresh_map_overlay()
	var world_shortcut: Label = scene.map_draw_root.get_node_or_null("WorldShortcut_"+region_id+"_"+shortcut_id)
	check(world_shortcut != null and world_shortcut.text == "⇆","real world atlas reads the region's live shortcut state")
	check(marker_assertions(scene.map_draw_root,"world",region_id,"hazard:"+hazard_id,true).is_empty(),"real world atlas emits same charted regional hazard")
	var world_ability: Label = scene.map_draw_root.get_node_or_null("WorldGate_"+region_id+"_"+ability_gate_id)
	var world_action: Label = scene.map_draw_root.get_node_or_null("WorldGate_"+region_id+"_"+action_gate_id)
	check(world_ability!=null and world_ability.text=="▢" and world_action!=null and world_action.text=="▢","real world atlas reads that region's live ability and action state")
	scene.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
	print("SURVEY_MAP_KNOWLEDGE checks=%d failures=%d" % [checks,failures])
	call_deferred("quit",1 if failures else 0)
