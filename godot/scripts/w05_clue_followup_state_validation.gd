extends RefCounted
func run()->Dictionary:
 var s:=W05ClueFollowupState.new(); return {"ok":s.disclose("c") and s.revisit("c") and not s.revisit("x")}