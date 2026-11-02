extends "res://scripts/spatial_enemy_alert.gd"
## Keep exploration landmarks on the world SFX chain, including while moving
## between clear and obstructed space. Enemy warnings use their original voice.
const FILTER := preload("res://scripts/enemy_sound_filter.gd")
const FILTER_BUS := "CrimsonLandmarkOccluded"
const FILTER_OWNER := "crimson_landmark_occlusion_filter"

func refresh_spatial(source: Vector2, listener: Node2D) -> bool:
    if not super.refresh_spatial(source, listener):
        return false
    bus = FILTER.ensure_bus("SFXWorld", FILTER_BUS, FILTER_OWNER) if occluded else FILTER.fallback("SFXWorld", FILTER_BUS)
    return true
