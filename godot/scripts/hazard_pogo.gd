extends RefCounted
## C01: hazards a downslash can bounce from. Static spikes only; collapsing,
## falling and exploding hazards are not standing surfaces.
const GROUP := &"pogo_surface"
const KINDS := ["spikes"]
## Short grace after a hazard bounce so a fast fall cannot take the spike hit
## in the same frames the bounce reverses it.
const CONTACT_GRACE := 0.12

static func mark(area: Area2D, kind: String, size: Vector2) -> bool:
    if not KINDS.has(kind):
        return false
    area.set_meta("pogo_size", size)
    area.add_to_group(GROUP)
    return true

static func surface_rect(area: Node2D) -> Rect2:
    var size: Vector2 = area.get_meta("pogo_size", Vector2.ZERO)
    return Rect2(area.global_position - size * 0.5, size)
