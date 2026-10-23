extends RefCounted
## Authored pixels only. This helper never moves a projectile or applies damage.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/projectiles/projectiles.png")
const FAMILIES := ["blade", "bolt", "chime", "incense", "key", "light", "net", "page", "pollen", "seed", "slug", "spore", "stinger", "thorn", "wheel"]
const CELL := 128.0
const BODY := 64.0
const FLIGHT_FPS := 14.0
const IMPACT_FPS := 20.0
const IMPACT_SECONDS := 4.0 / IMPACT_FPS
# Existing commands used a handful of generic skins. Only those legacy pairs
# are translated; a future command's explicit different skin remains its choice.
const LEGACY := {
    "root_cage_hunter": {"thorn":"net"},
    "wax_bee": {"thorn":"stinger"},
    "phase_censor": {"thorn":"blade"},
    "delayed_shadow": {"thorn":"blade"},
    "kneeling_crossbowman": {"thorn":"bolt"},
    "pipe_thrower": {"metal":"slug"},
    "silent_bugbler": {"metal":"chime"},
    "falling_clapper": {"metal":"chime"},
    "rain_censer_mote": {"pollen":"incense"},
    "broken_string_gardener": {"pollen":"seed"}
}

static func family_for(skin: String, owner_node: Node = null) -> String:
    var kind := String(owner_node.get("kind")) if is_instance_valid(owner_node) and "kind" in owner_node else ""
    var family := String(LEGACY.get(kind, {}).get(skin, skin))
    if family == "metal":
        family = "slug"
    return family if FAMILIES.has(family) else ""

static func flight_frame(seconds: float) -> int:
    return int(maxf(0.0, seconds) * FLIGHT_FPS) % 4

static func impact_frame(seconds: float) -> int:
    return 4 + clampi(int(maxf(0.0, seconds) * IMPACT_FPS), 0, 3)

static func atlas_rect(family: String, frame: int) -> Rect2:
    var row := FAMILIES.find(family)
    if row < 0 or frame < 0 or frame > 7:
        return Rect2()
    return Rect2(Vector2(frame * CELL, row * CELL), Vector2(CELL, CELL))

static func draw_frame(host: Node2D, family: String, frame: int, radius: float, axis: Vector2, alpha: float, reflected: bool = false) -> bool:
    var source := atlas_rect(family, frame)
    if source.size == Vector2.ZERO or not is_finite(radius) or radius <= 0.0:
        return false
    var size := Vector2.ONE * CELL * (radius * 2.0 / BODY)
    var direction := axis.normalized() if axis.length_squared() > 0.0001 else Vector2.RIGHT
    host.draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE)
    if reflected:
        # A reflected shot keeps its authored silhouette and a gold return cue.
        host.draw_arc(Vector2.ZERO, radius * 1.08, 0, TAU, 24, Color(0.96, 0.86, 0.53, alpha * 0.9), 1.2, true)
    host.draw_texture_rect_region(ATLAS, Rect2(-size * 0.5, size), source, Color(1.0, 0.95 if reflected else 1.0, 0.75 if reflected else 1.0, alpha))
    host.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    return true

static func spawn_impact(host: Node2D, point: Vector2, family: String, radius: float, axis: Vector2, reflected: bool) -> Node2D:
    if not FAMILIES.has(family):
        return null
    var mark := Impact.new()
    mark.name = "ProjectileImpactVfx"
    mark.family = family
    mark.radius = radius
    mark.axis = axis
    mark.reflected = reflected
    mark.paint = draw_frame
    if not POLICY.attach_contact(host, mark):
        return null
    mark.global_position = point
    return mark

class Impact extends Node2D:
    var family := ""
    var radius := 11.0
    var axis := Vector2.RIGHT
    var reflected := false
    var paint: Callable
    var age := 0.0
    var sampled := false

    func _process(delta: float) -> void:
        if is_queued_for_deletion():
            return
        if not sampled:
            sampled = true
        else:
            age += maxf(0.0, delta)
        if age >= IMPACT_SECONDS:
            queue_free()
            return
        queue_redraw()

    func _draw() -> void:
        var frame := 4 + clampi(int(age * IMPACT_FPS), 0, 3)
        paint.call(self, family, frame, radius, axis, clampf((IMPACT_SECONDS - age) / 0.05, 0, 1), reflected)
