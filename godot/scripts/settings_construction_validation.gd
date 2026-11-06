extends SceneTree
## Executes the actual HUD job plan with a paused World, then exercises its controls.
const UI := preload("res://scripts/pilgrimage_interface.gd")
const CAPTURE := preload("res://scripts/settings_construction_capture_validation.gd")
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
var world: Node
var checks := 0
var failures := 0
var cancel_on_slider := false
var partial_cancel := {}
var settings_work: Array = []

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func controls(node: Node) -> int:
    if node == null: return 0
    var result := 1 if node is Control else 0
    for child in node.get_children(): result += controls(child)
    return result

func control_structure(snapshot: Dictionary) -> Dictionary:
    # Resolved size includes minimum-size notifications delivered on different
    # frames while hidden. Published pixel/full-tree parity is captured separately.
    # Retain positions, custom minimums, text, ranges, state and child ordering.
    var result: Dictionary = snapshot.duplicate(true)
    result.erase("size")
    for index in result.children.size():
        result.children[index] = control_structure(result.children[index])
    return result

func progress_state() -> String:
    return var_to_str([world.currency_count,world.inventory_counts,world.story_flags,
        world.build_system.serialize(),world.player.hp,world.player.energy])

func key(code: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = true
    return event

func observe_slider(node: Node) -> void:
    if not cancel_on_slider or not node is HSlider: return
    if world.world_loader.phase != "committing" or world.ui_shell == null: return
    var ui: Control = world.ui_shell
    if node.get_parent() != ui.settings: return
    cancel_on_slider = false
    var overlay: String = world.active_overlay
    ui._input(key(KEY_B))
    partial_cancel = {"observed":true,"controls":controls(ui.settings),
        "input_disabled":not ui.construction_complete and not ui.is_processing_input(),
        "shortcut_ignored":world.active_overlay == overlay}
    world.world_loader.cancel_transition()

func cancel_during_settings() -> void:
    var source: String = world.config.id
    var position: Vector2 = world.player.global_position
    var before := progress_state()
    var destination := ROUTES.config_path("demo_ch02_rain_foundry_canal")
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(destination))
    node_added.connect(observe_slider)
    cancel_on_slider = true
    world._request_world_travel(destination,Vector2(config.player_start[0],config.player_start[1]))
    for unused in 4000:
        if world.world_loader.phase == "idle": break
        await process_frame
    cancel_on_slider = false
    node_added.disconnect(observe_slider)
    check(bool(partial_cancel.get("observed",false)), "actual arrival reaches a partially constructed settings page")
    check(bool(partial_cancel.get("input_disabled",false)) and bool(partial_cancel.get("shortcut_ignored",false)),
        "partial actual settings cannot consume the build shortcut")
    check(world.world_loader.phase == "idle" and bool(world.world_loader.last_transition.get("rolled_back",false)),
        "cancellation inside settings construction completes source rollback")
    check(String(world.config.id) == source and world.player.global_position == position and progress_state() == before,
        "partial-settings rollback preserves source position and settled progress")
    check(world.ui_shell.construction_complete and world.ui_shell.is_processing_input(), "rollback restores a complete source interface")
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.world_save_path))
    check(String(saved.get("current_region","")) == source, "partial settings never publish the destination save")

