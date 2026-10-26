extends Node2D
## Finite swept effects; tools never generate attack energy.
const SKILL_ART := preload("res://scripts/player_skill_art.gd")
const TOOL_ART := preload("res://scripts/player_tool_art.gd")
var art_family := ""
var tool_art_family := ""
var payload: Dictionary = {}
var direction := 1
var owner_player: Node2D = null
var elapsed := 0.0
var travelled := 0.0
var targets: Dictionary = {}
var trap := false
var ballistic_velocity := Vector2.ZERO
var landed := false
var warning_timer := -1.0
var landing_ray_origin := Vector2.INF

func _ready() -> void:
    var id := String(payload.get("id", ""))
    trap = String(payload.get("kind", "")) == "trap" or id == "mine"
    if String(payload.get("kind", "")) == "snare_field":
        trap = true
    if trap:
        add_to_group("player_snare_field" if String(payload.get("kind", "")) == "snare_field" else "player_trap")
    if id == "shard":
        ballistic_velocity = Vector2(direction * 290.0, -270.0)
    art_family = SKILL_ART.family_for(payload)
    tool_art_family = TOOL_ART.family_for(payload)
    if not art_family.is_empty() or not tool_art_family.is_empty():
        z_as_relative = false
        z_index = SKILL_ART.POLICY.BLADE_Z
        queue_redraw()
        return
    var visual := Polygon2D.new()
    visual.polygon = PackedVector2Array([Vector2(-8, -5), Vector2(8, -5), Vector2(8, 5), Vector2(-8, 5)])
    visual.color = Color(0.86, 0.65, 0.28) if id in ["shard", "lure"] else Color(0.88, 0.86, 0.72)
    add_child(visual)

