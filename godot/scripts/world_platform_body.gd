extends RefCounted
## Shared exact geometry factory. Detached bodies have no active-world owner.
static func create(node_name: String, rect: Rect2, collision_role: String) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.name = node_name
    body.position = rect.get_center()
    var role := collision_role.to_lower()
    var lower_name := node_name.to_lower()
    if role not in ["decorative", "no_collision"]:
        var shape := CollisionShape2D.new()
        var rectangle := RectangleShape2D.new()
        rectangle.size = rect.size
        shape.shape = rectangle
        if role == "one_way" or lower_name.begins_with("bridge_") or lower_name.begins_with("step_") or lower_name.begins_with("shaft_bridge_"):
            shape.one_way_collision = true
            shape.one_way_collision_margin = 2.0
        body.add_child(shape)
    return body
