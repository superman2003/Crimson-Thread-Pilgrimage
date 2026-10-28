class_name U07InputRecovery
extends RefCounted

var pending := {}
func propose(action: String, key: String) -> bool:
    if action.is_empty() or key.is_empty(): return false
    pending[action] = key; return true
func commit() -> Dictionary:
    var result := pending.duplicate(); pending.clear(); return result
func rollback() -> void: pending.clear()
