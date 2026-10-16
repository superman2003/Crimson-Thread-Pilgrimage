extends "res://scripts/world_route_manifest_walk_helper.gd"
## The two crown links, both directions; complete input/collision traversal.
func route_ids() -> Array[String]:
    return ["obsidian_crown_causeway", "greenhouse_crown_roots"]

func suite_name() -> String:
    return "WORLD_ROUTE_MANIFEST_WALK_UPPER"
