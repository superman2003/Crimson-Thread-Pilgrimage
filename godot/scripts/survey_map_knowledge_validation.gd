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
