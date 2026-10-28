extends Node2D
## Finite swept effects; tools never generate attack energy.
const SKILL_ART := preload("res://scripts/player_skill_art.gd")
const TOOL_ART := preload("res://scripts/player_tool_art.gd")
const LIFECYCLE := preload("res://scripts/player_effect_lifecycle.gd")
var owner_generation := 0
var cancelled := false
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
    add_to_group("player_combat_effect")
    if is_instance_valid(owner_player): owner_generation = LIFECYCLE.generation(owner_player)
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
    if cancelled or is_queued_for_deletion(): return
    var state := LIFECYCLE.state(owner_player, get_parent(), owner_generation)
    if state == LIFECYCLE.RETIRED:
        cancel()
        return
    if state == LIFECYCLE.PAUSED: return
    if not is_finite(delta) or delta <= 0.0: return
    var id := String(payload.get("id", ""))
    if not trap and id not in ["shard", "fog", "lure"]:
        _advance_projectile(delta)
        return
    elapsed += delta
    if not art_family.is_empty() or not tool_art_family.is_empty():
        queue_redraw()
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
        _apply_contact(enemy)
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


## Targets and terrain compete on one segment. Terrain wins exact ties.
func _advance_projectile(delta: float) -> void:
    if not is_instance_valid(owner_player) or not owner_player is CollisionObject2D:
        queue_free()
        return
    var lifetime := maxf(0.0, float(payload.get("duration", 5.0)))
    var reach := maxf(0.0, float(payload.get("range", 420.0)))
    if not is_finite(lifetime) or not is_finite(reach):
        queue_free()
        return
    var seconds := minf(delta, maxf(0.0, lifetime - elapsed))
    var distance := minf(620.0 * seconds, maxf(0.0, reach - travelled))
    if distance <= 0.0:
        _finish_skill("expiry", global_position)
        return
    var start := global_position
    var finish := start + Vector2(direction * distance, 0)
    var wall := _terrain_contact(start, finish)
    var wall_time := preload("res://scripts/attack_sweep.gd").fraction(start, finish, wall.position) if not wall.is_empty() else INF
    var contacts: Array[Dictionary] = []
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if not _eligible_target(enemy): continue
        var box: Rect2 = enemy.get_hurtbox_rect() if enemy.has_method("get_hurtbox_rect") else Rect2(enemy.global_position - Vector2(34, 38), Vector2(68, 76))
        var time := preload("res://scripts/attack_sweep.gd").rect_time(start, finish, box.grow(8.0))
        if time >= wall_time or time > 1.0: continue
        contacts.append({"actor": enemy, "time": time, "path": String(enemy.get_path())})
    contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a.time < b.time if not is_equal_approx(a.time, b.time) else a.path < b.path)
    for contact in contacts:
        var enemy: Node2D = contact.actor
        if not _eligible_target(enemy): continue
        global_position = start.lerp(finish, contact.time)
        _apply_contact(enemy)
        if is_queued_for_deletion(): return
        if String(payload.get("kind", "")) != "wave":
            travelled += start.distance_to(global_position)
            elapsed += seconds * contact.time
            _finish_skill("hit", global_position)
            return
    global_position = wall.position if not wall.is_empty() else finish
    travelled += start.distance_to(global_position)
    elapsed += seconds
    if not wall.is_empty():
        _finish_skill("wall", global_position)
    elif elapsed >= lifetime or travelled >= reach:
        _finish_skill("expiry", global_position)
    queue_redraw()

func _eligible_target(enemy: Node) -> bool:
    return is_instance_valid(enemy) and enemy is Node2D and not enemy.is_queued_for_deletion() and enemy.get("dying") != true and enemy.has_method("take_hit") and not targets.has(enemy.get_instance_id()) and (not enemy.has_method("world_residency_active") or enemy.world_residency_active())

func _terrain_contact(start: Vector2, finish: Vector2) -> Dictionary:
    var level := get_parent()
    if level.has_method("_ensure_collision_segment"): level._ensure_collision_segment(start, finish)
    var query := PhysicsRayQueryParameters2D.create(start, finish, 1, [owner_player.get_rid()])
    query.collide_with_areas = false
    var hit := get_world_2d().direct_space_state.intersect_ray(query)
    if level.has_method("_rock_ray_hit"):
        var rock: Dictionary = level._rock_ray_hit(start, finish)
        if not rock.is_empty() and (hit.is_empty() or start.distance_squared_to(rock.position) < start.distance_squared_to(hit.position)): hit = rock
    return hit

func _apply_contact(enemy: Node2D) -> void:
    targets[enemy.get_instance_id()] = true
    var hp_before: Variant = enemy.get("hp")
    enemy.take_hit(maxi(1, int(payload.get("damage", 1))), direction)
    if cancelled or is_queued_for_deletion() or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("dying") == true: return
    var hp_after: Variant = enemy.get("hp")
    if (hp_before is int or hp_before is float) and (hp_after is int or hp_after is float) and float(hp_after) >= float(hp_before): return
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


func cancel() -> void:
    if cancelled: return
    cancelled = true
    hide()
    set_physics_process(false)
    queue_free()
