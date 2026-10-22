extends "res://scripts/world_archive_ascent_playback.gd"
## Input-only continuation from the normally earned #190 crest checkpoint.
## Damage enabled; no grants or position writes; not a fresh campaign or human playtest.
const LOWER_SAVE := "user://test_world_archive_lower_route.json"
const CREST_SEED := "res://../artifacts/w02_salt_crest/earned_crest_seed.json"
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--archive-lower-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--archive-lower-restart-proof="))
            if not proof is Dictionary:
                _check(false,"lower archive restart proof must be a dictionary")
                quit(1)
                return
            await _verify_lower_restart(proof)
            return
    var bytes:=FileAccess.get_file_as_bytes(CREST_SEED)
    _check(not bytes.is_empty(),"earned crest seed exists")
    if bytes.is_empty():quit(1);return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(LOWER_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(LOWER_SAVE+suffix))
    var file:=FileAccess.open(LOWER_SAVE,FileAccess.WRITE)
    _check(file!=null,"private lower archive save can be written")
    if file==null:quit(1);return
    file.store_buffer(bytes)
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=LOWER_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.active_save_point_id=="save_ch03_lower_loop" and scene.currency_count==124,"restores actual earned crest checkpoint")
    await _walk(Vector2(4920,880),"crest eastern takeoff")
    if not await _leap(Vector2(5200,922),35,"eastern archive scribe landing"):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _leap(Vector2(5540,986),35,"cross the crest clapper to the chute lip"):await _finish();return
    for point in [Vector2(5665,1300),Vector2(5478,1618),Vector2(5360,1748)]:
        if not await _walk_without_jump(point):await _finish();return
    if not await _clear_nearby():await _finish();return
    await _walk(Vector2(5340,1748),"archive testimony shelf")
    await _world_interact()
    _check(scene.inventory_counts.has("testimony_03"),"normal F collects the archive testimony")
    if not await _leap(Vector2(5140,1876),999,"land beyond the false shelf"):await _finish();return
    if not await _leap(Vector2(4880,2008),999,"jump the false shelf onto the lower stacks"):await _finish();return
    if not await _clear_nearby():await _finish();return
    for point in [Vector2(5000,2172),Vector2(4740,2338),Vector2(5000,2492),Vector2(5180,2606)]:
        if not await _walk_without_jump(point):await _finish();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_late_runback","normal F rests at the index passage shrine")
    if not await _leap(Vector2(4765,2640),35,"cross the upper shelf to the index western bank"):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _leap(Vector2(4585,2680),999,"single jump across the vault gap"):await _finish();return
    await _walk(Vector2(4390,2680),"normal bell shell guard pickup")
    if not scene.inventory_counts.has("bell_guard"):await _world_interact()
    _check(scene.inventory_counts.has("bell_guard") and scene.player.bell_guard_unlocked,"actual vault visit earns bell shell guard")
    await _walk(Vector2(4555,2680),"wax seal lever")
    await _world_interact()
    _check(bool(scene.opened_shortcuts.get("ch03_salt_gate_shortcut",false)) and scene.boss_unlocked,"normal lever opens the salt shortcut and Boss route")
    await _walk(Vector2(4590,2680),"vault return bank")
    if not await _leap(Vector2(4765,2640),999,"single jump back across the vault gap"):await _finish();return
    trace_ceiling="--archive-lower-trace" in OS.get_cmdline_user_args()
    if not await _leap(Vector2(4995,2640),55,"cross the spore chest to the index eastern bank"):await _finish();return
    if not await _clear_nearby():await _finish();return
    steps+=1
    _axis(1)
    await _tick(20)
    _release()
    await _tick(3)
    _check(scene.player.position.x>5038 and scene.player.position.x<5044,"real input approaches the actual index shrine step")
    if not await _leap(Vector2(5180,2606),999,"single jump onto the index shrine platform"):await _finish();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.hp==scene.player.max_hp,"normal final index rest")
    await _inspect_map_without_position()
    if failures==0:
        var seed:=FileAccess.open("user://test_world_salt_index_earned_seed.json",FileAccess.WRITE)
        _check(seed!=null,"earned index checkpoint can be archived")
        if seed!=null:
            seed.store_buffer(FileAccess.get_file_as_bytes(LOWER_SAVE))
            seed.close()
            print("SALT_INDEX_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_salt_index_earned_seed.json"))
    await _finish()

func _finish() -> void:
    _release()
    _check(deaths==0,"lower archive continuation survives")
    if failures==0:
        print("ARCHIVE_LOWER_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)}))
    print("ARCHIVE_LOWER_FINISH ",JSON.stringify({"position":str(scene.player.position),"hp":scene.player.hp,"energy":scene.player.energy,"wallet":scene.currency_count,"inventory":scene.inventory_counts,"checkpoint":scene.active_save_point_id,"shortcut":scene.opened_shortcuts}))
    print("WORLD_ARCHIVE_LOWER steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,damage_events,heals,deaths])
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _tick(count: int=1) -> void:
    for unused in count:
        var target:=_near_foe()
        if target!=null and is_instance_valid(scene.player):
            var dx: float=target.position.x-scene.player.position.x
            if absf(dx)<110 and scene.player.hurt_timer<=0 and scene.player.facing==signi(dx) and frames%20==0:
                Input.action_press("attack")
                attack_pressed_frame=frames
                print("ARCHIVE_LOWER_AIR_ATTACK ",JSON.stringify({"position":str(scene.player.position),"enemy":str(target.position),"enemy_hp":target.hp,"floor":scene.player.is_on_floor()}))
        await super._tick()
        if trace_ceiling and frames%10==0:
            for index in scene.player.get_slide_collision_count():
                var hit: KinematicCollision2D=scene.player.get_slide_collision(index)
                if absf(hit.get_normal().x)>0.5:
                    print("ARCHIVE_LOWER_WALL ",JSON.stringify({"position":str(scene.player.position),"normal":str(hit.get_normal()),"collider":str(hit.get_collider().get_path())}))

func _verify_lower_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=LOWER_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var previous_pid: Variant=proof.get("pid",0)
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"index checkpoint opens in a different process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"restart retains the actual region and index checkpoint")
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.position.distance_to(Vector2(5180,2566))<90,"new process actually resumes at the index shrine")
    _check(scene.currency_count==proof.get("wallet",-1),"index restart retains exact normal combat income")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"index restart retains every exact earned item count")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(not proof.get("charted",{}).is_empty() and chart.charted==proof.get("charted",{}),"index restart retains all actual charted archive notes")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"index restart retains paid map and quill")
    _check(scene.inventory_counts.get("bell_guard",0)==1 and scene.player.bell_guard_unlocked and scene.inventory_counts.get("testimony_03",0)==1,"restart retains the actual guard pickup and manually collected testimony once")
    _check(bool(scene.opened_shortcuts.get("ch03_salt_gate_shortcut",false)) and scene.boss_unlocked and not scene.demo_complete,"restart retains the actual lever while the archive Boss remains undefeated")
    await _inspect_map_without_position()
    print("WORLD_ARCHIVE_LOWER_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)
