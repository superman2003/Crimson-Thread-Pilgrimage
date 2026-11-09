extends RefCounted
## Material/weapon weight is independent of the damage/telegraph severity tier.
const ROOT := "res://assets/audio/sfx/ai_combat/"

static func release_family(kind: String, locomotion: String, command: Dictionary) -> String:
    var type:=String(command.get("type","melee"))
    var pose:=String(command.get("animation","attack"))
    if type=="dive" or (locomotion=="flight" and type in ["lunge","vault","retreat"]):return "wing"
    if type in ["projectile","fan","mortar"]:return "seed"
    if type in ["rootline","pool"] or ((kind.contains("root") or kind.contains("gardener")) and type in ["aoe","wave"]):return "root"
    if type in ["beam","nova","shockwave","wave","aoe"]:return "bell"
    if pose in ["heavy","phase"] or type=="vault" or int(command.get("damage",1))>=2:return "heavy"
    if kind in ["moss_larva","rain_slug","root_hound"] or kind.contains("larva") or kind.contains("beetle"):return "claw"
    return "blade"

static func preparation_family(release: String) -> String:
    if release in ["seed","root","bell"]:return "prep_cast"
    if release=="heavy":return "prep_heavy"
    return "prep_light"

static func variant_count(family: String) -> int:
    return 2 if family.begins_with("prep_") else 3

static func path(family: String, variant: int) -> String:
    return ROOT+"%s_%d.ogg" % [family,variant]
