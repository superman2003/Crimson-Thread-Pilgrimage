extends Node
## Beehave owns tactical sequences. EnemyActor retains movement/hit execution.
const TREE = preload("res://scripts/boss_behavior_tree.gd")
const ACTION = preload("res://scripts/boss_behavior_action.gd")
const CONDITION = preload("res://scripts/boss_behavior_condition.gd")
const SELECTOR = preload("res://addons/beehave/nodes/composites/selector.gd")
const SEQUENCE = preload("res://addons/beehave/nodes/composites/sequence.gd")
const SWEEP = preload("res://scripts/enemy_motion_sweep.gd")
const CATALOG_PATH = "res://data/boss_behavior_trees.json"
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
var actor: Area2D
var target: CharacterBody2D
var tree: BeehaveTree
var kit: Dictionary
var clock := 0.0
var samples: Array[Dictionary] = []
var sensed: Dictionary = {}
var history: Array[String] = []
var neglected: Dictionary = {}
var intent := "observe"
var branch_count := 0
var attack_count := 0
var last_branch := ""

func setup(owner_actor: Area2D) -> void:
    actor = owner_actor
    kit = catalog.bosses[actor.kind]
    tree = TREE.new()
    tree.name = "BeehaveBossDecision"
    tree.actor = actor
    tree.process_thread = BeehaveTree.ProcessThread.MANUAL
    var root := SELECTOR.new()
    root.name = "ChooseTacticalSequence"
    for branch: Dictionary in kit.branches:
        var sequence := SEQUENCE.new()
        sequence.name = String(branch.id).to_pascal_case()
        var gate := CONDITION.new()
        gate.name = "Observe" + sequence.name
        gate.intent = branch.id
        sequence.add_child(gate)
        for index in branch.steps.size():
            var step: Dictionary = branch.steps[index]
            var action := ACTION.new()
            action.task = step.get("task", "attack")
            action.specification = step
            action.name = str(index + 1) + action.task.to_pascal_case()
            sequence.add_child(action)
        root.add_child(sequence)
    tree.add_child(root)
    add_child(tree)

func observe(delta: float, player: CharacterBody2D) -> void:
    target = player
    clock += delta
    if player == null or not actor._has_line_of_sight(player):
        samples.clear()
        sensed.clear()
        return
    # Only public, visible character actions; no pending inputs or future paths.
    samples.append({"at": clock, "position": player.global_position,
        "action": actor.last_player_command})
    var latency := float(kit.get("reaction_seconds", .18))
    while not samples.is_empty() and clock - float(samples[0].at) >= latency:
        sensed = samples.pop_front()
    tree.blackboard.set_value("observation", sensed.duplicate())

func step(delta: float, player: CharacterBody2D) -> void:
    target = player
    if actor.ai_commands.is_empty():
        reset_plan(false)
        return
    if sensed.is_empty():
        actor._set_enemy_animation("ready_guard")
        return
    tree.blackboard.set_value("delta", delta)
    tree.blackboard.set_value("phase", actor.battle_phase)
    tree.blackboard.set_value("intent", intent)
    tree.tick()

func reset_plan(clear_memory: bool = true) -> void:
    if tree != null:
        tree.interrupt()
        tree.status = -1
        tree.last_tick = -1
    intent = "observe"
    if clear_memory:
        samples.clear()
        sensed.clear()
        history.clear()
        neglected.clear()
        clock = 0.0
        attack_count = 0
        branch_count = 0
        last_branch = ""

func distance_seen() -> float:
    return absf(Vector2(sensed.get("position", actor.global_position)).x - actor.global_position.x)

func response_matches(response: String) -> bool:
    var action := String(sensed.get("action", "none"))
    match response:
        "approach": return distance_seen() < float(kit.get("close_range", 220))
        "retreat": return distance_seen() > float(kit.get("close_range", 220))
        "airborne": return action in ["jump", "fall", "slash_up", "slash_down", "falling_attack"]
        "committed": return action in ["slash_forward", "slash_up", "slash_down", "skill", "hook", "heal"]
        "grounded": return action not in ["jump", "fall", "slash_up", "slash_down", "falling_attack"]
    return false

