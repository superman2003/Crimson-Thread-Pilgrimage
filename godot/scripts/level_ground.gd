extends RefCounted
## Safe ground and the death cache, collision segments and rock rays, and releasing region platforms.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const WORLD_STATE_SCRIPT := preload("res://scripts/world_state.gd")

static func update_safe_ground(level: Node) -> void:
    if level.player == null or not is_instance_valid(level.player):
        return
    if level.player.is_on_floor() and level.player.hp > 0 and level._standing_on_permanent_floor():
        level.last_safe_ground = level.player.global_position


static func standing_on_permanent_floor(level: Node) -> bool:
    for index in range(level.player.get_slide_collision_count() - 1, -1, -1):
        var collision = level.player.get_slide_collision(index)
        if collision.get_normal().dot(Vector2.UP) < 0.7:
            continue
        # AnimatableBody2D (lift baskets) is a StaticBody2D subclass that moves.
        var body = collision.get_collider() as StaticBody2D
        if body == null or not is_instance_valid(body) or body is AnimatableBody2D:
            return false
        if body.is_in_group("fragile_terrain") or body.is_in_group("phase_gate") or level.locked_gate_bodies.values().has(body):
            return false
        return true
    return false


static func ground_is_hazardous(level: Node, _position_value: Vector2) -> bool:
    return false


static func record_death_cache(level: Node) -> void:
    if not level.world_mode or level.death_recorded or level.world_state == null:
        return
    var lost := int(level.currency_count / 2)
    var recovery = level.last_safe_ground if level.last_safe_ground != Vector2.ZERO else level.active_spawn
    if level.boss_spawned:recovery=level.active_spawn
    var cache: Dictionary={"region_id":String(level.config.get("id","")),"position":[recovery.x,recovery.y],"currency":lost}
    var result: Dictionary = level._persist_world_change({"currency":level.currency_count-lost,"death_cache":cache})
    if not result.has("candidate"):
        level._toast("这次失落未能记录，请检查归途记录。")
        return
    # Death is already occurring: retain one coherent unsaved snapshot so the
    # ordinary respawn save can retry it. Claim/purchase paths never do this.
    level.world_state.data=result.candidate
    level.currency_count=int(result.candidate.currency)
    level.death_recorded=true
    level._spawn_death_cache()
    level._toast("一半碎钱留在归途结" if result.ok else "这次失落已暂记在旅途中，存档尚未写入；请稍后保存。")


static func spawn_death_cache(level: Node) -> void:
    if level.death_cache_area != null and is_instance_valid(level.death_cache_area):
        level.death_cache_area.queue_free()
    level.death_cache_area = null
    if not level.world_mode or level.world_state == null:
        return
    var cache: Dictionary = level.world_state.data.get("death_cache", {})
    if cache.is_empty() or String(cache.get("region_id", "")) != String(level.config.get("id", "")) or int(cache.get("currency", 0)) <= 0:
        return
    var area := Area2D.new()
    area.name = "DeathRecoveryKnot"
    area.position = level._vec2(cache.position)
    area.set_meta("kind", "death_cache")
    area.set_meta("manual_pickup", true)
    area.set_meta("label", "归途结 · 找回碎钱")
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 54.0
    shape.shape = circle
    area.add_child(shape)
    var ring := Line2D.new()
    ring.closed = true
    ring.width = 4.0
    ring.default_color = Color("e9c276")
    for i in range(17):
        var angle := TAU * float(i) / 16.0
        ring.add_point(Vector2(cos(angle), sin(angle)) * 24.0 - Vector2(0, 32))
    area.add_child(ring)
    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)
    level.death_cache_area = area


static func recover_death_cache(level: Node, area: Area2D) -> void:
    if not level.world_mode or level.player==null or level.player.hp<=0 or level.world_state==null or level.world_loading or level.world_save_blocked:return
    if not is_instance_valid(area) or area!=level.death_cache_area or area.is_queued_for_deletion() or not area.is_inside_tree():return
    var cache: Dictionary=level.world_state.data.get("death_cache",{})
    if not WORLD_STATE_SCRIPT._valid_death_cache(cache) or cache.is_empty() or int(cache.currency)<=0:return
    if String(cache.region_id)!=String(level.config.get("id","")) or area.global_position.distance_to(level.player.global_position)>level.INTERACTION_REACH:return
    if area.position.distance_to(level._vec2(cache.position))>1.0:return
    var result: Dictionary = level._persist_world_change({"currency":level.currency_count+int(cache.currency),"death_cache":{}})
    if not result.ok:level._toast("归途结尚未写入；碎钱与结保持原状，可再次找回。");return
    level.world_state.data=result.candidate
    level.currency_count=int(result.candidate.currency)
    area.queue_free();level.death_cache_area=null
    level._toast("归途结已收回")
    level._refresh_hud()


static func hold_actor_support(level: Node, platform_id: String) -> void:
    if level.world_platforms != null:
        level.world_platforms.hold(level, platform_id)
    if is_instance_valid(level.chapter_terrain):
        level.chapter_terrain.hold_collision_support(platform_id)


static func ensure_collision_segment(level: Node, from: Vector2, to: Vector2) -> void:
    if level.world_mode and is_instance_valid(level.chapter_terrain):
        level.chapter_terrain.ensure_collision_segment(from, to)
    if level.world_mode and is_instance_valid(level.cave_world):
        level.cave_world.ensure_collision_segment(from, to)
    if level.world_platforms != null:
        level.world_platforms.ensure_segment(level, from, to)


static func rock_ray_hit(level: Node, from: Vector2, to: Vector2) -> Dictionary:
    var hit: Dictionary = level.cave_world.rock_ray_hit(from, to) if level.world_mode and is_instance_valid(level.cave_world) else {}
    if level.world_platforms != null:
        var platform: Dictionary = level.world_platforms.ray_hit(level, from, to)
        if not platform.is_empty() and (hit.is_empty() or from.distance_squared_to(platform.position) < from.distance_squared_to(hit.position)):
            hit = platform
    if level.world_mode and is_instance_valid(level.chapter_terrain):
        var terrain: Dictionary = level.chapter_terrain.terrain_ray_hit(from, to)
        if not terrain.is_empty() and (hit.is_empty() or from.distance_squared_to(terrain.position) < from.distance_squared_to(hit.position)):
            hit = terrain
    return hit


static func walking_world_passage(level: Node) -> bool:
    return is_instance_valid(level.world_passage) and level.world_passage.active


static func world_collision_ready(level: Node) -> bool:
    if is_instance_valid(level.world_passage) and level.world_passage.active:
        return not level.world_passage.settling and Engine.get_physics_frames() > level.world_passage.sync_until
    var cave_ready: bool = not level.world_mode or not is_instance_valid(level.cave_world) or level.cave_world.critical_collision_ready()
    var terrain_ready: bool = not level.world_mode or not is_instance_valid(level.chapter_terrain) or level.chapter_terrain.critical_collision_ready()
    return cave_ready and terrain_ready and (level.world_platforms == null or level.world_platforms.ready())


static func release_region_platforms(level: Node) -> void:
    if is_instance_valid(level.chapter_terrain):
        level.chapter_terrain.close_collisions()
    if level.world_platforms != null:
        level.world_platforms.shutdown()
    if level.world_gameplay_residency != null:
        level.world_gameplay_residency.shutdown()
    level.npc_residency_memory.clear()
    level.save_point_residency_memory.clear()
