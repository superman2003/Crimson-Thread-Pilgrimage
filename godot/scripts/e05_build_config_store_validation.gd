extends RefCounted
func run()->Dictionary:
 var s:=E05BuildConfigStore.new(); return {"ok":s.save_config("a",{"x":1}) and s.load_config("a").x==1 and s.delete_config("a")}