extends SceneTree
## Reusable component assertion plus focused knowledge-policy regression.
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
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
	ATLAS.configurations[region_id] = scene.config
	scene.world_map_view = true
	scene._refresh_map_overlay()
	check(marker_assertions(scene.map_draw_root,"world",region_id,"hazard:"+hazard_id,true).is_empty(),"real world atlas emits same charted regional hazard")
	var world_ability: Label = scene.map_draw_root.get_node_or_null("WorldGate_"+region_id+"_"+ability_gate_id)
	var world_action: Label = scene.map_draw_root.get_node_or_null("WorldGate_"+region_id+"_"+action_gate_id)
	check(world_ability!=null and world_ability.text=="▢" and world_action!=null and world_action.text=="▢","real world atlas reads that region's live ability and action state")
	scene.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
	print("SURVEY_MAP_KNOWLEDGE checks=%d failures=%d" % [checks,failures])
	call_deferred("quit",1 if failures else 0)
