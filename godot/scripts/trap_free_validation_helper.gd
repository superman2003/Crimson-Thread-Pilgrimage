extends RefCounted
## Probe the legacy entry points with real Player state, including unknown kinds.
const KINDS := ["spikes", "bell", "bell_gap", "fake_moss_floor", "spore_chest", "falling_clapper", "shortcut_revenge", "false_lamp", "unknown_legacy_trap"]

static func probe(level: Node2D, player: CharacterBody2D) -> Array:
    var results: Array = []
    var children := level.get_child_count()
    player.arrival_guard_timer = 0.0
    player.hurt_timer = 0.0
    var hp: int = player.hp
    for kind: String in KINDS:
        level.call("_hazard", {"id":"retired_"+kind,"kind":kind,"rect":[100,100,200,30],"damage":999})
        results.append([level.get_child_count()==children, kind+" cannot create an environmental trap"])
        var legacy := Area2D.new()
        legacy.set_meta("damage",999)
        level.call("_add_hazard_visual",legacy,kind,Vector2(200,30))
        results.append([legacy.get_child_count()==0,kind+" cannot recreate an old visual or collider"])
        level.call("_on_hazard_body_entered",player,legacy)
        results.append([player.hp==hp,kind+" legacy contact cannot damage the Player"])
        legacy.free()
    results.append([not level.call("_ground_is_hazardous",Vector2(100,100)),"retired trap bounds cannot reject safe ground"])
    return results
