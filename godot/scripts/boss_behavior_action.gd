extends "res://addons/beehave/nodes/leaves/action.gd"
## Owns a complete authored action, including its punishable recovery.
var task := "attack"
var specification: Dictionary = {}
var started := false
var serial := -1
var elapsed := 0.0

func before_run(_actor: Node, _blackboard: Blackboard) -> void:
    started = false
    serial = -1
    elapsed = 0.0

func tick(actor: Node, blackboard: Blackboard) -> int:
    var brain: Node = actor.boss_brain
    if task == "attack":
        if started:
            if actor.attack_execution_serial != serial:
                return FAILURE
            if actor.attack_completed_serial == serial:
                return SUCCESS
            return RUNNING if actor._is_attack_state() else FAILURE
        if specification.has("response") and not brain.response_matches(specification.response):
            return SUCCESS # Optional follow-up; the opponent did not take the bait.
        var command: Dictionary = brain.select_command(specification.get("moves", []))
        if command.is_empty():
            return SUCCESS if specification.get("optional", false) else FAILURE
        brain.record_attack(command)
        actor._face_target(brain.target)
        actor._begin_attack(command)
        serial = actor.attack_execution_serial
        started = actor.state == "windup"
        return RUNNING if started else FAILURE
    elapsed += float(blackboard.get_value("delta", 0.0))
    brain.perform_stance(task, float(blackboard.get_value("delta", 0.0)))
    if not started:
        started = true
        var animation := String(actor.animated_sprite.animation) if actor.animated_sprite != null else ""
        if animation in ["backstep", "ready_guard", "ready_settle"]:
            actor._set_enemy_animation(animation, true)
            actor._fit_animation_duration(float(specification.get("duration", .3)))
    return SUCCESS if elapsed >= float(specification.get("duration", .3)) else RUNNING

func interrupt(_actor: Node, _blackboard: Blackboard) -> void:
    started = false
    serial = -1
