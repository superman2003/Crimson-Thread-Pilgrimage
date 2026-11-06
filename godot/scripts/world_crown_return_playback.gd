extends "res://scripts/world_second_order_playback.gd"
## Continue the accepted alternate-order front shrine with production Input only.
## The published G-J controller and evidence remain unchanged.
var return_resonance_actions:=0
const RETURN_GATE:="upgrade_crown_resonance_3_action_gate"

func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--order-stage="):order_stage=arg.trim_prefix("--order-stage=")
        if arg.begins_with("--output="):order_output=arg.trim_prefix("--output=")
        if arg.begins_with("--input-checkpoint="):order_input=arg.trim_prefix("--input-checkpoint=")
        if arg.begins_with("--input-sha="):order_input_sha=arg.trim_prefix("--input-sha=")
        if arg.begins_with("--input-proof="):order_input_proof=arg.trim_prefix("--input-proof=")
    _check(order_stage in ["crown_return_resonance","crown_resonance_workshop","earned_restore"],"explicit bounded earned crown return stage")
    order_save="user://second_order_%d.json" % OS.get_process_id()
    _check(not FileAccess.file_exists(order_save),"return PID has a private unused save")
    var raw:=FileAccess.get_file_as_bytes(order_input)
    var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
    _check(not raw.is_empty() and hash.finish().hex_encode()==order_input_sha,"return uses exact accepted preceding shrine bytes")
    parent_proof=JSON.parse_string(FileAccess.get_file_as_string(order_input_proof))
    _check(String(parent_proof.get("save_sha256",""))==order_input_sha and int(parent_proof.get("pid",-1))!=OS.get_process_id(),"return source proof matches exact bytes and a different engine PID")
    if failures>0:await finish_order();return
    var file:=FileAccess.open(order_save,FileAccess.WRITE);file.store_buffer(raw);file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true;scene.world_save_path=order_save
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    return_connect_observers()
    await _tick(15)
    var initial:=snapshot()
    print("SECOND_ORDER_INITIAL "+JSON.stringify(initial));write_json("initial.json",initial)
    for key in ["region","checkpoint","wallet","inventory","build","flags","hp","max_hp","energy","max_energy"]:
        _check(same_json(initial[key],parent_proof[key]),"return restores earned source field "+key)
    _check(not scene.player.debug_invulnerable and not SHOP_RUNTIME.shows_position(scene),"return keeps damage enabled without a position aid")
    if failures==0 and order_stage=="crown_return_resonance":await crown_return_resonance()
    elif failures==0 and order_stage=="crown_resonance_workshop":await crown_resonance_workshop()
    elif failures==0 and order_stage=="earned_restore":
        _check(scene.player.crown_resonance_unlocked==bool(scene.inventory_counts.get("crown_resonance",0)),"independent World restores the actually earned resonance controller ability")
        if bool(scene.story_flags.get("action_gate_"+RETURN_GATE,false)):
            _check(not scene.locked_gate_bodies.has(RETURN_GATE),"independent production restore physically omits the paid R gate")
    await finish_order()

func return_connect_observers() -> void:
    if not scene.player.ability_action.is_connected(order_ability_observed):scene.player.ability_action.connect(order_ability_observed)
    for actor in get_nodes_in_group("enemy"):
        if not actor.died.is_connected(order_crown_defeated):actor.died.connect(order_crown_defeated)

func order_ability_observed(id: String,origin: Vector2,direction: Vector2) -> void:
    super.order_ability_observed(id,origin,direction)
    if id=="crown_resonance":return_resonance_actions+=1