func intent_allowed(id: String) -> bool:
    if sensed.is_empty() or target == null:
        return false
    var branch: Dictionary = {}
    for item: Dictionary in kit.branches:
        if item.id == id:
            branch = item
            break
    var gate := String(branch.get("when", "always"))
    if int(branch.get("phase", 1)) > actor.battle_phase:
        return false
    var allowed := gate == "always" or response_matches(gate)
    # A neglected *eligible* action takes precedence over favoured branches.
    var overdue := overdue_command()
    if not overdue.is_empty():
        allowed = overdue in branch.get("opening", [])
    if not allowed:
        return false
    var available := select_command(branch.get("opening", []))
    if available.is_empty() and gate != "always":
        return false
    intent = id
    last_branch = id
    branch_count += 1
    actor.boss_tactic = id
    tree.blackboard.set_value("intent", id)
    return true

func eligible_commands() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if target == null or sensed.is_empty() or not actor._has_line_of_sight(target):
        return result
    var seen: Vector2 = sensed.position
    var dx := absf(seen.x - actor.global_position.x)
    var dy := absf(seen.y - actor.global_position.y)
    for command: Dictionary in actor.ai_commands:
        if int(command.get("phase", 1)) > actor.battle_phase:
            continue
        if float(actor.cooldowns.get(command.id, 0.0)) > 0.0:
            continue
        if dx < float(command.get("min_range", 0)) or dx > float(command.get("range", 70)) or dy > actor._command_vertical_tolerance(command):
            continue
        # Revalidate current geometry too; delayed memory cannot force a whiff
        # from outside the move's authored targeting envelope.
        if actor._attack_can_reach_target(command, target):
            result.append(command)
    if history.size() >= 2 and history[-1] == history[-2] and result.size() > 1:
        result = result.filter(func(c: Dictionary) -> bool: return c.id != history[-1])
    return result

func overdue_command() -> String:
    var best := ""
    var age := 3
    for command: Dictionary in eligible_commands():
        var count := int(neglected.get(command.id, 0))
        if count > age:
            age = count
            best = command.id
    return best

func select_command(preferences: Array) -> Dictionary:
    var eligible := eligible_commands()
    var overdue := overdue_command()
    if not overdue.is_empty() and overdue not in preferences:
        return {}
    if not overdue.is_empty():
        for command: Dictionary in eligible:
            if command.id == overdue:
                return command
    for id in preferences:
        for command: Dictionary in eligible:
            if command.id == id:
                return command
    return {}

func record_attack(command: Dictionary) -> void:
    for other: Dictionary in eligible_commands():
        neglected[other.id] = 0 if other.id == command.id else int(neglected.get(other.id, 0)) + 1
    history.append(command.id)
    while history.size() > 12:
        history.pop_front()
    attack_count += 1
    tree.blackboard.set_value("attack_history", history.duplicate())
    tree.blackboard.set_value("neglected", neglected.duplicate())

func perform_stance(task: String, delta: float) -> void:
    actor.last_ai_decision = "beehave:" + intent + ":" + task
    if target == null:
        return
    actor._face_target(target)
    var seen_x := Vector2(sensed.get("position", target.global_position)).x
    var dx := seen_x - actor.global_position.x
    var movement := 0.0
    if task == "backstep" and absf(dx) < float(kit.get("close_range", 220)) * 1.3:
        movement = -signf(dx)
    elif task == "approach" and absf(dx) > float(kit.get("approach_range", 165)):
        movement = signf(dx)
    var previous := actor.global_position
    var desired := previous + Vector2(movement * actor._movement_speed() * delta, 0)
    # Face the opponent during backsteps. At walls hold guard rather than
    # flipping every tick or teleporting to the opposite side of the player.
    actor.global_position = SWEEP.constrain(actor, previous, desired)
    actor._clamp_movement_bounds()
    var moved := absf(actor.global_position.x - previous.x) > .01
    var animation := "backstep" if task == "backstep" and moved else "walk" if moved else "ready_settle" if task == "settle" else "ready_guard"
    actor._set_enemy_animation(animation)

func debug_state() -> Dictionary:
    return {"framework": "Beehave 2.9.3", "intent": intent, "reaction_seconds": kit.get("reaction_seconds", .18),
        "observation": sensed.duplicate(), "history": history.duplicate(), "neglected": neglected.duplicate(),
        "branch_count": branch_count, "attack_count": attack_count}
