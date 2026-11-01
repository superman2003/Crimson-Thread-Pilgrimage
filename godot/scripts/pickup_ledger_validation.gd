extends SceneTree
const STATE=preload("res://scripts/world_state.gd")
const RETIRE=preload("res://scripts/audio_retirement.gd")
const AUDIO=preload("res://scripts/audio_director.gd")
var checks:=0
var failures:=0
var scene: Node
var state: CountingState
const SAVE="user://pickup_ledger.json"
class CountingState extends "res://scripts/world_state.gd":
    var host: Node
    var writes:=0
    var seen: Dictionary={}
    func write_candidate(candidate: Dictionary,path: String=DEFAULT_PATH) -> bool:
        writes+=1;seen={"items":host.inventory_counts.duplicate(true),"collected":host.world_collected_ids.duplicate(true),"flags":host.story_flags.duplicate(true),"dash":host.player.dash_unlocked,"wallet":host.currency_count,"max_hp":host.player.max_hp,"max_energy":host.player.max_energy}
        return super.write_candidate(candidate,path)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1;print("CHECK %s %s" % ["PASS" if ok else "FAIL",label])
    if not ok:failures+=1
func snapshot() -> Dictionary:
    return {"items":scene.inventory_counts.duplicate(true),"flags":scene.story_flags.duplicate(true),"world":scene.world_state.data.duplicate(true),"collected":scene.world_collected_ids.duplicate(true),"wallet":scene.currency_count,"bells":scene.bell_count,"materials":scene.inventory_materials.duplicate(true),"relics":scene.inventory_relics.duplicate(),"tools":scene.inventory_tools.duplicate(),"build":scene.build_system.serialize(),"profile":scene.player.build_profile.duplicate(true),"hp":scene.player.hp,"energy":scene.player.energy,"max_hp":scene.player.max_hp,"max_energy":scene.player.max_energy,"dash":scene.player.dash_unlocked}
func spawn(id: String,item: String,amount: Variant=1,kind: String="item") -> Area2D:
    var point: Vector2=scene.player.global_position+Vector2(0,-40)
    scene._collectible({"id":id,"kind":kind,"item_id":item,"amount":amount,"position":[point.x,point.y],"label":"拾取事务诊断"})
    return scene.get_node_or_null(id) as Area2D
func collect(area: Area2D) -> void:scene._on_collectible_body_entered(scene.player,area)
func press_interact() -> void:
    Input.action_press("interact")
    scene._process(0.0)
    Input.action_release("interact")
func assert_failed_pickup(area: Area2D,label: String) -> void:
    var before:=snapshot();var disk:=FileAccess.get_file_as_bytes(SAVE)
    state.writes=0;scene.world_save_failure_injected_for_validation=true;collect(area)
    check(snapshot()==before and FileAccess.get_file_as_bytes(SAVE)==disk and state.writes==0 and not area.is_queued_for_deletion(),label+" save failure preserves exact inventory flags build resources region IDs and file")
    check(area.get_meta("manual_pickup",false) and String(area.get_meta("interaction_label","")).contains("重试"),label+" failure leaves an explicit interaction retry")
    scene.world_save_failure_injected_for_validation=false
