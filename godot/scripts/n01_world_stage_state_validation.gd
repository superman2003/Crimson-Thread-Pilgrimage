extends RefCounted
func run()->Dictionary:
 var s:=N01WorldStageState.new(); s.set_stage("mid"); s.mark_completed("gate"); return {"ok":s.snapshot().stage=="mid" and s.snapshot().completed.size()==1}