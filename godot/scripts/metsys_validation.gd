extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _assert(root.has_node("MetSys"), "MetSys autoload exists")
    _assert(ProjectSettings.get_setting("addons/metroidvania_system/settings_file") == "res://MetSysSettings.tres", "MetSys settings path configured")

    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var state: Dictionary = scene.get_demo_state()
    _assert(bool(state.get("metsys_ready", false)), "MetSys bridge is ready")
    _assert(int(state.get("metsys_map_cells", 0)) >= 7, "MetSys map has demo room cells")
    _assert(int(state.get("metsys_wall_borders", 0)) > 0, "MetSys marks closed wall borders")
    _assert(int(state.get("metsys_passage_borders", 0)) > 0, "MetSys opens route passage borders")
    _assert(int(state.get("metsys_route_edges", 0)) >= 6, "MetSys creates main chapter route edges")
    _assert(int(state.get("metsys_locked_edges", 0)) >= 1, "MetSys marks locked boss gate edge")
    _assert(int(state.get("metsys_connector_cells", 0)) >= 1, "MetSys adds connector cells for vertical room transitions")
    _assert(int(state.get("metsys_discovered_cells", 0)) >= 1, "MetSys discovers the starting room")
    _assert(int(state.get("metsys_registered_objects", 0)) >= 4, "MetSys registers interactables")

    scene.player.global_position = Vector2(2050, 478)
    await process_frame
    state = scene.get_demo_state()
    _assert(String(state.get("current_room_id", "")) == "gear_lift", "room tracking moves to Gear Lift")
    _assert(int(state.get("metsys_discovered_cells", 0)) >= 2, "MetSys discovers traveled rooms")

    var save_point: Area2D = scene.get_node_or_null("save_hidden_upper_respite")
    _assert(save_point != null, "save point object exists for MetSys storage")
    scene.nearby_interactable = save_point
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(int(state.get("metsys_stored_objects", 0)) >= 1, "MetSys stores activated save point object")
    var stored_count := int(state.get("metsys_stored_objects", 0))
    scene.metsys_bridge.store_object(save_point)
    state = scene.get_demo_state()
    _assert(int(state.get("metsys_stored_objects", 0)) == stored_count, "MetSys ignores duplicate object store safely")
    _assert(state.has("metsys_save_data"), "MetSys exposes save data dictionary")

    print("METSYS_VALIDATION_PASS cells=%d walls=%d passages=%d routes=%d locked=%d connectors=%d discovered=%d registered=%d stored=%d" % [
        int(state.get("metsys_map_cells", 0)),
        int(state.get("metsys_wall_borders", 0)),
        int(state.get("metsys_passage_borders", 0)),
        int(state.get("metsys_route_edges", 0)),
        int(state.get("metsys_locked_edges", 0)),
        int(state.get("metsys_connector_cells", 0)),
        int(state.get("metsys_discovered_cells", 0)),
        int(state.get("metsys_registered_objects", 0)),
        int(state.get("metsys_stored_objects", 0))
    ])
    quit(0)


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    quit(1)
