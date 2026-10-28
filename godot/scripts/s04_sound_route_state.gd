class_name S04SoundRouteState
extends RefCounted

var active := {}
func start(event_id: String, priority: int = 0) -> bool:
    if event_id.is_empty(): return false
    active[event_id] = priority; return true
func stop(event_id: String) -> bool: return active.erase(event_id)
func clear() -> void: active.clear()
