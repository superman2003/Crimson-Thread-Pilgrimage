extends SceneTree
## Positioned NPC metadata and supplied offerings are explicit fixtures, not an earned route.
const WORLD_STATE = preload("res://scripts/world_state.gd")
const RETIREMENT = preload("res://scripts/audio_retirement.gd")
const AUDIO = preload("res://scripts/audio_director.gd")
var scene: Node2D
var area: Area2D
var checks := 0
var failures := 0
var save_path := ""

class CountingState extends "res://scripts/world_state.gd":
    var writes := 0
    var host: Node
    var observed: Dictionary = {}
    func write_candidate(candidate: Dictionary, path: String = DEFAULT_PATH) -> bool:
        writes += 1
        if is_instance_valid(host):observed = {"max_energy":host.player.max_energy,"energy":host.player.energy,"spindles":host.inventory_counts.get("energy_spindle",0),"mine_unlocked":host.build_system.state.unlocked_tools.has("mine")}
        return super.write_candidate(candidate, path)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    print("CHECK %s %s" % ["PASS" if ok else "FAIL", label])
    if not ok: failures += 1
func frames(count: int) -> void:
    for i in count:
        await physics_frame
        await process_frame
func same_json(actual: Variant, expected: Variant) -> bool:
    if (actual is int or actual is float) and (expected is int or expected is float):return float(actual) == float(expected)
    if typeof(actual) != typeof(expected):return false
    if actual is Dictionary:
        if actual.size() != expected.size():return false
        for key in actual:
            if not expected.has(key) or not same_json(actual[key],expected[key]):return false
        return true
    if actual is Array:
        if actual.size() != expected.size():return false
        for index in actual.size():
            if not same_json(actual[index],expected[index]):return false
        return true
    return actual == expected
func snapshot() -> Dictionary:
    return {"counts":scene.inventory_counts.duplicate(true),"materials":scene.inventory_materials.duplicate(true),
        "relics":scene.inventory_relics.duplicate(),"tools":scene.inventory_tools.duplicate(),"flags":scene.story_flags.duplicate(true),
        "currency":scene.currency_count,"build":scene.build_system.serialize(),"permanent":scene.build_system.permanent_stats.duplicate(true),
        "profile":scene.player.build_profile.duplicate(true),"applied":scene.applied_build_profile.duplicate(true),
        "hp":scene.player.hp,"energy":scene.player.energy,"max_hp":scene.player.max_hp,"max_energy":scene.player.max_energy,
        "world":scene.world_state.data.duplicate(true)}
func topic(quest: Dictionary, pending: bool = false, confirm: bool = true) -> void:
    area.set_meta("dialogue_topics", {"wish":"fixture request", "quest":quest})
    area.set_meta("world_line_committed", not pending)
    area.set_meta("world_displayed_index",0 if pending else -1)
    area.set_meta("world_displayed_total",1)
    area.set_meta("dialogue_state","first_meet")
    area.set_meta("dialogue_state_indices",{})
    area.set_meta("world_dialogue_result", {"lines":["read fixture line"],"grant_flags":["wish_fixture_dialogue_done"],"reward_flag":"wish_fixture_dialogue_paid","grant_rewards":{"currency":3}})
    scene.ui_shell.dialogue_area = area
    scene.active_overlay = "dialogue"
    scene.dialogue_text_label.visible_characters = -1
    area.global_position=scene.player.global_position
    scene.ui_shell.dialogue.show()
    scene.ui_shell._topic("wish")
    if confirm and is_instance_valid(scene.ui_shell.wish_confirmation) and scene.ui_shell.wish_confirmation.visible:
        scene.ui_shell.wish_confirmation.confirmed.emit()
