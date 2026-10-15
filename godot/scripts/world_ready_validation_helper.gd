extends RefCounted
## Wait for the production publication boundary; add_child no longer finishes
## initial World construction synchronously. Standalone demos remain synchronous.
static func wait_for(scene: Node) -> void:
    if not is_instance_valid(scene) or scene.get_script() == null or scene.get_script().resource_path != "res://scripts/main_level.gd":
        return
    var tree := scene.get_tree()
    var deadline := Time.get_ticks_msec() + 15000
    while is_instance_valid(scene) and not scene.initial_region_ready:
        if Time.get_ticks_msec() >= deadline:
            push_error("World did not publish initial region within 15 seconds")
            tree.quit(1)
            return
        await tree.process_frame

static func original_camera_zones(scene: Node) -> int:
    var count := 0
    for zone in scene.player.room_camera.zones:
        if not String(zone.id).begins_with("upgrade_"): count += 1
    return count
