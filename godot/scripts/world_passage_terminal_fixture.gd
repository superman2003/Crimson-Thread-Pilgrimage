extends RefCounted
## Explicit terminal placement for state/quest suites. NOT traversal evidence.
static func finish(scene: Node) -> bool:
    var passage: Node=scene.world_passage
    if not passage.active: return true
    # A placed terminal skips the walk the hidden destination build relies on
    # (W00 stages 4-5); use the ordinary terminal load these suites were written
    # against instead of waiting for a build the walk would have covered.
    var started := Time.get_ticks_msec()
    if passage.staged:
        passage.staged = false
        scene.world_loader.cancel_staging()
        var unwind := Time.get_ticks_msec() + 15000
        while scene.world_loader.phase != "idle" and Time.get_ticks_msec() < unwind:
            await scene.get_tree().process_frame
    var unwound := Time.get_ticks_msec() - started
    scene.player.global_position=passage.destination_point+Vector2(0,40)
    scene.player.velocity=Vector2.ZERO
    passage.step()
    # Fixed-fps state suites may execute thousands of frames before the real
    # texture workers finish a cold region. Bound IO by wall time instead; the
    # software-GL CI runners need well over 15 s for a cold terminal load.
    var deadline := Time.get_ticks_msec() + 45000
    while Time.get_ticks_msec() < deadline:
        if not passage.active: return true
        if not passage.settling:
            print("TERMINAL_FIXTURE settled without arriving: unwind_ms=%d phase=%s error=%s" % [unwound, scene.world_loader.phase, scene.world_loader.last_error])
            return false
        await scene.get_tree().process_frame
    print("TERMINAL_FIXTURE timeout: unwind_ms=%d load_ms=%d phase=%s staging_retiring=%d" % [unwound, Time.get_ticks_msec() - started - unwound, scene.world_loader.phase, scene.world_loader.staging_retiring])
    return false
