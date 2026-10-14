extends SceneTree
const MARKER := preload("res://scripts/world_wayfinding.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://wayfinding_validation.json"
    root.add_child(scene)
    await process_frame
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)
    var rests: Array = []
    for child in scene.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "save_point":
            rests.append(child)
    check(not rests.is_empty(), "authored rest points exist")
    scene.story_flags.erase("tutorial_interaction_seen_save_point")
    var first_rest := true
    for rest in rests:
        var marker: Node = rest.get_node("Wayfinding")
        check(marker.symbol == "rest", "all checkpoints share flame glyph")
        scene.player.global_position = rest.global_position + Vector2(350, 0)
        marker._process(0)
        check(not marker.visible and marker.key_hint.is_empty(), "distant/hidden checkpoint has no floating prompt")
        scene.player.global_position = rest.global_position
        marker._process(0)
        check(marker.visible and marker.nearby, "approaching rest shows object pictogram")
        if first_rest:
            check(String(scene.toast_label.text).contains("休息"), "first rest encounter teaches interaction once")
            first_rest = false
        scene.toast_label.text = "sentinel"
        marker._process(0)
        check(scene.toast_label.text == "sentinel", "repeat rest encounter does not replace toast with tutorial")
        scene.active_overlay = "map"
        marker._process(0)
        check(not marker.visible and marker.key_hint.is_empty(), "overlay clears nearby prompt")
        scene.active_overlay = ""
    var saved := preload("res://scripts/world_state.gd").new()
    check(saved.read(scene.world_save_path) and bool(saved.data.story_flags.get("tutorial_interaction_seen_save_point", false)), "seen tutorial persists in save")
    var portal: Node = scene.get_node("moss_rain_pipe")
    var sign: Node = portal.get_node("Wayfinding")
    check(sign.physical_sign and sign.symbol == "forge" and sign.direction == Vector2.RIGHT, "pipe mouth points to foundry using emblem and arrow")
    scene.player.global_position = portal.global_position
    sign._process(0)
    var bindings := InputMap.action_get_events("interact")
    InputMap.action_erase_events("interact")
    var event := InputEventKey.new()
    event.physical_keycode = KEY_E
    InputMap.action_add_event("interact", event)
    sign._process(0)
    check(sign.key_hint == "E", "proximity key follows remapping")
    InputMap.action_erase_events("interact")
    for binding in bindings:
        InputMap.action_add_event("interact", binding)
    for child in scene.get_children():
        if child is Area2D and child.has_meta("map_seller_region"):
            scene.player.global_position = child.global_position
            var marker: Node = child.get_node("Wayfinding")
            marker._process(0)
            check(marker.symbol == "map" and not child.has_node("MapSellerMarker"), "map seller uses distinct book-map glyph without price caption")
    scene.ui_shell._process(0)
    check(not scene.ui_shell.prompt.visible and scene.ui_shell.prompt.text.is_empty(), "HUD does not duplicate interaction prose")
    scene.player.global_position = portal.global_position
    check(scene.world_passage.begin("moss_rain_pipe"), "pipe begins")
    var floor_art: Texture2D = scene.world_passage.get_node("AuthoredFloor").material.get_shader_parameter("edge_atlas")
    var ceiling_art: Texture2D = scene.world_passage.get_node("AuthoredCeiling").material.get_shader_parameter("edge_atlas")
    check(floor_art.resource_path != ceiling_art.resource_path, "floor and ceiling use independently authored images")
    var rim: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/flat_maps/shared_ink/edges.json"))
    var floor_data: Dictionary = rim.floor
    var anchor: float = floor_data.anchor_v
    var max_rim_shift := maxf(absf(float(floor_data.edge_pixel_range[0])/float(floor_data.height)-anchor),absf(float(floor_data.edge_pixel_range[1])/float(floor_data.height)-anchor))*600*0.18+600/255
    check(max_rim_shift < 20, "painted floor rim stays within 20px of collision; boots remain readable")
    var endpoint_count := 0
    var mounts: Array = []
    for child in scene.world_passage.get_children():
        check(not child is CanvasLayer and not child is Label, "pipe contains no text guidance layer")
        if String(child.name).begins_with("Endpoint_"):
            endpoint_count += 1
            mounts.append(child.mount)
            check(child is Node2D and child.physical_sign, "pipe endpoint is grounded sign")
    check(mounts.has("stone") and mounts.has("lantern"), "pipe mixes grounded and hanging signs with same semantic glyphs")
    check(endpoint_count == 2, "both pipe directions have physical signs")
    scene.world_passage._return_to_source(true)
    scene.free()
    await process_frame
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://wayfinding_validation.json" + suffix))
    print("WORLD_WAYFINDING checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