func _physics_process(delta: float) -> void:
    if is_queued_for_deletion():
        return
    elapsed += delta
    if not art_family.is_empty() or not tool_art_family.is_empty():
        queue_redraw()
    var id := String(payload.get("id", ""))
    if not is_instance_valid(owner_player):
        queue_free()
        return
    # Flight limits still retire missed throws. Once a pot lands, its bounded
    # warning must finish even when the flight used almost all of its lifetime.
    var waiting_for_fuse := id == "shard" and landed
    if not waiting_for_fuse and (elapsed >= float(payload.get("duration", 5.0)) or travelled >= float(payload.get("range", 420.0))):
        _finish_skill("expiry", global_position)
        return
    var previous := global_position
    var next := previous
    if id == "shard" and not landed:
        ballistic_velocity.y += 700.0 * delta
        next += ballistic_velocity * delta
    elif not trap and id not in ["fog", "lure"] and not landed:
        next += Vector2(direction * 620.0 * delta, 0)
    if next != previous:
        if get_parent().has_method("_ensure_collision_segment"):
            get_parent()._ensure_collision_segment(previous, next)
        var ray := PhysicsRayQueryParameters2D.create(previous, next, 1, [owner_player.get_rid()])
        var hit := get_world_2d().direct_space_state.intersect_ray(ray)
        if get_parent().has_method("_rock_ray_hit"):
            var rock: Dictionary = get_parent()._rock_ray_hit(previous, next)
            if not rock.is_empty() and (hit.is_empty() or previous.distance_squared_to(rock.position) < previous.distance_squared_to(hit.position)):
                hit = rock
        if not hit.is_empty():
            global_position = hit.position
            if id == "shard":
                landed = true
                # Retain a known free point outside the contacted surface.
                # Rays starting exactly on that surface can miss a wall or
                # intersect the floor at distance zero in authored geometry.
                landing_ray_origin = previous
                warning_timer = 0.35
                modulate = Color(1.0, 0.45, 0.15)
            else:
                _finish_skill("wall", hit.position)
                return
        else:
            global_position = next
    travelled += previous.distance_to(global_position)
    if id == "shard":
        if not landed:
            return
        warning_timer -= delta
        if warning_timer > 0.0:
            return
    if id == "lure":
        for enemy in get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("world_residency_active") and not enemy.world_residency_active(): continue
            if enemy is Node2D and enemy.global_position.distance_to(global_position) <= float(payload.get("range", 320.0)) and enemy.has_method("investigate_lure"):
                enemy.investigate_lure(global_position, 1.5)
        _finish_skill("ring", global_position)
        return
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if enemy.has_method("world_residency_active") and not enemy.world_residency_active():
            continue
        if not enemy is Node2D or not enemy.has_method("take_hit") or targets.has(enemy.get_instance_id()):
            continue
        var hurtbox: Rect2 = enemy.get_hurtbox_rect() if enemy.has_method("get_hurtbox_rect") else Rect2(enemy.global_position - Vector2(34,38), Vector2(68,76))
        var radius := 130.0 if id == "fog" else (75.0 if id == "shard" else (36.0 if trap else 8.0))
        var point := Geometry2D.get_closest_point_to_segment(hurtbox.get_center(), previous, global_position)
        if not hurtbox.grow(radius).has_point(point):
            continue
        var ray_origin := landing_ray_origin if id == "shard" and landing_ray_origin.is_finite() else global_position
        if get_parent().has_method("_ensure_collision_segment"):
            get_parent()._ensure_collision_segment(ray_origin, hurtbox.get_center())
        var ray := PhysicsRayQueryParameters2D.create(ray_origin, hurtbox.get_center(), 1, [owner_player.get_rid()])
        if get_parent().has_method("_rock_ray_hit") and not get_parent()._rock_ray_hit(ray_origin, hurtbox.get_center()).is_empty():
            continue
        if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
            continue
        if id == "fog":
            if enemy.has_method("apply_target_interference"):
                enemy.apply_target_interference(2.0)
            continue
        targets[enemy.get_instance_id()] = true
        enemy.take_hit(maxi(1, int(payload.get("damage", 1))), direction)
        if bool(payload.get("skill_effect",false)) and enemy.has_method("report_skill_contact"):
            enemy.report_skill_contact(owner_player,String(payload.get("practice_skill_id","")),int(payload.get("practice_cast_serial",0)))
        if bool(payload.get("salt_mark", false)) and enemy.has_method("apply_salt_mark"):
            enemy.apply_salt_mark(5.0)
        if float(payload.get("stagger", 0.0)) > 0.0 and enemy.has_method("apply_stagger"):
            enemy.apply_stagger(float(payload.stagger))
        if String(payload.get("kind", "")) == "snare_field" and enemy.has_method("apply_snare"):
            var control_duration := float(payload.get("duration", 1.5))
            if bool(payload.get("salt_consume", false)) and enemy.has_method("consume_salt_mark") and enemy.consume_salt_mark():
                control_duration += 1.5
            enemy.apply_snare(control_duration)
        elif trap and enemy.has_method("apply_trip"):
            enemy.apply_trip(0.7)
        elif trap and enemy.has_method("apply_snare"):
            enemy.apply_snare(1.5)
        if not trap and id != "shard" and String(payload.get("kind", "")) != "wave":
            _finish_skill("hit", point)
            return
    if id == "shard" or id == "mine" and not targets.is_empty():
        _finish_skill("trigger", global_position)

func _draw() -> void:
    if not tool_art_family.is_empty():
        TOOL_ART.draw_frame(self, tool_art_family, TOOL_ART.active_frame(tool_art_family, elapsed, landed, warning_timer), direction)
        return
    if art_family.is_empty():
        return
    SKILL_ART.draw_frame(self, art_family, SKILL_ART.active_frame(art_family, elapsed), direction)
    if art_family == "snare":
        # Appearance does not delay the original active control radius.
        draw_arc(Vector2.ZERO,36,0,TAU,32,Color(.08,.1,.12,.8),3,true)
        draw_arc(Vector2.ZERO,36,0,TAU,32,Color(.9,.92,.84,.7),1,true)

func _finish_skill(reason: String, point: Vector2) -> void:
    if is_queued_for_deletion():
        return
    if not art_family.is_empty():
        SKILL_ART.spawn_terminal(get_parent(),point,art_family,direction,reason)
    if not tool_art_family.is_empty():
        TOOL_ART.spawn_terminal(get_parent(),point,tool_art_family,direction,reason)
    hide()
    set_physics_process(false)
    queue_free()
