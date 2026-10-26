extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/landmarks/model.gd")
const A := preload("res://journey/fieldwork/landmarks/advanced.gd")
const FEATURE := preload("res://journey/features/i_landmarks.gd")


func run() -> void:
    label = "I30_LANDMARKS"
    var context := field_fixture("j30_landmarks")
    await exercise(context, M, FEATURE, "j_landmarks", "markers")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func observation(id: String, point: Vector2, origin: Vector2, sigma: float=1.0) -> Dictionary:
    var delta:=point-origin
    return {"id":id,"point":[point.x,point.y],"bearing":fposmod(rad_to_deg(atan2(-delta.y,delta.x)),360),"sigma":sigma}


func domain_checks(context: RefCounted) -> void:
    var origin:=Vector2(20,30)
    var rows:=[observation("east",Vector2(200,30),origin),observation("north",Vector2(20,-100),origin),observation("southwest",Vector2(-80,140),origin)]
    var solved:=A.solve(rows)
    check(solved.ok and V.point(solved.point).distance_to(origin)<0.001, "three exact bearings reconstruct the known origin")
    check(solved.weighted_error<0.000001, "exact intersecting geometry has zero residual")
    check(solved.major>=solved.minor and solved.minor>0, "reported geometry ellipse has ordered positive scales")
    check(solved.condition>=1, "normal matrix condition number is at least one")
    check(A.leave_one_out(rows,solved).size()==3, "every landmark gets leave-one-out geometry audit")
    var duplicate:=rows.duplicate(true)
    duplicate[1].id=duplicate[0].id
    check(not A.solve(duplicate).ok, "duplicate landmark cannot double its confidence weight")
    check(not A.solve([rows[0]]).ok, "one bearing is insufficient for 2D location")
    var parallel:=[{"id":"a","point":[0,0],"bearing":0.0,"sigma":1.0},{"id":"b","point":[100,0],"bearing":0.0,"sigma":1.0}]
    check(not A.solve(parallel).ok, "parallel bearings do not invent a finite position")
    parallel[1].bearing=0.001
    check(not A.solve(parallel).ok, "nearly parallel unstable matrix is rejected")
    var invalid:=rows.duplicate(true)
    invalid[0].sigma=0.0
    check(not A.solve(invalid).ok, "zero uncertainty cannot divide by zero")
    invalid=rows.duplicate(true)
    invalid[0].bearing=NAN
    check(not A.solve(invalid).ok, "NaN direction rejected")
    invalid=rows.duplicate(true)
    invalid[0].point=[INF,0]
    check(not A.solve(invalid).ok, "infinite landmark rejected")
    var reversed:=rows.duplicate(true)
    reversed[0].bearing=fposmod(reversed[0].bearing+180,360)
    check(not A.solve(reversed).ok, "intersection behind declared forward bearing is not accepted")
    for seed in 24:
        var at:=Vector2(seed*17-80,seed*11-140)
        var sample:=[observation("a",at+Vector2(100,30),at),observation("b",at+Vector2(-40,-120),at),observation("c",at+Vector2(80,-60),at)]
        var frozen:=JSON.stringify(sample)
        var result:=A.solve(sample)
        check(result.ok and V.point(result.point).distance_to(at)<0.005, "translated multi-bearing geometry reconstructs absolute known coordinates")
        var weighted:=sample.duplicate(true)
        for row in weighted:
            row.sigma*=2
        var doubled:=A.solve(weighted)
        check(doubled.ok and absf(doubled.major/result.major-2)<0.001, "doubling all observation errors doubles ellipse scale")
        var shifted:=sample.duplicate(true)
        for row in shifted:
            row.point[0]+=123
            row.point[1]-=45
        var moved:=A.solve(shifted)
        check(moved.ok and V.point(moved.point).distance_to(at+Vector2(123,-45))<0.005, "translation equivariance of weighted line solve")
        check(JSON.stringify(sample)==frozen, "solving and leave-one-out analysis are read only")
    var payload:=M.capture(context.snapshot())
    payload.markers=[]
    for i in 30:
        payload.markers.append({"id":str(i),"name":str(i),"point":[100+i*10,100+i*i],"kind":"room"})
    payload.origin=[0,0]
    payload.radius=100000.0
    var selected:=A.observations(payload)
    check(selected.size()==24, "work cap takes at most nearest 24 known landmarks")
    payload.radius=1.0
    check(A.observations(payload).is_empty(), "outside-radius markers cannot enter location analysis")
    payload.markers=[{"id":"same","name":"same","point":[0,0],"kind":"room"}]
    check(A.observations(payload).is_empty(), "coincident origin marker cannot supply undefined bearing")
    var many:=[]
    for i in 25:
        many.append(observation(str(i),Vector2(i+1,i*i+1),Vector2.ZERO))
    check(not A.solve(many).ok, "oversized bearing input rejects instead of silently dropping observations")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/landmarks/advanced_view.gd").new()
    view.configure({"payload":payload})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view._calculate()
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
