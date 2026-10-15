extends SceneTree
const PINS := preload("res://scripts/map_player_pins.gd")
const UI := preload("res://scripts/map_player_pins_runtime.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SURVEY := preload("res://scripts/cartography_runtime.gd")
const SAVE := "user://map_player_pins_validation.json"
const A := "demo_ch01_moss_bell_court"
const B := "demo_ch02_rain_foundry_canal"
var checks := 0
var failures: Array[String] = []
var level: Node
var capture_output := ""

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="): capture_output = argument.trim_prefix("--capture-output=")
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func _run() -> void:
    root.size = Vector2i(1280, 720)
    _model()
    await _world()
    if is_instance_valid(level): level.free()
    await process_frame
    for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    if failures.is_empty():
        print("MAP PLAYER PINS PASS checks=%d" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)

func _model() -> void:
    var config := {"map_rooms": [{"id": "hall", "layout_rect": [0, 0, 1000, 600]},
        {"id": "secret", "hidden": true, "layout_rect": [100, 100, 100, 100]}]}
    var configs := {A: config, B: config}
    var flags := {}
    _check(not PINS.add(flags, configs, A, Vector2(50, 50), "goal").ok and flags.is_empty(), "unowned annotation rejection does not create or repair a journal")
    JOURNAL.region(flags, A).owned = true
    var before := flags.duplicate(true)
    _check(not PINS.add(flags, configs, A, Vector2(50, 50), "goal").ok and flags == before, "owned public outline is insufficient without resting to chart")
    JOURNAL.region(flags, A).charted["hall"] = true
    var result := PINS.add(flags, configs, A, Vector2(50, 50), "goal")
    _check(result.ok and not flags.has(PINS.KEY), "charted addition returns private candidate without mutating flags")
    if not result.ok: return
    flags[PINS.KEY] = result.records
    _check(not PINS.add(flags, configs, A, Vector2(150, 150), "goal").ok, "uncharted nested secret cannot borrow the enclosing hall knowledge")
    _check(not PINS.add(flags, configs, A, Vector2(200, 150), "goal").ok and not PINS.add(flags, configs, A, Vector2(1000, 300), "goal").ok, "nested and outer far boundaries never fall through to a broader room")
    JOURNAL.region(flags, A).charted["secret"] = true
    result = PINS.add(flags, configs, A, Vector2(150, 150), "return")
    _check(result.ok, "separately charted secret addition reaches its private candidate")
    if not result.ok: return
    flags[PINS.KEY] = result.records
    _check(result.ok and PINS.visible(flags, configs).size() == 2, "separately charted secret can own its own pin")
    JOURNAL.region(flags, A).charted.erase("secret")
    _check(PINS.records(flags, configs).size() == 1, "unknown old secret pin is ignored without leaking or consuming capacity")
    var unknown := []
    for index in 12: unknown.append({"id": index + 20, "region_id": B, "room_id": "hall", "kind": "goal", "position": [300 + index * 40, 300]})
    flags[PINS.KEY] = unknown
    result = PINS.add(flags, configs, A, Vector2(50, 50), "warning")
    _check(result.ok and result.records.size() == 1, "twelve unknown old pins cannot lock the user out of usable capacity")
    if not result.ok: return
    flags[PINS.KEY] = result.records
    _check(PINS.remove(flags, configs, int(result.records[0].id)).ok, "replacement known pin remains deletable")
    flags.erase(PINS.KEY)
    for index in 12:
        result = PINS.add(flags, configs, A, Vector2(300 + index * 40, 300), PINS.KINDS[index % 3])
        _check(result.ok, "known bounded pin %d is accepted" % index)
        if result.ok: flags[PINS.KEY] = result.records
    _check(PINS.records(flags, configs).size() == 12 and not PINS.add(flags, configs, A, Vector2(900, 300), "goal").ok, "global twelve-pin capacity is enforced")
    _check(not PINS.add(flags, configs, A, Vector2(305, 300), "return").ok, "nearby duplicate across types is rejected")
    _check(not PINS.add(flags, configs, A, Vector2(NAN, 3), "goal").ok and not PINS.add(flags, configs, A, Vector2(30, 30), "invented").ok, "nonfinite input and unknown type are rejected")
    var valid: Dictionary = flags[PINS.KEY][0].duplicate(true)
    var malformed: Array = [null, 1, "bad", {}, {"id": 1, "kind": "goal", "region_id": A, "room_id": "hall", "position": [true, 2]},
        {"id": 2, "kind": "goal", "region_id": "missing", "room_id": "hall", "position": [50, 50]}, valid, valid.duplicate(true)]
    flags[PINS.KEY] = malformed
    before = flags.duplicate(true)
    _check(PINS.records(flags, configs).size() == 1 and flags == before, "malformed and duplicate old records are ignored without read-time writes")
    flags[PINS.KEY] = "bad container"
    _check(PINS.records(flags, configs).is_empty(), "wrong old container is safe")
    flags[PINS.KEY] = []
    for unused in 1000: flags[PINS.KEY].append({})
    flags[PINS.KEY].append(valid)
    _check(PINS.records(flags, configs).is_empty(), "hostile old array scanning is capped rather than traversing every element")

func _spawn(resume: bool) -> void:
    level = load("res://scenes/World.tscn").instantiate()
    level.world_resume = resume
    level.world_save_path = SAVE
    root.add_child(level)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(level)
    level.set_process(false)
    level.player.set_physics_process(false)
    for actor in get_nodes_in_group("enemy"): actor.process_mode = Node.PROCESS_MODE_DISABLED
    await _frames(2)
func _frames(count: int = 2) -> void:
    for unused in count: await process_frame
func _known_here() -> void:
    var room := PINS.owner(level.config, level.player.global_position)
    _check(not room.is_empty(), "authored player location has an innermost map room")
    if room.is_empty(): return
    JOURNAL.region(level.story_flags, String(level.config.id)).owned = true
    JOURNAL.region(level.story_flags, String(level.config.id)).charted[String(room.id)] = true
func _records() -> Array[Dictionary]: return PINS.records(level.story_flags, UI.configurations(level))
func _count() -> int: return _records().size()
func _toolbar() -> Control: return level.map_panel.get_node("PlayerPinToolbar")

func _mouse(button: MouseButton, pressed: bool, local: Vector2) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = button
    event.pressed = pressed
    event.position = level.survey_map_view.get_global_transform_with_canvas() * local
    event.global_position = event.position
    Input.parse_input_event(event)
    await _frames()
func _right(region: String, point: Vector2) -> void:
    var content := UI.project(level, region, point)
    var local: Vector2 = level.map_draw_root.position + content * level.survey_map_view.zoom
    _check(Rect2(Vector2.ZERO, level.survey_map_view.size).has_point(local), "mouse fixture lies in clipped viewport")
    await _mouse(MOUSE_BUTTON_RIGHT, true, local)
    await _mouse(MOUSE_BUTTON_RIGHT, false, local)
func _different_point(config: Dictionary, flags: Dictionary, region: String, from: Vector2) -> Vector2:
    var room := PINS.owner(config, from)
    var rect := SURVEY.room_rect(room)
    for x in [0.2, 0.4, 0.6, 0.8]:
        for y in [0.25, 0.5, 0.75]:
            var point := rect.position + rect.size * Vector2(x, y)
            if point.distance_to(from) > 60 and PINS.allowed(flags, region, config, point): return point
    return from

func _world() -> void:
    await _spawn(false)
    level._toggle_map()
    var toolbar := _toolbar()
    _check(toolbar.get_node("PinCurrent").focus_mode == Control.FOCUS_ALL and toolbar.get_node("PinKind").focus_mode == Control.FOCUS_ALL, "current-position and type controls support focus navigation")
    _check(toolbar.get_node("PinCurrent").disabled and _count() == 0, "unowned actual map disables current-position marker")
    await _right(A, level.player.global_position)
    _check(_count() == 0 and level.map_panel.get_node("PlayerPinStatus").text.contains("已补绘"), "actual right mouse rejects unknown rooms with a readable map-panel message")
    JOURNAL.region(level.story_flags, A).owned = true
    level._refresh_map_overlay()
    _check(toolbar.get_node("PinCurrent").disabled, "owned but uncharted actual map still disables marker")
    _known_here()
    level._refresh_map_overlay()
    var button: Button = toolbar.get_node("PinCurrent")
    button.grab_focus()
    var accept := InputEventAction.new()
    accept.action = "ui_accept"
    accept.pressed = true
    Input.parse_input_event(accept)
    await _frames()
    accept = InputEventAction.new()
    accept.action = "ui_accept"
    accept.pressed = false
    Input.parse_input_event(accept)
    await _frames()
    _check(_count() == 1 and button.has_focus(), "focused current-position button accepts UI activation and preserves focus after redraw")
    var marker: Label = level.map_draw_root.get_node_or_null("PlayerMapPin_1")
    _check(marker != null and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE and (marker.position + Vector2(8, 12)).distance_to(UI.project(level, A, level.player.global_position)) < 0.01, "regional marker projects local position and never steals drag input")
    toolbar.get_node("PinKind").select(1)
    var second := _different_point(level.config, level.story_flags, A, level.player.global_position)
    level.survey_map_view.magnify(2.0, UI.project(level, A, second))
    await _right(A, second)
    _check(_count() == 2 and _records()[1].kind == "warning" and Vector2(_records()[1].position[0], _records()[1].position[1]).distance_to(second) < 1.0, "real right mouse inverse zoom/pan stores the chosen local point and type")
    var signal_count := {"value": 0}
    var count_secondary := func(_point: Vector2): signal_count.value += 1
    level.survey_map_view.secondary_pressed.connect(count_secondary)
    var outside := InputEventMouseButton.new()
    outside.button_index = MOUSE_BUTTON_RIGHT
    outside.pressed = true
    outside.position = Vector2(-1, -1)
    level.survey_map_view._gui_input(outside)
    outside.position = Vector2(400, 200)
    level.survey_map_view.dragging = true
    level.survey_map_view._gui_input(outside)
    level.survey_map_view.dragging = false
    level.survey_map_view.secondary_pressed.disconnect(count_secondary)
    _check(signal_count.value == 0 and _count() == 2, "out-of-viewport and active-left-drag right presses emit no annotation event")
    var before_pan: Vector2 = level.map_draw_root.position
    var drag_at := Vector2(500, 260)
    await _mouse(MOUSE_BUTTON_LEFT, true, drag_at)
    var motion := InputEventMouseMotion.new()
    motion.position = level.survey_map_view.get_global_transform_with_canvas() * (drag_at - Vector2(30, 20))
    motion.relative = Vector2(-30, -20)
    Input.parse_input_event(motion)
    await _frames()
    await _mouse(MOUSE_BUTTON_LEFT, false, drag_at - Vector2(30, 20))
    _check(level.map_draw_root.position != before_pan and not level.survey_map_view.dragging and _count() == 2, "left drag and release still pan without creating a pin")
    var list: OptionButton = toolbar.get_node("PinList")
    list.select(0)
    list.item_selected.emit(0)
    _check(toolbar.get_node("PinDelete").disabled, "placeholder cannot enable delete")
    list.select(1)
    list.item_selected.emit(1)
    var original_key: Variant = level.story_flags[PINS.KEY]
    var disk := FileAccess.get_file_as_bytes(SAVE)
    var state: Dictionary = level.world_state.data
    var saved_currency := int(state.currency)
    level.currency_count += 7
    level.story_flags["pin_live_progress"] = true
    var earned_currency: int = level.currency_count
    level.world_save_failure_injected_for_validation = true
    toolbar.get_node("PinDelete").pressed.emit()
    _check(is_same(level.story_flags[PINS.KEY], original_key) and _count() == 2 and is_same(level.world_state.data, state) and FileAccess.get_file_as_bytes(SAVE) == disk, "failed delete restores only the exact old pin key and retains committed data and bytes")
    _check(bool(level.story_flags.pin_live_progress) and level.currency_count == earned_currency and int(state.currency) == saved_currency and not state.story_flags.has("pin_live_progress"), "pin rollback preserves newly earned live flag and currency while retaining the earlier committed checkpoint")
    var another := second + Vector2(40, 0)
    _check(PINS.allowed(level.story_flags, A, level.config, another), "failed-add fixture is a distinct charted point")
    var failed := UI.add_at_content(level, UI.project(level, A, another))
    _check(not failed.ok and String(failed.reason).contains("撤回") and is_same(level.story_flags[PINS.KEY], original_key) and _count() == 2, "failed add reaches storage and retains old pin ownership and count")
    level.world_save_failure_injected_for_validation = false
    level.world_save_blocked = true
    toolbar.get_node("PinDelete").pressed.emit()
    _check(is_same(level.story_flags[PINS.KEY], original_key) and is_same(level.world_state.data, state) and FileAccess.get_file_as_bytes(SAVE) == disk and level.map_panel.get_node("PlayerPinStatus").text.contains("暂停"), "blocked modification rejects before touching memory or disk")
    level.world_save_blocked = false
    level._refresh_map_overlay()
    level.world_map_view = true
    level._refresh_map_overlay()
    var config_b := ATLAS.configuration(B)
    var raw_point: Array = config_b.player_start
    var point_b := Vector2(raw_point[0], raw_point[1])
    await _right(B, point_b)
    _check(_count() == 2, "world overview rejects a point in an unknown region")
    var owner_b := PINS.owner(config_b, point_b)
    JOURNAL.region(level.story_flags, B).owned = true
    JOURNAL.region(level.story_flags, B).charted[String(owner_b.id)] = true
    level._refresh_map_overlay()
    level.survey_map_view.magnify(2.0, UI.project(level, B, point_b))
    await _right(B, point_b)
    _check(_count() == 3 and _records()[2].region_id == B and Vector2(_records()[2].position[0], _records()[2].position[1]).distance_to(point_b) < 1.0, "world overview right click inverts world origin plus zoom and pan to the correct region")
    marker = level.map_draw_root.get_node_or_null("PlayerMapPin_3")
    _check(marker != null and (marker.position + Vector2(8, 12)).distance_to(UI.project(level, B, point_b)) < 0.01, "world pin uses the same fixed projection as the atlas")
    for record in _records():
        var displayed: Label = level.map_draw_root.get_node("PlayerMapPin_" + str(record.id))
        var item_text := ""
        list = _toolbar().get_node("PinList")
        for index in range(1, list.item_count):
            if list.get_item_id(index) == int(record.id): item_text = list.get_item_text(index)
        _check(displayed.text.ends_with(str(record.id)) and item_text.begins_with(PINS.NAMES[PINS.KINDS.find(record.kind)] + str(record.id)), "visible marker and deletion list share pin number %d" % int(record.id))
    # Retain detached old controls deliberately: their callbacks must not act
    # on the persistent host after new region controls replace their owners.
    var old_view: Control = level.survey_map_view
    var old_toolbar: Control = toolbar
    level._close_overlays()
    level.map_panel.remove_child(old_toolbar)
    level.map_panel.remove_child(old_view)
    _check(await level.world_loader.replace_region_async(level, ROUTES.cached_config_path(B), point_b), "real cross-region transition carries custom pin journal")
    level.set_process(false)
    level.player.set_physics_process(false)
    _known_here()
    level._toggle_map()
    var pin_value: Variant = level.story_flags[PINS.KEY].duplicate(true)
    old_toolbar.get_node("PinCurrent").pressed.emit()
    old_view.secondary_pressed.emit(UI.project(level, B, point_b + Vector2(60, 0)))
    old_toolbar.get_node("PinDelete").pressed.emit()
    _check(level.story_flags[PINS.KEY] == pin_value and _toolbar() != old_toolbar and level.survey_map_view != old_view, "retained old buttons and view cannot mutate the new region journal")
    old_toolbar.free()
    old_view.free()
    _check(_count() == 3 and level.map_draw_root.get_node_or_null("PlayerMapPin_3") != null and level.map_draw_root.get_node_or_null("PlayerMapPin_1") == null, "destination regional view shows only its own pin while preserving the others")
    # Make an old-save fixture containing valid records plus JSON-safe damage.
    var malformed: Array = [1, {}, {"id": "bad", "position": ["bad", 0]}]
    malformed.append_array(level.story_flags[PINS.KEY])
    level.story_flags[PINS.KEY] = malformed
    _check(level._save_world(), "malformed-record old-save fixture remains valid World JSON")
    level.free()
    await _frames()
    await _spawn(true)
    level._toggle_map()
    _check(level.config.id == B and _count() == 3 and level.story_flags[PINS.KEY].size() == 6, "restart safely ignores malformed records without rewriting the old pin payload")
    list = _toolbar().get_node("PinList")
    for index in range(1, list.item_count):
        if list.get_item_id(index) == 3: list.select(index)
    list.item_selected.emit(list.selected)
    _toolbar().get_node("PinDelete").pressed.emit()
    _check(_count() == 2 and level.map_draw_root.get_node_or_null("PlayerMapPin_3") == null, "real delete button persists its selected known pin removal after restart")
    _toolbar().get_node("PinCurrent").pressed.emit()
    _check(_count() == 3, "current new-region button can add again after deletion")
    if not capture_output.is_empty(): await _capture()
    level._close_overlays()
    var closed_before: Variant = level.story_flags[PINS.KEY].duplicate(true)
    level.survey_map_view.secondary_pressed.emit(Vector2(200, 200))
    _toolbar().get_node("PinCurrent").pressed.emit()
    _check(level.story_flags[PINS.KEY] == closed_before, "closed map cannot accept lingering control events")
    var freed_toolbar := _toolbar()
    var freed_view: Control = level.survey_map_view
    level.map_panel.remove_child(freed_toolbar)
    level.map_panel.remove_child(freed_view)
    var freed_disk := FileAccess.get_file_as_bytes(SAVE)
    level.free()
    freed_toolbar.get_node("PinCurrent").pressed.emit()
    freed_view.secondary_pressed.emit(Vector2(200, 200))
    _check(FileAccess.get_file_as_bytes(SAVE) == freed_disk, "retained control callbacks after whole-host free do not error or write")
    freed_toolbar.free()
    freed_view.free()

func _capture() -> void:
    DirAccess.make_dir_recursive_absolute(capture_output)
    var layer := CanvasLayer.new()
    layer.layer = 110
    root.add_child(layer)
    var label := Label.new()
    label.position = Vector2(250, 3)
    label.text = "SHOWCASE | CHARTED MAP FIXTURE / PAUSED ACTORS / PLAYER PINS"
    label.add_theme_font_size_override("font_size", 13)
    layer.add_child(label)
    var rows := []
    for name in ["region", "world"]:
        level.world_map_view = name == "world"
        level._refresh_map_overlay()
        await _frames(5)
        await RenderingServer.frame_post_draw
        var path := capture_output.path_join(name + ".webp")
        var image := root.get_texture().get_image()
        _check(image.get_size() == Vector2i(1280, 720) and image.save_webp(path, true, 0.88) == OK, "optional actual GL " + name + " screenshot writes")
        rows.append({"file": name + ".webp", "sha256": FileAccess.get_sha256(path), "fixture": true, "frame_post_draw": true})
    var hashes := {}
    for file in ["main_level.gd", "survey_map_view.gd", "map_player_pins.gd", "map_player_pins_runtime.gd", "map_player_pins_validation.gd"]: hashes[file] = FileAccess.get_sha256("res://scripts/" + file)
    var handle := FileAccess.open(capture_output.path_join("manifest.json"), FileAccess.WRITE)
    handle.store_string(JSON.stringify({"sources_sha256": hashes, "screenshots": rows, "region": String(level.config.id)}, "  "))
    handle.close()
    layer.free()
