extends RefCounted
## Presentation only. Anchors are measured from this project's packaged hero
## frames (384 x 384) by tools/build_hero_supplement_motion.py; no borrowed
## effect assets or combat geometry live here.
## The brief blade smear follows the rendered weapon, never the hitbox envelope.

const VISUAL_POLICY := preload("res://scripts/combat_visual_policy.gd")

const SOURCE_SIZE := Vector2(384.0, 384.0)
const TRACE_SECONDS := 0.10
## Below this swept angle the trace stays a thin tail along the blade.
const ARC_MIN_RADIANS := 0.10
const ARC_MAX_RADIANS := PI * 1.5
const CONTACT_SECONDS := 0.065
const ANCHOR_FILE := "res://assets/sprites/player/generated_hero_motion_v4/runtime_supplement/blade_anchors.json"
## animation -> per-frame [root, tip]; an empty frame has no visible blade.
static var BLADE_ANCHORS: Dictionary = _load_blade_anchors()


static func _load_blade_anchors() -> Dictionary:
    var result := {}
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANCHOR_FILE))
    if not data is Dictionary or not data.get("animations") is Dictionary:
        push_error("Blade anchors missing or invalid: " + ANCHOR_FILE)
        return result
    for animation: String in data.animations:
        var frames: Array = []
        for pair: Variant in data.animations[animation]:
            if pair is Array and pair.size() == 2:
                frames.append([Vector2(pair[0][0], pair[0][1]), Vector2(pair[1][0], pair[1][1])])
            else:
                frames.append([])
        result[StringName(animation)] = frames
    return result


static func blade_points(sprite: AnimatedSprite2D, frame_index: int, relative_to: Node2D) -> PackedVector2Array:
    if not is_instance_valid(sprite) or not is_instance_valid(relative_to):
        return PackedVector2Array()
    var frames: Array = BLADE_ANCHORS.get(sprite.animation, [])
    if frames.is_empty():
        return PackedVector2Array()
    var anchors: Array = frames[clampi(frame_index, 0, frames.size() - 1)]
    var result := PackedVector2Array()
    for anchor: Vector2 in anchors:
        var local := anchor
        if sprite.flip_h:
            local.x = SOURCE_SIZE.x - local.x
        if sprite.flip_v:
            local.y = SOURCE_SIZE.y - local.y
        if sprite.centered:
            local -= SOURCE_SIZE * 0.5
        local += sprite.offset
        result.append(relative_to.to_local(sprite.to_global(local)))
    return result


static func spawn_swing(owner_node: Node2D, sprite: AnimatedSprite2D, active_seconds: float, preferences: Dictionary = {}) -> Node2D:
    if not is_instance_valid(owner_node) or not is_instance_valid(sprite) or active_seconds <= 0.0:
        return null
    var trace := BladeTrace.new()
    trace.name = "AttackSlashVfx"
    trace.weapon_sprite = sprite
    trace.lifetime = minf(TRACE_SECONDS, active_seconds)
    trace.reduced_flash = not bool(preferences.get("flash_enabled", true))
    trace.sample_blade = blade_points
    trace.z_as_relative = false
    trace.z_index = VISUAL_POLICY.BLADE_Z
    owner_node.add_child(trace)
    return trace


static func spawn_hit(parent_node: Node2D, world_position: Vector2, direction: Vector2, animation: StringName, preferences: Dictionary = {}) -> Node2D:
    if not is_instance_valid(parent_node):
        return null
    var contact := ContactNick.new()
    contact.name = "HitConfirmVfx"
    contact.strike_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
    contact.length = 16.0 if animation == &"attack_2" else 11.0
    contact.reduced_flash = not bool(preferences.get("flash_enabled", true))
    if not VISUAL_POLICY.attach_contact(parent_node, contact):
        return null
    contact.global_position = world_position
    return contact


