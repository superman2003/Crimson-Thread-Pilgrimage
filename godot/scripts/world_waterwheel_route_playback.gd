extends "res://scripts/world_damage_route_playback.gd"
## Real-input continuation from an immutable, normally earned checkpoint.
## No grants, position writes or damage suppression; not a fresh-campaign proof.
const WHEEL_SAVE := "user://test_world_waterwheel_route.json"
const EARNED_SEED := "res://../artifacts/t04_pot_fuse/earned_seed.json"
func _run() -> void:
    var bytes := FileAccess.get_file_as_bytes(EARNED_SEED)
    _check(not bytes.is_empty(),"earned route seed exists")
    if bytes.is_empty():
        quit(1)
        return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(WHEEL_SAVE+suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(WHEEL_SAVE+suffix))
    var destination := FileAccess.open(WHEEL_SAVE, FileAccess.WRITE)
    _check(destination!=null,"private replay save can be written")
    if destination==null:
        quit(1)
        return
    destination.store_buffer(bytes)
    destination.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=WHEEL_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.currency_count==24 and scene.inventory_counts.has("double_thread_jump"),"resumes the recorded earned aqueduct checkpoint")
    if not await _walk_without_jump(Vector2(3450,1320)):
        quit(1)
        return
    for point in [Vector2(3820,1480),Vector2(3670,1620),Vector2(3560,1700),Vector2(3180,1740)]:
        await _walk(point,"rain pump atrium route")
        if failures>0:
            _release()
            quit(1)
            return
    if not await _walk_without_jump(Vector2(2725,3320)):
        quit(1)
        return
    await _walk(Vector2(2990,3320),"pump western bank")
    await _tick(3)
    Input.action_press("jump")
    for frame in 180:
        var delta_x: float=3110-scene.player.position.x
        _axis(signf(delta_x) if absf(delta_x)>5 else 0)
        if frame==32:Input.action_release("jump")
        await _tick()
        if scene.player.position.y>3450:break
    _release()
    _check(scene.player.position.y>3450,"normal jump enters the lower exploration shaft")
    for point in [Vector2(3110,3560),Vector2(2945,3800),Vector2(3045,4260)]:
        if not await _walk_without_jump(point):
            quit(1)
            return
    await _walk(Vector2(3070,4260),"overflow upper landing")
    await _recover()
    for point in [Vector2(2870,4410),Vector2(3100,4550)]:
        if not await _walk_without_jump(point):
            quit(1)
            return
    await _walk(Vector2(3180,4550),"overflow lower-bank pot position")
    var target: Node2D
    for candidate in get_nodes_in_group("enemy"):
        if candidate.get("spawn_id")=="E08":target=candidate
    _check(target!=null,"natural route reaches the authored overflow lower-bank foe")
    if target==null:
        quit(1)
        return
    var target_hp: int=target.hp
    var ammo: int=scene.build_system.state.tool_counts.shard
    var hp_before: int=scene.player.hp
    var energy_before: int=scene.player.energy
    var wallet_before: int=scene.currency_count
    _release()
    await _tick(3)
    Input.action_press("tool_cast")
    await process_frame
    await _tick(3)
    Input.action_release("tool_cast")
    var observed: Array=[]
    for frame in 140:
        await _tick()
        if frame%5==0:
            for child in scene.get_children():
                if child.get_script()==preload("res://scripts/player_tool_effect.gd"):
                    observed.append({"frame":frame,"position":[child.position.x,child.position.y],"elapsed":child.elapsed,"landed":child.landed,"warning":child.warning_timer,"target":str(target.position) if is_instance_valid(target) else "defeated"})
    print("T04_OVERFLOW_POT ",JSON.stringify({"ammo_before":ammo,"ammo_after":scene.build_system.state.tool_counts.shard,"hp_before":hp_before,"hp_after":scene.player.hp,"energy_before":energy_before,"energy_after":scene.player.energy,"enemy_hp_before":target_hp,"enemy_hp_after":target.hp if is_instance_valid(target) else 0,"samples":observed}))
    _check(scene.build_system.state.tool_counts.shard==ammo-1,"normal tool input consumes exactly one earned pot")
    _check(not is_instance_valid(target) or target.hp<=0,"a naturally thrown pot defeats the actual overflow ground foe")
    _check(scene.currency_count==wallet_before+8,"the real foe awards its normal eight-fragment reward")
    _check(scene.player.hp==hp_before,"the throw finishes without another injury")
    _check(deaths==0,"earned-checkpoint route completes without death")
    await _walk(Vector2(2870,4410),"overflow return lower step")
    if not await _leap(Vector2(3045,4260),20,"double jump onto overflow upper bank"):
        quit(1)
        return
    for point in [Vector2(3510,4260),Vector2(3735,4260),Vector2(3875,4360),Vector2(4060,4470),Vector2(4140,4470)]:
        await _walk(point,"overflow return to silt vault",false,point.x in [3735.0,3875.0])
        if failures>0:
            quit(1)
            return
    if not await _leap(Vector2(4530,4530),35,"silt chest and leech crossing"):
        quit(1)
        return
    await _walk(Vector2(4635,4530),"western wheel approach")
    if not await _leap(Vector2(5000,4570),42,"live elite wheel crossing"):
        quit(1)
        return
    await _walk(Vector2(5050,4570),"waterwheel control")
    await _world_interact()
    _check(bool(scene.opened_shortcuts.get("ch02_wheel_hub_shortcut",false)),"real F opens the waterwheel return shortcut")
    _check(scene.boss_unlocked,"exploration lever unlocks the smith gate")
    await _recover()
    if not await _leap(Vector2(4620,4478),35,"waterwheel return across live gap"):
        quit(1)
        return
    for point in [Vector2(4575,4478),Vector2(4735,4386),Vector2(4575,4294),Vector2(4735,4202),Vector2(4670,4202),Vector2(4575,4110)]:
        await _walk(point,"spillway return ladder")
    if not await _leap(Vector2(4575,3926),20,"earned double jump above revenge ambush"):
        quit(1)
        return
    for point in [Vector2(4735,3834),Vector2(4520,3742),Vector2(4735,3650),Vector2(4575,3558),Vector2(4735,3466),Vector2(4475,3396),Vector2(4200,3380),Vector2(3960,3350)]:
        if point==Vector2(4520,3742):
            if not await _walk_without_jump(Vector2(4520,3800)):
                quit(1)
                return
        await _walk(point,"upper spillway return",false,point==Vector2(4735,3650))
    if not await _leap(Vector2(3440,3320),35,"pump atrium return"):
        quit(1)
        return
    _check(scene.player.position.distance_to(Vector2(3440,3320))<70,"lower wheel circuit returns to the actual pump atrium")
    for point in [Vector2(3960,3350),Vector2(4200,3380)]:
        await _walk(point,"return from pump to eastern causeway")
    for point in [Vector2(4085,3500),Vector2(4250,3620),Vector2(4380,3760)]:
        if not await _walk_without_jump(point):
            quit(1)
            return
    await _walk(Vector2(4505,3742),"western causeway stair above the spillway",false,true)
    await _walk(Vector2(4735,3650),"early jump over the hanging hammer",false,true)
    if not await _walk_without_jump(Vector2(4920,3760)):
        quit(1)
        return
    if failures>0:
        quit(1)
        return
    await _world_interact()
    _check(scene.active_save_point_id=="save_ch02_forge","normal F rests at the forge shrine after completing the wheel loop")
    _check(scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"normal forge rest restores health and energy")
    _check(deaths==0,"whole wheel circuit and forge approach complete without death")
    if failures==0:
        var forge_seed := FileAccess.open("user://test_world_forge_earned_seed.json",FileAccess.WRITE)
        _check(forge_seed!=null,"earned forge checkpoint can be archived")
        if forge_seed==null:
            quit(1)
            return
        forge_seed.store_buffer(FileAccess.get_file_as_bytes(WHEEL_SAVE))
        forge_seed.close()
        print("WHEEL_FINISH_STATE ",JSON.stringify({"save_point":scene.active_save_point_id,"hp":scene.player.hp,"energy":scene.player.energy,"wallet":scene.currency_count,"deaths":deaths,"damage_events":damage_events,"heals":heals}))
        print("WORLD_FORGE_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_forge_earned_seed.json"))
    print("WORLD_WHEEL_ROUTE steps=%d failures=%d damage_suppression=false earned_checkpoint=true" % [steps,failures])
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _walk_without_jump(target: Vector2) -> bool:
    steps+=1
    _release()
    await _tick(3)
    for frame in 480:
        var player: CharacterBody2D=scene.player
        var delta: Vector2=target-player.global_position
        if absf(delta.x)<16 and absf(delta.y)<35 and player.is_on_floor():
            _release()
            print("WHEEL_ROUTE_WALK reached ",player.position)
            return true
        _axis(signf(delta.x) if absf(delta.x)>8 else 0)
        await _tick()
        if frame%90==89:
            var collisions: Array=[]
            for index in player.get_slide_collision_count():
                var c:=player.get_slide_collision(index)
                collisions.append({"collider":str(c.get_collider().get_path()),"point":str(c.get_position()),"normal":str(c.get_normal())})
            print("WHEEL_ROUTE_WALK pending ",player.position," collisions=",JSON.stringify(collisions))
    _release()
    _check(false,"walk-only route blocked at "+str(scene.player.position))
    return false

