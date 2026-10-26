extends SceneTree
const STATE=preload("res://scripts/world_state.gd")
const SHOP=preload("res://scripts/cartography_runtime.gd")
const JOURNAL=preload("res://scripts/pilgrimage_cartography.gd")
const RETIRE=preload("res://scripts/audio_retirement.gd")
const AUDIO=preload("res://scripts/audio_director.gd")
var checks:=0
var failures:=0
class CountingState extends "res://scripts/world_state.gd":
    var writes:=0
    var host: Node
    var seen: Dictionary={}
    func write_candidate(candidate: Dictionary,path: String=DEFAULT_PATH) -> bool:
        writes+=1;seen={"wallet":host.currency_count,"map":JOURNAL.owned(host.story_flags.duplicate(true),String(host.config.id)),"quill":JOURNAL.has_quill(host.story_flags),"compass":host.build_system.state.unlocked_passives.has("compass")}
        return super.write_candidate(candidate,path)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1;print("CHECK %s %s" % ["PASS" if ok else "FAIL",label])
    if not ok:failures+=1
func snapshot(scene: Node) -> Dictionary:
    return {"wallet":scene.currency_count,"flags":scene.story_flags.duplicate(true),"items":scene.inventory_counts.duplicate(true),"world":scene.world_state.data.duplicate(true),"build":scene.build_system.serialize(),"profile":scene.player.build_profile.duplicate(true),"hp":scene.player.hp,"energy":scene.player.energy}
