extends SceneTree
const STATE=preload("res://scripts/world_state.gd")
const RECALL=preload("res://scripts/death_recall.gd")
const AUDIO=preload("res://scripts/audio_director.gd")
const RETIRE=preload("res://scripts/audio_retirement.gd")
var checks:=0
var failures:=0
class CountingState extends "res://scripts/world_state.gd":
    var writes:=0
    var host: Node
    var seen: Dictionary={}
    func write_candidate(candidate: Dictionary,path: String=DEFAULT_PATH) -> bool:
        writes+=1;seen={"currency":host.currency_count,"cache":host.world_state.data.death_cache.duplicate(true)}
        return super.write_candidate(candidate,path)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1;print("CHECK %s %s" % ["PASS" if ok else "FAIL",label])
    if not ok:failures+=1
func snapshot(scene: Node) -> Dictionary:
    return {"wallet":scene.currency_count,"world":scene.world_state.data.duplicate(true),"build":scene.build_system.serialize(),"hp":scene.player.hp,"energy":scene.player.energy,"inventory":scene.inventory_counts.duplicate(true)}
func run() -> void:
    var path:="user://return_knot_transaction.json"
    var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes("res://tests/fixtures/quiet_sole_earned_return.json"));file.close()
    var scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=true;scene.world_save_path=path;root.add_child(scene);current_scene=scene
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    scene.set_process(false);scene.player.set_physics_process(false);scene.player.hp=3;scene.player.energy=43
    var state:=CountingState.new();state.host=scene;state.data=scene.world_state.data.duplicate(true);scene.world_state=state
    scene.currency_count=101;scene.last_safe_ground=scene.player.global_position;scene.death_recorded=false
    scene._record_death_cache()
    check(state.writes==1 and state.seen.currency==101,"death writes one detached checkpoint before publishing lost currency")
    check(scene.currency_count==51 and scene.world_state.data.death_cache.currency==50,"odd currency splits exactly once")
    var restart:=STATE.new();check(restart.read(path) and restart.data.currency==51 and restart.data.death_cache.currency==50,"one file restores both wallet and knot")
    scene._record_death_cache();check(state.writes==1 and scene.currency_count==51,"same death cannot charge twice")
    var disk:=FileAccess.get_file_as_bytes(path)
    scene.currency_count=80;scene.death_recorded=false;scene.world_save_failure_injected_for_validation=true
    scene._record_death_cache()
    check(scene.currency_count==40 and scene.world_state.data.death_cache.currency==40 and FileAccess.get_file_as_bytes(path)==disk,"death storage failure retains coherent explicitly unsaved field snapshot")
    scene.world_save_failure_injected_for_validation=false
    check(scene._save_world() and restart.read(path) and restart.data.currency==40 and restart.data.death_cache.currency==40,"normal respawn save can retry the full death snapshot")
    var knot: Area2D=scene.death_cache_area
    var before:=snapshot(scene);disk=FileAccess.get_file_as_bytes(path);state.writes=0
    var fake:=Area2D.new();scene.add_child(fake);fake.position=knot.position
    scene._recover_death_cache(fake)
    check(snapshot(scene)==before and state.writes==0,"noncanonical area cannot collect the stored knot")
    fake.free()
    scene.player.position+=Vector2(1000,0);scene._recover_death_cache(knot)
    check(snapshot(scene)==before and state.writes==0,"remote physical pickup rejected")
    scene.player.position=knot.global_position
    knot.position+=Vector2(5,0);scene._recover_death_cache(knot)
    check(snapshot(scene)==before and state.writes==0,"moved stale knot cannot claim current position record")
    knot.position-=Vector2(5,0)
    scene.world_save_failure_injected_for_validation=true;scene._recover_death_cache(knot)
    check(snapshot(scene)==before and FileAccess.get_file_as_bytes(path)==disk and scene.death_cache_area==knot and not knot.is_queued_for_deletion(),"failed field claim preserves wallet knot build HP energy and disk")
    scene.world_save_failure_injected_for_validation=false;scene._recover_death_cache(knot)
    check(state.writes==1 and state.seen.currency==40 and state.seen.cache.currency==40,"field claim writes once while observing old owners")
    check(scene.currency_count==80 and scene.world_state.data.death_cache.is_empty() and scene.death_cache_area==null,"successful field claim publishes money and cache clear together")
    scene._recover_death_cache(knot);check(state.writes==1 and scene.currency_count==80,"late duplicate field callback cannot pay again")
    check(restart.read(path) and restart.data.currency==80 and restart.data.death_cache.is_empty(),"field claim reload cannot duplicate currency")
    check(RECALL.bosses_defeated({"boss_down_fake":true,"boss_down_ch99":true,"boss_down_ch01":false})==0,"only the six canonical defeated guardians unlock recall")
    for chapter in ["ch01","ch02","ch03"]:scene.story_flags["boss_down_"+chapter]=true
    var cache: Dictionary={"region_id":String(scene.config.id),"position":[scene.player.position.x,scene.player.position.y],"currency":99}
    scene.world_state.capture_global({"death_cache":cache});scene._spawn_death_cache();scene._save_world()
    var shrine: Area2D
    for child in scene.get_children():
        if child is Area2D and child.get_meta("kind","")=="save_point":shrine=child;break
    check(is_instance_valid(shrine),"real World supplies an actual shrine")
    scene.player.position=shrine.global_position+Vector2(2000,0)
    check(not RECALL.offer(scene),"recall offer cannot be opened away from a shrine")
    scene.player.position=shrine.global_position
    check(RECALL.offer(scene),"three guardians and actual shrine admit explicit recall")
    var dialog: ConfirmationDialog=scene.get_node(RECALL.DIALOG)
    check(dialog.get_cancel_button().has_focus() and scene.ui_shell.has_modal_window(),"walking back is default and native modal blocks polled shortcuts")
    state.writes=0;scene.currency_count+=1;before=snapshot(scene)
    dialog.confirmed.emit()
    check(dialog.visible and dialog.dialog_text.contains("已变化") and state.writes==0 and snapshot(scene)==before,"changed wallet refreshes price before another confirmation")
    scene.player.position+=Vector2(1000,0);dialog.confirmed.emit()
    check(dialog.visible and state.writes==0 and snapshot(scene)==before,"walking away rejects captured shrine confirmation")
    scene.player.position=shrine.global_position;scene.world_save_failure_injected_for_validation=true;disk=FileAccess.get_file_as_bytes(path)
    dialog.confirmed.emit()
    check(dialog.visible and snapshot(scene)==before and FileAccess.get_file_as_bytes(path)==disk,"failed recall preserves all owners and keeps retry available")
    scene.world_save_failure_injected_for_validation=false;dialog.confirmed.emit()
    check(state.writes==1 and scene.currency_count==140 and scene.world_state.data.death_cache.is_empty() and not dialog.visible,"deliberate retry commits floor sixty percent and clear in one write")
    check(state.seen.currency==81 and state.seen.cache.currency==99 and restart.read(path) and restart.data.currency==140 and restart.data.death_cache.is_empty(),"remote write sees old owners and disk restores the same result")
    check(scene.player.hp==3 and scene.player.energy==43 and not RECALL.recall(scene).ok,"recall never refills resources or pays again")
    RETIRE.retire_tree(scene);scene.free();await process_frame;AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"fixture releases actual World audio")
    print("RETURN_KNOT_TRANSACTION checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