func crown_resonance_workshop() -> void:
    _check(scene.active_save_point_id=="save_hidden_upper_respite" and scene.player.crown_resonance_unlocked and scene.inventory_counts.get("crown_resonance",0)==1,"own K restores its actually earned resonance at the hidden shrine")
    _check(not bool(scene.story_flags.get("action_gate_"+RETURN_GATE,false)) and int(scene.inventory_counts.get("upgrade_crown_resonance_3_record",0))==0,"workshop action gate and its evidence remain unearned")
    if failures>0:return
    if not await order_leap(Vector2(2124,1496),999,"earned resonance visit reaches the original free cage"):return
    if not await order_crown_cage():return
    if not await order_walk_only(Vector2(2960,700)):return
    if not await return_portal("upgrade_crown_resonance_3_access_a",Vector2(2960,700),Vector2(5900,530)):return
    if not await order_walk_only(Vector2(6050,570)):return
    _check(scene.locked_gate_bodies.has(RETURN_GATE),"possessing resonance alone leaves the actual workshop blocker installed")
    _axis(1)
    await _tick(30)
    var blocked_position: Vector2=scene.player.position
    _check(scene.player.is_on_wall() and blocked_position.x<6130 and blocked_position.x>6090 and not bool(scene.story_flags.get("action_gate_"+RETURN_GATE,false)),"ordinary right movement physically stops at the still-closed resonance gate")
    print("CROWN_RETURN_GATE_BLOCKED ",JSON.stringify({"frame":frames,"position":str(blocked_position),"energy":scene.player.energy,"wall":scene.player.is_on_wall()}))
    _release();await _tick(3)
    if failures>0:return
    await order_capture("crown_gate_blocked")
    var before_energy: int=scene.player.energy
    Input.action_press("crown_resonance");await process_frame;await _tick(2)
    Input.action_release("crown_resonance");await _tick(2)
    var action: Dictionary={"pid":OS.get_process_id(),"position":str(scene.player.position),"energy_before":before_energy,"energy_after":scene.player.energy,"observed_actions":return_resonance_actions,"gate_before":false,"gate_after":bool(scene.story_flags.get("action_gate_"+RETURN_GATE,false))}
    write_json("resonance_action.json",action)
    print("CROWN_RETURN_GATE_RECONNECTED ",JSON.stringify(action))
    _check(return_resonance_actions==1 and scene.player.energy==before_energy-20 and action.gate_after and not scene.locked_gate_bodies.has(RETURN_GATE),"one actual R action pays twenty thread and permanently reconnects its authored gate")
    if failures>0:return
    await order_capture("crown_gate_paid_R")
    for settle in 120:
        if scene.player._can_start_action():break
        await _tick()
    if not await order_walk_only(Vector2(6150,570)):return
    if not await order_leap(Vector2(6225,480),999,"real jump onto the workshop terminal dais"):return
    if not await order_leap(Vector2(6290,390),999,"real jump to the optional maintenance record gallery"):return
    if not await order_walk_only(Vector2(6354,390)):return
    var expected: Dictionary=parent_proof.inventory.duplicate(true)
    expected.upgrade_crown_resonance_3_record=1
    _check(same_json(scene.inventory_counts,expected) and scene.currency_count==int(parent_proof.wallet)+75,"actual gallery body pickups grant only the authored record and seventy-five currency")
    if failures>0:return
    await order_capture("crown_workshop_gallery_earned")
    if not await order_walk_only(Vector2(5900,570)):return
    if not await return_portal("upgrade_crown_resonance_3_access_b",Vector2(5900,570),Vector2(2960,660)):return
    _check(bool(scene.story_flags.get("action_gate_"+RETURN_GATE,false)) and not scene.locked_gate_bodies.has(RETURN_GATE),"normal workshop exit keeps the real R unlock after region content replacement")
    if not await order_leap(Vector2(2508,700),20,"normal return jump over the westbound old-city mouth after workshop exit"):return
    _check(not _transition_busy(),"workshop return jump avoids the old-city walking passage")
    if failures>0:return
    if not await return_call_upper_cage():return
    if not await order_walk_only(Vector2(2124,700)):return
    if not await order_crown_cage(false):return
    if not await order_leap(Vector2(1965,1400),20,"normal return from the workshop cage to the hidden light"):return
    if not await order_precise_interact("save_hidden_upper_respite",1965):return
    _check(same_json(scene.inventory_counts,expected) and scene.currency_count==int(parent_proof.wallet)+75 and same_json(scene.build_system.serialize(),parent_proof.build),"normal shrine save keeps exact workshop rewards and the original build")
    _check(scene.player.hp==6 and scene.player.energy==100 and order_crown_defeats.is_empty() and return_resonance_actions==1 and not scene.boss_spawned,"only normal shrine refill follows one real R action; workshop has no fabricated combat or Boss victory")
    if failures==0:export_checkpoint("own earned K resonance -> original optional workshop F -> actual blocked movement and paid R gate -> physical gallery rewards -> original exit F and hidden shrine F")

