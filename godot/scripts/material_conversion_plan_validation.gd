extends SceneTree
const MODEL:=preload("res://scripts/material_conversion_plan.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func run() -> void:
    var recipes: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/material_exchange.json")).recipes
    var known: Array=[]
    for row in recipes:
        if row.id in ["exchange_01_02","exchange_02_03"]:known.append(row)
    var inventory:={"moss_chitin":9,"wet_chitin":0,"salt_crystal_shard":0}
    var before:=inventory.duplicate(true);var rows_before:=var_to_str(known)
    var result:=MODEL.search(known,inventory,32,"salt_crystal_shard",1)
    check(result.ok,"actual two-hop canonical rates produce feasible result")
    if result.ok:
        check(result.cost==32 and result.money==0,"nine first materials require three intermediate trades plus one final trade")
        check(result.counts.moss_chitin==0 and result.counts.wet_chitin==0 and result.counts.salt_crystal_shard==1,"exact canonical material balances")
        check(MODEL.verify(known,inventory,32,"salt_crystal_shard",1,result),"independent replay validates every accepted exchange")
        var forged:=result.duplicate(true);forged.money=1
        check(not MODEL.verify(known,inventory,32,"salt_crystal_shard",1,forged),"forged remaining wallet rejected")
        forged=result.duplicate(true);forged.path[0].gained+=1
        check(not MODEL.verify(known,inventory,32,"salt_crystal_shard",1,forged),"forged per-step material gain rejected")
        forged=result.duplicate(true);forged.path[0].recipe="unknown"
        check(not MODEL.verify(known,inventory,32,"salt_crystal_shard",1,forged),"unknown route ID rejected")
    check(inventory==before and var_to_str(known)==rows_before,"planning and replay do not mutate source wallet or canonical recipes")
    check(not MODEL.search(known,inventory,31,"salt_crystal_shard",1).ok,"one missing currency prevents impossible plan")
    check(not MODEL.search(known,{"moss_chitin":8},100,"salt_crystal_shard",1).ok,"one missing source material cannot be invented")
    check(not MODEL.search(known.slice(0,1),inventory,100,"salt_crystal_shard",1).ok,"undisclosed second recipe cannot be used")
    var owned:=MODEL.search(known,{"salt_crystal_shard":1},0,"salt_crystal_shard",1)
    check(owned.ok and owned.path.is_empty() and owned.cost==0,"already-owned target consumes nothing")
    for bad in [true,-1,0.5,NAN,INF,"32"]:
        check(not MODEL.search(known,inventory,bad,"salt_crystal_shard",1).ok,"invalid wallet fails closed")
    check(not MODEL.search(known,{"moss_chitin":true},100,"salt_crystal_shard",1).ok,"boolean material is not inventory")
    check(not MODEL.search(known,inventory,100,"hidden_material",1).ok,"unknown requested material not admitted")
    check(not MODEL.search(known,inventory,100,"salt_crystal_shard",0).ok,"zero request rejected")
    var duplicate:=known.duplicate(true);duplicate.append(known[0])
    check(not MODEL.search(duplicate,inventory,100,"salt_crystal_shard",1).ok,"duplicate recipe identities rejected")
    var bad_rate:=known.duplicate(true);bad_rate[0].input_amount=0
    check(not MODEL.search(bad_rate,inventory,100,"salt_crystal_shard",1).ok,"zero-cost material source cannot be synthesized")
    var direct: Dictionary=known[0].duplicate(true);direct.id="direct";direct.output="salt_crystal_shard";direct.currency=20;direct.input_amount=9
    var choices:=known.duplicate(true);choices.append(direct)
    var cheaper:=MODEL.search(choices,inventory,32,"salt_crystal_shard",1)
    check(cheaper.ok and cheaper.cost==20 and cheaper.path.size()==1,"minimum spending wins over canonical two-hop choice")
    var node:={"counts":{"moss_chitin":3,"wet_chitin":999999},"money":100,"path":[]}
    check(MODEL.transition(node,known[0],1).is_empty(),"save capacity cannot overflow in a hypothetical step")
    check(MODEL.transition({"counts":inventory,"money":100,"path":[]},known[0],11).is_empty(),"per-transaction ten-batch bound retained")
    print("MATERIAL_CONVERSION_PLAN checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
