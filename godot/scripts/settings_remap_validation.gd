extends SceneTree
## U06: every gameplay action the player presses can be remapped from the real
## settings page, including movement and the four permanent abilities; a clash
## names the action it hits; remaps survive a restart; one press restores the
## shipped bindings; and the larger list still fits the panel without overlap.
const UI := preload("res://scripts/pilgrimage_interface.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const SAVE := "user://settings_remap_validation.json"
const PREFS := "user://pilgrimage_accessibility.cfg"
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

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func keys(action: String) -> Array:
	var found: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			found.append(int(event.physical_keycode))
	found.sort()
	return found

func pads(action: String) -> int:
	var count := 0
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			count += 1
	return count

func boot() -> void:
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE
	root.add_child(scene)
	current_scene = scene
	await READY.wait_for(scene)
	await tick(4)

func retire() -> void:
	scene._close_overlays()
	AUDIO.retire_tree(scene)
	scene.queue_free()
	await tick(6)

## Press the remap button for an action, then the new input, as a player would.
func remap_action(action: String, event: InputEvent) -> String:
	var ui: Node = scene.ui_shell
	ui.remap_buttons[action].pressed.emit()
	ui._input(event)
	await tick(2)
	return String(ui.remap_status.text)

func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))
	await boot()
	var ui: Node = scene.ui_shell

	# --- Every action the player presses in play is remappable. ---
	var source := FileAccess.get_file_as_string("res://scripts/player_controller.gd")
	var pressed: Dictionary = {}
	var pattern := RegEx.new()
	pattern.compile("is_action(?:_just)?_(?:pressed|released)\\(\"([a-z_0-9]+)\"")
	for found in pattern.search_all(source):
		pressed[found.get_string(1)] = true
	var axes := RegEx.new()
	axes.compile("get_axis\\(\"([a-z_0-9]+)\", *\"([a-z_0-9]+)\"\\)")
	for found in axes.search_all(source):
		pressed[found.get_string(1)] = true
		pressed[found.get_string(2)] = true
	var missing: Array = []
	for action in pressed:
		if not UI.REMAPPABLE_ACTIONS.has(action) and not String(action) in ["close_overlay", "map", "inventory"]:
			missing.append(action)
	check(missing.is_empty() and pressed.has("hook") and pressed.has("move_left"), "every gameplay action the player presses is remappable (missing: %s)" % [missing])

	# --- The settings page lays out all of them inside the panel without overlap. ---
	scene._toggle_audio_settings()
	await tick(3)
	check(ui.settings.visible and ui.remap_buttons.size() == UI.REMAPPABLE_ACTIONS.size() and UI.REMAPPABLE_ACTIONS.size() == 17, "the settings page shows a button for each of the 17 actions")
	var panel := Rect2(Vector2.ZERO, ui.settings.size)
	var rects: Array = []
	for action in ui.remap_buttons:
		rects.append(Rect2(ui.remap_buttons[action].position, ui.remap_buttons[action].size))
	rects.append(Rect2(ui.remap_status.position, ui.remap_status.size))
	rects.append(Rect2(ui.reset_bindings_button.position, ui.reset_bindings_button.size))
	for slot in ui.save_slot_buttons:
		rects.append(Rect2(ui.save_slot_buttons[slot].position, ui.save_slot_buttons[slot].size))
	var overlap := false
	var outside := false
	for index in rects.size():
		outside = outside or not panel.encloses(rects[index])
		for other in range(index + 1, rects.size()):
			overlap = overlap or rects[index].intersects(rects[other])
	check(not overlap and not outside, "remap buttons, status, reset and save slots neither overlap nor leave the panel")
	check(String(ui.remap_buttons["hook"].text).begins_with("回声钩索 · ") and String(ui.remap_buttons["hook"].text).contains("K"), "an ability button names the ability and its keys")

	# --- Remap an ability and a movement direction through the page. ---
	var hook_pads := pads("hook")
	var message := await remap_action("hook", key(KEY_P))
	check(keys("hook") == [KEY_P] and pads("hook") == hook_pads and message.contains("回声钩索"), "回声钩索 moves from K / X to P, its controller button kept")
	message = await remap_action("move_left", key(KEY_Z))
	check(keys("move_left") == [KEY_Z] and pads("move_left") >= 1, "左移 can be moved to Z")
	message = await remap_action("attack", key(KEY_Q))
	check(message.contains("钟壳格挡") and not keys("attack").has(KEY_Q), "a clash with an ability key is refused and names the ability")
	message = await remap_action("jump", key(KEY_M))
	check(message.contains("保留") and not keys("jump").has(KEY_M), "the map key stays reserved for the interface")
	# A remapped key is free for another action.
	message = await remap_action("attack", key(KEY_K))
	check(keys("attack") == [KEY_K], "the key 回声钩索 gave up can be taken by 普攻")

	# --- Remaps survive a restart (a new World and a new player). ---
	await retire()
	await boot()
	ui = scene.ui_shell
	check(keys("hook") == [KEY_P] and keys("move_left") == [KEY_Z] and keys("attack") == [KEY_K], "remaps survive a restart")

	# --- One press restores the shipped bindings, and that is saved too. ---
	var shake_before: float = float(ui.get_accessibility("camera_shake"))
	scene._toggle_audio_settings()
	await tick(3)
	ui.reset_bindings_button.pressed.emit()
	await tick(2)
	check(keys("hook") == [KEY_K, KEY_X] and keys("move_left") == [KEY_A, KEY_LEFT] and keys("attack") == [KEY_J], "恢复默认按键 restores hook, movement and attack")
	check(String(ui.remap_status.text).contains("已恢复全部默认按键") and is_equal_approx(float(ui.get_accessibility("camera_shake")), shake_before), "the reset says so and leaves other settings alone")
	await retire()
	await boot()
	check(keys("hook") == [KEY_K, KEY_X] and keys("attack") == [KEY_J], "the defaults are what loads after the next restart")

	await retire()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))
	check(await AUDIO.drain(self), "the fixture releases playback")
	print("SETTINGS_REMAP checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
