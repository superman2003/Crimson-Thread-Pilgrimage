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
    _thread_thresholds(main, player, ui, system, check)
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
    system.state.active_tool_slot = 0
    system.select_tool("mine", 0)
    system.state.tool_counts.mine = 0
    check.call(not main.get_tool_readiness("mine").available and main.get_tool_readiness("mine").text == "已用尽", "zero stock outside practice is unavailable")
    main.toast_label.text = ""
    var result: Dictionary = main.perform_build_action("use_tool")
    check.call(not result.ok and main.toast_label.text == "战具已用尽，请在钟龛补给" and system.state.tool_counts.mine == 0, "using an exhausted tool shows the resupply toast without spending stock")
    system.state.tools[0] = ""
    main.toast_label.text = ""
    result = main.perform_build_action("use_tool")
    check.call(not result.ok and result.reason == "此战具槽位为空" and main.toast_label.text == result.reason, "empty tool slot reports its own reason instead of exhausted stock")
    system.state.tools[0] = "mine"
    system.state.tool_counts.mine = 1
    check.call(main.get_tool_readiness("mine").available, "positive stock becomes available without spending")
    for blocked_state in ["death", "transition", "loading"]:
        player.hp = 0 if blocked_state == "death" else 3
        main.chapter_transitioning = blocked_state == "transition"
        main.world_loading = blocked_state == "loading"
        main.toast_label.text = ""
        result = main.perform_build_action("use_tool")
        check.call(not result.ok and not main.toast_label.text.is_empty() and main.toast_label.text == result.reason and system.state.tool_counts.mine == 1, "%s tool rejection shows feedback without consuming stock" % blocked_state)
    player.hp = 3
    main.chapter_transitioning = false
    main.world_loading = false
    main.toast_label.text = "unchanged"
    player.hurt_timer = 0.2
    result = main.perform_build_action("use_tool")
    check.call(not result.ok and main.toast_label.text == "unchanged" and system.state.tool_counts.mine == 1, "action-locked tool rejection stays silent without consuming stock")
    player.hurt_timer = 0.0
    var traps: Array[Node] = []
    for index in 2:
        var trap := Trap.new()
        trap.owner_player = player
        main.add_child(trap)
        trap.add_to_group("player_trap")
        traps.append(trap)
    check.call(main.get_tool_readiness("mine").text == "已布满", "two actual owned trap group members block a third placement")
    result = main.perform_build_action("use_tool")
    check.call(not result.ok and main.toast_label.text == "unchanged" and system.state.tool_counts.mine == 1, "full mine field rejection stays silent without consuming stock")
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
    system.state.tools[0] = ""
    main.toast_label.text = ""
    result = main.perform_build_action("use_tool")
    check.call(not result.ok and main.toast_label.text == "此战具槽位为空" and not system.state.tool_counts.has(""), "practice does not make an empty slot usable or invent stock")
    player.hurt_timer = 0.2
    check.call(main.get_tool_readiness("shard").text == "动作中", "practice still obeys combat recovery gates")
    player.hurt_timer = 0.0
    check.call(system.state.tool_counts.shard == 0 and system.state.tool_counts.mine == 1, "readiness queries and rejected uses leave counts untouched")
    main.current_room_id = saved_room
    system.restore(before)
    player.global_position = old_position
    player.hp = old_hp


## U03: the thread meter marks the heal threshold and the active art's cost,
## lit only when the current thread actually pays for them.
func _thread_thresholds(main: Node, player: Node, ui: Node, system: RefCounted, check: Callable) -> void:
    var marks: Control = ui.thread_thresholds
    var saved_energy: int = player.energy
    var saved_heal: int = player.heal_energy_cost
    var saved_skills: Array = system.state.skills.duplicate()
    var active: Dictionary = system.selected_skill()
    var skill_cost := int(active.get("energy_cost", 0))
    check.call(marks != null and marks.get_parent() == ui.thread_bar.get_parent() and marks.size.x == ui.thread_bar.size.x, "threshold marks overlay the actual thread meter")
    player.energy = player.heal_energy_cost - 1
    ui._process(0.0)
    check.call(marks.heal_cost == player.heal_energy_cost and marks.maximum == player.max_energy and marks.energy == player.energy, "the HUD frame copies the real heal cost and thread into the meter marks")
    check.call(not marks.threshold_state().heal_lit, "one thread short of a heal leaves the heal mark dim")
    check.call(absf(float(marks.threshold_state().heal_x) - marks.size.x * float(player.heal_energy_cost) / float(player.max_energy)) < 0.01, "the heal mark sits at the heal cost along the meter")
    player.energy = player.heal_energy_cost
    ui._process(0.0)
    check.call(marks.threshold_state().heal_lit and player.get_heal_readiness().get("reason", "") != "energy", "exactly enough thread lights the heal mark and the heal gate agrees")
    check.call(marks.skill_cost == skill_cost and (skill_cost == 0 or not active.is_empty()), "the art mark uses the active slot's real cost")
    if skill_cost > 0:
        player.energy = skill_cost - 1
        ui._process(0.0)
        check.call(not marks.threshold_state().skill_lit and ui._skill_readiness(active, 0.0, true).text == "缺1", "one thread short dims the art mark and the slot reports the same shortfall")
        player.energy = skill_cost
        ui._process(0.0)
        check.call(marks.threshold_state().skill_lit, "affording the active art lights its mark")
    player.heal_energy_cost = maxi(1, saved_heal - 20)
    ui._process(0.0)
    check.call(marks.heal_cost == player.heal_energy_cost, "a changed heal cost (crest or charm) moves the heal mark")
    var slot := int(system.state.get("active_skill_slot", 0))
    system.state.skills[slot] = ""
    ui._process(0.0)
    check.call(marks.skill_cost == 0 and not marks.threshold_state().skill_lit, "an empty active art slot draws no cost mark")
    system.state.skills = saved_skills
    player.heal_energy_cost = saved_heal
    player.energy = saved_energy
    ui._process(0.0)

