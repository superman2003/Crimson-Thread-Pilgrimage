extends RefCounted
## Explicit terminal placement for state/quest suites. NOT traversal evidence.
static func finish(scene: Node) -> bool:
    var passage: Node=scene.world_passage
    if not passage.active: return true
    # A placed terminal skips the walk the hidden destination build relies on
    # (W00 stages 4-5); use the ordinary terminal load these suites were written
    # against instead of waiting for a build the walk would have covered.
    if passage.staged:
        passage.staged = false
        scene.world_loader.cancel_staging()
        var unwind := Time.get_ticks_msec() + 15000
        while scene.world_loader.phase != "idle" and Time.get_ticks_msec() < unwind:
            await scene.get_tree().process_frame
    scene.player.global_position=passage.destination_point+Vector2(0,40)
    scene.player.velocity=Vector2.ZERO
    passage.step()
    # Fixed-fps state suites may execute thousands of frames before the real
    # texture workers finish a cold region. Bound IO by wall time instead.
    var deadline := Time.get_ticks_msec() + 15000
    while Time.get_ticks_msec() < deadline:
        if not passage.active: return true
        if not passage.settling: return false
        await scene.get_tree().process_frame
    return false
