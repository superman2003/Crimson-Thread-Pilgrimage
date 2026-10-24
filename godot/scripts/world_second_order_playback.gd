extends "res://scripts/world_damage_route_playback.gd"
## Fresh second-order campaign: only production Input, no grants/position writes.
## Parent _run/old seeds are never called. Initial probe has no gameplay input.
const RETIREMENT = preload("res://scripts/audio_retirement.gd")
const AUDIO = preload("res://scripts/audio_director.gd")
var order_stage := "probe"
var order_output := ""
var order_save := ""
var order_input := ""
var order_input_sha := ""
var order_input_proof := ""
var parent_proof: Dictionary = {}
func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--order-stage="):order_stage = arg.trim_prefix("--order-stage=")
        if arg.begins_with("--output="):order_output = arg.trim_prefix("--output=")
        if arg.begins_with("--input-checkpoint="):order_input = arg.trim_prefix("--input-checkpoint=")
        if arg.begins_with("--input-sha="):order_input_sha = arg.trim_prefix("--input-sha=")
        if arg.begins_with("--input-proof="):order_input_proof = arg.trim_prefix("--input-proof=")
    order_save = "user://second_order_%d.json" % OS.get_process_id()
    _check(order_stage in ["probe","first_lamp","canal_aqueduct"],"explicit bounded fresh-start stage")
    _check(not FileAccess.file_exists(order_save),"private new-game save does not exist")
    var continuing := order_stage == "canal_aqueduct"
    if continuing:
        var raw := FileAccess.get_file_as_bytes(order_input)
        var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
        _check(not raw.is_empty() and hash.finish().hex_encode()==order_input_sha,"continuation uses exact preceding earned checkpoint bytes")
        parent_proof = JSON.parse_string(FileAccess.get_file_as_string(order_input_proof))
        _check(String(parent_proof.get("save_sha256",""))==order_input_sha and int(parent_proof.get("pid",-1))!=OS.get_process_id(),"source proof and independent PID match the real preceding stage")
        if failures>0:await finish_order();return
        var file := FileAccess.open(order_save,FileAccess.WRITE);file.store_buffer(raw);file.close()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = continuing
    scene.world_save_path = order_save
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _tick(15)
    var initial := snapshot()
    print("SECOND_ORDER_INITIAL "+JSON.stringify(initial))
    if not order_output.is_empty():write_json("initial.json",initial)
    if continuing:
        _check(scene.initial_region_ready and String(scene.config.id)==String(parent_proof.region) and scene.active_save_point_id==String(parent_proof.checkpoint),"new PID restores actual source region and normal shrine")
        _check(scene.currency_count==int(parent_proof.wallet) and same_json(scene.inventory_counts,parent_proof.inventory) and same_json(scene.build_system.serialize(),parent_proof.build),"new PID restores earned wallet inventory and complete build without grants")
        _check(scene.player.hp==int(parent_proof.hp) and scene.player.energy==int(parent_proof.energy) and not scene.player.debug_invulnerable,"source HP and thread restore with damage enabled")
        if failures>0:await finish_order();return
        await canal_aqueduct()
        await finish_order()
        return
    _check(scene.initial_region_ready and String(scene.config.id)=="demo_ch01_moss_bell_court","new game starts in original C1")
    _check(scene.currency_count==0 and scene.player.hp==5 and scene.player.max_hp==5 and scene.player.energy==100 and scene.player.max_energy==100,"unmodified fresh HP thread limits and zero wallet")
    _check(scene.inventory_counts=={"thread_burst":1,"menders_right":1,"moss_lens":1},"exact original starting tools and relic only")
    _check(not scene.player.debug_invulnerable and not SHOP_RUNTIME.shows_position(scene) and not SHOP_RUNTIME.owns_tool(scene,"compass"),"damage enabled with no navigation position or compass")
    for ability in scene.WORLD_ABILITIES:_check(int(scene.inventory_counts.get(ability,0))==0,"no pre-granted permanent ability "+String(ability))
    if failures>0 or order_stage=="probe":await finish_order();return
    for point in [Vector2(410,3400),Vector2(640,3452),Vector2(870,3532),Vector2(1130,3612),Vector2(1420,3692),Vector2(1710,3752)]:
        await _walk(point,"fresh C1 drainage to first authored lamp")
        if failures>0:await finish_order();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_first_bell","real F rests at original first bell lamp")
    _check(FileAccess.file_exists(order_save),"normal shrine produced actual save bytes")
    if failures==0:export_checkpoint("fresh new game, actual input to first C1 lamp")
    await finish_order()
