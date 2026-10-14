extends SceneTree
# Observation harness. Run ONLY from a disposable copy of the Godot project.
# Entry mode uses ordinary action input; boss mode explicitly spawns/teleports.
var frame := 0
var mode := "entry"
var scene: Node
var player: Node
var previous_hp := -1
var last_states: Dictionary = {}

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--probe-mode="):
            mode = arg.get_slice("=", 1)
    call_deferred("run")

func run() -> void:
    scene = load("res://scenes/Main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    player = scene.player
    if mode.begins_with("boss"):
        scene._spawn_boss()
        scene._set_boss_arena_locked(true)
        player.global_position = scene.boss_actor.global_position + Vector2(-200, -20)
        player.velocity = Vector2.ZERO
        if mode == "boss_phase2":
            # Explicit artificial phase setup; never counts as a earned phase transition.
            scene.boss_actor.hp = int(scene.boss_actor.max_hp * 0.5)
    player.heal_state_changed.connect(func(state): emit({"event":"heal", "state":state}))
    emit({"event":"start", "config":scene.config.id,"mode":mode,"max_hp":player.max_hp,"energy":player.energy,"heal_duration":player.heal_duration,"heal_cost":player.heal_energy_cost,"enemy_count":get_nodes_in_group("enemy").size()})
    for tick in range(2400):
        frame = tick
        if mode == "entry":
            if tick == 300: Input.action_press("move_right")
            if tick >= 300:
                if tick % 90 == 0: Input.action_press("jump")
                if tick % 90 == 18: Input.action_release("jump")
                if tick % 45 == 0: Input.action_press("attack")
                if tick % 45 == 2: Input.action_release("attack")
        else:
            # No attacks, health/resource edits, immunity, or repeated teleport.
            if tick % 120 == 0: Input.action_press("heal")
            if tick % 120 == 2: Input.action_release("heal")
        await physics_frame
        if player.hp != previous_hp:
            emit({"event":"hp", "hp":player.hp,"position":[player.position.x,player.position.y]})
            previous_hp = player.hp
        if tick % 120 == 0:
            emit({"event":"sample","position":[player.position.x,player.position.y],"hp":player.hp,"energy":player.energy,"ground":player.is_on_floor(),"ui_locked":player.ui_input_locked})
        for enemy in get_nodes_in_group("enemy"):
            var key := str(enemy.get_instance_id())
            var token := str(enemy.state)+":"+str(enemy.last_attack_id)
            if token != last_states.get(key, "") and (enemy.state == "windup" or enemy.state == "active"):
                emit({"event":"enemy_state","kind":enemy.kind,"state":enemy.state,"attack":enemy.last_attack_id,"boss":enemy.is_boss,"telegraph":is_instance_valid(enemy.telegraph),"original_visual":enemy.original_visual,"original_warning_nodes":enemy.find_children("OriginalAttackWarning", "", false, false).size(),"position":[enemy.position.x,enemy.position.y]})
            last_states[key] = token
    for action in ["move_right","jump","attack","heal"]: Input.action_release(action)
    emit({"event":"end","hp":player.hp,"position":[player.position.x,player.position.y]})
    quit()

func emit(data: Dictionary) -> void:
    data["frame"] = frame
    data["simulation_seconds"] = snappedf(frame / 60.0, 0.001)
    print("REVIEW_JSON " + JSON.stringify(data))
