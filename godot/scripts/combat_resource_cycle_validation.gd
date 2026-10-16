extends SceneTree
## Real Player input, accepted enemy hits and paid heal/skill cycles. Opponent AI
## is frozen for repeatability; this is not boss difficulty or a natural unlock run.
const BUILD := preload("res://scripts/build_system.gd")
var checks := 0
var failures := 0
var player: CharacterBody2D
var enemy: Area2D
var build: RefCounted
var reentrant_results: Array[bool] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error(label)
func frames(count: int) -> void:
    for i in count:
        await physics_frame
        await process_frame
func pulse(action: String, hold: int = 2, settle: int = 42) -> void:
    Input.action_press(action)
    await frames(hold)
    Input.action_release(action)
    await frames(settle)
func reenter(_energy: int, _maximum: int) -> void:
    reentrant_results.append(player._try_heal())
func charge_to(amount: int, label: String) -> void:
    for swing in 7:
        if player.energy>=amount: return
        player.global_position=Vector2(100,180)
        player.velocity=Vector2.ZERO
        await frames(3)
        var before: int=player.energy
        var hp_before: int=enemy.hp
        await pulse("attack")
        check(enemy.hp<hp_before,label+": actual basic input hits the production enemy")
        check(player.energy==mini(player.max_energy,before+player.energy_per_hit),label+": one accepted target grants exactly one hit reward")
    check(player.energy>=amount,label+": basic combat can fund the authored action")
