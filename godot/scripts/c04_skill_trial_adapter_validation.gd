extends RefCounted
func run() -> Dictionary:
 var s:=C04SkillTrialAdapter.new(); var ok:=s.start("focus",2) and not s.start("other",1); s.finish_round(); s.finish_round(); return {"ok":ok and s.trial.is_empty()}