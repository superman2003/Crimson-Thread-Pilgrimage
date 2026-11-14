extends RefCounted
## Player visual effects: dash ghosts, heal rings, attack, skill, landing, double-jump and thread-snap effects.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CONTACT_ART := preload("res://scripts/player_contact_art.gd")

static func spawn_double_jump_vfx(player: Node) -> void:
    for index in range(2):
        var thread := Line2D.new()
        thread.name = "DoubleJumpThread"
        thread.points = PackedVector2Array([Vector2(-24.0, -12.0 + index * 10.0), Vector2(0.0, 2.0 + index * 10.0), Vector2(24.0, -12.0 + index * 10.0)])
        thread.width = 3.0
        thread.default_color = player.THREAD_T2_CORE if index == 0 else player.THREAD_T1_CORE
        thread.z_index = 58
        if not player.VISUAL_POLICY.attach_secondary(player, thread, &"motion", player): continue
        var tween := thread.create_tween()
        tween.tween_property(thread, "scale", Vector2(1.5, 1.0), 0.22)
        tween.parallel().tween_property(thread, "modulate:a", 0.0, 0.22)
        tween.finished.connect(Callable(thread, "queue_free"))


static func spawn_dash_ghost(player: Node) -> void:
    var parent_node = player.get_parent()
    if parent_node == null or player.sprite == null or player.sprite.sprite_frames == null:
        return
    var texture = player.sprite.sprite_frames.get_frame_texture(player.sprite.animation, player.sprite.frame)
    if texture == null:
        return
    var ghost := Sprite2D.new()
    ghost.name = "DashGhost"
    ghost.texture = texture
    ghost.flip_h = player.sprite.flip_h
    ghost.offset = player.sprite.offset
    ghost.self_modulate = Color(player.THREAD_T2_CORE.r, player.THREAD_T2_CORE.g, player.THREAD_T2_CORE.b, 0.55)
    ghost.z_index = 55
    var ghost_material := CanvasItemMaterial.new()
    ghost_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    ghost.material = ghost_material
    if not player.VISUAL_POLICY.attach_secondary(parent_node, ghost, &"motion", player): return
    ghost.global_transform = player.sprite.global_transform
    var tween := ghost.create_tween()
    tween.tween_property(ghost, "self_modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.94, 0.24)
    tween.finished.connect(Callable(ghost, "queue_free"))


static func spawn_heal_effect(player: Node) -> void:
    for index in range(3):
        player._add_heal_ring(22.0 + float(index) * 15.0, 0.10 * float(index))
    for index in range(8):
        var thread := Line2D.new()
        thread.name = "HealThread"
        var x := -34.0 + float(index) * 9.7
        thread.points = PackedVector2Array([Vector2(x, -18.0), Vector2(x + 4.0, -76.0)])
        thread.width = 2.0
        thread.default_color = Color(player.THREAD_T3_CORE.r, player.THREAD_T3_CORE.g, player.THREAD_T3_CORE.b, 0.82)
        thread.z_index = 44
        if not player.VISUAL_POLICY.attach_secondary(player, thread, &"state", player): continue
        var tween := thread.create_tween()
        tween.tween_property(thread, "position:y", -18.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(thread, "modulate:a", 0.0, 0.42)
        tween.finished.connect(Callable(thread, "queue_free"))


static func add_heal_ring(player: Node, radius: float, delay: float) -> void:
    var ring := Line2D.new()
    ring.name = "HealEffectRing"
    var points := PackedVector2Array()
    for step in range(32):
        var angle := TAU * float(step) / 32.0
        points.append(Vector2(cos(angle), sin(angle)) * radius + Vector2(0.0, -44.0))
    ring.points = points
    ring.closed = true
    ring.width = 3.0
    ring.default_color = player.THREAD_T3_CORE
    ring.z_index = 45
    if not player.VISUAL_POLICY.attach_secondary(player, ring, &"state", player): return
    ring.scale = Vector2(0.38, 0.38)
    var tween := ring.create_tween()
    tween.tween_interval(delay)
    tween.tween_property(ring, "scale", Vector2(1.9, 1.9), 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.46)
    tween.finished.connect(Callable(ring, "queue_free"))


static func spawn_attack_vfx(player: Node, animation: StringName) -> void:
    if animation == &"hook_throw":
        player._spawn_hook_trail_vfx()
    elif animation == &"attack_2":
        player._spawn_skill_slash_vfx()


static func spawn_skill_slash_vfx(player: Node) -> void:
    if player.CONTACT_ART.supported_slash(player):
        CONTACT_ART.skill_slash(player)


static func spawn_land_vfx(player: Node) -> void:
    var dust := Line2D.new()
    dust.name = "LandDustVfx"
    dust.points = PackedVector2Array([
        Vector2(-24.0, -3.0),
        Vector2(-8.0, 2.0),
        Vector2(8.0, 2.0),
        Vector2(24.0, -3.0)
    ])
    dust.width = 3.0
    dust.default_color = Color(0.64, 0.92, 0.56, 0.72)
    dust.z_index = 34
    if not player.VISUAL_POLICY.attach_secondary(player, dust, &"motion", player): return
    var tween := dust.create_tween()
    tween.tween_property(dust, "scale", Vector2(1.7, 1.0), 0.18)
    tween.parallel().tween_property(dust, "modulate:a", 0.0, 0.18)
    tween.finished.connect(Callable(dust, "queue_free"))


static func spawn_thread_snap_vfx(player: Node, source_position: Vector2) -> void:
    var parent_node = player.get_parent()
    if parent_node == null:
        return
    var origin = player.global_position + Vector2(0.0, -34.0)
    var away = signf(player.global_position.x - source_position.x)
    if away == 0.0:
        away = -float(player.facing)
    for index in range(5):
        var thread := Line2D.new()
        thread.name = "ThreadSnapVfx"
        var angle = -PI * 0.5 + (float(index) - 2.0) * 0.42 + away * 0.3
        var length := 20.0 + float(index % 3) * 7.0
        var tip := Vector2(cos(angle), sin(angle)) * length
        thread.points = PackedVector2Array([Vector2.ZERO, tip])
        thread.width = 3.0
        thread.default_color = player.THREAD_T2_CORE
        thread.z_index = 80
        thread.position = origin
        if not player.VISUAL_POLICY.attach_secondary(parent_node, thread, &"state", player): continue
        var tween := thread.create_tween()
        tween.tween_property(thread, "position", origin + tip * 0.8, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(thread, "modulate:a", 0.0, 0.25)
        tween.finished.connect(Callable(thread, "queue_free"))