func run() -> void:
    root.size=Vector2i(1280,720)
    var floor := StaticBody2D.new()
    floor.position=Vector2(400,202)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size=Vector2(1800,44)
    shape.shape=rect
    floor.add_child(shape)
    root.add_child(floor)
    player=load("res://scenes/Player.tscn").instantiate()
    root.add_child(player)
    player.global_position=Vector2(100,180)
    player.feel=null
    build=BUILD.new()
    build.state.unlocked_crests=build.catalog.crests.keys()
    build.state.unlocked_skills=build.catalog.skills.keys()
    build.state.mechanisms=["crimson","bell","salt"]
    player.build_system=build
    enemy=load("res://scripts/enemy_actor.gd").new()
    enemy.configure({"id":"resource_cycle_target","hp":200,"kind":"moss_larva"},"",false,{})
    enemy.position=Vector2(155,140)
    root.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.contact_timer=1000.0
    await frames(8)
    check(not player.debug_invulnerable,"Cycle uses damage-enabled Player")
    for crest in ["crimson","bell","salt"]:
        build.state.crest=crest
        var skill := "cleave" if crest=="crimson" else "shockwave" if crest=="bell" else "needle"
        build.state.equipped_families.thread_skill=[skill,""]
        build._normalize_active_slots()
        build.cooldowns.clear()
        player.apply_build_stats(build.profile())
        player.restore_at_save_point()
        player.bell_guard_unlocked=true
        player.energy=0
        player.hp=player.max_hp-2
        player.global_position=Vector2(100,180)
        player.velocity=Vector2.ZERO
        await frames(5)
        await charge_to(player.heal_energy_cost,crest)
        if crest=="bell":
            await pulse("bell_guard",1,0)
            player.take_damage(1,Vector2(200,180),true)
            check(player.bell_pressure==1,crest+": real prepaid guard builds one pressure")
            await frames(12)
            await charge_to(player.heal_energy_cost,crest)
        if crest=="salt":
            await pulse("skill_1",2,55)
            check(enemy.salt_mark_timer>0.0,crest+": actual needle projectile applies mark")
            await charge_to(player.heal_energy_cost,crest)
        var before: int=player.energy
        var hp_before: int=player.hp
        var cost: int=player.heal_energy_cost
        check(player.get_heal_readiness().available,crest+": live action and HUD agree heal is available")
        await pulse("heal",1,0)
        check(player.heal_timer>0.0 and player.energy==before-cost and player.hp==hp_before,crest+": input reserves once without early healing")
        var channel: Dictionary=player.get_combat_ui_state().heal
        check(channel.reason=="channeling" and channel.interrupt_loss==cost,crest+": HUD exposes the active reservation")
        await frames(int(ceil(player.heal_duration*60.0))+3)
        check(player.hp==hp_before+player.heal_amount and player.energy==before-cost and player.heal_reserved_cost==0,crest+": completion grants exactly authored HP and spends exactly one cost")
        var profile: Dictionary=build.profile()
        if crest=="crimson": check(player.heal_speed_timer>0.0 and player.heal_speed_timer<=float(profile.heal_move_duration),"Crimson heal duration comes from catalog")
        elif crest=="bell":
            check(player.heal_stability_timer>0.0 and player.heal_stability_timer<=float(profile.heal_knockback_duration),"Bell heal duration comes from catalog")
            player.hurt_timer=0.0
            var healed_hp: int=player.hp
            player.take_damage(1,Vector2(200,180),false)
            check(player.hp==healed_hp-1 and player.velocity==Vector2.ZERO and player.heal_stability_timer==0.0,"Bell healing protects one knockback, never the damage")
            await frames(40)
        else:
            check(is_equal_approx(enemy.salt_mark_timer,5.0+float(profile.heal_mark_extension)),"Salt completed heal extends the actual projectile mark once")
            player._seal_heal_completed()
            check(is_equal_approx(enemy.salt_mark_timer,7.0),"Repeated salt healing cannot extend the same mark twice")
        await frames(25)
        build.state.skill_levels[skill]=1
        var preview: Dictionary=build.selected_skill()
        await charge_to(int(preview.energy_cost),crest+" follow-up")
        for i in 180:
            if float(build.cooldowns.get(skill,0.0))<=0.0: break
            await frames(1)
        before=player.energy
        var skill_target_hp: int=enemy.hp
        await pulse("skill_1",1,0)
        check(not player.active_skill.is_empty() and int(player.active_skill.get("level",0))==1,crest+": actual follow-up uses the upgraded equipped skill")
        check(player.energy==before-int(preview.energy_cost) and float(build.cooldowns.get(skill,0.0))>0.0,crest+": follow-up pays displayed cost and starts its own cooldown")
        var blocked_energy: int=player.energy
        check(not player.cast_selected_skill() and player.energy==blocked_energy,crest+": active/recovery recast cannot pay twice")
        await frames(60)
        check(enemy.hp<skill_target_hp and player.energy==blocked_energy,crest+": upgraded skill damages the real target without paying itself back")
        # Damage, not only movement, must cancel the paid channel with no late HP.
        player.apply_build_stats(build.profile())
        player.restore_at_save_point()
        player.hp=player.max_hp-2
        player.energy=100
        check(player._try_heal(),crest+": damage-interrupt fixture begins a paid channel")
        await frames(8)
        hp_before=player.hp
        player.arrival_guard_timer=0.0
        player.take_damage(1,Vector2(200,180),false)
        check(player.heal_timer==0.0 and player.heal_reserved_cost==0 and player.energy==mini(player.max_energy,100-cost+player.energy_on_damage) and player.hp==hp_before-1,crest+": damaging hit settles the reservation without healing")
        await frames(65)
        check(player.hp==hp_before-1,crest+": interrupted heal cannot complete later")
        print("COMBAT_RESOURCE_CYCLE crest=",crest," actual_hits=true actual_heal_input=true upgraded_followup=true")
    await verify_reservation()
    await verify_locked_mechanisms()
    enemy.queue_free()
    player.queue_free()
    floor.queue_free()
    await frames(2)
    await verify_world_hud()
    check(await preload("res://scripts/audio_retirement.gd").drain(self),"Cycle audio retires")
    print("COMBAT_RESOURCE_CYCLE checks=%d failures=%d crests=3 actual_input=true" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
func verify_reservation() -> void:
    player.apply_build_stats({"crest_id":"crimson","heal_interrupt_loss_ratio":0.25})
    player.restore_at_save_point()
    player.hp=player.max_hp-1
    player.energy=100
    player.energy_changed.connect(reenter)
    check(player._try_heal() and player.energy==40,"Channel publishes its reservation before resource signals")
    player.apply_build_stats({"crest_id":"bell","heal_interrupt_loss_ratio":1.0,"max_energy":50})
    check(player.energy==50 and player.heal_reserved_cost==0 and player.heal_timer==0.0,"Build change settles old 25% loss before applying new loss and capacity")
    var settled: int=player.energy
    player._interrupt_heal()
    check(player.energy==settled,"Repeated interruption cannot refund twice")
    check(not reentrant_results.is_empty() and not reentrant_results.has(true),"Resource signal reentry cannot begin a second channel during payment or refund")
    player.energy_changed.disconnect(reenter)
    player.apply_build_stats({"crest_id":"crimson","max_energy":100})
    player.restore_at_save_point()
    player.hp=player.max_hp-1
    player.energy=59
    var snapshot: Dictionary=player.get_heal_readiness()
    for i in 20: player.get_combat_ui_state()
    check(snapshot.reason=="energy" and snapshot.missing_energy==1 and player.energy==59 and player.heal_reserved_cost==0,"Repeated HUD queries are pure and report exact shortage")
    check(not player._try_heal() and player.energy==59,"Insufficient energy rejects without a reservation")
    player.energy=100
    Input.action_press("move_right")
    check(player.get_heal_readiness().reason=="moving" and not player._try_heal() and player.energy==100,"Moving input and UI share the same rejection")
    Input.action_release("move_right")
    player.global_position=Vector2(100,90)
    player.velocity=Vector2.ZERO
    await frames(2)
    check(player.get_heal_readiness().reason=="airborne" and not player._try_heal(),"Airborne HUD and actual action both require grounding")
    player.global_position=Vector2(100,180)
    player.velocity=Vector2.ZERO
    await frames(5)
    player.heal_cooldown=0.2
    check(player.get_heal_readiness().reason=="cooldown" and not player._try_heal(),"Cooldown HUD agrees with action lock")
    player.heal_cooldown=0.0
    player.hp=player.max_hp
    check(player.get_heal_readiness().reason=="full_health" and not player._try_heal(),"Full-health query does not reserve resource")
func verify_locked_mechanisms() -> void:
    for crest in ["crimson","bell","salt"]:
        player.apply_build_stats({"crest_id":crest,"mechanism_unlocked":false,"crimson_repaired":false})
        player.restore_at_save_point()
        check(not player.get_seal_mechanism_snapshot().unlocked,crest+": missing repair is visible in live snapshot")
        if crest=="crimson":
            player._basic_seal_hit()
            check(player.line_stacks==0,"Unrepaired Crimson cannot accumulate line")
        elif crest=="bell":
            player.bell_guard_unlocked=true
            check(player._try_guard(),"Unrepaired Bell retains ordinary paid guard")
            player.take_damage(1,Vector2(200,180),true)
            check(player.bell_pressure==0 and player.energy==96,"Unrepaired Bell cannot acquire pressure or free resource from guard")
        else:
            player.build_system=null
            enemy.clear_salt_mark()
            player.configure_selected_skill({"id":"needle","kind":"ranged","energy_cost":20,"damage":1,"range":300,"windup":0.08,"active":0.2,"recovery":0.1})
            var hp_before: int=enemy.hp
            await pulse("skill_1",2,55)
            check(enemy.hp<hp_before and enemy.salt_mark_timer==0.0,"Unrepaired Salt retains needle damage without granting the locked mark")
func verify_world_hud() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false
    world.world_save_path="user://combat_resource_hud.json"
    var source: Array=preload("res://scripts/world_routes.gd")._data().ability_backtracks[0].source_position
    world.entry_spawn_override_enabled=true
    world.entry_spawn_override=Vector2(source[0],source[1])
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    for actor in get_nodes_in_group("enemy"): actor.queue_free()
    for i in 120:
        await frames(1)
        if world.player.is_on_floor(): break
    check(world.player.is_on_floor(),"Production HUD fixture settles on the authored shrine floor")
    world._close_overlays()
    world.player.set_physics_process(false)
    world.ui_shell.set_process(false)
    world.build_system.state.unlocked_crests=world.build_system.catalog.crests.keys()
    world.build_system.state.mechanisms=["crimson","bell","salt"]
    for crest in ["crimson","bell","salt"]:
        world.build_system.state.crest=crest
        world.build_system._normalize_active_slots()
        world._sync_player_build()
        world.player.hp=world.player.max_hp-1
        if crest=="crimson":
            world.player.line_stacks=2
            world.player.line_expiry=2.8
        elif crest=="bell": world.player.bell_pressure=1
        world.player.energy=59
        world.ui_shell._refresh_combat_status(world.player)
        var label: Label=world.ui_shell.healing_status
        check(label.visible and label.text.contains("60") and label.text.contains("缺 1 绯线"),crest+": production HUD displays actual heal cost and shortage")
        check(label.tooltip_text.contains("中断损失 60") and label.tooltip_text.contains("0.80秒"),crest+": production HUD displays the authored duration and interruption cost")
        check(label.position.y+label.size.y<world.ui_shell.healing_bar.position.y and world.ui_shell.healing_bar.position.y+world.ui_shell.healing_bar.size.y<world.ui_shell.pinned.position.y,"Resource text, channel bar and pinned objective have separate bounds")
        world.ui_shell._process(0.0)
        check(world.ui_shell.energy_status.text=="59 / 100" and world.ui_shell.hearts.text=="%d / %d" % [world.player.hp,world.player.max_hp],crest+": full HUD and readiness display the same live resources")
        if DisplayServer.get_name()!="headless":
            await process_frame
            await RenderingServer.frame_post_draw
            var output := ProjectSettings.globalize_path("res://../artifacts/combat_resource_cycle")
            DirAccess.make_dir_recursive_absolute(output)
            check(root.get_texture().get_image().save_webp(output.path_join(crest+"_world_hud.webp"))==OK,"Actual World HUD capture saved")
        world.player.energy=100
        check(world.player._try_heal(),crest+": production World begins grounded paid heal")
        world.ui_shell._refresh_combat_status(world.player)
        check(label.text.contains("治疗中") and world.ui_shell.healing_bar.visible,crest+": channel text and progress bar use live timer")
        world.player._update_heal(float(world.player.heal_duration))
        world.ui_shell._refresh_combat_status(world.player)
        if crest!="salt": check(world.ui_shell.mechanism_status.text.contains("疾行" if crest=="crimson" else "抗击退"),crest+": completed-heal effect window is visible")
        world.player.heal_cooldown=0.0
        world.ui_shell._refresh_combat_status(world.player)
        check(label.text.contains("生命已满"),crest+": full-health HUD matches unavailable heal")
        world.player.build_profile.mechanism_unlocked=false
        world.ui_shell._refresh_combat_status(world.player)
        check(world.ui_shell.mechanism_status.text.contains("尚未修复"),crest+": unrepaired mechanism has explicit HUD state")
    var bindings: Array=InputMap.action_get_events("heal").duplicate()
    InputMap.action_erase_events("heal")
    var remap := InputEventKey.new()
    remap.physical_keycode=KEY_F10
    InputMap.action_add_event("heal",remap)
    world.ui_shell._refresh_combat_status(world.player)
    check(world.ui_shell.healing_status.text.contains("F10"),"Healing HUD follows actual input remapping")
    InputMap.action_erase_events("heal")
    for event in bindings: InputMap.action_add_event("heal",event)
    world._toggle_map()
    world.ui_shell._refresh_combat_status(world.player)
    check(not world.ui_shell.healing_status.visible and not world.ui_shell.healing_bar.visible,"Resource feedback is hidden by modal map")
    world.free()
    await process_frame
    for suffix in ["", ".tmp", ".bak"]:
        if FileAccess.file_exists("user://combat_resource_hud.json"+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://combat_resource_hud.json"+suffix))
