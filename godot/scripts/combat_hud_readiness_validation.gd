extends RefCounted
## Real player gates and production tool/HUD adapters; queries cannot spend stock.
class Trap extends Node:
    var owner_player: Node

func run(main: Node, check: Callable) -> void:
    main._close_overlays()
    var player: Node = main.player
    var ui: Node = main.ui_shell
    var system: RefCounted = main.build_system
    var before: Dictionary = system.serialize()
    var old_position: Vector2 = player.global_position
    var old_hp: int = player.hp
    player.attack_timer = 0.0
    player.hurt_timer = 0.0
    player.heal_timer = 0.0
    player.dash_timer = 0.0
    player.grapple_timer = 0.0
    player.guard_timer = 0.0
    player.phase_active = false
    player.skill_cooldown = 0.0
    player.ui_input_locked = false
    player.hp = 3
    var skill := {"id":"cleave","energy_cost":0}
    player.hurt_timer = 0.4
    check.call(not player.get_cast_readiness("cleave").available and ui._skill_readiness(skill,0,true).text == "动作中", "HUD blocks casting during actual hurt recovery")
    player.hurt_timer = 0.0
    player.skill_cooldown = 0.7
    check.call(ui._skill_readiness(skill,0,true).text == "0.7s", "another skill's recovery blocks a zero-cooldown slot")
    player.skill_cooldown = 0.0
    check.call(player.get_cast_readiness("cleave").available, "free player can cast an airborne-compatible skill")
    check.call(player.get_cast_readiness("shockwave").available == player.is_on_floor(), "shockwave HUD follows real floor requirement")
    player.hp = 0
    check.call(ui._skill_readiness(skill,0,true).text == "复生中", "dead player does not advertise a ready cast")
    player.hp = 3
    system.unlock_event("tool_mine_found")
    system.state.tool_counts.mine = 0
    check.call(not main.get_tool_readiness("mine").available and main.get_tool_readiness("mine").text == "已用尽", "zero stock outside practice is unavailable")
    system.state.tool_counts.mine = 1
    check.call(main.get_tool_readiness("mine").available, "positive stock becomes available without spending")
    var traps: Array[Node] = []
    for index in 2:
        var trap := Trap.new()
        trap.owner_player = player
        main.add_child(trap)
        trap.add_to_group("player_trap")
        traps.append(trap)
    check.call(main.get_tool_readiness("mine").text == "已布满", "two actual owned trap group members block a third placement")
    for trap in traps:trap.free()
    var practice_id := ""
    # Use authored plan/room geometry for the free-practice fixture.
    var plans: Array = preload("res://scripts/world_routes.gd").cached_data().get("tool_practice_plan",[])
    for plan in plans:
        if String(plan.get("tool_id","")) == "shard" and String(plan.get("region_id","")) == String(main.config.id):
            practice_id = String(plan.get("room_id",""))
    var saved_room: String = main.current_room_id
    main.current_room_id = practice_id
    system.state.tool_counts.shard = 0
    var practice: bool = main._in_tool_practice_room()
    check.call(not practice_id.is_empty() and practice, "fixture enters the authored shard practice room")
    check.call(main.get_tool_readiness("shard").available and main.get_tool_readiness("shard").text == "练习", "empty stock remains usable in free practice")
    player.hurt_timer = 0.2
    check.call(main.get_tool_readiness("shard").text == "动作中", "practice still obeys combat recovery gates")
    player.hurt_timer = 0.0
    check.call(system.state.tool_counts.shard == 0 and system.state.tool_counts.mine == 1, "all readiness queries leave counts untouched")
    main.current_room_id = saved_room
    system.restore(before)
    player.global_position = old_position
    player.hp = old_hp
