extends AudioStreamPlayer2D
## A brief, stationary vocal accent at the enemy's actual encounter position.
const HEARING_DISTANCE := 900.0
const OCCLUSION_DB := 12.0
var occluded := false
var spatial_base_db := -19.0

static func in_range(source: Vector2, listener: Vector2) -> bool:
    return source.is_finite() and listener.is_finite() and source.distance_squared_to(listener) <= HEARING_DISTANCE * HEARING_DISTANCE

func place(source: Vector2, listener: Node2D, base_db: float = -19.0) -> bool:
    if not is_finite(base_db):return false
    spatial_base_db=base_db
    if not refresh_spatial(source,listener):return false
    max_distance=HEARING_DISTANCE
    attenuation=1.0
    return true

func refresh_spatial(source: Vector2, listener: Node2D) -> bool:
    if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(listener) or not listener.is_inside_tree() or listener.is_queued_for_deletion():return false
    if get_world_2d()!=listener.get_world_2d() or not in_range(source,listener.global_position):return false
    global_position=source
    var exclude: Array[RID] = []
    if listener is CollisionObject2D: exclude.append(listener.get_rid())
    var ray := PhysicsRayQueryParameters2D.create(source, listener.global_position, 1, exclude)
    occluded = not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
    volume_db = spatial_base_db - (OCCLUSION_DB if occluded else 0.0)
    return true
