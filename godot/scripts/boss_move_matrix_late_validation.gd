extends "res://scripts/boss_move_matrix_validation.gd"
## B03 second half: greenhouse, obsidian road and silent crown arenas.


func _chapters() -> Array:
    return CHAPTERS.slice(3)


func _marker() -> String:
    return "BOSS_MOVE_MATRIX_LATE"
