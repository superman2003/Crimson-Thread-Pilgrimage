class_name W05ClueFollowupState
extends RefCounted

var _seen := {}
func disclose(clue_id: String) -> bool:
    if clue_id.is_empty() or _seen.has(clue_id): return false
    _seen[clue_id] = {"status":"disclosed","visited":false}; return true
func revisit(clue_id: String) -> bool:
    if not _seen.has(clue_id): return false
    _seen[clue_id].visited = true; return true
func snapshot() -> Dictionary: return _seen.duplicate(true)
