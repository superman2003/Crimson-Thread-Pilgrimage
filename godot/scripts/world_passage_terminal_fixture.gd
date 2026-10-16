extends RefCounted
## Explicit terminal placement for state/quest suites. NOT traversal evidence.
static func finish(scene: Node) -> bool:
    var passage: Node=scene.world_passage
    if not passage.active: return true
    scene.player.global_position=passage.destination_point+Vector2(0,40)
    scene.player.velocity=Vector2.ZERO
    passage.step()
    for tick in 2400:
        if not passage.active: return true
        if not passage.settling: return false
        await scene.get_tree().process_frame
    return false
