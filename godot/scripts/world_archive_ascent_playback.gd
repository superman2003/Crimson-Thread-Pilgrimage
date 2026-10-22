extends "res://scripts/world_waterwheel_route_playback.gd"
## Damage-enabled archive ascent from the normally earned #183 hook save.
## Real input, no grants or position writes; not a fresh campaign or human playtest.
const SALT_SAVE := "user://test_world_archive_ascent.json"
const HOOK_SEED := "res://../artifacts/t04_smith_hud/earned_hook_seed.json"
var trace_ceiling := false
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--archive-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--archive-restart-proof="))
            if not proof is Dictionary:
                _check(false,"archive restart proof must be a dictionary")
                quit(1)
                return
            await _verify_archive_restart(proof)
            return
    var bytes:=FileAccess.get_file_as_bytes(HOOK_SEED)
    _check(not bytes.is_empty(),"normally earned hook seed exists")
    if bytes.is_empty():
        quit(1)
        return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(SALT_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(SALT_SAVE+suffix))
    var file:=FileAccess.open(SALT_SAVE,FileAccess.WRITE)
    _check(file!=null,"private archive replay save can be written")
    if file==null:
        quit(1)
        return
    file.store_buffer(bytes)
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=SALT_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.demo_complete and scene.inventory_counts.has("echo_hook") and scene.currency_count==124,"restores the earned smith defeat, hook and wallet")
    await _world_interact()
    _check(scene.player.energy==scene.player.max_energy,"normal forge rest refills the earned checkpoint")
    await _walk(Vector2(5100,3760),"forge eastern ledge")
    if not await _leap(Vector2(5330,3820),35,"walk into the already cleared smith court"):
        await _finish()
        return
    await _walk(Vector2(5880,3820),"cleared arena eastern bank")
    if not await _leap(Vector2(6120,3780),35,"outfall bank"):
        await _finish()
        return
    if not await _walk_without_jump(Vector2(6360,3780)):
        await _finish()
        return
    if not await _leap(Vector2(6520,3820),999,"single jump toward the contract lift"):
        await _finish()
        return
    steps+=1
    _axis(1)
    for frame in 240:
        await _tick()
        if _transition_busy() or String(scene.config.id)!="demo_ch02_rain_foundry_canal":break
    _release()
    for frame in 2000:
        if not _transition_busy():break
        await process_frame
    await _tick(15)
    _check(String(scene.config.id)=="demo_ch03_saltwhite_archive" and scene.player.position.distance_to(Vector2(300,2580))<90,"actual chapter exit reaches the archive entry")
    if failures>0:
        await _finish()
        return
    await _walk(Vector2(510,2620),"salt librarian map counter")
    var wallet: int=scene.currency_count
    _check(not JOURNAL.owned(scene.story_flags,String(scene.config.id)),"archive map has not been granted")
    await _world_interact()
    var dialog: ConfirmationDialog=scene.get_node("MapPurchaseDialog")
    _check(dialog.visible and dialog.get_ok_button().has_focus(),"normal F opens the affordable archive map shop")
    if not dialog.visible:
        await _finish()
        return
    await _key(KEY_ENTER,dialog)
    await _tick(4)
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and scene.currency_count==wallet-40,"actual Enter buys the archive map for forty earned fragments")
    _check(JOURNAL.has_quill(scene.story_flags),"previously purchased quill remains available")
    for point in [Vector2(700,2570),Vector2(1050,2620),Vector2(1430,2556),Vector2(1760,2612),Vector2(2090,2548),Vector2(1930,2442),Vector2(1740,2350),Vector2(1640,2240),Vector2(1440,2240),Vector2(1640,2240)]:
        await _walk(point,"archive candle return",false,point.x in [1440.0,1640.0])
        if failures>0:
            await _finish()
            return
    if not await _clear_nearby():
        await _finish()
        return
    if not await _leap(Vector2(1935,2184),20,"cross from the candle landing"):
        await _finish()
        return
    await _walk(Vector2(2060,2184),"duel on the eastern candle walk")
    for point in [Vector2(2320,2158),Vector2(2555,2130),Vector2(2785,2032),Vector2(2577,1926),Vector2(2865,1812)]:
        if not await _leap(point,999 if point.y in [2158.0,2130.0] else 20,"atrium second-floor ascent"):
            await _finish()
            return
    if not await _leap(Vector2(2530,1782),35,"west reading ledge"):
        await _finish()
        return
    if not await _leap(Vector2(2150,1752),35,"western reading gallery"):
        await _finish()
        return
    await _walk(Vector2(2030,1752),"quiet reader's gallery")
    await _walk(Vector2(2290,1752),"reading gallery return bank")
    if not await _leap(Vector2(2530,1782),35,"return to the atrium second floor"):
        await _finish()
        return
    if not await _leap(Vector2(2865,1812),35,"atrium east landing"):
        await _finish()
        return
    trace_ceiling=true
    for point in [Vector2(3135,1712),Vector2(3380,1622),Vector2(3160,1512),Vector2(3365,1400)]:
        if point.y==1512:
            if not await _walk_without_jump(Vector2(3338,1622)):
                await _finish()
                return
        if not await _leap(point,27 if point.y==1512 else 20,"atrium third-floor ascent"):
            await _finish()
            return
    trace_ceiling=false
    if not await _walk_without_jump(Vector2(3450,1400)):
        await _finish()
        return
    if not await _leap(Vector2(3710,1356),20,"jump onto the inverse-page gallery"):
        await _finish()
        return
    if not await _clear_nearby():
        await _finish()
        return
    if not await _leap(Vector2(4090,1290),35,"jump over the gallery clapper and gap"):
        await _finish()
        return
    await _walk(Vector2(4140,1290),"inverse page stepping stone")
    if not await _leap(Vector2(4310,1350),999,"single jump onto the eastern gallery"):
        await _finish()
        return
    await _walk(Vector2(4525,1350),"eastern gallery duel")
    if not await _leap(Vector2(4750,1298),999,"crest approach shelf"):
        await _finish()
        return
    trace_ceiling=true
    for point in [Vector2(4985,1194),Vector2(4815,1088),Vector2(5007,982),Vector2(4830,880)]:
        if not await _leap(point,999 if point.y in [982.0,880.0] else 35,"crest bridge ascent"):
            await _finish()
            return
    trace_ceiling=false
    await _walk(Vector2(4700,880),"crest bridge shrine")
    await _world_interact()
    _check(scene.active_save_point_id=="save_ch03_lower_loop","normal F rests at the actual crest bridge shrine")
    _check(scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"crest shrine restores health and energy normally")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(chart.pending.is_empty() and not chart.charted.is_empty(),"purchased quill charts the actual archive ascent at rest")
    await _inspect_map_without_position()
    if failures==0:
        var seed:=FileAccess.open("user://test_world_salt_crest_earned_seed.json",FileAccess.WRITE)
        _check(seed!=null,"normally earned crest checkpoint can be archived")
        if seed==null:
            await _finish()
            return
        seed.store_buffer(FileAccess.get_file_as_bytes(SALT_SAVE))
        seed.close()
        print("SALT_CREST_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_salt_crest_earned_seed.json"))
    await _finish()

