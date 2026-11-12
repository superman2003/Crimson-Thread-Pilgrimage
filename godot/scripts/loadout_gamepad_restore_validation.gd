extends SceneTree
## E05: on the real World and with only joypad events, a player at a shrine can
## open the build page, save a loadout, change equipment, review the restore's
## differences and cost, back out safely, and confirm the restore. Every move
## is a real d-pad/button event; the route is planned over the same focus
## neighbours the viewport uses, then each step's focus is checked.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const PATH := "user://loadout_gamepad_restore.json"
var checks := 0
var failures := 0
var world: Node
var ui: Control
var presses := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func frames(count: int) -> void:
	for index in count:
		await process_frame

func pad(button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button
	press.pressed = true
	Input.parse_input_event(press)
	await frames(2)
	var lift: InputEventJoypadButton = press.duplicate()
	lift.pressed = false
	Input.parse_input_event(lift)
	await frames(2)
	presses += 1

func focus() -> Control:
	var window: Window = root
	for candidate in [ui.loadout_restore_dialog, ui.get("loadout_dialog")]:
		if candidate is Window and candidate.visible:
			window = candidate
	return window.gui_get_focus_owner()

## Shortest d-pad route between two controls over find_valid_focus_neighbor.
func route(start: Control, goal: Control) -> Array:
	var sides := {SIDE_LEFT: JOY_BUTTON_DPAD_LEFT, SIDE_TOP: JOY_BUTTON_DPAD_UP, SIDE_RIGHT: JOY_BUTTON_DPAD_RIGHT, SIDE_BOTTOM: JOY_BUTTON_DPAD_DOWN}
	var previous := {start: null}
	var queue: Array = [start]
	while not queue.is_empty():
		var control: Control = queue.pop_front()
		if control == goal:
			var path: Array = []
			while previous[control] != null:
				path.push_front(previous[control][1])
				control = previous[control][0]
			return path
		for side in sides:
			var next: Control = control.find_valid_focus_neighbor(side)
			if next != null and not previous.has(next):
				previous[next] = [control, sides[side]]
				queue.append(next)
	return []

func walk_to(goal: Control, label: String) -> bool:
	var start := focus()
	if start == null:
		check(false, label + ": nothing has controller focus")
		return false
	var path := route(start, goal)
	check(start == goal or not path.is_empty(), label + ": reachable with the d-pad from " + String(start.name))
	for button in path:
		await pad(button)
	check(focus() == goal, label + ": d-pad focus arrives (" + (String(focus().name) if focus() else "none") + ")")
	return focus() == goal

func find_button(text: String) -> Button:
	for node in ui.build_panel.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and String(node.text) == text:
			return node
	return null

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	world = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = PATH
	root.add_child(world)
	await READY.wait_for(world)
	await frames(6)
	ui = world.ui_shell
	var shrine: Area2D = null
	for child in world.get_children():
		if child is Area2D and String(child.get_meta("kind", "")) == "save_point":
			shrine = child
			break
	check(shrine != null, "start region has a shrine")
	world.player.global_position = shrine.global_position
	world.player.velocity = Vector2.ZERO
	await frames(4)
	check(world._near_workstation(), "player stands at the shrine workstation")
	var build: RefCounted = world.build_system
	var owned_tool := ""
	for id in build.catalog.tools:
		if int(build.state.tool_counts.get(id, 0)) > 0 or build.state.tools.has(id):
			owned_tool = id
	if owned_tool.is_empty():
		owned_tool = String(build.catalog.tools.keys()[0])
		build.state.tool_counts[owned_tool] = 2
	build.state.equipped_families.tool[0] = owned_tool
	build.state.tool_counts[owned_tool] = maxi(1, int(build.state.tool_counts.get(owned_tool, 0)))
	build._sync_aliases()

	# Open the build page from gameplay with the left-stick click.
	await pad(JOY_BUTTON_LEFT_STICK)
	await frames(4)
	check(world.active_overlay == "build" and ui.build_panel.visible, "left-stick click opens the build page")
	var tab: Button = null
	for candidate in ui.build_tabs:
		if String(candidate.get_meta("build_category", "")) == "构筑":
			tab = candidate
	if not await walk_to(tab, "loadout tab"):
		await finish()
		return
	await pad(JOY_BUTTON_A)
	await frames(3)
	check(ui.build_category == "构筑", "A on the tab switches to the loadout page")

	# Save the current equipment into an empty plan, all by controller.
	var save_button: Button = null
	var plan := ""
	for node in ui.build_panel.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and String(node.text).begins_with("保存为「"):
			save_button = node
			plan = String(node.get_meta("build_id", ""))
			break
	check(save_button != null and not plan.is_empty(), "an empty plan slot offers to save")
	if save_button == null or not await walk_to(save_button, "save plan"):
		await finish()
		return
	await pad(JOY_BUTTON_A)
	await frames(4)
	check(build.state.loadouts.has(plan), "A on save stores the plan (%s)" % plan)

	# Change the equipment so restoring is a real difference.
	build.state.equipped_families.tool[0] = ""
	build._sync_aliases()
	ui.refresh_build()
	await frames(3)
	var restore := find_button("恢复「%s」" % plan)
	check(restore != null and not restore.disabled, "the saved plan's restore entry is enabled at the shrine")
	if restore == null or not await walk_to(restore, "restore entry"):
		await finish()
		return
	var before: Dictionary = build.serialize()
	await pad(JOY_BUTTON_A)
	await frames(4)
	var dialog: ConfirmationDialog = ui.loadout_restore_dialog
	check(is_instance_valid(dialog) and dialog.visible, "A opens the restore review instead of restoring")
	check(build.serialize() == before, "opening the review changes nothing")
	check(focus() == dialog.get_cancel_button(), "the review opens on its safe keep-current button")
	var text := String(dialog.get("changes").text)
	check(text.contains("碎钱花费") and text.contains("生命：") and text.contains("绯线："), "review shows the cost and resource consequences")
	check(text.contains("战具"), "review lists the tool difference")
	# B backs out without a transaction.
	await pad(JOY_BUTTON_B)
	await frames(3)
	check(not dialog.visible and build.serialize() == before, "B closes the review and keeps the current build")
	check(world.active_overlay == "build", "backing out of the review stays on the build page")
	# Re-open and confirm with the d-pad and A.
	restore = find_button("恢复「%s」" % plan)
	if restore == null or not await walk_to(restore, "restore entry again"):
		await finish()
		return
	await pad(JOY_BUTTON_A)
	await frames(4)
	check(dialog.visible, "review opens again")
	if not await walk_to(dialog.get_ok_button(), "confirm button"):
		await finish()
		return
	await pad(JOY_BUTTON_A)
	await frames(6)
	check(not dialog.visible, "A on confirm completes and closes the review")
	check(String(build.state.equipped_families.tool[0]) == owned_tool, "the saved tool is equipped again")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(saved is Dictionary, "the restored build was written to the journey save")
	await finish()

func finish() -> void:
	world._close_overlays()
	await frames(2)
	world.queue_free()
	await frames(3)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	print("LOADOUT_GAMEPAD_RESTORE checks=%d presses=%d failures=%d" % [checks, presses, failures])
	quit(0 if failures == 0 else 1)
