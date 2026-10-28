class_name G03MapNavigationState
extends RefCounted

var current := ""
var target := ""
func set_position(value: String) -> void: current = value
func guide_to(value: String) -> bool:
    if value.is_empty(): return false
    target = value; return true
func snapshot() -> Dictionary: return {"current":current,"target":target}
