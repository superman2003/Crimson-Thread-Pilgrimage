extends "res://scripts/skill_branches_validation.gd"
const CH03="demo_ch03_saltwhite_archive"
const STATE=preload("res://scripts/world_state.gd")
const RETIRE=preload("res://scripts/audio_retirement.gd")
const AUDIO_DIRECTOR=preload("res://scripts/audio_director.gd")
class CountingState extends "res://scripts/world_state.gd":
    var writes:=0
    var host: Node
    var observed_complete:=false
    func write_candidate(candidate: Dictionary,path: String=DEFAULT_PATH) -> bool:
        writes+=1;observed_complete=bool(host.story_flags.get("skill_practiced_cleave",false))
        return super.write_candidate(candidate,path)
func run() -> void:
    scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=false;scene.world_save_path=SAVE;root.add_child(scene);current_scene=scene
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    build=scene.build_system
    await travel(CH01,practice_spot("cleave")+Vector2(-90,-20));await equip_skill("cleave")
    var rack:=await face_rack("cleave",90)
    var state:=CountingState.new();state.data=scene.world_state.data.duplicate(true);state.host=scene;scene.world_state=state
    check(scene.get_skill_practice_progress("cleave").count==0 and not scene.get_skill_practice_progress("unknown").known,"only actually learned skills have a progress record")
    player.last_skill_cast="cleave";player.last_skill_cast_msec=Time.get_ticks_msec()
    rack.take_hit(1,1)
    check(scene.get_skill_practice_progress("cleave").count==0,"ordinary melee damage cannot borrow a recent skill identity")
    check(await cast(),"first independent actual cleave is accepted")
    check(scene.get_skill_practice_progress("cleave").count==1,"actual skill contact advances exactly one step")
    var serial: int=player.last_skill_cast_serial
    for unused in 3:rack.take_hit(1,1);rack.report_skill_contact(player,"cleave",serial)
    check(scene.get_skill_practice_progress("cleave").count==1,"repeated damage and callbacks from one cast cannot complete training")
    rack._refresh_practice_caption()
    check(String(rack.get_node("PracticeCaption").text).contains("1 / 3"),"production rack caption displays actual independent-cast progress")
    var outsider:=Node2D.new();scene.add_child(outsider)
    rack.take_hit(1,1);rack.report_skill_contact(outsider,"cleave",serial+1)
    check(scene.get_skill_practice_progress("cleave").count==1,"foreign effect owner cannot train the player's skill")
    outsider.free()
    scene._on_skill_practice_hit("cleave",null,serial+1)
    scene._on_skill_practice_hit("ward",rack,serial+1,"guard")
    check(scene.get_skill_practice_progress("cleave").count==1,"missing or mismatched canonical rack reports rejected")
    await face_rack("cleave",90);check(await cast(),"second actual cleave is accepted")
    check(scene.get_skill_practice_progress("cleave").count==2,"second distinct accepted cast advances one step")
    check(scene._save_world(),"partial-training baseline persists without granting completion")
    var disk:=FileAccess.get_file_as_bytes(SAVE)
    var counts: Dictionary=scene.inventory_counts.duplicate(true);var cash: int=scene.currency_count
    scene.world_save_failure_injected_for_validation=true
    await face_rack("cleave",90);check(await cast(),"third actual cast reaches the save boundary")
    check(not scene.story_flags.get("skill_practiced_cleave",false) and scene.get_skill_practice_progress("cleave").pending_save and FileAccess.get_file_as_bytes(SAVE)==disk,"failed training record never unlocks artisan directions or changes disk")
    rack._refresh_practice_caption()
    check(String(rack.get_node("PracticeCaption").text).contains("记录待写入") and scene.inventory_counts==counts and scene.currency_count==cash,"failure caption explains retry without granting items or currency")
    scene.world_save_failure_injected_for_validation=false;state.writes=0
    await face_rack("cleave",90);check(await cast(),"new valid cast retries pending completion")
    check(state.writes==1 and not state.observed_complete and scene.story_flags.get("skill_practiced_cleave",false),"completion publishes only after one durable write observing the old flag")
    var restart:=STATE.new();check(restart.read(SAVE) and restart.data.story_flags.get("skill_practiced_cleave",false),"actual production save restores completed training")
    check(scene.get_skill_practice_progress("cleave").count==3 and int(build.state.skill_levels.cleave)==0,"trained skill gains no free branch purchase")
    state.writes=0;rack.take_hit(1,1);rack.report_skill_contact(player,"cleave",player.last_skill_cast_serial)
    check(state.writes==0,"late completed contact makes no extra save")
    # Actual ranged effect must carry its emitting skill and cast sequence.
    await travel(CH03,practice_spot("needle")+Vector2(-100,-20));await equip_skill("needle");await face_rack("needle",100)
    check(await cast(),"actual ranged needle is accepted")
    check(scene.get_skill_practice_progress("needle").count==1,"projectile hit attributes practice to its captured originating cast")
    scene.player.global_position=Vector2(-1000,-1000);scene.player._settle_practice_energy()
    check(scene.player.practice_energy==0,"training does not retain free practice energy outside the racks")
    RETIRE.retire_tree(scene);scene.free();await process_frame;AUDIO_DIRECTOR._stream_cache.clear();AUDIO_DIRECTOR._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"practice fixture retires actual World audio")
    print("PRACTICE_COACH checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