func return_call_upper_cage() -> bool:
    if not await order_walk_only(Vector2(2210,700)):return false
    steps+=1;_release();await _tick(5)
    var lift: Node2D=null
    for candidate in scene.cave_lifts:
        if String(candidate.name)=="ch06_cave_lift":lift=candidate
    _check(lift!=null and absf(scene.player.position.y-700)<8 and scene.player.is_on_floor(),"normal workshop return waits on the actual upper landing")
    if lift==null or failures>0:return false
    _check(not lift.moving and absf(lift.basket.position.y-lift.bottom_y)<1,"region content replacement leaves the original cage at its lower landing")
    _check(scene.interaction_target()==null,"normal F from the upper dock can call the original cage")
    if failures>0:return false
    print("CROWN_RETURN_CAGE_CALL_BEFORE ",JSON.stringify({"player":str(scene.player.position),"basket":str(lift.basket.position)}))
    await _world_interact()
    for frame in 240:
        await _tick()
        if not lift.moving and absf(lift.basket.position.y-lift.top_y)<1:
            _check(absf(scene.player.position.y-700)<8 and scene.player.is_on_floor(),"actual F call arrives while the player stays on the upper dock")
            print("CROWN_RETURN_CAGE_CALL_AFTER ",JSON.stringify({"player":str(scene.player.position),"basket":str(lift.basket.position)}))
            return failures==0
    _check(false,"normal upper-dock call did not bring the original cage");return false

func return_portal(id: String,standing: Vector2,arrival: Vector2) -> bool:
    steps+=1;_release()
    for frame in 240:
        var dx: float=standing.x-scene.player.position.x
        Input.action_release("move_left");Input.action_release("move_right")
        if absf(dx)>1:Input.action_press("move_right" if dx>0 else "move_left",clampf(absf(dx)/60.0,0.08,1.0))
        await _tick()
        if absf(dx)<2 and absf(scene.player.velocity.x)<8:
            _release();await _tick(15)
            var target: Area2D=scene.interaction_target()
            if target!=null and String(target.name)==id:
                print("CROWN_RETURN_PORTAL ",JSON.stringify({"id":id,"position":str(scene.player.position)}))
                await _interact(id,"demo_ch06_silent_crown_core",arrival)
                return_connect_observers()
                return failures==0
    _release();_check(false,"normal F could not select authored workshop portal "+id);return false