func run() -> void:
    scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=false;scene.world_save_path=SAVE;root.add_child(scene);current_scene=scene
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    scene.set_process(false);scene.player.set_physics_process(false);scene.player.debug_invulnerable=true;scene._close_overlays()
    await preload("res://scripts/resource_purpose_validation.gd").new().run(self,scene,check)
    scene.player.global_position+=Vector2(450,0);scene.player.hp=3;scene.player.energy=43;scene.currency_count=37
    scene._update_room_visit() # Settle this explicitly positioned room before measuring pickup writes.
    state=CountingState.new();state.host=scene;state.data=scene.world_state.data.duplicate(true);scene.world_state=state
    # An explicit whisper fixture proves its flag joins the same pickup checkpoint.
    scene.config["whispers"]=[{"id":"pickup_ledger_fixture","trigger":"pickup_item","item_id":"thread_dash","line":"线在掌心轻轻一紧。"}]
    for bad in [0,-1,true,0.5,NAN,INF]:
        scene.inventory_counts["thread_dash"]=bad
        check(not scene._owns_permanent_item("thread_dash"),"malformed or empty quantity cannot activate permanent power %s" % str(bad))
    scene.inventory_counts.erase("thread_dash");scene._sync_player_abilities()
    check(not scene.player.dash_unlocked and scene._save_world(),"fresh unearned dash stays locked and fixture baseline persists")
    var area:=spawn("pickup_txn_dash","thread_dash")
    check(area!=null and scene.world_pickup_leases.has(area.get_instance_id()),"production factory registers the exact originating pickup instance")
    var before:=snapshot();state.writes=0
    var fake:=Area2D.new();scene.add_child(fake);fake.position=area.position;fake.set_meta("kind","item");fake.set_meta("item_id","thread_dash");fake.set_meta("amount",999)
    collect(fake);check(snapshot()==before and state.writes==0,"forged area without an originating lease cannot grant anything");fake.free()
    var original_position: Vector2=scene.player.global_position;scene.player.position+=Vector2(1000,0);collect(area)
    check(snapshot()==before and state.writes==0,"remote callback cannot collect a distant permanent reward")
    scene.player.global_position=original_position
    var region: String=scene.config.id;scene.config["id"]="other_region";collect(area);scene.config["id"]=region
    check(snapshot()==before and state.writes==0,"stale region callback cannot enter a different region checkpoint")
    area.position+=Vector2(4,0);collect(area);area.position-=Vector2(4,0)
    check(snapshot()==before and state.writes==0,"moved stale actor cannot replace the originating pickup location")
    area.set_meta("amount",999);area.set_meta("item_id","energy_spindle")
    assert_failed_pickup(area,"permanent dash")
    check(not scene.player.dash_unlocked and not scene.story_flags.has("whisper_pickup_ledger_fixture"),"failure opens no permanent power or whisper flag")
    check(scene.interaction_target()==area,"failed reward is the real interaction target for retry")
    press_interact()
    check(state.writes==1 and not state.seen.dash and not state.seen.items.has("thread_dash") and not state.seen.collected.has("pickup_txn_dash"),"single durable pickup observes old ability inventory and region ledger")
    check(scene.player.dash_unlocked and scene.inventory_counts.get("thread_dash",0)==1 and not scene.inventory_counts.has("energy_spindle") and scene.world_collected_ids.get("pickup_txn_dash",false),"source lease grants exact original ability despite altered metadata")
    check(scene.story_flags.get("whisper_pickup_ledger_fixture",false) and scene.player.hp==3 and scene.player.energy==43,"whisper commits with pickup without refilling combat resources")
    collect(area);check(state.writes==1 and scene.inventory_counts.get("thread_dash",0)==1,"same-frame body callback cannot duplicate deliberate interaction pickup")
    var restart:=STATE.new();check(restart.read(SAVE) and restart.data.inventory_counts.get("thread_dash",0)==1 and restart.data.regions[region].collected_ids.get("pickup_txn_dash",false) and restart.data.story_flags.get("whisper_pickup_ledger_fixture",false),"actual disk restores ability whisper and collected identity together")
    var lease_id:=area.get_instance_id();await process_frame
    check(not scene.world_pickup_leases.has(lease_id),"freed actor releases its weak originating lease")
    var old_max_hp: int=scene.player.max_hp
    area=spawn("pickup_txn_heart","heart_knot");assert_failed_pickup(area,"heart capacity");press_interact()
    check(state.writes==1 and state.seen.max_hp==old_max_hp and scene.player.max_hp==old_max_hp+1 and scene.player.hp==3,"permanent HP capacity changes only after one saved pickup and gives no free healing")
    await process_frame
    var old_max_energy: int=scene.player.max_energy
    area=spawn("pickup_txn_spindle","energy_spindle");assert_failed_pickup(area,"energy capacity");press_interact()
    check(state.writes==1 and state.seen.max_energy==old_max_energy and scene.player.max_energy==old_max_energy+20 and scene.player.energy==43,"permanent energy capacity changes only after save and gives no free energy")
    await process_frame
    scene.config["wish_board"]=[{"id":"pickup_testimony_reward","target_flag":"true_ending_testimony_complete","reward_currency":7}]
    var testimony_cash: int=scene.currency_count
    for index in range(1,6):scene.inventory_counts["testimony_%02d" % index]=1
    scene._sync_player_build();check(scene._save_world(),"five testimony fixture baseline persists")
    area=spawn("pickup_txn_testimony","testimony_06");assert_failed_pickup(area,"sixth testimony")
    check(not scene.story_flags.get("true_ending_testimony_complete",false),"failed sixth testimony grants no derived chain flag")
    press_interact()
    check(state.writes==1 and not state.seen.flags.get("true_ending_testimony_complete",false) and scene.story_flags.get("true_ending_testimony_complete",false),"sixth testimony and derived completion use one durable pickup instead of nested saves")
    check(scene.currency_count==testimony_cash+7 and scene.story_flags.get("wish_claimed_pickup_testimony_reward",false) and state.writes==1,"derived wish-board money and claim join the same testimony checkpoint")
    check(restart.read(SAVE) and restart.data.inventory_counts.get("testimony_06",0)==1 and restart.data.story_flags.get("true_ending_testimony_complete",false) and restart.data.regions[region].collected_ids.get("pickup_txn_testimony",false),"disk restores testimony reward derived flag and source identity together")
    await process_frame
    var cash: int=scene.currency_count;var bells: int=scene.bell_count
    area=spawn("pickup_txn_coins","currency",7,"currency");assert_failed_pickup(area,"currency")
    press_interact()
    check(state.writes==1 and state.seen.wallet==cash and scene.currency_count==cash+7 and scene.bell_count==bells and not scene.inventory_counts.has("currency"),"currency pickup saves exact wallet once without item or bell count inflation")
    await process_frame
    before=snapshot();state.writes=0
    var index:=0
    for bad in [0,-1,true,0.5,NAN,INF]:
        var malformed:=spawn("pickup_bad_%d" % index,"heart_knot",bad);index+=1;collect(malformed)
        check(snapshot()==before and state.writes==0 and not malformed.is_queued_for_deletion(),"invalid originating amount cannot grant or save %s" % str(bad))
        malformed.free()
    var fake_player:=Node2D.new();scene.add_child(fake_player);area=spawn("pickup_wrong_body","heart_knot")
    scene._on_collectible_body_entered(fake_player,area)
    check(snapshot()==before and state.writes==0,"a different body cannot collect for the player")
    fake_player.free();area.free()
    var lease_count: int=scene.world_pickup_leases.size();scene._collectible({"id":"pickup_txn_dash","kind":"item","item_id":"thread_dash","position":[0,0]})
    check(scene.get_node_or_null("pickup_txn_dash")==null and scene.world_pickup_leases.size()==lease_count,"already-collected identity is not spawned or leased again")
    RETIRE.retire_tree(scene);scene.free();await process_frame;AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"pickup fixture releases actual audio ownership")
    print("PICKUP_LEDGER checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
