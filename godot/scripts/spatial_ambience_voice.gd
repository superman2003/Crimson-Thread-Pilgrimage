extends "res://scripts/spatial_enemy_alert.gd"
## A separate route keeps environmental occlusion off danger/NPC/music buses.
const FILTER := preload("res://scripts/enemy_sound_filter.gd")
const FILTER_BUS := "CrimsonAmbienceOccluded"
const FILTER_OWNER := "crimson_ambience_occlusion_filter"

func refresh_spatial(source: Vector2, listener: Node2D) -> bool:
    if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(listener):
        return false
    if not listener.is_inside_tree() or listener.is_queued_for_deletion():
        return false
    if get_world_2d()!=listener.get_world_2d() or not in_range(source,listener.global_position):
        return false
    global_position=source
    var exclude: Array[RID]=[]
    if listener is CollisionObject2D:exclude.append(listener.get_rid())
    var ray:=PhysicsRayQueryParameters2D.create(source,listener.global_position,1,exclude)
    # A fixed environmental origin can lie inside an authored rock mass; it
    # must sound muffled rather than treating an inside-start ray as clear.
    ray.hit_from_inside=true
    occluded=not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
    volume_db=spatial_base_db-(OCCLUSION_DB if occluded else 0.0)
    bus = FILTER.ensure_bus("Ambience",FILTER_BUS,FILTER_OWNER) if occluded else clear_bus()
    return true

static func clear_bus() -> String:
    return "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
