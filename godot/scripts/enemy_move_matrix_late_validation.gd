extends "res://scripts/enemy_move_matrix_validation.gd"
## Field enemy moves, obsidian road and silent crown.


func _chapters() -> Array:
    return CHAPTERS.slice(4)


func _marker() -> String:
    return "ENEMY_MOVE_MATRIX_LATE"
