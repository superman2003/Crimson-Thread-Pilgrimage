class_name C05TrainingResult
extends RefCounted

var _claimed := {}
func record(session_id: String, outcome: String) -> Dictionary:
    if session_id.is_empty() or outcome.is_empty(): return {}
    return {"session_id":session_id,"outcome":outcome,"claimable":not _claimed.has(session_id)}
func claim(session_id: String) -> bool:
    if session_id.is_empty() or _claimed.has(session_id): return false
    _claimed[session_id] = true; return true