func canal_aqueduct() -> void:
    await _walk(Vector2(1790,3752),"normal first-lamp departure to rain pipe")
    if failures>0:return
    await _interact("moss_rain_pipe","demo_ch02_rain_foundry_canal",Vector2(330,720))
    if failures>0:return
    for point in [Vector2(620,812),Vector2(960,880),Vector2(1350,836),Vector2(1700,920)]:
        await _walk(point,"second-order C2 normal repair route")
        if failures>0:return
    _check(int(scene.inventory_counts.get("silk_wall_grip",0))==1,"wall grip comes from actual authored pickup")
    print("SECOND_ORDER_MISSED_MAP_SELLER "+JSON.stringify({"wallet":scene.currency_count,"map_owned":JOURNAL.owned(scene.story_flags,String(scene.config.id)),"quill_owned":SHOP_RUNTIME.owns_tool(scene,"quill"),"reason":"continue the original route without buying the optional map on the first pass"}))
    for point in [Vector2(2040,1000),Vector2(2320,1080),Vector2(2540,1160),Vector2(2730,1160),Vector2(2990,1240)]:
        await _walk(point,"second-order C2 to actual aqueduct shrine",false,point.x==2730.0)
        if failures>0:return
    await _world_interact()
    _check(scene.active_save_point_id=="save_ch02_aqueduct" and scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"actual aqueduct F rest preserves natural income and refills by shrine only")
    _check(not int(scene.inventory_counts.get("double_thread_jump",0))>0 and not int(scene.inventory_counts.get("lantern_phase",0))>0,"later-region abilities remain unearned at the first canal shrine")
    if failures==0:export_checkpoint("actual C1 lamp bytes -> original rain passage -> authored wall-grip pickup -> actual aqueduct shrine")
func export_checkpoint(origin: String) -> void:
    var raw:=FileAccess.get_file_as_bytes(order_save)
    var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
    var proof:=snapshot();proof["save_sha256"]=hash.finish().hex_encode();proof["save_bytes"]=raw.size();proof["origin"]=origin
    proof["source_save_sha256"]=order_input_sha
    proof["source_pid"]=int(parent_proof.get("pid",-1))
    print("SECOND_ORDER_EARNED "+JSON.stringify(proof))
    if not order_output.is_empty():
        var file:=FileAccess.open(order_output.path_join("earned_checkpoint.json"),FileAccess.WRITE);file.store_buffer(raw);file.close()
        write_json("checkpoint_proof.json",proof)
func same_json(actual: Variant,expected: Variant) -> bool:
    if (actual is int or actual is float) and (expected is int or expected is float):return float(actual)==float(expected)
    if typeof(actual)!=typeof(expected):return false
    if actual is Dictionary:
        if actual.size()!=expected.size():return false
        for key in actual:
            if not expected.has(key) or not same_json(actual[key],expected[key]):return false
        return true
    if actual is Array:
        if actual.size()!=expected.size():return false
        for index in actual.size():
            if not same_json(actual[index],expected[index]):return false
        return true
    return actual==expected
func snapshot() -> Dictionary:
    return {"pid":OS.get_process_id(),"stage":order_stage,"region":String(scene.config.get("id","")),"position":[scene.player.position.x,scene.player.position.y],
        "authored_start":scene.config.get("player_start",[]),"hp":scene.player.hp,"max_hp":scene.player.max_hp,"energy":scene.player.energy,"max_energy":scene.player.max_energy,
        "wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"flags":scene.story_flags.duplicate(true),"build":scene.build_system.serialize(),
        "checkpoint":scene.active_save_point_id,"damage_enabled":not scene.player.debug_invulnerable,"deaths":deaths,"damage_events":damage_events,"heals":heals,
        "private_user_dir":OS.get_user_data_dir(),"appdata":OS.get_environment("APPDATA")}
func write_json(name: String,data: Dictionary) -> void:
    var file:=FileAccess.open(order_output.path_join(name),FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close()
func finish_order() -> void:
    _release()
    if is_instance_valid(scene):
        if not order_output.is_empty():write_json("terminal.json",snapshot())
        RETIREMENT.retire_tree(root)
        scene.queue_free()
        for i in 5:await physics_frame;await process_frame
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    _check(await RETIREMENT.drain(self),"owned audio playback retires after stage")
    print("SECOND_ORDER_STAGE stage=%s steps=%d physics_frames=%d damage_events=%d heals=%d deaths=%d failures=%d" % [order_stage,steps,frames,damage_events,heals,deaths,failures])
    quit(1 if failures else 0)
