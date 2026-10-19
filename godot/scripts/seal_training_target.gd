extends "res://scripts/enemy_actor.gd"
## A practice fixture in the real level, never a progression enemy or reward source.
var training_reset := 0.0
var hit_count := 0
var guard_practice_clock := 0.0

func _ready() -> void:
    super._ready()
    collision_mask = 0
    set_meta("seal_training_target", true)

func _physics_process(delta: float) -> void:
    var practice_player: Node2D = get_tree().get_first_node_in_group("player")
    if practice_player != null and bool(practice_player.get("ui_input_locked")):
        return
    salt_mark_timer = maxf(0.0, salt_mark_timer - delta)
    snare_timer = maxf(0.0, snare_timer - delta)
    trip_timer = maxf(0.0, trip_timer - delta)
    training_reset = maxf(0.0, training_reset - delta)
    if training_reset <= 0.0 and hp <= 0:
        hp = max_hp
        clear_salt_mark()
    modulate = Color("d6a75e") if snare_timer > 0.0 else (Color("e9e1bd") if salt_mark_timer > 0.0 else Color.WHITE)
    if String(name) == "seal_training_ward":
        guard_practice_clock += delta
        queue_redraw()
        if guard_practice_clock >= 2.0:
            guard_practice_clock = 0.0
            if practice_player != null and practice_player.global_position.distance_to(global_position) < 115.0 and practice_player.has_method("practice_guard_contact"):
                if practice_player.practice_guard_contact(global_position):
                    _report_practice()

func _draw() -> void:
    if String(name) == "seal_training_ward" and guard_practice_clock > 1.5:
        draw_line(Vector2(-44, -30), Vector2(44, -30), Color("f0ce83"), 3.0)
        draw_line(Vector2(-44, -30), Vector2(-32, -40), Color("f0ce83"), 3.0)

func take_hit(amount: int, _hit_direction: int) -> void:
    if hp <= 0:
        return
    hp = maxi(0, hp - maxi(0, amount))
    hit_count += 1
    training_reset = 1.5 if hp <= 0 else 0.0
    _report_practice()

## C04: tell the level this rack's skill was practised; it checks the last cast.
func _report_practice() -> void:
    var level := get_parent()
    if level != null and level.has_method("_on_skill_practice_hit"):
        level._on_skill_practice_hit(String(name).trim_prefix("seal_training_"))
