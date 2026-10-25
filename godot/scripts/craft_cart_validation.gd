extends SceneTree
const BUILD=preload("res://scripts/build_system.gd")
const STATE=preload("res://scripts/world_state.gd")
const RETIRE=preload("res://scripts/audio_retirement.gd")
const AUDIO=preload("res://scripts/audio_director.gd")
var checks:=0
var failures:=0
class CountingState extends "res://scripts/world_state.gd":
    var writes:=0
    func write_candidate(candidate: Dictionary,path: String=DEFAULT_PATH) -> bool:
        writes+=1;return super.write_candidate(candidate,path)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1;print("CHECK %s %s" % ["PASS" if ok else "FAIL",label])
    if not ok:failures+=1
func snapshot(scene: Node) -> Dictionary:
    return {"build":scene.build_system.serialize(),"wallet":scene._build_wallet_snapshot(),"materials":scene.inventory_materials.duplicate(true),"hp":scene.player.hp,"energy":scene.player.energy,"profile":scene.player.build_profile.duplicate(true),"world":scene.world_state.data.duplicate(true)}
func run() -> void:
    var build:=BUILD.new();build.unlock_event("tool_mine_found");build.unlock_event("tool_lure_found")
    var wallet: Dictionary={"currency":500,"inventory_counts":{"wet_chitin":3,"pollen_wax":3,"evidence_counterweight_echo":1,"evidence_root_track":1}}
    var before: Dictionary=build.serialize();var wallet_before:=wallet.duplicate(true)
    var quote: Dictionary=build.quote_craft_batch(["mod_mine","mod_lure"],wallet)
    check(quote.ok and quote.currency_spent==170 and quote.wallet.currency==330,"pure full cart sums both prices")
    check(quote.materials=={"wet_chitin":3,"pollen_wax":3} and quote.wallet.inventory_counts.evidence_root_track==1,"aggregate exact materials and retain patterns")
    check(build.serialize()==before and wallet==wallet_before,"pure quote owns all candidate mutations")
    var rebuilt:=BUILD.new();check(rebuilt.restore(quote.build).ok and rebuilt.tool_capacity("mine")==build.tool_capacity("mine")+1 and rebuilt.tool_capacity("lure")==build.tool_capacity("lure")+1,"whole candidate carries both capacity upgrades")
    for request in [[],["mod_mine","mod_mine"],["unknown"],[true],"mod_mine",["mod_mine","mod_lure","a","b","c","d","e","f","g"]]:
        check(not build.quote_craft_batch(request,wallet).ok,"reject malformed duplicate unknown or oversized cart %s" % str(request))
    var poor:=wallet.duplicate(true);poor.currency=100
    check(not build.quote_craft_batch(["mod_mine","mod_lure"],poor).ok and build.serialize()==before and poor.currency==100,"later affordability failure cannot buy an earlier item")
    poor=wallet.duplicate(true);poor.inventory_counts.pollen_wax=2
    check(not build.quote_craft_batch(["mod_mine","mod_lure"],poor).ok and build.serialize()==before,"later material failure has no partial build")
    build.catalog.recipes.mod_mine.currency=81
    var repriced: Dictionary=build.quote_craft_batch(["mod_mine","mod_lure"],wallet)
    check(repriced.ok and repriced.currency_spent==171 and repriced.wallet.currency==329,"actual changed catalog price matches aggregate and charged candidate")
    build.catalog.recipes.mod_mine.currency=80
    var directions: Array=[]
    for id in build.catalog.recipes:
        if String(build.catalog.recipes[id].get("kind",""))=="skill_branch" and String(build.catalog.recipes[id].target)=="cleave":directions.append(String(id))
    check(directions.size()==2 and not build.quote_craft_batch(directions,wallet).ok,"conflicting directions for the same skill are rejected")
    var save_path:="user://craft_cart_%d.json" % OS.get_process_id()
    var file:=FileAccess.open(save_path,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes("res://tests/fixtures/quiet_sole_earned_return.json"));file.close()
    var scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=true;scene.world_save_path=save_path;root.add_child(scene);current_scene=scene
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    var routes=preload("res://scripts/world_routes.gd")
    scene._travel_world(routes.config_path("demo_ch02_rain_foundry_canal"),Vector2(1000,500))
    for unused in 20:await physics_frame;await process_frame
    var npc: Area2D
    for child in scene.get_children():
        if child is Area2D and String(child.get_meta("npc_id",""))=="npc_rain_smith_liu":npc=child
    check(is_instance_valid(npc),"actual authored rain smith loaded")
    if not is_instance_valid(npc):quit(1);return
    scene.player.global_position=npc.global_position;scene.player.debug_invulnerable=true;scene.player.hp=3;scene.player.energy=43
    scene.player.set_physics_process(false);scene.set_process(false)
    scene.build_system.unlock_event("tool_mine_found");scene.build_system.unlock_event("tool_lure_found")
    scene.currency_count=500
    for id in wallet.inventory_counts:scene.inventory_counts[id]=wallet.inventory_counts[id]
    scene._set_build_wallet(scene._build_wallet_snapshot());scene._sync_player_build()
    var state:=CountingState.new();state.data=scene.world_state.data.duplicate(true);scene.world_state=state
    check(scene.near_artisan_id()=="npc_rain_smith_liu" and scene._save_world(),"positioned fixture qualifies beside actual artisan and persists")
    before=snapshot(scene);var disk:=FileAccess.get_file_as_bytes(save_path);state.writes=0
    var ids: Array=["mod_mine","mod_lure"]
    quote=scene.quote_craft_cart(ids)
    check(quote.ok and snapshot(scene)==before and state.writes==0,"production quote changes no live or durable state")
    scene.player.position+=Vector2(1200,0)
    check(not scene.perform_build_action("craft_batch","",ids).ok and snapshot(scene)==before,"remote batch cannot bypass workstation reach")
    scene.player.global_position=npc.global_position
    check(not scene.quote_craft_cart(["mod_shard"]).ok,"wrong named artisan cannot craft another artisan's item")
    scene._toggle_build();scene.ui_shell.build_category="强化";scene.ui_shell.refresh_build()
    check(scene.ui_shell.craft_cart_button.visible,"production upgrade page exposes cart entrance")
    scene.ui_shell._open_craft_cart()
    var dialog=scene.ui_shell.craft_cart
    dialog.set_recipe("mod_mine",true);dialog.set_recipe("mod_lure",true)
    check(dialog.visible and dialog.get_cancel_button().has_focus() and dialog.quote.ok and state.writes==0,"real cart selection defaults to free cancellation")
    dialog.confirmed.emit()
    check(dialog.staged and state.writes==0,"first explicit confirmation stages exact totals")
    scene.build_system.catalog.recipes.mod_mine.currency+=1
    dialog.confirmed.emit()
    check(not dialog.staged and state.writes==0 and dialog.summary.text.contains("已变化"),"changed actual recipe price requires renewed confirmation")
    scene.build_system.catalog.recipes.mod_mine.currency-=1
    dialog._refresh_quote();dialog.confirmed.emit()
    scene.world_save_failure_injected_for_validation=true
    dialog.confirmed.emit()
    check(dialog.visible and snapshot(scene)==before and FileAccess.get_file_as_bytes(save_path)==disk,"failed whole-cart save rolls back both crafts costs player and file")
    scene.world_save_failure_injected_for_validation=false;state.writes=0
    dialog.confirmed.emit();dialog.confirmed.emit()
    check(state.writes==1 and not dialog.visible and scene.currency_count==330,"whole cart commits once after deliberate retry")
    check(scene.build_system.state.crafted.has("mod_mine") and scene.build_system.state.crafted.has("mod_lure"),"successful cart grants every requested craft")
    check(scene.player.hp==3 and scene.player.energy==43 and scene.build_system.state.tool_counts==before.build.tool_counts,"capacity purchase does not refill HP energy or tool charges")
    var restart:=STATE.new();check(restart.read(save_path) and restart.data.currency==330 and restart.data.build_state.crafted.has("mod_lure"),"production disk reload restores entire cart")
    var after:=snapshot(scene);check(not scene.perform_build_action("craft_batch","",ids).ok and snapshot(scene)==after,"already-made cart cannot buy duplicate permanent capacity")
    scene.ui_shell.craft_cart.hide();scene.ui_shell._open_craft_cart();scene.ui_shell.build_panel.hide()
    check(not dialog.visible,"closing upgrade page closes cart")
    RETIRE.retire_tree(scene);scene.free();await process_frame;AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"cart fixture releases real World audio ownership")
    print("CRAFT_CART checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