func run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://settings_construction_validation.json"
    root.add_child(world)
    await READY.wait_for(world)
    current_scene = world
    await cancel_during_settings()
    var before := progress_state()
    var save_bytes := FileAccess.get_file_as_bytes(world.world_save_path)
    var bindings: Dictionary = UI.BINDING_POLICY.snapshot()
    var previous_canvas: CanvasLayer = world.ui_canvas
    previous_canvas.visible = false
    # Match the production destination reset while manually stepping the HUD plan.
    # Autoload observers run even though this fixture's World is paused.
    world.initial_region_ready = false
    world.world_loading = true
    var previous_panel: Control
    var previous_count := 0
    var maximum := 0
    var jobs: Array = world._hud_build_jobs()
    for index in jobs.size():
        var job: Dictionary = jobs[index]
        world.callv(job.method,job.args)
        var ui: Control = world.ui_shell
        var panel: Control = ui.settings
        var count := controls(panel)
        var added := count - previous_count if panel == previous_panel else count
        if added > 0:
            maximum = maxi(maximum,added)
            settings_work.append({"job":String(job.method),"args":job.args,"controls_added":added})
        previous_panel = panel
        previous_count = count
        if index < jobs.size() - 1:
            check(not ui.construction_complete and not ui.is_processing_input(), "unfinished HUD retains its input gate")
            var overlay: String = world.active_overlay
            ui._input(key(KEY_B))
            check(world.active_overlay == overlay, "unfinished HUD ignores the actual shortcut handler")
            check(panel == null or not panel.visible, "unfinished settings stay hidden")
        await process_frame
    check(settings_work.size() >= 3 and maximum <= 32,
        "settings controls are spread across admissions of at most 32 controls")
    check(world.ui_shell.construction_complete and world.ui_shell.is_processing_input(), "only the completed HUD enables input")
    previous_canvas.free()
    for unused in 4: await process_frame
    var staged: Control = world.ui_shell
    var staged_tree := CAPTURE.snapshot_settings(staged.settings)
    var legacy := UI.new()
    world.ui_canvas.add_child(legacy)
    world.ui_shell = legacy
    legacy.begin_bind(world)
    for method in ["_build_hud", "_build_bag", "_build_dialogue", "_build_settings", "_build_build_panel"]:
        legacy.call(method)
    world._build_settings_overlay()
    legacy.finish_bind()
    var workbench: Node = root.get_node_or_null("JourneyWorkbench")
    if workbench != null: workbench.bind_region_ui(world)
    for unused in 4: await process_frame
    var synchronous_tree := CAPTURE.snapshot_settings(legacy.settings)
    if control_structure(synchronous_tree) != control_structure(staged_tree):
        var directory := ProjectSettings.globalize_path("res://../artifacts/settings_construction_v12")
        DirAccess.make_dir_recursive_absolute(directory)
        var file := FileAccess.open(directory.path_join("contract-tree-diff.json"),FileAccess.WRITE)
        file.store_string(JSON.stringify({"staged":staged_tree,"synchronous":synchronous_tree},"  "))
        file.close()
    check(control_structure(synchronous_tree) == control_structure(staged_tree),
        "direct synchronous settings wrapper retains control structure and values")
    world.ui_shell = staged
    world._build_settings_overlay()
    if workbench != null: workbench.bind_region_ui(world)
    legacy.free()
    world.initial_region_ready = true
    world.world_loading = false
    world._toggle_audio_settings()
    var ui: Control = world.ui_shell
    check(ui.settings.visible and world.player.ui_input_locked, "completed actual settings open and own gameplay input")
    for index in world.AUDIO_SETTINGS_ROWS.size():
        var name: String = world.AUDIO_SETTINGS_ROWS[index][0]
        var value: int = 61 + index
        ui.settings_sliders[name].value = value
        check(world.audio_director.get_user_volume(name) == value and world.settings_selection == index,
            "each volume callback retains its own row and bus")
    ui.accessibility_controls.camera_shake.slider.value = 0.25
    check(is_equal_approx(float(ui.accessibility.camera_shake),0.25), "accessibility slider still changes its authored preference")
    ui.accessibility_toggles.flash_enabled.button_pressed = false
    check(not bool(ui.accessibility.flash_enabled), "accessibility toggle keeps its original callback")
    ui.remap_buttons.jump.pressed.emit()
    check(ui.remap_target == "jump", "completed remap button enters the original capture flow")
    ui._input(key(KEY_ESCAPE))
    check(ui.remap_target.is_empty() and UI.BINDING_POLICY.snapshot() == bindings, "cancelled capture preserves actual bindings")
    ui._open_controller_comfort()
    check(ui.controller_comfort_dialog != null and ui.controller_comfort_dialog.visible, "controller calibration still opens from completed settings")
    ui.controller_comfort_dialog.hide()
    var output: Node = ui.get_node("AudioOutputDesk")
    output.open()
    check(output.window != null and output.window.visible, "audio output still builds on first open")
    output.window.hide()
    world._close_overlays()
    check(not ui.settings.visible and not world.player.ui_input_locked, "closing completed settings restores gameplay input")
    check(progress_state() == before and FileAccess.get_file_as_bytes(world.world_save_path) == save_bytes,
        "construction and preference controls preserve actual progress and exact game save")
    RETIRE.retire_tree(world)
    world.free()
    current_scene = null
    check(await RETIRE.drain(self), "settings fixture releases actual audio owners")
    print("SETTINGS CONSTRUCTION METRICS ",JSON.stringify({"work":settings_work,"max_controls":maximum,
        "partial_cancel":partial_cancel,"natural_playthrough":false}))
    print("SETTINGS_CONSTRUCTION checks=%d failures=%d" % [checks,failures])
    quit(0 if failures == 0 else 1)