class BladeTrace extends Node2D:
    var weapon_sprite: AnimatedSprite2D
    var sample_blade: Callable
    var lifetime := TRACE_SECONDS
    var reduced_flash := false
    var age := 0.0
    var blade := PackedVector2Array()
    var prior_blade := PackedVector2Array()
    var sampled_frame := -1
    var sampled_animation: StringName = &""
    # Signed angle the drawn blade has swept since the wind-up pose, around the grip.
    var sweep_from := 0.0
    var sweep := 0.0
    var last_angle := 0.0

    func _process(delta: float) -> void:
        if is_queued_for_deletion():
            return
        if lifetime <= 0.0 or not is_instance_valid(weapon_sprite):
            queue_free()
            return
        var next_blade: PackedVector2Array = sample_blade.call(weapon_sprite, weapon_sprite.frame, self)
        if next_blade.size() != 2 or next_blade[0].is_equal_approx(next_blade[1]):
            queue_free()
            return
        if sampled_frame < 0:
            # The first process delta includes time before this node had a draw
            # opportunity. Start its short lifetime at the first valid sample,
            # once only; otherwise a 53/100 ms frame would erase it unseen.
            # Invalid/missing weapon poses above cancel rather than waiting.
            age = 0.0
            prior_blade = sample_blade.call(weapon_sprite, maxi(0, weapon_sprite.frame - 1), self)
            if prior_blade.size() != 2 or prior_blade[0].is_equal_approx(prior_blade[1]):
                prior_blade = next_blade
            last_angle = (prior_blade[1] - prior_blade[0]).angle()
            sweep_from = last_angle
            sweep = 0.0
            _accumulate((next_blade[1] - next_blade[0]).angle())
        else:
            age += maxf(0.0, delta)
            if age >= lifetime:
                queue_free()
                return
            if weapon_sprite.frame != sampled_frame or weapon_sprite.animation != sampled_animation:
                prior_blade = blade
                _accumulate((next_blade[1] - next_blade[0]).angle())
        blade = next_blade
        sampled_frame = weapon_sprite.frame
        sampled_animation = weapon_sprite.animation
        queue_redraw()

    func _accumulate(angle: float) -> void:
        # Cels only show where the blade is; a swing travels through the front
        # of the body (a rising cut passes forward, never back over the head),
        # and once begun keeps turning the same way.
        var short_way := wrapf(angle - last_angle, -PI, PI)
        if is_zero_approx(short_way):
            return
        var long_way := short_way - signf(short_way) * TAU
        var step := short_way
        if not is_zero_approx(sweep):
            if signf(short_way) != signf(sweep) and absf(sweep + long_way) <= ARC_MAX_RADIANS:
                step = long_way
        else:
            var forward := Vector2.LEFT if weapon_sprite.flip_h else Vector2.RIGHT
            var short_mid := Vector2.from_angle(last_angle + short_way * 0.5).dot(forward)
            var long_mid := Vector2.from_angle(last_angle + long_way * 0.5).dot(forward)
            if long_mid > short_mid:
                step = long_way
        sweep = clampf(sweep + step, -ARC_MAX_RADIANS, ARC_MAX_RADIANS)
        last_angle = angle

    func _draw() -> void:
        if blade.size() != 2 or prior_blade.size() != 2:
            return
        var fade := clampf(1.0 - age / maxf(lifetime, 0.001), 0.0, 1.0)
        var root_point := blade[0].lerp(blade[1], 0.18)
        var tip := blade[1]
        var edge_color := Color(0.75, 0.70, 0.63, 0.24 * fade) if reduced_flash else Color(0.95, 0.90, 0.78, 0.56 * fade)
        if absf(sweep) >= ARC_MIN_RADIANS:
            _draw_arc(fade)
            draw_line(root_point.lerp(tip, 0.30), tip, edge_color, 0.85, true)
            return
        # Only the last fraction of the measured motion remains visible. No
        # expanding ellipse, additive halo, screen flash, or particle cloud.
        var tail_tip := tip.lerp(prior_blade[1], 0.22 * fade)
        var tail_root := root_point.lerp(prior_blade[0].lerp(prior_blade[1], 0.18), 0.09 * fade)
        if absf((tip - root_point).cross(tail_tip - root_point)) > 0.25:
            draw_colored_polygon(PackedVector2Array([root_point, tip, tail_tip, tail_root]), Color(0.70, 0.58, 0.49, 0.27 * fade))
        draw_line(root_point.lerp(tip, 0.30), tip, edge_color, 0.85, true)

    func _draw_arc(fade: float) -> void:
        # A flat band swept around the grip between the wind-up blade and the
        # current blade; the leading edge is opaque and the trailing end fades.
        var pivot := blade[0]
        var outer := (blade[1] - blade[0]).length() * 1.08
        var inner := outer * 0.38
        var steps := clampi(int(absf(sweep) / deg_to_rad(8.0)), 4, 32)
        var strength := (0.24 if reduced_flash else 0.55) * fade
        var tint := Color(0.70, 0.58, 0.49) if reduced_flash else Color(0.95, 0.86, 0.72)
        for index in steps:
            var t0 := float(index) / steps
            var t1 := float(index + 1) / steps
            var a0 := Vector2.from_angle(sweep_from + sweep * t0)
            var a1 := Vector2.from_angle(sweep_from + sweep * t1)
            var c0 := Color(tint, strength * t0 * t0)
            var c1 := Color(tint, strength * t1 * t1)
            draw_polygon(PackedVector2Array([pivot + a0 * inner, pivot + a0 * outer, pivot + a1 * outer, pivot + a1 * inner]),
                PackedColorArray([Color(c0, c0.a * 0.35), c0, c1, Color(c1, c1.a * 0.35)]))


class ContactNick extends Node2D:
    var strike_direction := Vector2.RIGHT
    var length := 11.0
    var reduced_flash := false
    var age := 0.0
    var sampled := false

    func _process(delta: float) -> void:
        if is_queued_for_deletion():
            return
        if not is_finite(length) or length <= 0.0 or not strike_direction.is_finite():
            queue_free()
            return
        if not sampled:
            # As with the blade trace, a slow first process interval must not
            # consume the mark before its first valid draw opportunity.
            sampled = true
            age = 0.0
        else:
            age += maxf(0.0, delta)
            if age >= CONTACT_SECONDS:
                queue_free()
                return
        queue_redraw()

    func _draw() -> void:
        var fade := clampf(1.0 - age / CONTACT_SECONDS, 0.0, 1.0)
        var axis := strike_direction.rotated(0.65)
        var normal := axis.orthogonal()
        var color := Color(0.74, 0.60, 0.50, 0.46 * fade) if reduced_flash else Color(0.96, 0.88, 0.70, 0.76 * fade)
        draw_colored_polygon(PackedVector2Array([-axis * length * 0.55, normal * 1.35, axis * length * 0.45, -normal * 0.85]), color)
