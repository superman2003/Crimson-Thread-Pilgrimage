extends RefCounted
## Lever-controlled shortcuts, room bounds, and opening the boss and combat-clear routes.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func shortcut_is_lever_controlled(level: Node, shortcut_id: String) -> bool:
    if shortcut_id.is_empty():
        return false
    for interactive in level.config.get("interactives", []):
        if interactive is Dictionary and String(interactive.get("kind", "")) == "lever" and String(interactive.get("shortcut_id", "")) == shortcut_id:
            return true
    return false


static func room_has_position_bounds(level: Node, room_data: Dictionary) -> bool:
    if level._room_layout_rect(room_data).has_area():
        return true
    for rect_value in room_data.get("visit_rects", []):
        if level._rect2(rect_value).has_area():
            return true
    return false


static func room_containing_area(level: Node, room_data: Dictionary, world_position: Vector2) -> float:
    var area := INF
    var layout: Rect2 = level._room_layout_rect(room_data)
    if layout.has_area() and level._rect_contains_position(layout, world_position):
        area = layout.get_area()
    for rect_value in room_data.get("visit_rects", []):
        var rect: Rect2 = level._rect2(rect_value)
        if rect.has_area() and level._rect_contains_position(rect, world_position):
            area = minf(area, rect.get_area())
    return area


static func unlock_boss_route(level: Node) -> void:
    level.boss_unlocked = true
    level.shortcut_open = true
    if level.gate_body != null and is_instance_valid(level.gate_body):
        level.gate_body.queue_free()
        level.gate_body = null


static func open_combat_clear_route(level: Node) -> void:
    for shortcut_id in level._shortcut_ids():
        if not level._shortcut_is_lever_controlled(String(shortcut_id)):
            level.opened_shortcuts[String(shortcut_id)] = true
    level._unlock_boss_route()
    level._refresh_hud()
