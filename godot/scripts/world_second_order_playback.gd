extends "res://scripts/world_damage_route_playback.gd"
## Fresh second-order campaign: only production Input, no grants/position writes.
## Parent _run/old seeds are never called. Initial probe has no gameplay input.
const RETIREMENT = preload("res://scripts/audio_retirement.gd")
const AUDIO = preload("res://scripts/audio_director.gd")
var order_stage := "probe"
var order_output := ""
var order_save := ""
func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--order-stage="):order_stage = arg.trim_prefix("--order-stage=")
        if arg.begins_with("--output="):order_output = arg.trim_prefix("--output=")
    order_save = "user://second_order_%d.json" % OS.get_process_id()
    _check(order_stage in ["probe","first_lamp"],"explicit bounded fresh-start stage")
    _check(not FileAccess.file_exists(order_save),"private new-game save does not exist")
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = order_save
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _tick(15)
    var initial := snapshot()
    print("SECOND_ORDER_INITIAL "+JSON.stringify(initial))
    if not order_output.is_empty():write_json("initial.json",initial)
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
    if failures==0:
        var raw:=FileAccess.get_file_as_bytes(order_save)
        var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
        var proof:=snapshot();proof["save_sha256"]=hash.finish().hex_encode();proof["save_bytes"]=raw.size();proof["origin"]="fresh new game, actual input to first C1 lamp"
        print("SECOND_ORDER_EARNED "+JSON.stringify(proof))
        if not order_output.is_empty():
            var file:=FileAccess.open(order_output.path_join("earned_checkpoint.json"),FileAccess.WRITE);file.store_buffer(raw);file.close()
            write_json("checkpoint_proof.json",proof)
    await finish_order()
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
