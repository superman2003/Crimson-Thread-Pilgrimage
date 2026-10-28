class_name C04SkillTrialAdapter
extends RefCounted

var trial := {}
func start(skill_id: String, rounds := 3) -> bool:
    if trial.has("skill_id") or skill_id.is_empty() or rounds < 1:
        return false
    trial = {"skill_id": skill_id, "rounds": rounds, "temporary": true}
    return true
func finish_round() -> bool:
    if trial.is_empty(): return false
    trial.rounds -= 1
    if trial.rounds <= 0: trial.clear()
    return true
func reset() -> void: trial.clear()
