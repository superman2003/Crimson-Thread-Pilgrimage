extends RefCounted
const LEVEL_HOST := preload("res://scripts/level_host.gd")
## Effects of the player's commands on an enemy: lures, trips, locomotion while commanded, and the command effects spawned.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ATTACK_EFFECT := preload("res://scripts/enemy_attack_effect.gd")
const ENEMY_EFFECTS := preload("res://scripts/enemy_effects.gd")

static func apply_trip(actor: Node, seconds: float) -> void:
    if not bool(actor.combat_resistance.get("trip_immune", actor.is_boss)):
        actor.trip_timer = maxf(actor.trip_timer, minf(1.0, seconds))
        actor.attack_recovery=false
        actor.recovery_velocity_x=0.0
        actor._cancel_unarmed_attack_effects()
        actor._clear_telegraph()
        actor.state = "recover"
        actor.state_timer = maxf(actor.state_timer, actor.trip_timer)


static func investigate_lure(actor: Node, point: Vector2, seconds: float) -> void:
    if bool(actor.combat_resistance.get("lure_immune", actor.is_boss)) or not bool(actor.ai_profile.get("lure_eligible", not actor.is_boss)) or actor.dying or actor.state in ["windup", "active"]:
        return
    if actor.is_inside_tree():
        if LEVEL_HOST.of(actor).has_method("_ensure_collision_segment"):
            LEVEL_HOST.of(actor)._ensure_collision_segment(actor.global_position + Vector2(0, -24), point)
        if LEVEL_HOST.of(actor).has_method("_rock_ray_hit") and not LEVEL_HOST.of(actor)._rock_ray_hit(actor.global_position + Vector2(0, -24), point).is_empty():
            return
        var lure_ray = PhysicsRayQueryParameters2D.create(actor.global_position + Vector2(0,-24), point, 1)
        lure_ray.collide_with_areas = false
        # Like sight, a lure is hidden by terrain, not by the Player's body.
        lure_ray.exclude = ATTACK_EFFECT.player_bodies(actor.get_tree())
        if not actor.get_world_2d().direct_space_state.intersect_ray(lure_ray).is_empty():
            return
    actor.lure_position = point
    actor.lure_timer = maxf(actor.lure_timer, minf(2.0, seconds))


static func update_locomotion(actor: Node, delta: float, target: CharacterBody2D) -> void:
    if actor.locomotion=="stationary":
        actor.global_position=actor.spawn_position
        return
    if actor.locomotion=="flight":
        if actor.state=="active" and String(actor.active_attack.get("type",""))=="dive":
            return
        actor.flight_clock+=delta
        var desired = actor.spawn_position.y+sin(actor.flight_clock*2.8+actor.start_x*.01)*11
        var aggro_range := float(actor.ai_profile.get("aggro_range", 220.0 if not actor.is_boss else 460.0))
        var target_engaged = target != null and actor._target_inside_leash(target) and actor._target_in_engage_window(target, aggro_range) and actor._has_line_of_sight(target)
        var returning_home = not actor.is_boss and actor.leash_radius > 0.0 and (absf(actor.global_position.x - actor.spawn_position.x) > actor.leash_radius or actor._should_return_to_spawn(target, aggro_range))
        # Keep the authored boss tracking rule intact. Ordinary flyers only
        # follow a visible target inside their territory, so remote/rest targets
        # cannot pull them away from their home pocket while horizontal patrol idles.
        var should_track_target = target != null if actor.is_boss else target_engaged and not returning_home
        if should_track_target and actor.state not in ["windup","active"]:
            desired=clampf(target.global_position.y-90,actor.spawn_position.y-65,actor.spawn_position.y+75)+sin(actor.flight_clock*3)*8
        var candidate := Vector2(actor.global_position.x,move_toward(actor.global_position.y,desired,85*delta))
        var level = LEVEL_HOST.of(actor)
        if not level.has_method("_enemy_spawn_rect_clear") or level._enemy_spawn_rect_clear(candidate,24,float(actor.get_meta("spawn_visual_height",60)),String(actor.get_meta("platform_id",""))):
            actor.global_position=candidate
        return
    if actor.state=="active" and String(actor.active_attack.get("type",""))=="vault":
        return
    var terrain: Node = LEVEL_HOST.of(actor).get("chapter_terrain")
    if terrain!=null:
        var floor_y: float = terrain.floor_height(actor.global_position.x,actor.spawn_position.y+40,210)
        if is_finite(floor_y):
            actor.global_position.y=floor_y-40


static func spawn_command_effects(actor: Node, command: Dictionary, warning: bool) -> void:
    ENEMY_EFFECTS.spawn_command_effects(actor, command, warning)
