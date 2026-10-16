extends RefCounted
## Presentation only. Anchors were measured on this project's authored hero v3
## frames (384 x 384); no borrowed effect assets or combat geometry live here.
## The brief blade smear follows the rendered weapon, never the hitbox envelope.

const SOURCE_SIZE := Vector2(384.0, 384.0)
const TRACE_SECONDS := 0.055
const CONTACT_SECONDS := 0.065
const BLADE_ANCHORS := {
    &"attack_1": [
        [Vector2(190, 210), Vector2(246, 218)],
        [Vector2(177, 130), Vector2(170, 86)],
        [Vector2(207, 155), Vector2(254, 110)],
        [Vector2(190, 210), Vector2(248, 213)]
    ],
    &"air_attack": [
        [Vector2(230, 142), Vector2(263, 111)],
        [Vector2(228, 143), Vector2(262, 111)],
        [Vector2(229, 144), Vector2(263, 110)],
        [Vector2(232, 158), Vector2(232, 158)]
    ],
    &"down_attack": [
        [Vector2(151, 258), Vector2(200, 284)],
        [Vector2(176, 147), Vector2(155, 113)],
        [Vector2(210, 243), Vector2(269, 285)],
        [Vector2(216, 252), Vector2(259, 283)]
    ]
}


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
    trace.z_index = 60
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
    contact.z_index = 80
    parent_node.add_child(contact)
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
        else:
            age += maxf(0.0, delta)
            if age >= lifetime:
                queue_free()
                return
            if weapon_sprite.frame != sampled_frame or weapon_sprite.animation != sampled_animation:
                prior_blade = blade
        blade = next_blade
        sampled_frame = weapon_sprite.frame
        sampled_animation = weapon_sprite.animation
        queue_redraw()

    func _draw() -> void:
        if blade.size() != 2 or prior_blade.size() != 2:
            return
        var fade := clampf(1.0 - age / maxf(lifetime, 0.001), 0.0, 1.0)
        var root_point := blade[0].lerp(blade[1], 0.18)
        var tip := blade[1]
        # Only the last fraction of the measured motion remains visible. No
        # expanding ellipse, additive halo, screen flash, or particle cloud.
        var tail_tip := tip.lerp(prior_blade[1], 0.22 * fade)
        var tail_root := root_point.lerp(prior_blade[0].lerp(prior_blade[1], 0.18), 0.09 * fade)
        if absf((tip - root_point).cross(tail_tip - root_point)) > 0.25:
            draw_colored_polygon(PackedVector2Array([root_point, tip, tail_tip, tail_root]), Color(0.70, 0.58, 0.49, 0.27 * fade))
        var edge_color := Color(0.75, 0.70, 0.63, 0.24 * fade) if reduced_flash else Color(0.95, 0.90, 0.78, 0.56 * fade)
        draw_line(root_point.lerp(tip, 0.30), tip, edge_color, 0.85, true)


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
