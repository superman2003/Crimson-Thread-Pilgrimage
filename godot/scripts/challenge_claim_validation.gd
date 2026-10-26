extends "res://scripts/optional_challenges_validation.gd"
const RETIRE=preload("res://scripts/audio_retirement.gd")
const AUDIO=preload("res://scripts/audio_director.gd")
class CountingState extends "res://scripts/world_state.gd":
    var writes:=0
    var host: Node
    var observed: Dictionary={}
    func write_candidate(candidate: Dictionary,path: String=DEFAULT_PATH) -> bool:
        writes+=1;observed={"wallet":host.currency_count,"flags":host.story_flags.duplicate(true),"items":host.inventory_counts.duplicate(true)}
        return super.write_candidate(candidate,path)
func press_interact() -> void:
    Input.action_press("interact")
    scene._process(0.0)
    Input.action_release("interact")
func economy() -> Dictionary:
    return {"wallet":scene.currency_count,"items":scene.inventory_counts.duplicate(true),"materials":scene.inventory_materials.duplicate(true),"tools":scene.inventory_tools.duplicate(),"relics":scene.inventory_relics.duplicate(),"build":scene.build_system.serialize(),"hp":scene.player.hp,"energy":scene.player.energy,"defeated":scene.enemy_defeated}
func run() -> void:
    wipe_save();await boot(false)
    var id:="ch01_crown_nook_trial"
    var spec:=challenge(id);check(not spec.is_empty(),"actual authored challenge supplies its own reward plan")
    var pending: String=scene._challenge_pending_flag(spec)
    var clear: String=spec.clear_flag
    var evidence: String=spec.reward.item_id
    var shrine: Area2D=scene.get_node(String(spec.shrine.id))
    scene.player.global_position=shrine.global_position;scene.player.debug_invulnerable=true
    scene.player.set_physics_process(false);scene.set_process(false);scene.current_room_id=String(spec.room_id)
    scene.player.hp=3;scene.player.energy=43;scene.currency_count=110
    var state:=CountingState.new();state.host=scene;state.data=scene.world_state.data.duplicate(true);scene.world_state=state
    check(scene._save_world(),"explicit challenge fixture baseline persists")
    state.writes=0;var before:=economy();var disk:=FileAccess.get_file_as_bytes(SAVE)
    scene._grant_optional_challenge_reward(spec)
    check(economy()==before and state.writes==0 and not scene.story_flags.get(clear,false),"calling an authored reward without victory proof cannot grant it")
    var fake:=spec.duplicate(true);fake.reward.currency=9999
    scene._grant_optional_challenge_reward(fake)
    check(economy()==before and state.writes==0,"altered reward dictionary cannot replace canonical authored amounts")
    scene._start_optional_challenge(spec)
    check(scene.active_challenge_id==id and not scene.challenge_alive_ids.is_empty(),"real shrine challenge registers actual living enemies")
    scene.world_save_failure_injected_for_validation=true
    for spawn in spec.enemies:
        var foe:=challenge_enemy(String(spawn.id))
        check(is_instance_valid(foe),"actual challenge foe exists for the victory fixture")
        for unused in 60:
            if not scene.challenge_alive_ids.has(String(spawn.id)):break
            if is_instance_valid(foe) and not foe.dying:foe.take_hit(99,int(foe.direction))
            await tick(2)
    check(scene.active_challenge_id.is_empty() and scene.challenge_alive_ids.is_empty(),"last actual foe completes the attempt even during storage failure")
    check(not is_instance_valid(scene.challenge_arena_lock_body),"earned victory releases the arena while claim is pending")
    check(economy()==before and not scene.story_flags.get(clear,false) and scene.story_flags.get(pending,false),"failed reward retains only earned pending proof with no economic or completion grant")
    check(FileAccess.get_file_as_bytes(SAVE)==disk and String(shrine.get_meta("label")).contains("胜利待记录"),"failed claim leaves exact disk and a visible retry entrance")
    var enemies_before:=get_nodes_in_group("enemy").size()
    scene._start_optional_challenge(spec)
    check(scene.active_challenge_id.is_empty() and get_nodes_in_group("enemy").size()==enemies_before and economy()==before,"pending victory retries the claim without spawning another fight")
    scene.world_save_failure_injected_for_validation=false
    check(scene._save_world(),"ordinary successful save preserves pending victory proof")
    var saved:=STATE.new();check(saved.read(SAVE) and saved.data.story_flags.get(pending,false) and not saved.data.story_flags.get(clear,false) and saved.data.currency==110,"disk stores pending proof without reward or false clear")
    RETIRE.retire_tree(scene);scene.free();await tick(2)
    await boot(true)
    spec=challenge(id);shrine=scene.get_node(String(spec.shrine.id))
    scene.player.global_position=shrine.global_position;scene.player.debug_invulnerable=true
    scene.player.set_physics_process(false);scene.set_process(false);scene.current_room_id=String(spec.room_id)
    scene.player.hp=3;scene.player.energy=43
    check(scene.story_flags.get(pending,false) and String(shrine.get_meta("label")).contains("胜利待记录"),"production World restart restores pending victory and retry label")
    scene._update_room_visit() # Settle explicit restart placement before counting reward writes.
    before=economy();disk=FileAccess.get_file_as_bytes(SAVE)
    state=CountingState.new();state.host=scene;state.data=scene.world_state.data.duplicate(true);scene.world_state=state
    check(scene.interaction_target()==shrine,"pending shrine is an actual interaction target after World restart")
    scene.world_save_failure_injected_for_validation=true;press_interact()
    check(economy()==before and FileAccess.get_file_as_bytes(SAVE)==disk and scene.story_flags.get(pending,false),"failed post-restart retry retains exact reward ownership")
    scene.world_save_failure_injected_for_validation=false;state.writes=0
    enemies_before=get_nodes_in_group("enemy").size();press_interact()
    check(state.writes==1 and state.observed.wallet==110 and not state.observed.flags.get(clear,false) and not state.observed.items.has(evidence),"retry writes one checkpoint observing old wallet flag and evidence")
    check(scene.currency_count==140 and scene.inventory_counts.get(evidence,0)==1 and scene.inventory_materials.get("moss_chitin",0)==int(before.materials.get("moss_chitin",0))+2,"single durable claim grants exact authored money evidence and material")
    check(scene.story_flags.get(clear,false) and not scene.story_flags.has(pending) and scene.active_challenge_id.is_empty() and get_nodes_in_group("enemy").size()==enemies_before,"claim replaces pending proof with clear without respawning foes")
    check(scene.player.hp==3 and scene.player.energy==43 and scene.enemy_defeated==int(before.defeated),"claim does not refill combat resources or advance region kill quotas")
    check(saved.read(SAVE) and saved.data.currency==140 and saved.data.inventory_counts.get(evidence,0)==1 and saved.data.story_flags.get(clear,false) and not saved.data.story_flags.has(pending),"production disk restores complete reward and cleared pending proof together")
    var after:=economy();scene._activate_challenge_shrine(shrine);scene._grant_optional_challenge_reward(spec)
    check(economy()==after and state.writes==1,"repeated shrine and late direct grant cannot pay twice")
    RETIRE.retire_tree(scene);scene.free();await process_frame;AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"all replaced challenge Worlds release real audio")
    print("CHALLENGE_CLAIM checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
