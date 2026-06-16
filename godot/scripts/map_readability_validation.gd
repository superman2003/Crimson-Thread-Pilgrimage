extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var start_ground := scene.get_node_or_null("start_ground")
    _assert(start_ground != null, "start platform exists")
    _assert(start_ground.get_child_count() >= 6, "platform has layered visual plates")

    scene._toggle_map()
    await process_frame
    _assert(scene.map_panel.visible, "map overlay opens")
    _assert(scene.map_panel.color.a >= 0.95, "map overlay backing is opaque enough")
    _assert(scene.map_panel.size.x >= 1160.0 and scene.map_panel.size.y >= 630.0, "map overlay is large enough")

    var current_room: ColorRect = scene.map_draw_root.get_node_or_null("Room_entry_bell") as ColorRect
    var current_border: ColorRect = scene.map_draw_root.get_node_or_null("Room_entry_bellBorder") as ColorRect
    var player_marker: ColorRect = scene.map_draw_root.get_node_or_null("PlayerMarker") as ColorRect
    _assert(current_room != null, "current room block is drawn")
    _assert(current_border != null, "current room border is drawn")
    _assert(player_marker != null, "player marker is drawn")
    _assert(player_marker.size.y >= 90.0, "player marker is tall enough to read")

    var room_blocks := 0
    for child in scene.map_draw_root.get_children():
        if String(child.name).begins_with("Room_") and not String(child.name).ends_with("Border"):
            room_blocks += 1
    _assert(room_blocks >= 7, "all room blocks draw on map")

    print("MAP_READABILITY_VALIDATION_PASS rooms=%d panel=%sx%s platform_children=%d" % [
        room_blocks,
        scene.map_panel.size.x,
        scene.map_panel.size.y,
        start_ground.get_child_count()
    ])
    quit(0)


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    quit(1)
