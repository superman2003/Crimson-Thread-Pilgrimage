extends Area2D

@export var patrol_distance: float = 90.0
@export var speed: float = 42.0
@export var hp: int = 2

var start_x: float
var direction: int = 1


func _ready() -> void:
    add_to_group("enemy")
    start_x = global_position.x
    body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
    position.x += direction * speed * delta
    if absf(global_position.x - start_x) > patrol_distance:
        direction *= -1
        scale.x = direction


func take_hit(amount: int, hit_direction: int) -> void:
    hp -= amount
    position.x += hit_direction * 18.0
    modulate = Color(1.0, 0.72, 0.55)
    if hp <= 0:
        queue_free()


func _on_body_entered(body: Node) -> void:
    if body.has_method("take_damage"):
        body.take_damage(1, global_position)
