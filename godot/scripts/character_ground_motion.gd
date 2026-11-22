extends RefCounted

const GRAVITY := 1850.0
const ACCELERATION := 9.5


static func configure_floor(body: CharacterBody2D) -> void:
    body.floor_snap_length = 18.0
    body.floor_constant_speed = true


static func approach_speed(current_speed: float, target_speed: float, base_speed: float, delta: float) -> float:
    return move_toward(current_speed, target_speed, base_speed * ACCELERATION * delta)
