extends SceneTree
const STATE=preload("res://scripts/world_state.gd")
const INSPECT=preload("res://scripts/save_inspector.gd")
const RETIRE=preload("res://scripts/audio_retirement.gd")
const AUDIO=preload("res://scripts/audio_director.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1;print("CHECK %s %s" % ["PASS" if ok else "FAIL",label])
    if not ok:failures+=1
func put(path: String, text: String) -> void:
    var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
func data(cash: int) -> Dictionary:
    var result:=STATE.fresh_data();result.currency=cash;result.current_region="demo_ch01_moss_bell_court"
    result.world_location=preload("res://scripts/world_coordinates.gd").location(result.current_region,Vector2.ZERO)
    return result
func wait_replaced(old: Node) -> Node:
    for unused in 3:await process_frame;await physics_frame
    var scene:=current_scene
    if scene==old:check(false,"replacement happened");return scene
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    return scene
func run() -> void:
    var path:="user://save_desk_fixture.json"
    var target:=STATE.slot_path(2)
    check(not INSPECT.inspect(target).exists and INSPECT.describe(INSPECT.inspect(target))=="尚无记录","missing save is explicit without creating a file")
    put(target,"damaged");var broken:=INSPECT.inspect(target)
    check(broken.exists and not broken.valid and FileAccess.get_file_as_string(target)=="damaged","invalid primary inspection preserves original bytes")
    put(target,JSON.stringify(data(77)));put(target+".bak",JSON.stringify(data(66)))
    var info:=INSPECT.inspect(target)
    check(info.valid and info.currency==77 and info.sha==FileAccess.get_sha256(target) and INSPECT.describe(info).contains("苔钟庭"),"valid inspection shows saved state and exact byte identity")
    put(path,FileAccess.get_file_as_string("res://tests/fixtures/quiet_sole_earned_return.json"))
    var scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=true;scene.world_save_path=path;scene.world_slot=1;root.add_child(scene);current_scene=scene
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    scene.set_process(false);scene.player.set_physics_process(false);scene.player.debug_invulnerable=true
    scene.currency_count=321;check(scene._save_world(),"current explicit fixture persists")
    var original:=FileAccess.get_file_as_bytes(path)
    var backup_original:=FileAccess.get_file_as_bytes(target+".bak")
    var memory: Dictionary=scene.world_state.data.duplicate(true)
    var rows: Array=scene.get_save_slots()
    check(rows.size()==3 and rows[0].currency==321 and rows[1].backup.currency==66,"three-slot overview uses actual current custom path and each backup")
    var quote: Dictionary=scene.quote_save_operation("switch",2)
    check(quote.ok and quote.primary.currency==77 and scene.world_state.data==memory and FileAccess.get_file_as_bytes(path)==original,"production switch preview is read-only")
    for index in [-1,0,4,999]:check(not scene.quote_save_operation("switch",index).ok and not scene.restore_save_backup(index if index!=0 else 999),"reject out-of-range slot without clamping %d" % index)
    check(not scene.quote_save_operation("erase",2).ok and not scene.quote_save_operation("switch",1).ok,"unknown operation and current-slot switch rejected")
    scene.world_save_failure_injected_for_validation=true
    check(not scene.select_save_slot(2) and not scene.chapter_transitioning and FileAccess.get_file_as_bytes(path)==original,"failed current save prevents direct slot departure")
    check(not scene.restore_save_backup(2) and not scene.chapter_transitioning and FileAccess.get_file_as_bytes(target+".bak")==backup_original,"failed current save prevents entering another slot backup")
    scene.world_save_failure_injected_for_validation=false
    scene._toggle_audio_settings();scene.ui_shell._select_save_slot(2)
    var dialog=scene.ui_shell.save_desk
    check(dialog.visible and dialog.get_cancel_button().has_focus() and dialog.description.text.contains("77碎钱") and not scene.chapter_transitioning,"settings opens actual preview with cancellation focused")
    dialog.hide();check(not scene.chapter_transitioning and FileAccess.get_file_as_bytes(path)==original,"cancel leaves current save and journey intact")
    scene.ui_shell._select_save_slot(2)
    put(target,JSON.stringify(data(88)))
    dialog.confirmed.emit()
    check(dialog.visible and dialog.description.text.contains("已变化") and not scene.chapter_transitioning,"changed target file requires another confirmation")
    var stale: Dictionary=quote
    check(not scene.perform_save_operation("switch",2,String(stale.fingerprint)).ok and not scene.chapter_transitioning,"production operation also rejects stale byte identity")
    scene.world_save_failure_injected_for_validation=true;dialog.confirmed.emit()
    check(dialog.visible and not scene.chapter_transitioning and FileAccess.get_file_as_bytes(path)==original,"confirmed failed save keeps current scene and exact file")
    scene.world_save_failure_injected_for_validation=false
    scene.currency_count=322;dialog.confirmed.emit()
    check(dialog.visible and not scene.chapter_transitioning,"changed current unsaved progress also requires reconfirmation")
    RETIRE.retire_tree(scene);dialog.confirmed.emit()
    var old=scene;scene=await wait_replaced(old)
    check(scene!=old and scene.world_slot==2 and scene.currency_count==88,"confirmed switch enters actual selected World")
    var saved:=STATE.new();check(saved.read(path) and saved.data.currency==322,"departing journey saved latest live progress before replacement")
    scene.set_process(false);scene.player.set_physics_process(false)
    var preserved_backup:=FileAccess.get_file_as_bytes(target+".bak")
    put(target,"corrupt primary exact bytes")
    scene._toggle_audio_settings();scene.ui_shell._restore_save_backup()
    dialog=scene.ui_shell.save_desk
    check(dialog.visible and dialog.quote.ok and dialog.description.text.contains("原文件") and not scene.chapter_transitioning,"current damaged primary can preview its valid backup")
    put(target+".bak",JSON.stringify(data(67)));dialog.confirmed.emit()
    check(dialog.visible and dialog.description.text.contains("已变化") and FileAccess.get_file_as_string(target)=="corrupt primary exact bytes","changed backup is revalidated before any replacement")
    RETIRE.retire_tree(scene);dialog.confirmed.emit();old=scene;scene=await wait_replaced(old)
    check(scene!=old and scene.world_slot==2 and scene.currency_count==67,"confirmed backup recovery enters actual recovered World")
    check(FileAccess.get_file_as_string(target+".bak")==JSON.stringify(data(67)),"recovery leaves exact chosen backup intact")
    var found:=false
    for file in DirAccess.get_files_at("user://"):
        if file.begins_with(target.get_file()+".before_restore_") and FileAccess.get_file_as_string("user://"+file)=="corrupt primary exact bytes":found=true
    check(found,"recovery preserves damaged primary byte for byte under a unique name")
    RETIRE.retire_tree(scene);scene.free();await process_frame;AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"all replaced Worlds release actual playback")
    print("SAVE_DESK checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