func _tick(count: int=1) -> void:
    for unused in count:
        await super._tick()
        if trace_ceiling and frames%10==0:
            for index in scene.player.get_slide_collision_count():
                var hit: KinematicCollision2D=scene.player.get_slide_collision(index)
                if hit.get_normal().y>0.5:
                    print("SALT_CEILING ",JSON.stringify({"position":str(scene.player.position),"normal":str(hit.get_normal()),"collider":str(hit.get_collider().get_path())}))

func _finish() -> void:
    _release()
    _check(deaths==0,"archive ascent completes without death")
    if failures==0:
        print("ARCHIVE_ASCENT_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)}))
    print("WORLD_ARCHIVE_ASCENT steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,damage_events,heals,deaths])
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 and deaths==0 else 1)

func _clear_nearby() -> bool:
    _release()
    for frame in 360:
        var foe:=_near_foe()
        if foe==null:
            combat_enabled=false
            _release()
            await _recover()
            return true
        var dx: float=foe.position.x-scene.player.position.x
        _axis(signf(dx) if absf(dx)>95 or scene.player.facing!=signi(dx) else 0)
        combat_enabled=true
        await _tick()
        if scene.player.hp<=0:break
    combat_enabled=false
    _release()
    _check(false,"live candle duel did not finish")
    return false

func _verify_archive_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=SALT_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var previous_pid: Variant=proof.get("pid",0)
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"archive checkpoint opens in a different process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"restart retains the actual region and rested checkpoint")
    _check(scene.player.position.distance_to(Vector2(4700,840))<90,"new process resumes at the crest shrine")
    _check(scene.currency_count==proof.get("wallet",-1),"restart retains exact income after the archive map payment")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"restart retains every exact earned item count")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(not proof.get("charted",{}).is_empty() and chart.charted==proof.get("charted",{}),"restart retains all actual charted archive notes")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"restart retains the paid map and quill")
    _check(not scene.boss_unlocked and not scene.demo_complete,"reaching the crest does not grant the unopened archive Boss route")
    await _inspect_map_without_position()
    print("WORLD_ARCHIVE_ASCENT_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)
