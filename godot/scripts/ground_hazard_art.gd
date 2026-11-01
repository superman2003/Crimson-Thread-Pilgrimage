extends RefCounted
## Presentation only: the attack retains its original circular collision/timing.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/ground_hazards/ground_hazards.png")
const FAMILIES := ["caltrops", "focus", "fungus", "haze", "seal", "shadow", "slag", "snare"]
const CELL := 192.0
const BODY := 128.0
const FLOOR_ANCHOR := Vector2(96, 144)
const APPEAR_SECONDS := 0.2
const ACTIVE_FPS := 12.0
const FADE_FPS := 12.0
const FADE_SECONDS := 2.0 / FADE_FPS
const LEGACY := {
    "spore_bellmaker": {"spore":"fungus"}, "echo_moss_larva": {"thorn":"fungus"},
    "rain_censer_mote": {"thorn":"haze"}, "pollen_lutist": {"thorn":"haze"},
    "index_scribe": {"thorn":"seal"}, "echo_contract_scribe": {"thorn":"seal"},
    "root_cage_hunter": {"thorn":"snare"}, "broken_string_gardener": {"thorn":"snare"},
    "sunken_hammer_smith": {"thorn":"snare"}, "pilgrim_chariot": {"thorn":"caltrops"},
    "delayed_shadow": {"thorn":"shadow"}, "silent_pilgrim_commander": {"thorn":"shadow"},
    "isotope_lumen": {"thorn":"focus"}, "pipe_thrower": {"metal":"slag", "slug":"slag"}
}

static func family_for(skin: String, owner_node: Node = null) -> String:
    var kind := String(owner_node.get("kind")) if is_instance_valid(owner_node) and "kind" in owner_node else ""
    var family := String(LEGACY.get(kind, {}).get(skin, skin))
    return family if FAMILIES.has(family) else ""

static func frame_for(age: float, arm_delay: float) -> int:
    if age < arm_delay:
        var span := minf(APPEAR_SECONDS, arm_delay)
        var start := arm_delay - span
        return -1 if age < start else clampi(int((age - start) / maxf(span, 0.001) * 2.0), 0, 1)
    return 2 + int(maxf(0, age - arm_delay) * ACTIVE_FPS) % 4

static func atlas_rect(family: String, frame: int) -> Rect2:
    var row := FAMILIES.find(family)
    if row < 0 or frame < 0 or frame > 7: return Rect2()
    return Rect2(Vector2(frame * CELL, row * CELL), Vector2(CELL, CELL))

static func draw_frame(host: Node2D, family: String, frame: int, radius: float, tint: Color) -> bool:
    var source := atlas_rect(family, frame)
    if source.size == Vector2.ZERO or not is_finite(radius) or radius <= 0: return false
    var scale := radius * 2.0 / BODY
    # Attack centers are five pixels above sampled terrain. Keep feet on it,
    # including small/large radii; never rotate a ground patch with projectile aim.
    var destination := Rect2(Vector2(0, 5) - FLOOR_ANCHOR * scale, Vector2.ONE * CELL * scale)
    var color := tint if family == "haze" else Color(1, 1, 1, tint.a)
    host.draw_texture_rect_region(ATLAS, destination, source, color)
    return true

static func spawn_fade(host: Node, point: Vector2, family: String, radius: float, tint: Color) -> Node2D:
    if not FAMILIES.has(family): return null
    var mark := Fade.new()
    mark.name = "GroundHazardFadeVfx"
    mark.family = family
    mark.radius = radius
    mark.tint = tint
    mark.paint = draw_frame
    if not POLICY.attach_contact(host, mark): return null
    mark.global_position = point
    return mark

class Fade extends Node2D:
    var family := ""
    var radius := 32.0
    var tint := Color.WHITE
    var paint: Callable
    var age := 0.0
    var sampled := false

    func _process(delta: float) -> void:
        if is_queued_for_deletion(): return
        if not sampled: sampled = true
        else: age += maxf(0, delta)
        if age >= FADE_SECONDS:
            queue_free()
            return
        queue_redraw()

    func _draw() -> void:
        var color := tint
        color.a = clampf((FADE_SECONDS - age) * FADE_FPS, 0, 1)
        paint.call(self, family, 6 + clampi(int(age * FADE_FPS), 0, 1), radius, color)
