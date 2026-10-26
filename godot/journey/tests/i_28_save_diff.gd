extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/save_diff/model.gd")
const A := preload("res://journey/fieldwork/save_diff/advanced.gd")
const FEATURE := preload("res://journey/features/i_save_diff.gd")


func run() -> void:
    label = "I28_SAVE_DIFF"
    var context := field_fixture("j28_save_diff")
    await exercise(context, M, FEATURE, "j_save_diff", "snapshot")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func options() -> Dictionary:
    return {"epsilon":0.0,"array_mode":"ordered","category":"全部","query":""}


func verify_pair(before: Dictionary, after: Dictionary) -> void:
    var frozen:=A.canonical(before)
    var target:=A.canonical(after)
    var changes:=M.difference(before,after,options())
    check(changes.ok, "controlled structural difference stays in capacity")
    var inverse:=A.inverse(changes.ops)
    check(inverse.ok and inverse.ops.size()==changes.ops.size(), "every generated operation has one reverse operation")
    var result:=A.audit(before,changes.ops,M.apply)
    check(result.ok and result.before==result.recovered, "forward/reverse/forward memory audit returns exact source fingerprint")
    var applied:=M.apply(before,changes.ops)
    check(applied.ok and A.canonical(applied.value)==target, "forward operations reconstruct exact requested target")
    if applied.ok and inverse.ok:
        var restored:=M.apply(applied.value,inverse.ops)
        check(restored.ok and A.canonical(restored.value)==frozen, "independent reverse replay recovers original null/existence and array order")
    check(A.canonical(before)==frozen and A.canonical(after)==target, "auditing preserves both caller documents")


func domain_checks(context: RefCounted) -> void:
    verify_pair({"a":1,"b":null},{"a":2,"c":null})
    verify_pair({"a/b":{"~x":[1,2,3]}},{"a/b":{"~x":[0,1,3,4]}})
    verify_pair({"数组":[1,1,1,2]},{"数组":[1,2]})
    verify_pair({"items":[1,2]},{"items":[0,1,2,3]})
    verify_pair({"nested":{"a":1}},{"nested":[1,2]})
    verify_pair({"a":false},{"a":0})
    verify_pair({},{"x":[]})
    verify_pair({"x":{}},{})
    verify_pair({"a":1},{"a":1})
    for seed in 24:
        var before:={"values":[seed,seed%3,seed+1],"nested":{"id":str(seed),"null":null}}
        var after:=before.duplicate(true)
        after.values.insert(0,seed+7)
        after.values.remove_at(2)
        after.nested.erase("null")
        after.nested["key/with~escape"]=seed*2
        verify_pair(before,after)
    var operations:=[M.operation("replace","/a",1,2)]
    var invalid:=operations.duplicate(true)
    invalid[0].old=999
    check(not A.audit({"a":1},invalid,M.apply).ok, "stale precondition is rejected before inverse certificate")
    invalid=operations.duplicate(true)
    invalid[0].old_exists=false
    check(not A.inverse(invalid).ok, "inconsistent existence flags cannot be inverted")
    invalid=[{"op":"unknown","path":"/a","old":1,"new":2,"old_exists":true,"new_exists":true}]
    check(not A.inverse(invalid).ok, "unsupported patch operation rejected")
    invalid=["not an operation"]
    check(not A.inverse(invalid).ok, "non-dictionary operation rejected")
    invalid=[]
    for i in 257:
        invalid.append(M.operation("replace","/a",i,i+1))
    check(not A.inverse(invalid).ok, "over-capacity reverse document rejects without truncation")
    var direct:=[M.operation("remove","/x/0",1,null,"/x"),M.operation("remove","/x/0",1,null,"/x")]
    check(A.audit({"x":[1,1,2]},direct,M.apply).ok, "repeated same-pointer removals are reversed in exact opposite order")
    var a:=M.capture(context.snapshot())
    var b:=a.duplicate(true)
    b.snapshot.wallet+=1
    check(M.compare(a,b).any(func(row: Dictionary): return row.get("title")=="内存差异可逆性"), "native comparison includes rollback certificate")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/save_diff/advanced_view.gd").new()
    view.configure({"before":{"wallet":1},"ops":[M.operation("replace","/wallet",1,2)],"apply":M.apply})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view._forward(); check(view.cursor==1, "native forward preview advances"); view._backward(); check(view.cursor==0 and view.current=={"wallet":1}, "native inverse preview returns exact origin")
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
