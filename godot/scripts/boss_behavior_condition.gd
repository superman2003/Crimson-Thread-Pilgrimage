extends "res://addons/beehave/nodes/leaves/condition.gd"
## Conditions are evaluated at branch entry, never in the middle of a strike.
var intent := ""

func tick(actor: Node, _blackboard: Blackboard) -> int:
    return SUCCESS if actor.boss_brain.intent_allowed(intent) else FAILURE
