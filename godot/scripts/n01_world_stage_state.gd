class_name N01WorldStageState
extends RefCounted

var stage := "unknown"
var completed: Array[String] = []
func set_stage(value: String) -> void:
    if not value.is_empty(): stage = value
func mark_completed(key: String) -> void:
    if not key.is_empty() and key not in completed: completed.append(key)
func snapshot() -> Dictionary: return {"stage": stage, "completed": completed.duplicate()}
func reset() -> void: stage = "unknown"; completed.clear()
