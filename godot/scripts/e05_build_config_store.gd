class_name E05BuildConfigStore
extends RefCounted

var _configs := {}
func save_config(name: String, payload: Dictionary) -> bool:
    if name.is_empty() or payload.is_empty(): return false
    _configs[name] = payload.duplicate(true); return true
func load_config(name: String) -> Dictionary: return _configs.get(name, {}).duplicate(true)
func delete_config(name: String) -> bool: return _configs.erase(name)
func names() -> Array: return _configs.keys()