func run() -> void:
    var path:="user://cartographer_trade.json"
    var scene=load("res://scenes/World.tscn").instantiate();scene.world_resume=false;scene.world_save_path=path;root.add_child(scene);current_scene=scene
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    scene.set_process(false);scene.player.set_physics_process(false);scene.player.hp=3;scene.player.energy=43;scene.currency_count=100
    var merchant: Area2D
    for child in scene.get_children():
        if child is Area2D and child.has_meta("map_seller_region"):merchant=child;break
    check(is_instance_valid(merchant),"actual authored cartographer supplies all three goods")
    scene.player.global_position=merchant.global_position
    var state:=CountingState.new();state.host=scene;state.data=scene.world_state.data.duplicate(true);scene.world_state=state
    check(scene._save_world(),"explicit trade fixture baseline persists")
    var before:=snapshot(scene);var disk:=FileAccess.get_file_as_bytes(path);state.writes=0
    for kind in ["map","quill","compass"]:
        var quote:=SHOP.quote_purchase(scene,merchant,kind)
        check(quote.ok and quote.price>0 and quote.summary.contains("购买后") and snapshot(scene)==before and state.writes==0,"read-only actual quote preserves ownership for "+kind)
    var fake:=Area2D.new();fake.name="TradeImposter";scene.add_child(fake);fake.position=merchant.position
    fake.set_meta("map_seller_region",String(scene.config.id));fake.set_meta("map_seller_data",merchant.get_meta("map_seller_data"))
    check(not SHOP.purchase(scene,fake).ok and snapshot(scene)==before,"noncanonical seller cannot charge or grant")
    fake.free();scene.player.position+=Vector2(1000,0)
    check(not SHOP.purchase_tool(scene,merchant,"quill").ok and snapshot(scene)==before,"remote tool purchase rejected")
    scene.player.global_position=merchant.global_position
    var seller: Dictionary=merchant.get_meta("map_seller_data").duplicate(true)
    var original_price: int=int(seller.get("price",JOURNAL.PRICE))
    for bad in [0,-1,true,0.5,NAN,INF]:
        var changed:=seller.duplicate(true);changed["price"]=bad;merchant.set_meta("map_seller_data",changed)
        check(not SHOP.quote_purchase(scene,merchant).ok and snapshot(scene)==before,"malformed map price never spends or grants %s" % str(bad))
    merchant.set_meta("map_seller_data",seller)
    check(not SHOP.purchase_tool(scene,merchant,"invalid").ok,"unknown tool cannot use compass fallback pricing")
    SHOP.open_shop(scene,merchant)
    var dialog: ConfirmationDialog=scene.get_node("MapPurchaseDialog")
    check(dialog.visible and dialog.get_cancel_button().has_focus() and scene.ui_shell.has_modal_window(),"real seller focuses cancellation and isolates native modal input")
    scene.currency_count=99;dialog.confirmed.emit()
    check(dialog.visible and state.writes==0 and dialog.dialog_text.contains("已变化") and scene.currency_count==99,"wallet changes require renewed explicit confirmation")
    scene.currency_count=100;SHOP.open_shop(scene,merchant)
    seller["price"]=original_price+1;merchant.set_meta("map_seller_data",seller);dialog.confirmed.emit()
    check(dialog.visible and state.writes==0 and dialog.dialog_text.contains("已变化") and not JOURNAL.owned(scene.story_flags.duplicate(true),String(scene.config.id)),"actual price changes refresh quote without purchase")
    scene.world_save_failure_injected_for_validation=true;dialog.confirmed.emit()
    check(snapshot(scene)==before and FileAccess.get_file_as_bytes(path)==disk and dialog.visible,"failed map save retains exact wallet knowledge build resources and file")
    scene.world_save_failure_injected_for_validation=false;dialog.confirmed.emit()
    var after_map: int=100-original_price-1
    check(state.writes==1 and state.seen.wallet==100 and not state.seen.map and scene.currency_count==after_map and JOURNAL.owned(scene.story_flags.duplicate(true),String(scene.config.id)),"map publishes exact current price and ownership after one durable write")
    check(not dialog.visible and not scene.player.ui_input_locked,"successful map confirmation returns gameplay control")
    var restored:=STATE.new();check(restored.read(path) and restored.data.currency==after_map and JOURNAL.owned(restored.data.story_flags,String(scene.config.id)),"actual map disk restores the same price and owned paper")
    SHOP.open_shop(scene,merchant);state.writes=0
    dialog.custom_action.emit("quill")
    check(dialog.visible and not JOURNAL.has_quill(scene.story_flags) and scene.currency_count==after_map and dialog.dialog_text.contains("盐墨绘针"),"tool selection stages a quote without silently buying")
    before=snapshot(scene);disk=FileAccess.get_file_as_bytes(path);scene.world_save_failure_injected_for_validation=true;dialog.confirmed.emit()
    check(snapshot(scene)==before and FileAccess.get_file_as_bytes(path)==disk and dialog.visible,"failed quill save preserves complete knowledge state and retry window")
    scene.world_save_failure_injected_for_validation=false;dialog.confirmed.emit()
    check(state.writes==1 and not state.seen.quill and JOURNAL.has_quill(scene.story_flags) and scene.currency_count==after_map-10,"quill commits exactly once at its real price")
    state.writes=0;dialog.custom_action.emit("compass")
    check(not scene.build_system.state.unlocked_passives.has("compass"),"compass quote does not unlock or equip it")
    before=snapshot(scene);disk=FileAccess.get_file_as_bytes(path);scene.world_save_failure_injected_for_validation=true;dialog.confirmed.emit()
    check(snapshot(scene)==before and FileAccess.get_file_as_bytes(path)==disk,"failed compass save preserves unlocks profile and disk")
    scene.world_save_failure_injected_for_validation=false;dialog.confirmed.emit()
    check(state.writes==1 and not state.seen.compass and scene.build_system.state.unlocked_passives.has("compass") and scene.story_flags.get("charm_compass_found",false) and scene.currency_count==after_map-25,"compass unlock and source flag commit with exact payment")
    check(not SHOP.shows_position(scene) and scene.player.hp==3 and scene.player.energy==43,"purchase does not auto-equip positioning or refill resources")
    check(restored.read(path) and restored.data.currency==after_map-25 and restored.data.build_state.unlocked_passives.has("compass") and JOURNAL.has_quill(restored.data.story_flags),"production disk restores both tools and final wallet")
    before=snapshot(scene)
    check(not SHOP.purchase(scene,merchant).ok and not SHOP.purchase_tool(scene,merchant,"quill").ok and not SHOP.purchase_tool(scene,merchant,"compass").ok and state.writes==1 and snapshot(scene)==before,"already-owned goods cannot charge twice")
    var late: Callable=dialog.get_signal_connection_list("confirmed")[0].callable
    RETIRE.retire_tree(scene);scene.free();await process_frame;late.call()
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"late native callback after owner exit is safe and real World audio retires")
    print("CARTOGRAPHER_TRADE checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
