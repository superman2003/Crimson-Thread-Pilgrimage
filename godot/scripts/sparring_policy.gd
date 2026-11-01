extends RefCounted
## Authored plans reference production actors; no player-supplied spawn data.
static func bouts() -> Array:
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/sparring_bouts.json"))
    return data.bouts.duplicate(true)

static func sources(bout: Dictionary) -> Dictionary:
    var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+String(bout.region)+".json"))
    var result: Dictionary={}
    for actor in config.enemy_spawns:result[String(actor.id)]=actor.duplicate(true)
    if config.get("boss") is Dictionary:result[String(config.boss.id)]=config.boss.duplicate(true)
    return {"actors":result,"profiles":config.get("ai_profiles",{}),"config":config}

static func available(level: Node) -> Array:
    var result: Array=[]
    for bout in bouts():
        if not preload("res://scripts/field_contracts.gd").known(level,String(bout.region)):continue
        var source:=sources(bout)
        var known:=true
        for wave in bout.waves:
            for id in wave:
                if not source.actors.has(id):known=false;continue
                var kind:=String(source.actors[id].kind)
                if not preload("res://scripts/field_contracts.gd").marked(level.story_flags,"journal_enemy_"+kind):known=false
        if known:result.append(bout)
    return result

static func quote(level: Node,id: String) -> Dictionary:
    if not preload("res://scripts/field_transaction.gd").ready(level):return {"ok":false,"reason":"在钟龛构筑页开始陪练。"}
    for bout in available(level):
        if bout.id==id:return {"ok":true,"bout":bout,"fingerprint":var_to_str([bout,level.build_system.serialize(),level.story_flags,level.inventory_counts]).sha256_text()}
    return {"ok":false,"reason":"先在旅途中击败这场复演涉及的敌人。"}
