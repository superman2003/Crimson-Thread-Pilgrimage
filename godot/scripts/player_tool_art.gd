extends RefCounted
## Presentation only. Damage, control, placement and lifetimes belong to the tool.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/player_tools/player_tools.png")
const FAMILIES := ["shard", "mine", "fog", "lure"]
const CELL := 256.0

static func family_for(payload: Dictionary) -> String:
    if bool(payload.get("skill_effect", false)):
        return ""
    var id := String(payload.get("id", ""))
    return id if FAMILIES.has(id) else ""

static func active_frame(family: String, seconds: float, landed: bool = false, warning: float = .35) -> int:
    var tick := int(maxf(0, seconds) * 12)
    if family == "shard":
        return (2 if warning > .175 else 3) if landed else tick % 2
    if family == "mine":
        return 0 if tick == 0 else 1 + (tick - 1) % 2
    if family == "fog":
        return tick if tick < 2 else 2 + (tick - 2) % 4
    return 0

static func atlas_rect(family: String, frame: int) -> Rect2:
    var row := FAMILIES.find(family)
    if row < 0 or frame < 0 or frame >= (4 if family == "lure" else 8):
        return Rect2()
    return Rect2(frame * CELL, row * CELL, CELL, CELL)

static func draw_frame(host: Node2D, family: String, frame: int, direction: int, alpha: float = 1) -> bool:
    var source := atlas_rect(family, frame)
    if source.size == Vector2.ZERO:
        return false
    var width := (20.0 if frame < 4 else 150.0) if family == "shard" else float({"mine": 72, "fog": 260, "lure": 40}[family])
    var factor := width / (64.0 if family == "shard" and frame < 4 else 128.0)
    var bottom := family in ["mine", "lure"] or family == "shard" and frame in [2, 3]
    var anchor := Vector2(128, 192 if bottom else 128)
    var offset := Vector2(0, 6 if family == "mine" else 42 if family == "lure" else 0)
    # A 260px cloud must not hide actors under its original opaque painted core.
    if family == "fog": alpha *= .45
    host.draw_set_transform(Vector2.ZERO, 0, Vector2(-1 if direction < 0 and family == "shard" else 1, 1))
    host.draw_texture_rect_region(ATLAS, Rect2(offset - anchor * factor, Vector2.ONE * CELL * factor), source, Color(1, 1, 1, alpha))
    host.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
    return true

static func terminal_frames(family: String, reason: String) -> Vector2i:
    if family == "shard" and reason == "trigger":
        return Vector2i(4, 4)
    if family == "mine":
        if reason == "trigger": return Vector2i(3, 5)
        if reason == "expiry": return Vector2i(6, 2)
    if family == "fog" and reason == "expiry":
        return Vector2i(6, 2)
    if family == "lure" and reason == "ring":
        return Vector2i(0, 4)
    return Vector2i.ZERO

static func spawn_terminal(host: Node, point: Vector2, family: String, direction: int, reason: String) -> Node2D:
    var frames := terminal_frames(family, reason)
    if frames.y == 0:
        return null
    var mark := Terminal.new()
    mark.name = "PlayerToolTerminalVfx"
    mark.family = family
    mark.direction = direction
    mark.first = frames.x
    mark.count = frames.y
    mark.paint = draw_frame
    if not POLICY.attach_contact(host, mark):
        return null
    mark.global_position = point
    return mark

class Terminal extends Node2D:
    var family := ""
    var direction := 1
    var first := 0
    var count := 0
    var age := 0.0
    var sampled := false
    var paint: Callable
    func _process(delta: float) -> void:
        if is_queued_for_deletion(): return
        if not sampled: sampled = true
        else: age += maxf(0, delta)
        if age >= count / 16.0:
            queue_free()
            return
        queue_redraw()
    func _draw() -> void:
        paint.call(self, family, first + clampi(int(age * 16), 0, count - 1), direction, clampf((count / 16.0 - age) * 16, 0, 1))
