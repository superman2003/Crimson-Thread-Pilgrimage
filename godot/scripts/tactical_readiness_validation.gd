extends RefCounted
## Actual HUD card production code, using the existing real build-system fixture.
func run(ui: Control, runtime: Node, check: Callable) -> void:
    var system: RefCounted = runtime.build_system
    var energy: int = runtime.player.energy
    var saved_cooldowns: Dictionary = system.cooldowns.duplicate(true)
    var snapshot: Dictionary = ui._build_snapshot()
    var skill: Dictionary = system.selected_skill(0)
    var cost: int = skill.energy_cost
    var id := String(skill.id)
    check.call(cost>0,"HUD fixture uses a positive real build-derived skill cost")
    system.cooldowns[id]=0.0
    runtime.player.energy=0
    ui._refresh_tactical_cards(snapshot,system.state,system)
    check.call(ui.tactical_values[0].text=="缺%d" % cost,"Zero energy card shows exact deficit instead of ready binding")
    check.call(ui.tactical_cards[0].tooltip_text.contains("绯线不足") and ui.tactical_cards[0].tooltip_text.contains("需要 %d" % cost),"Card tooltip explains actual resource requirement")
    check.call(ui.tactical_icons[0].modulate!=Color.WHITE,"Unavailable resource state dims skill icon")
    runtime.player.energy=cost-1
    ui._refresh_tactical_cards(snapshot,system.state,system)
    check.call(ui.tactical_values[0].text=="缺1","One point short stays unavailable")
    runtime.player.energy=cost
    ui._refresh_tactical_cards(snapshot,system.state,system)
    check.call(ui.tactical_values[0].text==ui._short_binding("skill_1") and ui.tactical_icons[0].modulate==Color.WHITE,"Exact cost restores active binding and ready icon")
    var inactive: Dictionary=ui._skill_readiness(skill,0.0,false)
    check.call(inactive.text=="待切换" and inactive.available,"Affordable inactive skill keeps selection hint")
    runtime.player.energy=0
    system.cooldowns[id]=1.5
    ui._refresh_tactical_cards(snapshot,system.state,system)
    check.call(ui.tactical_values[0].text=="1.5s" and ui.tactical_cards[0].tooltip_text.contains("冷却中"),"Cooldown remains the first unavailable reason")
    system.cooldowns[id]=0.0
    runtime.player.energy=cost
    ui._refresh_tactical_cards(snapshot,system.state,system)
    check.call(ui.tactical_values[0].text==ui._short_binding("skill_1"),"Resource recovery clears previous deficit text immediately")
    check.call(runtime.player.energy==cost and system.cooldowns[id]==0.0,"HUD queries do not spend energy or start cooldown")
    var adjusted: Dictionary = ui._skill_readiness({"energy_cost":cost+7},0.0,true)
    check.call(adjusted.text=="缺7","Presentation honors adjusted snapshot cost rather than a fixed catalog value")
    runtime.player.energy=energy
    system.cooldowns=saved_cooldowns
    ui._refresh_combat_status(runtime.player)
