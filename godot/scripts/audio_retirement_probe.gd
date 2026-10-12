extends RefCounted
## Fixed-fps simulation can outrun AudioServer's real-time playback retirement.
## Keep only weak references, and fail callers if audio survives a bounded wait.

static func stream_refs(presentation: Node) -> Array:
    if not is_instance_valid(presentation):
        return []
    var refs: Array = []
    for stream in presentation._streams.values():
        refs.append(weakref(stream))
    return refs

static func wait_for_release(tree: SceneTree, refs: Array, timeout_ms: int = 1000) -> bool:
    var deadline := Time.get_ticks_msec() + timeout_ms
    while refs.any(func(ref): return ref.get_ref() != null):
        if Time.get_ticks_msec() >= deadline:
            return false
        await tree.process_frame
    return true
