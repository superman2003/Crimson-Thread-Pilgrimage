extends "res://scripts/boss_heal_windows_validation.gd"
## C02 second half: greenhouse, obsidian road and silent crown arenas.


func _chapters() -> Array:
    return CHAPTERS.slice(3)


func _marker() -> String:
    return "BOSS_HEAL_WINDOWS_LATE"
