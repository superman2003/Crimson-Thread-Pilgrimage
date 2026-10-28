extends RefCounted
func run()->Dictionary:
 var s:=T06ReleaseAudit.new(); return {"ok":s.inspect("1.0",1,["ok"]).ready and not s.inspect("",0,["ok"]).ready}