extends "res://scripts/main_level.gd"
## Lightweight physics fixture: production action handler, gates and inventory;
## rendering and the full campaign loader are exercised by the World suites.
var save_requests := 0
func _ready() -> void:
    set_process(false)
    set_physics_process(false)
func _save_world() -> bool:
    save_requests += 1
    return true
func _toast(_text: String) -> void: pass
func _spawn_route_open_effect(_where: Vector2) -> void: pass
func _play_sfx(_key: String, _volume: float = -7.0) -> void: pass
