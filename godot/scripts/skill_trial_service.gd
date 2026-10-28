class_name SkillTrialService
extends RefCounted

signal changed(snapshot: Dictionary)

const MAX_TRIAL_ROUNDS := 3
var _active: Dictionary = {}

func begin_trial(skill_id: String, rounds: int, cost: int, source: String = "practice") -> Dictionary:
    if skill_id.is_empty() or rounds < 1 or rounds > MAX_TRIAL_ROUNDS or cost < 0:
        return {"ok": false, "reason": "invalid_trial", "trial": snapshot()}
    if not _active.is_empty():
        return {"ok": false, "reason": "trial_already_active", "trial": snapshot()}
    _active = {"skill_id": skill_id, "rounds_left": rounds, "cost": cost, "source": source, "confirmed": false}
    changed.emit(snapshot())
    return {"ok": true, "trial": snapshot()}

func confirm_trial() -> Dictionary:
    if _active.is_empty():
        return {"ok": false, "reason": "no_trial", "trial": snapshot()}
    _active["confirmed"] = true
    changed.emit(snapshot())
    return {"ok": true, "trial": snapshot()}

func advance_round() -> Dictionary:
    if _active.is_empty():
        return {"ok": false, "reason": "no_trial", "trial": snapshot()}
    _active["rounds_left"] = int(_active["rounds_left"]) - 1
    var expired := int(_active["rounds_left"]) <= 0
    var result := {"ok": true, "expired": expired, "trial": snapshot()}
    if expired:
        clear_trial("expired")
    else:
        changed.emit(snapshot())
    return result

func cancel_trial() -> Dictionary:
    if _active.is_empty():
        return {"ok": false, "reason": "no_trial", "trial": snapshot()}
    clear_trial("cancelled")
    return {"ok": true, "reason": "cancelled"}

func on_session_loaded() -> void:
    clear_trial("session_loaded")

func clear_trial(reason: String = "reset") -> void:
    _active.clear()
    changed.emit({"active": false, "reason": reason})

func snapshot() -> Dictionary:
    if _active.is_empty():
        return {"active": false}
    var result := _active.duplicate(true)
    result["active"] = true
    return result
