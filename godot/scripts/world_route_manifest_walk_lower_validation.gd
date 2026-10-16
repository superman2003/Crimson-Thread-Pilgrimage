extends "res://scripts/world_route_manifest_walk_helper.gd"
## First three links, both directions; complete input/collision traversal.
func route_ids() -> Array[String]:
    return ["moss_rain_drainpipe", "rain_archive_conduit", "archive_obsidian_gallery"]

func suite_name() -> String:
    return "WORLD_ROUTE_MANIFEST_WALK_LOWER"
