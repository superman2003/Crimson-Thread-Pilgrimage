extends "res://scripts/enemy_move_matrix_validation.gd"
## Field enemy moves, saltwhite archive and greenhouse.


func _chapters() -> Array:
    return CHAPTERS.slice(2, 4)


func _marker() -> String:
    return "ENEMY_MOVE_MATRIX_MID"
