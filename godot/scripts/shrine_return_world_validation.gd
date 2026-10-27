extends SceneTree
## Explicit station/permission fixtures exercise production World and loader;
## this is not a claim of naturally earned exploration or a full playthrough.
const NETWORK:=preload("res://scripts/shrine_return_network.gd")
const ATLAS:=preload("res://scripts/world_atlas.gd")
const RETIREMENT:=preload("res://scripts/audio_retirement.gd")
const AUDIO:=preload("res://scripts/audio_director.gd")
const A:="demo_ch01_moss_bell_court"
const B:="demo_ch02_rain_foundry_canal"
const SAVE:="user://shrine_return_world.json"
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    print("CHECK %s %s" % ["PASS" if ok else "FAIL",message])
    if not ok:failures+=1
func frames(count: int) -> void:
    for index in count:await process_frame
func settle(level: Node) -> void:
    var started:=Time.get_ticks_msec()
    while (level.world_portal_request_pending or level.world_loader.phase!="idle") and Time.get_ticks_msec()-started<60000:
        await process_frame
func run() -> void:
    var scene: Node=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path=SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    check(scene.initial_region_ready and scene.config.id==A,"production World reaches its real initial region")
    scene.player.set_physics_process(false)
    var source: Dictionary=scene.config.save_points[0]
    scene.player.position=NETWORK.point(source.position)
    await frames(12)
    var area:=scene.get_node_or_null(NodePath(String(source.id))) as Area2D
    check(area!=null,"source shrine is an installed production Area2D")
    if area==null:
        scene.queue_free();await frames(5);quit(1);return
    scene._activate_save_point(area)
    check(scene.active_save_point_id==String(source.id),"actual shrine interaction records the active checkpoint")
    # Author a previously visited destination in this isolated save fixture.
    var data:=ATLAS.configuration(B)
    var destination: Dictionary=data.save_points[0]
    check(scene.world_state.capture_region(B,{"checkpoint_id":destination.id,"checkpoint":destination.position,"visited_rooms":{"entry":true}}),"valid prior destination checkpoint installs in actual WorldState")
    for region in NETWORK.NAMES:
        for portal in ATLAS.configuration(region).get("interactives",[]):
            var ability:=String(portal.get("required_ability",""))
            if not ability.is_empty():scene.inventory_counts[ability]=1
            var latch:=String(portal.get("requires_shortcut",""))
            if not latch.is_empty():scene.story_flags["world_shortcut_"+latch]=true
    # A previously visited region has already supplied its authored starting relics.
    for item in data.get("inventory",{}).get("starting_relics",[]):
        if not scene.inventory_counts.has(String(item)):scene._add_inventory_item(String(item),1,false)
    scene.player.hp=3
    scene.player.energy=37
    scene._close_overlays()
    check(scene._save_world(),"source baseline writes through actual Main and WorldState")
    var key:=B+":"+String(destination.id)
    var quote:=NETWORK.quote(scene,key)
    check(quote.ok,"real source and saved destination produce a valid quote")
    if not quote.ok:
        print(quote.reason)
        RETIREMENT.retire_tree(scene);scene.queue_free();await frames(5)
        AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear();await RETIREMENT.drain(self)
        quit(1);return
    var player: Node=scene.player
    var id: int=area.get_instance_id()
    var cash: int=scene.currency_count
    var counts: Dictionary=scene.inventory_counts.duplicate(true)
    var disk:=FileAccess.get_file_as_bytes(SAVE)
    scene.world_save_failure_injected_for_validation=true
    check(NETWORK.begin(scene,key,quote.fingerprint).ok,"real request is accepted before asynchronous source-write failure")
    await settle(scene)
    check(scene.config.id==A and is_instance_valid(area) and area.get_instance_id()==id,"failed source save retains the exact source region and shrine owner")
    check(scene.player==player and scene.player.hp==3 and scene.player.energy==37,"failed travel preserves Player identity and current resources")
    check(FileAccess.get_file_as_bytes(SAVE)==disk,"failed departure preserves exact baseline save bytes")
    check(not scene.player.ui_input_locked and not scene.world_portal_request_pending and not scene.world_loading,"failure returns a fully interactive source world")
    scene.world_save_failure_injected_for_validation=false
    quote=NETWORK.quote(scene,key)
    check(NETWORK.begin(scene,key,quote.fingerprint).ok,"same real shrine can retry after save recovery")
    await settle(scene)
    check(scene.config.id==B and scene.player==player,"existing loader publishes actual target region and retains Player instance")
    check(scene.player.global_position.distance_to(NETWORK.point(destination.position))<2,"arrival uses the exact authored activated shrine position")
    check(scene.player.hp==3 and scene.player.energy==37,"successful real travel never refills health or energy")
    if scene.currency_count!=cash or scene.inventory_counts!=counts:
        print("RESOURCE_DELTA before_cash=%d after_cash=%d before=%s after=%s" % [cash,scene.currency_count,str(counts),str(scene.inventory_counts)])
    check(scene.currency_count==cash and scene.inventory_counts==counts,"zero-fare travel preserves actual wallet and inventory counts")
    check(scene.active_save_point_id==String(destination.id),"target keeps its actual previously activated checkpoint")
    var return_key:=A+":"+String(source.id)
    quote=NETWORK.quote(scene,return_key)
    check(quote.ok,"destination's existing checkpoint permits a known return journey")
    if quote.ok:
        NETWORK.begin(scene,return_key,quote.fingerprint)
        await settle(scene)
        check(scene.config.id==A and scene.player==player,"actual round trip returns to source with the same Player owner")
    RETIREMENT.retire_tree(scene)
    scene.queue_free()
    await frames(5)
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"actual World audio owners retire after round trip")
    for file in DirAccess.get_files_at("user://"):
        if file.begins_with(SAVE.get_file()):DirAccess.remove_absolute("user://"+file)
    print("SHRINE_RETURN_WORLD checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
