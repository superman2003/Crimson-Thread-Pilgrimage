extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/curriculum/model.gd")
const A := preload("res://journey/fieldwork/curriculum/advanced.gd")
const FEATURE := preload("res://journey/features/i_curriculum.gd")


func run() -> void:
    label = "I26_CURRICULUM"
    var context := field_fixture("j26_curriculum")
    await exercise(context, M, FEATURE, "j_curriculum", "sequence")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func course() -> Dictionary:
    return {
        "actions":[{"id":"a","name":"A","binding":"J","bindings":["J"],"cost":3.0,"cost_rate":0.0,"cooldown":5.0,"duration":1.0,"movement":false}],
        "sequence":["a","a"],"waits":{"a":1.0},"repeats":2.0,"rest":1.0,
        "energy":6.0,"recovery":5.0,"target_duration":300.0,"title":"测试动作"
    }


func independent_verify(payload: Dictionary, result: Dictionary) -> bool:
    var state := float(payload.energy)
    var last := {}
    var catalogue := {}
    for action in payload.actions:
        catalogue[action.id]=action
    var count := 0
    for row in result.rows:
        if absf(float(row["能量前"])-state)>0.0001:
            return false
        if row.kind=="action":
            var action: Dictionary=catalogue[row.id]
            var duration:=float(row["结束秒"])-float(row["开始秒"])
            var required:=float(action.cost)+float(action.cost_rate)*duration
            if state+0.000001<required:
                return false
            if last.has(row.id) and float(row["开始秒"])-float(last[row.id])<float(action.cooldown)-0.000001:
                return false
            last[row.id]=row["开始秒"]
            state-=required
            count+=1
        elif row.kind in ["rest","recovery"]:
            state=float(row["能量后"])
        if absf(state-float(row["能量后"]))>0.0001:
            return false
    return count==payload.sequence.size()*int(payload.repeats) and absf(state-float(result.energy))<0.0001


func domain_checks(_context: RefCounted) -> void:
    var payload:=course()
    check(M.validate(payload), "solver consumes valid persisted course fields")
    var result:=A.schedule(payload)
    check(result.ok and A.certify(payload,result), "scheduler produces a complete certified course")
    check(result.completed==4 and result.inserted>0, "cooldown waits and additional rest preserve all actions")
    check(independent_verify(payload,result), "independent timeline replay confirms energy and cooldowns")
    var actions: Array = result.rows.filter(func(row: Dictionary): return row.kind=="action")
    check(actions.map(func(row: Dictionary): return row["开始秒"])==[0.0,5.0,10.0,15.0], "same-action cooldown has exact earliest timestamps")
    check(is_equal_approx(result.duration,16), "final action duration is included")
    check(is_equal_approx(result.energy,4), "initial plus all rest recovery minus consumption balances")
    for seed in 32:
        var sample:=course()
        sample.actions[0].cooldown=float(seed%7)
        sample.actions[0].cost=float(1+seed%5)
        sample.actions[0].cost_rate=float(seed%3)*0.2
        sample.waits.a=0.5+float(seed%4)*0.3
        sample.actions[0].duration=0.25
        sample.repeats=float(1+seed%4)
        sample.rest=0.5+float(seed%3)
        sample.recovery=float(1+seed%5)
        sample.energy=float(seed%8)
        var signature:=JSON.stringify(sample)
        var solved:=A.schedule(sample)
        check(solved.ok and A.certify(sample,solved), "bounded parameter family has complete scheduling certificate")
        check(independent_verify(sample,solved), "independent replay validates variable cost rates and repeats")
        check(JSON.stringify(sample)==signature, "solver does not alter saved course")
    var impossible:=course()
    impossible.energy=0.0
    impossible.recovery=0.0
    check(not A.schedule(impossible).ok, "no recovery assumption cannot invent energy")
    impossible.recovery=10.0
    impossible.rest=0.0
    check(not A.schedule(impossible).ok, "inserted recovery requires explicit positive rest time")
    impossible=course()
    impossible.sequence=["unknown"]
    check(not A.schedule(impossible).ok, "unknown actions reject the complete schedule")
    var limited:=course()
    limited.target_duration=1.0
    result=A.schedule(limited)
    check(result.ok and not result.within_target, "feasible but over-target result does not claim target success")
    var huge:=course()
    huge.actions[0].cooldown=10000.0
    check(not A.schedule(huge).ok, "absolute scheduling cap gives failure without partial success")
    var rate:=course()
    rate.sequence=["a"]
    rate.repeats=1.0
    rate.actions[0].cost_rate=2.0
    rate.waits.a=2.0
    rate.energy=100.0
    result=A.schedule(rate)
    check(result.ok and is_equal_approx(result.consumed,7), "per-second cost applies to the complete held duration")
    var tampered:=result.duplicate(true)
    tampered.rows[0]["能量后"]=-1.0
    check(not A.certify(rate,tampered), "negative-energy action certificate cannot pass")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/curriculum/advanced_view.gd").new()
    view.configure({"payload":payload})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view._move(1); view._move(-1)
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
