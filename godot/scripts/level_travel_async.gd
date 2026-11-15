extends RefCounted
## The asynchronous part of travelling between regions.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func travel_world_async(level: Node, next_path: String, entry: Vector2, shortcut: String = "") -> void:
    if level.world_loader == null or level.world_loader.phase != "idle":
        level.world_portal_request_pending = false
        return
    var publish_flags: Dictionary = {}
    if not shortcut.is_empty():
        publish_flags["world_shortcut_" + shortcut] = true
    var ok: bool = await level.world_loader.replace_region_async(level, next_path, entry, Vector2.INF, publish_flags)
    if not is_instance_valid(level) or not level.is_inside_tree():
        return
    level.world_portal_request_pending = false
    if not ok:
        level._toast("旧路暂未接通，仍留在当前区域。" + level.world_loader.last_error)
