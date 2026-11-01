extends "res://scripts/world_greenhouse_vault_playback.gd"
## Actual-input continuation from earned bishop victory to the pilgrimage camp.
const OBSIDIAN_SAVE := "user://test_world_obsidian_earned_route.json"
const OBSIDIAN_SEED := "res://../artifacts/t04_bishop_route/earned_bishop_seed.json"
var spear_approach := false
var spear_cast := false
var spear_cast_frame := -100
var phase_crossing := false
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--obsidian-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--obsidian-restart-proof="))
            if not proof is Dictionary:
                _check(false,"obsidian restart proof must be a dictionary")
                quit(1)
                return
            await _verify_obsidian_restart(proof)
            return
    var bytes:=FileAccess.get_file_as_bytes(OBSIDIAN_SEED)
    _check(not bytes.is_empty(),"normally earned bishop victory seed exists")
    if bytes.is_empty():quit(1);return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(OBSIDIAN_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(OBSIDIAN_SAVE+suffix))
    var file:=FileAccess.open(OBSIDIAN_SAVE,FileAccess.WRITE)
    _check(file!=null,"private obsidian continuation save can be written")
    if file==null:quit(1);return
    file.store_buffer(bytes)
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=OBSIDIAN_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.active_save_point_id=="save_late_runback" and scene.currency_count==297 and scene.demo_complete,"restores actual bishop victory and dome checkpoint")
    for point in [Vector2(5380,794),Vector2(5490,794),Vector2(5710,832),Vector2(6170,832),Vector2(6450,788),Vector2(6740,744),Vector2(7070,792)]:
        if not await _leap(point,35,"normal post-victory eastern exit"):await _finish();return
    await _obsidian_exit()
    if failures>0:await _finish();return
    if not await _walk_without_jump(Vector2(505,2760)):await _finish();return
    var wallet: int=scene.currency_count
    await _world_interact()
    var dialog: ConfirmationDialog=scene.get_node("MapPurchaseDialog")
    _check(dialog.visible,"normal F opens obsidian map shop")
    if not dialog.visible:await _finish();return
    await _key(KEY_ENTER,dialog)
    await _tick(4)
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and scene.currency_count==wallet-50,"normal Enter buys obsidian map with earned fragments")
    trace_ceiling=false
    for point in [Vector2(650,2712),Vector2(1100,2764),Vector2(1450,2708),Vector2(2000,2772),Vector2(2290,2716),Vector2(2590,2768),Vector2(3030,2830),Vector2(3330,2760)]:
        if not await _leap(point,35,"normal lower pilgrimage road"):await _finish();return
        if point.x!=3030 and point.x!=3330 and not await _clear_nearby():await _finish();return
        if point.x==1450:
            if not await _walk_without_jump(Vector2(1650,2708)):await _finish();return
    for point in [Vector2(3470,2652),Vector2(3280,2544),Vector2(3470,2436),Vector2(3280,2328),Vector2(3470,2220),Vector2(3280,2112),Vector2(3460,2004)]:
        if not await _leap(point,999 if point.y==2004 else 20,"normal free shaft ascent"):await _finish();return
    trace_ceiling=true
    if not await _leap(Vector2(3220,1868),999,"free shaft actual upper dock"):await _finish();return
    trace_ceiling=false
    _check(absf(scene.player.position.y-1868)<4,"actual upper gallery floor reached")
    if not await _walk_without_jump(Vector2(2800,1868)):await _finish();return
    if not await _walk_without_jump(Vector2(2510,2608)):await _finish();return
    for point in [Vector2(2150,2496),Vector2(1800,2390),Vector2(1510,2286),Vector2(1300,2178),Vector2(900,2072),Vector2(640,1978),Vector2(300,1910)]:
        spear_approach=point.y==2178
        phase_crossing=point.x==1800
        if not await _leap(point,20,"western pilgrimage camp approach"):await _finish();return
        if spear_approach:
            Input.action_release("skill_1")
            await _tick(35)
            spear_approach=false
        phase_crossing=false
        Input.action_release("aim_down")
        Input.action_release("attack")
        if point.x!=2150 and not await _clear_nearby():await _finish();return
    if not await _walk_without_jump(Vector2(190,1910)):await _finish();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_ch05_lower_loop","normal F rests at actual pilgrimage camp")
    _check(scene.currency_count==287 and scene.inventory_counts.get("obsidian_splinter",0)==4,"normal enemy rewards retain exact 297 minus 50 plus 40 income")
    var initial: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OBSIDIAN_SEED))
    _check(_exact_state(scene.build_system.serialize(),initial.get("build_state",{})),"actual route preserves the earned equipment and consumable build")
    await _inspect_map_without_position()
    if failures==0:
        var earned:=FileAccess.open("res://../artifacts/t04_obsidian_route/earned_camp_seed.json",FileAccess.WRITE)
        _check(earned!=null,"actual rested camp save can be archived")
        if earned!=null:
            earned.store_buffer(FileAccess.get_file_as_bytes(OBSIDIAN_SAVE))
            earned.close()
        if DisplayServer.get_name()!="headless":
            await process_frame
            root.get_texture().get_image().save_png("res://../artifacts/t04_obsidian_route/camp_native.png")
    await _finish()