func _world_interact() -> void:
    _release()
    await _tick(3)
    Input.action_press("interact")
    await process_frame
    await _tick(3)
    Input.action_release("interact")
    await process_frame
    await _tick(4)

func _leap(target: Vector2, second_frame: int, label: String) -> bool:
    steps+=1
    _release()
    await process_frame
    await process_frame
    await _tick(3)
    for settle in 90:
        if scene.player.hurt_timer<=0 and scene.player.attack_timer<=0 and scene.player.heal_timer<=0:break
        await _tick()
    Input.action_press("jump")
    await process_frame
    for frame in 220:
        var player: CharacterBody2D=scene.player
        var delta_x: float=target.x-player.position.x
        _axis(signf(delta_x) if absf(delta_x)>8 else 0)
        if frame==second_frame-3 or frame==second_frame+30:
            Input.action_release("jump")
            await process_frame
            await process_frame
        if frame==second_frame:
            Input.action_press("jump")
            await process_frame
        await _tick()
        if frame>10 and absf(target.x-player.position.x)<16 and absf(target.y-player.position.y)<50 and player.is_on_floor():
            _release()
            print("WHEEL_LEAP reached ",label," ",player.position)
            return true
        if frame%50==49:print("WHEEL_LEAP pending ",label," ",player.position," velocity=",player.velocity," hp=",player.hp)
        if deaths>0:break
    _release()
    _check(false,"leap blocked: "+label+" at "+str(scene.player.position))
    return false