func crown_return_resonance() -> void:
    _check(scene.active_save_point_id=="save_late_runback" and scene.inventory_counts.get("testimony_06",0)==1,"own J starts at the front shrine after actually earning the sixth testimony")
    _check(scene.currency_count==193 and not scene.player.crown_resonance_unlocked and not scene.player.bell_guard_unlocked and not scene.player.dash_unlocked,"J has its original wallet and no unearned resonance guard or dash")
    _check(bool(scene.story_flags.get("elite_first_demo_ch06_silent_crown_core_E08",false)) and bool(scene.world_collected_ids.get("col_branch_echo_moss",false)),"previous elite bonus and hidden reward are already consumed")
    if failures>0:return
    if not await order_leap(Vector2(2370,3040),20,"actual return over the gap from the front shrine"):return
    if not await order_walk_only(Vector2(2270,3040)):return
    if not await order_leap(Vector2(2570,2900),35,"normal return jump to the lower-loop light"):return
    if not await order_precise_interact("save_ch06_lower_loop",2570):return
    if not await return_west_ascent():return
    _check(scene.currency_count==int(parent_proof.wallet)+48,"six respawned guards pay only their normal rewards on this return")
    var expected: Dictionary=parent_proof.inventory.duplicate(true)
    expected.crown_echo_shard=int(expected.crown_echo_shard)+6
    _check(same_json(scene.inventory_counts,expected),"return does not replay elite or hidden first-clear materials")
    if failures>0:return
    if not await order_leap(Vector2(2124,1496),999,"normal descent onto the free cage on the return visit"):return
    if not await order_crown_cage():return
    if not await order_walk_only(Vector2(3050,700)):return
    _check(scene.inventory_counts.get("crown_resonance",0)==1 and scene.player.crown_resonance_unlocked and scene.world_collected_ids.get("upgrade_obtain_crown_resonance",false),"actual forecourt body pickup earns crown resonance without pressing F on the nearby workshop")
    print("CROWN_RETURN_RESONANCE_PICKUP ",JSON.stringify({"frame":frames,"position":str(scene.player.position),"wallet":scene.currency_count,"inventory":scene.inventory_counts}))
    if failures>0:return
    await order_capture("crown_resonance_actually_earned")
    if not await order_precise_interact("npc_first_pilgrim_echo",3050):return
    _check(scene.active_overlay=="dialogue","actual F opens the first pilgrim conversation after the real pickup")
    Input.action_press("close_overlay");await _tick(3);Input.action_release("close_overlay");await _tick(3)
    if not await order_leap(Vector2(2508,700),20,"normal jump back over the directional old-city passage mouth"):return
    _check(not _transition_busy() and String(scene.config.id)=="demo_ch06_silent_crown_core","return jump stays outside the original westbound old-city passage")
    if failures>0:return
    if not await order_walk_only(Vector2(2124,700)):return
    if not await order_crown_cage(false):return
    if not await order_leap(Vector2(1965,1400),20,"actual return from the cage to the earned hidden shrine"):return
    if not await order_precise_interact("save_hidden_upper_respite",1965):return
    expected.crown_resonance=1
    _check(scene.active_save_point_id=="save_hidden_upper_respite" and same_json(scene.inventory_counts,expected) and scene.currency_count==241,"normal hidden-shrine save records only the earned resonance and six returning guards")
    _check(same_json(scene.build_system.serialize(),parent_proof.build) and scene.player.hp==6 and scene.player.energy==100,"original two loadouts and normal shrine refill remain intact")
    _check(order_crown_defeats==["E07","E13","E08","E12","E09","E10"] and not scene.boss_spawned,"return observes each actual guard death and leaves the final Boss untouched")
    if failures==0:export_checkpoint("own J front shrine -> physical west return and original cage -> actual forecourt crown resonance pickup and pilgrim F -> original hidden shrine F")

func return_west_ascent() -> bool:
    if not await order_walk_only(Vector2(2490,2900)):return false
    if not await order_leap(Vector2(2260,2794),24,"return through the original first west stair"):return false
    if not await order_walk_only(Vector2(2150,2794)):return false
    if not await order_crown_side_up(Vector2(2290,2578),2115):return false
    if not await order_clear():return false
    if not await order_leap(Vector2(2500,2470),20,"return to the right upper west step"):return false
    if not await order_walk_only(Vector2(2455,2470)):return false
    if not await order_leap(Vector2(2160,2360),20,"return over the original western high walk"):return false
    if not await order_clear():return false
    if not await order_crown_flyer("E13",2160):return false
    if not await order_walk_only(Vector2(2005,2360)):return false
    if not await order_leap(Vector2(1750,2252),20,"return into the obsidian echo"):return false
    if not await order_clear():return false
    if not await order_walk_only(Vector2(1585,2252)):return false
    if not await order_crown_combat_leap(Vector2(1390,2140),"return obsidian banner foothold","E12"):return false
    if not await order_clear():return false
    if not await order_walk_only(Vector2(1430,2140)):return false
    if not await order_crown_narrow_step():return false
    if not await order_walk_only(Vector2(1540,2030)):return false
    await order_settled_recover()
    if not await order_leap(Vector2(1260,1916),20,"return jump over the real salt false floor"):return false
    if not await order_crown_salt_punish():return false
    if not await order_clear():return false
    if not await order_walk_only(Vector2(1260,1916)):return false
    if not await order_crown_vertical(Vector2(1430,1700)):return false
    if not await order_crown_flyer("E10"):return false
    if not await order_walk_only(Vector2(1495,1700)):return false
    if not await order_leap(Vector2(1770,1590),20,"return salt-to-moss ascent"):return false
    if not await order_clear():return false
    if not await order_leap(Vector2(1965,1400),20,"return to the previously earned hidden moss light"):return false
    return await order_precise_interact("save_hidden_upper_respite",1965)
