extends RefCounted
## Forge supplies the texture. The displayed steel blade supplies every vertex
## and the emission timing; there is no independently playing slash animation.
const FRAMES: SpriteFrames = preload("res://assets/vfx/player_basic_attack/basic_slashes.tres")
const MELEE := preload("res://scripts/player_melee_feedback.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const TRAIL_SECONDS := 0.055
static var SOURCES: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/player_basic_attack/manifest.json")).effects


static func effect_key(direction: Vector2, airborne: bool) -> StringName:
    if direction.y < -0.5:
        return &"air_up" if airborne else &"up"
    if direction.y > 0.5:
        return &"air_down" if airborne else &"down"
    return &"left" if direction.x < 0.0 else &"right"


static func spawn(player: Node2D, weapon: AnimatedSprite2D, direction: Vector2, airborne: bool, active_seconds: float, preferences: Dictionary = {}) -> Node2D:
    if not is_instance_valid(player) or not is_instance_valid(weapon) or active_seconds <= 0.0:
        return null
    var slash := BladeRibbon.new()
    slash.name = "AttackSlashVfx"
    slash.set_meta("delivered_blade_art", true)
    slash.set_meta("contact_player_id", player.get_instance_id())
    slash.player = player
    slash.weapon = weapon
    slash.lifetime = active_seconds
    slash.effect = effect_key(direction, airborne)
    slash.source = SOURCES[String(slash.effect)].ribbon
    var cel := FRAMES.get_frame_texture(slash.effect, 1) as AtlasTexture
    slash.texture = cel.atlas
    slash.reduced_flash = not bool(preferences.get("flash_enabled", true))
    slash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    slash.visible = false
    if not POLICY.attach_action_trace(player, slash):
        return null
    return slash


class BladeRibbon extends Node2D:
    var player: Node2D
    var weapon: AnimatedSprite2D
    var effect: StringName
    var texture: Texture2D
    var source: Dictionary
    var lifetime := 0.18
    var reduced_flash := false
    var blade := PackedVector2Array()
    var prior_blade := PackedVector2Array()
    var quads: Array[PackedVector2Array] = []
    var uv_quads: Array[PackedVector2Array] = []
    var sampled_frame := -1
    var sampled_animation: StringName = &""
    var sampled_flip := false
    var trail_age := 0.0

    func _process(delta: float) -> void:
        if is_queued_for_deletion():
            return
        if not is_instance_valid(player) or not is_instance_valid(weapon) or player.is_queued_for_deletion():
            queue_free()
            return
        if player.attack_timer <= 0.0 or player.hurt_timer > 0.0 or player.death_timer > 0.0 or player.ui_input_locked or not player.active_skill.is_empty():
            queue_free()
            return
        var elapsed: float = player.attack_duration - player.attack_timer - player.attack_windup
        if elapsed < 0.0 or elapsed >= lifetime:
            visible = false
            if elapsed >= lifetime: queue_free()
            return
        # The six authored cels have wind-up 0/1, cutting 2/3 and recovery 4/5.
        # Holding any other pose must never conjure a detached crescent.
        if weapon.frame not in [2, 3] or not MELEE.BLADE_ANCHORS.has(weapon.animation):
            visible = false
            if weapon.frame >= 4 or not MELEE.BLADE_ANCHORS.has(weapon.animation): queue_free()
            return
        var next_blade := MELEE.blade_points(weapon, weapon.frame, self)
        var previous := MELEE.blade_points(weapon, weapon.frame - 1, self)
        if next_blade.size() != 2 or previous.size() != 2 or next_blade[0].is_equal_approx(next_blade[1]):
            visible = false
            queue_free()
            return
        var changed := weapon.frame != sampled_frame or weapon.animation != sampled_animation or weapon.flip_h != sampled_flip
        if changed:
            trail_age = 0.0
            sampled_frame = weapon.frame
            sampled_animation = weapon.animation
            sampled_flip = weapon.flip_h
        else:
            trail_age += maxf(0.0, delta)
        # Rebuild for sprite scale/offset changes (such as pogo), without
        # restarting the tail or advancing a separate texture animation.
        blade = next_blade
        prior_blade = previous
        visible = trail_age < TRAIL_SECONDS
        if visible:
            _build_ribbon()
            queue_redraw()

    func _build_ribbon() -> void:
        quads.clear()
        uv_quads.clear()
        var old_axis := prior_blade[1] - prior_blade[0]
        var new_axis := blade[1] - blade[0]
        var start := old_axis.angle()
        var sweep := wrapf(new_axis.angle() - start, -PI, PI)
        # An across-body wind-up uses the path through the facing side. Small
        # changes between actual cutting cels keep their measured signed turn.
        if absf(sweep) > PI * 0.6:
            var alternative := sweep - signf(sweep) * TAU
            var forward := Vector2.LEFT if weapon.flip_h else Vector2.RIGHT
            if Vector2.from_angle(start + alternative * 0.5).dot(forward) > Vector2.from_angle(start + sweep * 0.5).dot(forward):
                sweep = alternative
        var steps := clampi(int(absf(sweep) / deg_to_rad(5.0)), 2, 48)
        var inner := float(source.inner_ratio)
        for index in steps:
            var t0 := float(index) / steps
            var t1 := float(index + 1) / steps
            var root0 := prior_blade[0].lerp(blade[0], t0)
            var root1 := prior_blade[0].lerp(blade[0], t1)
            var axis0 := Vector2.from_angle(start + sweep * t0) * lerpf(old_axis.length(), new_axis.length(), t0)
            var axis1 := Vector2.from_angle(start + sweep * t1) * lerpf(old_axis.length(), new_axis.length(), t1)
            quads.append(PackedVector2Array([root0 + axis0 * inner, root0 + axis0, root1 + axis1, root1 + axis1 * inner]))
            uv_quads.append(PackedVector2Array([_source_uv(t0, inner), _source_uv(t0, 1.0), _source_uv(t1, 1.0), _source_uv(t1, inner)]))

    func _source_uv(progress: float, radial: float) -> Vector2:
        var angle := lerpf(float(source.start_angle), float(source.end_angle), progress)
        var center := Vector2(source.center[0], source.center[1])
        var origin := Vector2(source.atlas_frame.x, source.atlas_frame.y)
        return (origin + center + Vector2.from_angle(angle) * float(source.outer_radius) * radial) / texture.get_size()

    func _draw() -> void:
        var fade := clampf(1.0 - trail_age / TRAIL_SECONDS, 0.0, 1.0)
        var tint := Color(0.72, 0.64, 0.60, 0.46 * fade) if reduced_flash else Color(1.0, 1.0, 1.0, 0.78 * fade)
        for index in quads.size():
            var tail := float(index) / quads.size()
            var head := float(index + 1) / quads.size()
            var c0 := Color(tint, tint.a * (0.15 + 0.85 * tail * tail))
            var c1 := Color(tint, tint.a * (0.15 + 0.85 * head * head))
            draw_polygon(quads[index], PackedColorArray([c0, c0, c1, c1]), uv_quads[index], texture)