func run() -> void:
    save_path = "user://wish_atomic_%d.json" % OS.get_process_id()
    var seed := FileAccess.get_file_as_bytes("res://tests/fixtures/quiet_sole_earned_return.json")
    var file := FileAccess.open(save_path,FileAccess.WRITE);file.store_buffer(seed);file.close()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = true;scene.world_save_path = save_path;root.add_child(scene);current_scene = scene
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    check(scene.initial_region_ready,"real World loads exact earned legacy seed")
    check(scene.inventory_counts.get("heart_knot",0) == 2 and scene.player.max_hp == 7,"legacy held heart knots derive actual HP capacity")
    scene.player.hp = 4;scene.player.energy = 43
    area = Area2D.new();area.name = "WishAtomicFixture";area.set_meta("npc_id","wish_atomic_fixture");area.set_meta("kind","npc");scene.add_child(area)
    var state := CountingState.new();state.data = scene.world_state.data.duplicate(true);scene.world_state = state;state.host = scene
    # Authored map-fragment reward, with consumption enabled only for a focused material boundary fixture.
    var quest := {"item":"pollen_wax","consume":true,"reward":"energy_spindle","complete_flag":"wish_fixture_done","accept_flag":"wish_fixture_accepted","thanks":"fixture success"}
    scene.config.wish_board = [{"id":"atomic_fixture","target_flag":"wish_fixture_done","reward_currency":7}]
    for invalid in [0,-1,0.5,1.5]:
        scene.inventory_counts["pollen_wax"] = invalid
        scene.inventory_materials["pollen_wax"] = invalid
        scene.story_flags.erase("wish_fixture_done")
        var rewards_before := int(scene.inventory_counts.get("energy_spindle",0))
        topic(quest)
        check(not scene.story_flags.get("wish_fixture_done",false) and int(scene.inventory_counts.get("energy_spindle",0)) == rewards_before,"invalid offering %s never delivers" % str(invalid))
    # Restore exact pre-transaction fixture, then persist it as the failure disk baseline.
    scene.inventory_counts["pollen_wax"] = 2;scene.inventory_materials["pollen_wax"] = 2
    for key in ["wish_fixture_done","wish_fixture_accepted","wish_claimed_atomic_fixture","wish_fixture_dialogue_done","wish_fixture_dialogue_paid","npc_met_wish_atomic_fixture"]:scene.story_flags.erase(key)
    scene.inventory_counts.erase("energy_spindle");scene.inventory_relics.erase("energy_spindle")
    scene._sync_player_build()
    check(scene._save_world(),"fixture baseline persists")
    var before := snapshot()
    var disk_before := FileAccess.get_file_as_bytes(save_path)
    scene.world_save_failure_injected_for_validation = true
    topic(quest,true)
    check(snapshot() == before,"failed topic preserves inventory categories flags wallet build HP energy and capacities")
    check(FileAccess.get_file_as_bytes(save_path) == disk_before,"failed topic preserves exact disk bytes")
    check(not scene.dialogue_text_label.text.contains("fixture success"),"failure never shows thanks or reward success")
    scene.world_save_failure_injected_for_validation = false
    state.writes = 0
    topic(quest,true)
    check(state.writes == 1,"pending dialogue and wish reward use one candidate write")
    check(state.observed.get("max_energy",0) == 100 and state.observed.get("spindles",-1) == 0 and state.observed.get("energy",0) == 43,"write boundary still observes old live inventory and capacity")
    check(scene.inventory_counts.get("pollen_wax",0) == 1 and scene.inventory_materials.get("pollen_wax",0) == 1,"success consumes exactly one offering in both inventory views")
    check(scene.inventory_counts.get("energy_spindle",0) == 1 and scene.player.max_energy == 120 and scene.player.energy == 43,"only durable reward increases capacity without free energy")
    check(scene.player.hp == 4 and scene.player.max_hp == 7,"wish preserves existing heart capacity and current HP")
    check(scene.currency_count == int(before.currency)+10 and scene.story_flags.get("wish_fixture_done",false) and scene.story_flags.get("wish_claimed_atomic_fixture",false) and scene.story_flags.get("wish_fixture_dialogue_done",false),"completion derived dialogue and board money commit together")
    var restart := WORLD_STATE.new()
    check(restart.read(save_path),"production WorldState reads successful disk")
    check(same_json(restart.data.inventory_counts,scene.inventory_counts) and same_json(restart.data.story_flags,scene.story_flags) and restart.data.currency == scene.currency_count and same_json(restart.data.build_state,scene.build_system.serialize()),"single file restores offerings reward flags money and build")
    var after := snapshot();state.writes = 0
    topic(quest)
    check(snapshot() == after and state.writes == 0,"repeated topic grants nothing and makes no checkpoint write")
    # Sixth testimony exercises the old nested _set_story_flag/_save_world path.
    for i in range(1,6):scene.inventory_counts["testimony_%02d" % i] = 1
    scene.inventory_counts.erase("testimony_06");scene.story_flags.erase("true_ending_testimony_complete")
    scene.inventory_counts["pollen_wax"] = 1;scene.inventory_materials["pollen_wax"] = 1
    var testimony := quest.duplicate(true);testimony.reward = "testimony_06";testimony.complete_flag = "wish_fixture_testimony"
    check(scene._save_world(),"testimony fixture baseline persists")
    var testimony_before := snapshot();var testimony_disk := FileAccess.get_file_as_bytes(save_path)
    scene.world_save_failure_injected_for_validation = true
    topic(testimony)
    check(snapshot() == testimony_before and FileAccess.get_file_as_bytes(save_path) == testimony_disk,"sixth-testimony failure has no nested write or derived flag")
    scene.world_save_failure_injected_for_validation = false;state.writes = 0
    topic(testimony)
    check(state.writes == 1 and scene.story_flags.get("true_ending_testimony_complete",false),"sixth testimony derives chain flag inside the single commit")
    check(restart.read(save_path) and restart.data.story_flags.get("true_ending_testimony_complete",false) and restart.data.inventory_counts.get("testimony_06",0) == 1,"testimony chain and reward durable together")
    check(not scene.inventory_counts.has("pollen_wax") and not scene.inventory_materials.has("pollen_wax"),"consuming final offering removes both category keys")
    var authored: Dictionary = {}
    for npc in scene.config.get("npcs",[]):
        var q: Dictionary = npc.get("dialogue_topics",{}).get("quest",{})
        if String(q.get("reward","")) == "energy_spindle":authored = q.duplicate(true)
    check(not authored.is_empty() and not bool(authored.get("consume",true)),"authored cartographer request is available unchanged")
    scene.inventory_counts["map_fragment"] = 1 # Explicitly supplied quest offering fixture.
    scene.story_flags.erase(String(authored.get("complete_flag","")))
    state.writes = 0
    topic(authored)
    check(state.writes == 1 and scene.inventory_counts.get("map_fragment",0) == 1 and scene.inventory_counts.get("energy_spindle",0) == 2 and scene.player.max_energy == 140 and scene.player.energy == 43,"authored nonconsuming spindle reward commits once and retains offering")
    check(restart.read(save_path) and restart.data.inventory_counts.get("energy_spindle",0) == 2 and restart.data.story_flags.get(String(authored.complete_flag),false),"authored reward restores through production WorldState")
    var unlock_quest := quest.duplicate(true);unlock_quest.reward = "relic_tool_mine";unlock_quest.complete_flag = "wish_fixture_unlock"
    scene.inventory_counts["pollen_wax"] = 1;scene.inventory_materials["pollen_wax"] = 1
    check(not scene.build_system.state.unlocked_tools.has("mine"),"tool reward starts genuinely locked in this fixture")
    check(scene._save_world(),"unlock fixture baseline persists")
    var unlock_before := snapshot();var unlock_disk := FileAccess.get_file_as_bytes(save_path)
    scene.world_save_failure_injected_for_validation = true
    topic(unlock_quest)
    check(snapshot() == unlock_before and FileAccess.get_file_as_bytes(save_path) == unlock_disk,"failed relic reward grants neither item nor build unlock")
    scene.world_save_failure_injected_for_validation = false;state.writes = 0
    topic(unlock_quest)
    check(state.writes == 1 and not state.observed.get("mine_unlocked",true) and scene.build_system.state.unlocked_tools.has("mine"),"build unlock applies only after successful single commit")
    check(restart.read(save_path) and restart.data.build_state.unlocked_tools.has("mine") and restart.data.inventory_counts.get("relic_tool_mine",0) == 1,"relic and unlocked build restore from the same disk file")
    var preview_quest := quest.duplicate(true);preview_quest.complete_flag="wish_preview_fixture";preview_quest.reward="moss_chitin"
    scene.inventory_counts["pollen_wax"]=3;scene.inventory_materials["pollen_wax"]=3
    check(scene._save_world(),"preview baseline persists")
    var preview_before := snapshot();var preview_disk := FileAccess.get_file_as_bytes(save_path);state.writes=0
    topic(preview_quest,true,false)
    var modal=scene.ui_shell.wish_confirmation
    check(modal.visible and modal.get_cancel_button().has_focus(),"delivery opens real native confirmation with cancellation focused")
    var quotation: Dictionary=scene.quote_wish_topic(preview_quest,area)
    check(quotation.ok and quotation.delivered and quotation.summary.contains("× 1") and snapshot()==preview_before and state.writes==0 and FileAccess.get_file_as_bytes(save_path)==preview_disk,"quote exposes exact obligation without changing memory or disk")
    check(scene.ui_shell.has_modal_window(),"native modal suppresses shortcuts without text focus")
    modal.hide()
    check(scene.ui_shell.has_modal_window() and snapshot()==preview_before,"cancel is free and same-frame modal closure remains protected")
    Input.action_press("close_overlay");scene._process(0.0);Input.action_release("close_overlay")
    check(scene.active_overlay=="dialogue","cancel-frame Escape cannot also close the underlying dialogue")
    await process_frame
    state.writes=0 # Background fully read dialogue may commit before this next interaction.
    topic(preview_quest,true,false)
    scene.currency_count+=1
    var changed_before := snapshot()
    modal.confirmed.emit()
    check(state.writes==0 and snapshot()==changed_before and modal.visible and modal.description.text.contains("状态已变化"),"changed source requires another explicit confirmation")
    area.position+=Vector2(1000,0);modal.confirmed.emit()
    check(state.writes==0 and modal.get_ok_button().disabled and snapshot()==changed_before,"moving away rejects the captured interaction")
    area.global_position=scene.player.global_position
    topic(preview_quest,true,false)
    area.set_meta("dialogue_topics",{"quest":quest});modal.confirmed.emit()
    check(state.writes==0 and modal.get_ok_button().disabled,"changed canonical NPC wish cannot use an old captured quest")
    topic(preview_quest,true,false)
    scene.world_save_failure_injected_for_validation=true
    var failure_before := snapshot();var failure_disk := FileAccess.get_file_as_bytes(save_path)
    modal.confirmed.emit()
    check(modal.visible and snapshot()==failure_before and FileAccess.get_file_as_bytes(save_path)==failure_disk and modal.description.text.contains("记录未写入"),"confirmed save failure retains modal and exact ownership for retry")
    scene.world_save_failure_injected_for_validation=false;state.writes=0
    modal.confirmed.emit()
    check(state.writes==1 and not modal.visible and scene.inventory_counts.pollen_wax==2 and scene.story_flags.get("wish_preview_fixture",false),"deliberate retry commits the whole preview exactly once")
    check(restart.read(save_path) and restart.data.inventory_counts.get("pollen_wax",0)==2,"confirmed preview reward restores from actual disk")
    var legacy_disk := FileAccess.get_file_as_bytes(save_path)
    var legacy := quest.duplicate(true);legacy.complete_flag = "wish_legacy_fixture";legacy.reward = "moss_chitin"
    scene.inventory_counts["pollen_wax"] = 1;scene.inventory_materials["pollen_wax"] = 1
    var old_materials: int = scene.inventory_counts.get("moss_chitin",0)
    scene.world_mode = false
    topic(legacy)
    check(scene.story_flags.get("wish_legacy_fixture",false) and scene.inventory_counts.get("moss_chitin",0) == old_materials+1 and not scene.inventory_counts.has("pollen_wax") and FileAccess.get_file_as_bytes(save_path) == legacy_disk,"legacy non-World topic retains consumable reward behavior without a World save")
    scene.world_mode = true
    RETIREMENT.retire_tree(scene);scene.queue_free();await frames(5)
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"World audio ownership retires")
    print("WISH_REWARD_ATOMIC checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
