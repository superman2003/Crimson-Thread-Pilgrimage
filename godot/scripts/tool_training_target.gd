extends "res://scripts/enemy_actor.gd"
## A tool practice puppet in the real level. Unlike the skill practice rack it
## runs the normal enemy AI, so a lure pulls it, salt fog blinds its practice
## beam and a trip spike stops its walk. It deals no damage, is never a
## progression enemy or loot source, and stands back up after being knocked down.
var training_reset := 0.0

func _ready() -> void:
    super._ready()
    collision_mask = 0
    set_meta("tool_training_target", true)

func _physics_process(delta: float) -> void:
    training_reset = maxf(0.0, training_reset - delta)
    if hp <= 0:
        if training_reset <= 0.0:
            hp = max_hp
        return
    super._physics_process(delta)

func take_hit(amount: int, _hit_direction: int) -> void:
    if hp <= 0 or amount <= 0:
        return
    hp = maxi(0, hp - amount)
    _set_flash_amount(1.0)
    flash_timer = FLASH_TOTAL_TIME
    if hp <= 0:
        training_reset = 1.5
        _cancel_attack_effects()
        _clear_telegraph()
        active_attack = {}
        state = "patrol"
