extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/movement_trials/model.gd")
const A := preload("res://journey/fieldwork/movement_trials/advanced.gd")
const FEATURE := preload("res://journey/features/i_movement_trials.gd")


func run() -> void:
    label = "I27_MOVEMENT_TRIALS"
    var context := field_fixture("j27_movement_trials")
    await exercise(context, M, FEATURE, "j_movement_trials", "samples")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func trial(context: RefCounted, count: int=10, speed: float=10.0) -> Dictionary:
    var value:=M.capture(context.snapshot())
    value.origin=[0,0]
    value.samples=[]
    for i in count:
        value.samples.append({"time":float(i)*0.1,"position":[float(i)*speed,0.0],"velocity":[speed*10,0.0],"energy":100.0,"hp":5.0,"grounded":true,"segment":0})
    value.elapsed=float(count-1)*0.1
    return value


func domain_checks(context: RefCounted) -> void:
    var a:=trial(context)
    check(M.validate(a), "controlled samples follow actual stored trial schema")
    var b:=a.duplicate(true)
    var same:=A.compare(a,b)
    check(same.ok and is_zero_approx(same.segments[0].rms), "identical observed paths have zero alignment error")
    check(A.certify(same.segments[0],Vector2.ZERO,Vector2.ZERO), "alignment endpoints and cost have independent certificate")
    b.origin=[100,200]
    for row in b.samples:
        row.position[0]+=100
        row.position[1]+=200
    var translated:=A.compare(a,b)
    check(translated.ok and is_zero_approx(translated.segments[0].rms), "separately stored origin removes pure translation")
    for row in b.samples:
        row.time*=2
    var slower:=A.compare(a,b)
    check(slower.ok and is_zero_approx(slower.segments[0].rms) and slower.segments[0].mean_lag>0, "same geometry at slower timestamps exposes time lag without false spatial error")
    b=a.duplicate(true)
    for row in b.samples:
        row.position[1]=5.0
    var shifted:=A.compare(a,b)
    check(shifted.ok and is_equal_approx(shifted.segments[0].rms,5), "constant transverse spatial difference has exact RMS")
    b=a.duplicate(true)
    for row in b.samples:
        row.grounded=false
    check(A.compare(a,b).segments[0].ground_mismatch==10, "ground state mismatch is reported on aligned observations")
    b=a.duplicate(true)
    b.region="other"
    check(not A.compare(a,b).ok, "different regions cannot silently align")
    b=a.duplicate(true)
    b.samples[5].segment=1
    for i in range(5,10):
        b.samples[i].segment=1
    check(not A.compare(a,b).ok, "different pause segmentation is rejected rather than bridged")
    a.samples=[]
    check(not A.compare(a,b).ok, "empty recording does not produce zero-error success")
    var long:=trial(context,601,1.0)
    var reduced:=A.reduce_samples(long.samples)
    check(reduced.size()==80 and reduced[0]==long.samples[0] and reduced[-1]==long.samples[-1], "bounded sampling preserves both endpoints")
    var aligned:=A.align(long.samples,long.samples,Vector2.ZERO,Vector2.ZERO)
    check(aligned.ok and aligned.reduced and is_zero_approx(aligned.cost), "maximum trial stays within bounded exact alignment lattice")
    check(A.certify(aligned,Vector2.ZERO,Vector2.ZERO), "maximum trial cost certificate passes")
    var forged:=aligned.duplicate(true)
    forged.cost=100.0
    check(not A.certify(forged,Vector2.ZERO,Vector2.ZERO), "forged squared cost rejected")
    for seed in 20:
        a=trial(context,5+seed,1+float(seed%3))
        b=a.duplicate(true)
        var before:=JSON.stringify([a,b])
        var result:=A.compare(a,b)
        check(result.ok and is_zero_approx(result.segments[0].cost), "variable-length identical paths remain exact")
        check(JSON.stringify([a,b])==before, "comparison never resamples caller arrays in place")
    a=trial(context)
    check(M.compare(a,a).any(func(row: Dictionary): return row.get("title")=="逐段动态时间对齐"), "native saved-record comparison exposes new alignment sections")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := trial(context)
    var view := preload("res://journey/fieldwork/movement_trials/advanced_view.gd").new()
    view.configure({"a":payload,"b":payload.duplicate(true)})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view._show_segment()
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
