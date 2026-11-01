extends SceneTree
## B01 role cues on production enemy actors: ambush reveal burst, alarm call
## rings and the support channel. Fixture stage and target, real GL renderer.
## Graphical engine: --script res://scripts/capture_role_cues.gd -- --capture-output=DIR
const ENEMY := preload("res://scripts/enemy_actor.gd")
const PROFILE_PATH := "res://data/original_creature_combat.json"
var destination := ""

class CueTarget extends CharacterBody2D:
	var ui_input_locked := false
	func take_damage(_amount: int, _origin: Vector2, _blockable := true) -> void:
		pass

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			destination = argument.trim_prefix("--capture-output=")
	call_deferred("capture")

func spawn(stage: Node2D, kind: String, id: String, at: Vector2) -> Area2D:
	var enemy: Area2D = ENEMY.new()
	var species: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH)).get(kind, {})
	enemy.configure({"id": id, "kind": kind, "hp": 6, "damage": 1, "patrol": 80.0}, "", false, species)
	enemy.position = at
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	var stage := Node2D.new()
	root.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.08, 0.1)
	backdrop.position = Vector2(-200, -200)
	backdrop.size = Vector2(1680, 1120)
	backdrop.z_index = -100
	stage.add_child(backdrop)
	var camera := Camera2D.new()
	camera.position = Vector2(640, 360)
	stage.add_child(camera)
	var target := CueTarget.new()
	target.add_to_group("player")
	stage.add_child(target)
	var bookmite := spawn(stage, "salt_bookmite", "capture_ambush", Vector2(260, 330))
	var bell := spawn(stage, "spore_bellmaker", "capture_alarm", Vector2(700, 330))
	var donor := spawn(stage, "ash_banner_imp", "capture_support", Vector2(1080, 560))
	var hurt := spawn(stage, "moss_larva", "capture_hurt", Vector2(960, 560))
	hurt.hp = 1
	await process_frame
	await physics_frame
	target.position = Vector2(380, 330)
	await physics_frame
	bookmite._update_patrol_or_aggro(0.1, target)
	target.position = Vector2(760, 330)
	await physics_frame
	bell._update_patrol_or_aggro(0.1, target)
	target.position = Vector2(1200, 560)
	await physics_frame
	donor._update_patrol_or_aggro(0.1, target)
	var ok: bool = bookmite.role_cue_counts.get("ambush_reveal", 0) == 1 and bell.role_cue_counts.get("alarm_call", 0) == 1 and donor.role_cue_counts.get("support_mend", 0) == 1
	for frame in 9:
		await physics_frame
	await RenderingServer.frame_post_draw
	if not ok or root.get_texture().get_image().save_png(destination.path_join("role_cues.png")) != OK:
		push_error("Cannot capture role cues")
		quit(1)
		return
	print("ROLE_CUES_CAPTURE reveal=%d alarm=%d support=%d" % [bookmite.role_cue_counts.ambush_reveal, bell.role_cue_counts.alarm_call, donor.role_cue_counts.support_mend])
	stage.queue_free()
	await process_frame
	quit(0)
