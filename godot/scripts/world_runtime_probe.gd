extends RefCounted
## Numeric-only lifecycle measurements; retains no live object or resource.
var intervals: Array[int] = []
var samples: Array[Dictionary] = []
var frames := 0
var previous_usec := 0
var peak_memory := 0

func frame() -> void:
    var now := Time.get_ticks_usec()
    if previous_usec > 0:
        intervals.append(now - previous_usec)
        frames += 1
        if intervals.size() > 600: intervals.pop_front()
    previous_usec = now

func capture(label: String, host: Node) -> void:
    var sample := {"label": label, "time_usec": Time.get_ticks_usec(),
        "memory_bytes": OS.get_static_memory_usage(),
        "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
        "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
        "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
        "host_children": host.get_child_count(), "pending_sfx": host.pending_sfx_players.size(),
        "active_sfx": host.get_children().filter(func(child): return child is AudioStreamPlayer and String(child.name).begins_with("Sfx_")).size()}
    peak_memory = maxi(peak_memory, int(sample.memory_bytes))
    samples.append(sample)

func summary() -> Dictionary:
    var sorted := intervals.duplicate()
    sorted.sort()
    var first: Dictionary = samples.front() if not samples.is_empty() else {}
    var last: Dictionary = samples.back() if not samples.is_empty() else {}
    return {"samples": samples.size(), "history": samples.duplicate(true), "frames": frames,
        "frame_window": sorted.size(), "frame_p95_usec": sorted[int((sorted.size() - 1) * 0.95)] if not sorted.is_empty() else 0,
        "frame_max_usec": sorted.back() if not sorted.is_empty() else 0,
        "peak_memory_bytes": peak_memory,
        "memory_delta_bytes": int(last.get("memory_bytes", 0)) - int(first.get("memory_bytes", 0)),
        "node_delta": int(last.get("nodes", 0)) - int(first.get("nodes", 0)),
        "scope": "80 cache cycles and sampled engine counters; not a long session soak or target hardware FPS"}
