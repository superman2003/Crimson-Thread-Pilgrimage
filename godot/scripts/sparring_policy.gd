extends RefCounted
## Authored plans reference production actors; no player-supplied spawn data.
static var _bouts_cache: Array = []
static var _region_cache: Dictionary = {}

static func bouts() -> Array:
    if _bouts_cache.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/sparring_bouts.json"))
        if parsed is Dictionary and parsed.get("bouts") is Array:
            _bouts_cache = parsed.bouts
    return _bouts_cache.duplicate(true)

static func sources(bout: Dictionary) -> Dictionary:
    var region := String(bout.region)
    if not _region_cache.has(region):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/"+region+".json"))
        if parsed is Dictionary:
            var actors: Dictionary = {}
            for actor in parsed.get("enemy_spawns", []):
                actors[String(actor.id)] = actor
            if parsed.get("boss") is Dictionary:
                actors[String(parsed.boss.id)] = parsed.boss
            _region_cache[region] = {"actors": actors, "profiles": parsed.get("ai_profiles", {}), "config": parsed}
    var cached: Dictionary = _region_cache.get(region, {})
    if cached.is_empty():
        return {"actors": {}, "profiles": {}, "config": {}}
    return {"actors": cached.actors.duplicate(true), "profiles": cached.profiles, "config": cached.config}

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