func _obsidian_exit() -> void:
    steps+=1
    _axis(1)
    for frame in 360:
        await _tick()
        if _transition_busy() or scene.world_passage.active or String(scene.config.id)!="demo_ch04_broken_string_greenhouse":break
        if absf(scene.player.position.x-7140)<30:
            await _world_interact()
            break
    _release()
    if scene.world_passage.active:
        _axis(signf(scene.world_passage.destination_point.x-scene.world_passage.source_point.x))
        for frame in 3600:
            await _tick()
            if not scene.world_passage.active:break
        _release()
    for frame in 2000:
        if not _transition_busy():break
        await process_frame
    await _tick(15)
    print("OBSIDIAN_ENTRY ",scene.player.position)
    _check(String(scene.config.id)=="demo_ch05_obsidian_pilgrim_road","normal greenhouse exit enters obsidian road")

func _finish() -> void:
    _release()
    Input.action_release("skill_1")
    Input.action_release("dash")
    _check(deaths==0,"obsidian continuation survives without death")
    if failures==0:
        print("OBSIDIAN_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"build":scene.build_system.serialize(),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)}))
    print("OBSIDIAN_FINISH_STATE ",JSON.stringify({"position":str(scene.player.position),"hp":scene.player.hp,"energy":scene.player.energy,"wallet":scene.currency_count,"inventory":scene.inventory_counts,"checkpoint":scene.active_save_point_id}))
    print("WORLD_OBSIDIAN_ROUTE steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,damage_events,heals,deaths])
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _verify_obsidian_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=OBSIDIAN_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var previous_pid: Variant=proof.get("pid",0)
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"obsidian checkpoint opens in a different process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"obsidian restart retains the actual region and checkpoint")
    _check(scene.active_save_point_id=="save_ch05_lower_loop" and scene.player.position.distance_to(Vector2(190,1870))<90,"obsidian restart resumes at the actual rested pilgrimage camp")
    _check(scene.currency_count==proof.get("wallet",-1),"obsidian restart retains exact victory income without a duplicate reward")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"obsidian restart retains every exact earned item count")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(not proof.get("charted",{}).is_empty() and chart.charted==proof.get("charted",{}),"obsidian restart retains all actually charted notes")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"obsidian restart retains the paid map and quill")
    _check(not scene.demo_complete and not scene.boss_spawned,"pilgrimage Boss remains normally undefeated")
    _check(scene.inventory_counts.get("silent_mark_greenhouse",0)==1 and scene.inventory_counts.get("thorn_downstrike",0)==1 and scene.player.thorn_downstrike_unlocked,"earned greenhouse victory mark and downstrike remain exact")
    _check(scene.inventory_counts.get("lantern_phase",0)==1,"actually collected camp lantern phase persists once")
    _check(_exact_state(scene.build_system.serialize(),proof.get("build",{})),"restart preserves exact equipped build and remaining consumables")
    await _inspect_map_without_position()
    print("WORLD_OBSIDIAN_ROUTE_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)



func _tick(count: int=1) -> void:
    for unused in count:
        if spear_approach:
            if frames-spear_cast_frame>=3:Input.action_release("skill_1")
            if not spear_cast and scene.player.position.x<1400 and scene.player.position.y>2070 and scene.player.position.y<2180 and scene.player.attack_timer<=0:
                Input.action_press("skill_1")
                spear_cast=true
                spear_cast_frame=frames
                print("OBSIDIAN_SPEAR_AIR_SKILL ",scene.player.position," energy=",scene.player.energy)
                await process_frame
        if phase_crossing:
            if frames-attack_pressed_frame>=3:Input.action_release("attack")
            for foe in get_nodes_in_group("enemy"):
                if not is_instance_valid(foe) or foe.spawn_id!="E05":continue
                if absf(foe.position.x-scene.player.position.x)<85 and scene.player.position.y<foe.position.y and scene.player.attack_timer<=0 and scene.player.hurt_timer<=0 and not Input.is_action_pressed("attack"):
                    Input.action_press("aim_down")
                    Input.action_press("attack")
                    attack_pressed_frame=frames
                    print("OBSIDIAN_PHASE_DOWNSTRIKE ",scene.player.position," enemy=",foe.position)
                    await process_frame
        await super._tick()
        if trace_ceiling and not _transition_busy() and is_instance_valid(scene.player):
            for index in scene.player.get_slide_collision_count():
                var hit: KinematicCollision2D=scene.player.get_slide_collision(index)
                if hit.get_normal().y>0.5 and is_instance_valid(hit.get_collider()):
                    print("OBSIDIAN_CEILING ",JSON.stringify({"position":str(scene.player.position),"normal":str(hit.get_normal()),"collider":str(hit.get_collider().get_path())}))

func _near_foe() -> Node2D:
    if phase_crossing or spear_approach:return null
    return super._near_foe()

func _exact_state(actual: Variant, expected: Variant) -> bool:
    if actual is Dictionary and expected is Dictionary:
        if actual.size()!=expected.size():return false
        for key in actual:
            if not expected.has(key) or not _exact_state(actual[key],expected[key]):return false
        return true
    if actual is Array and expected is Array:
        if actual.size()!=expected.size():return false
        for i in actual.size():
            if not _exact_state(actual[i],expected[i]):return false
        return true
    if typeof(actual) in [TYPE_INT,TYPE_FLOAT] and typeof(expected) in [TYPE_INT,TYPE_FLOAT]:return actual==expected
    return typeof(actual)==typeof(expected) and actual==expected
