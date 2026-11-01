extends SceneTree
## Explicit map/death fixtures exercise real UI, WorldState and physical pickup.
## They do not stand in for a naturally earned recovery route playthrough.
const READOUT:=preload("res://scripts/death_recovery_readout.gd")
const MAP:=preload("res://scripts/death_recovery_map.gd")
const JOURNAL:=preload("res://scripts/pilgrimage_cartography.gd")
const PINS:=preload("res://scripts/map_player_pins.gd")
const ATLAS:=preload("res://scripts/world_atlas.gd")
const NETWORK:=preload("res://scripts/shrine_return_network.gd")
const AUDIO:=preload("res://scripts/audio_director.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const SAVE:="user://death_recovery_map.json"
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    print("CHECK %s %s" % ["PASS" if ok else "FAIL",message])
    if not ok:failures+=1
func cache(region: String,point: Vector2,amount: int=99) -> Dictionary:
    return {"region_id":region,"position":[point.x,point.y],"currency":amount}
func pure_checks() -> void:
    var config:={"id":"known","chapter_name":"已知区域","map_rooms":[
        {"id":"hall","name":"大厅","layout_rect":[0,0,2560,720]},
        {"id":"secret","name":"秘密工房","layout_rect":[200,200,200,200]}]}
    var flags:={JOURNAL.KEY:{"known":{"owned":true,"charted":{"hall@0":true},"pending":{"hall@1":true}}}}
    var before:=flags.duplicate(true)
    var data:=READOUT.describe(cache("known",Vector2(20,20)),flags,{"known":config},"known")
    check(data.present and data.locatable and data.text.contains("大厅") and data.text.contains("99枚"),"inked segment admits its actual point and full field refund")
    check(data.text.contains("当前0/3") and not data.text.contains("保留59枚"),"locked recall explains earned guardian threshold without offering a purchase")
    data=READOUT.describe(cache("known",Vector2(1350,20)),flags,{"known":config},"known")
    check(not data.locatable and data.text.contains("尚未补绘"),"pending second segment does not become charted through a death record")
    data=READOUT.describe(cache("known",Vector2(300,300)),flags,{"known":config},"known")
    check(not data.locatable and not data.text.contains("秘密工房"),"charted enclosing hall never reveals an uncharted nested room")
    data=READOUT.describe(cache("unknown",Vector2(20,20)),flags,{"known":config},"known")
    check(not data.locatable and not data.text.contains("unknown") and not data.text.contains("已知区域"),"unreliable region does not disclose raw id, authored name or position")
    check(flags==before,"all knowledge reads leave even pending survey notes unchanged")
    flags[JOURNAL.KEY].known.charted.secret=true
    data=READOUT.describe(cache("known",Vector2(300,300)),flags,{"known":config},"known")
    check(data.locatable and data.text.contains("秘密工房"),"the same inner room becomes locatable only after its own chart exists")
    flags.boss_down_ch01=true;flags.boss_down_ch02=true;flags.boss_down_ch03=true
    data=READOUT.describe(cache("known",Vector2(20,20)),flags,{"known":config},"other")
    check(data.text.contains("保留59枚，失去40枚") and not data.text.contains("（本区）"),"recall comparison uses the exact production floor rounding and region relation")
    check(data.text.contains("再次倒下") and data.text.contains("能力与装备保留"),"second-death replacement and retained progression are explained before choosing a method")
    for malformed in [null,[],{"region_id":"known"},cache("known",Vector2.INF),cache("known",Vector2.ZERO,-1)]:
        data=READOUT.describe(malformed,flags,{"known":config},"known")
        check(not data.present and not data.locatable,"malformed saved knot is rejected without a lookup or repair")
    for empty in [{},cache("known",Vector2.ZERO,0)]:
        data=READOUT.describe(empty,flags,{"known":config},"known")
        check(not data.present and not data.locatable,"empty and zero-value knots have an honest empty state")
    for region in NETWORK.NAMES:
        var authored:=ATLAS.configuration(region)
        var room: Dictionary=authored.map_rooms[0]
        var rect: Array=room.get("layout_rect",room.get("play_rect",[]))
        var point:=Vector2(rect[0]+rect[2]*0.5,rect[1]+rect[3]*0.5)
        var owner:=PINS.owner(authored,point)
        if owner.is_empty():check(false,"authored map room has a usable anchor");continue
        var known:={JOURNAL.KEY:{region:{"owned":true,"charted":{String(owner.id):true},"pending":{}}}}
        var knot:=cache(region,point)
        before={"flags":known.duplicate(true),"cache":knot.duplicate(true),"config":authored.duplicate(true)}
        data=READOUT.describe(knot,known,{region:authored},region)
        check(data.locatable and data.region==region and data.point==point,"each authored region projects the exact local knot coordinate")
        check(known==before.flags and knot==before.cache and authored==before.config,"authored region readout does not mutate any source container")

func resources(scene: Node) -> Dictionary:
    return {"wallet":scene.currency_count,"cache":scene.world_state.data.death_cache.duplicate(true),"flags":scene.story_flags.duplicate(true),"inventory":scene.inventory_counts.duplicate(true),"build":scene.build_system.serialize(),"hp":scene.player.hp,"energy":scene.player.energy,"position":scene.player.position}
func run() -> void:
    preload("res://scripts/world_routes.gd")._data()
    pure_checks()
    var scene: Node=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path=SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    check(scene.initial_region_ready,"actual World initial region publishes")
    scene.set_process(false)
    scene.player.set_physics_process(false)
    scene._close_overlays()
    scene.currency_count=101
    scene.last_safe_ground=scene.player.position
    scene.death_recorded=false
    scene._record_death_cache()
    check(scene.currency_count==51 and scene.world_state.data.death_cache.currency==50,"actual death creates a fifty-coin knot from an odd wallet")
    var region:=String(scene.config.id)
    var point: Vector2=scene.death_cache_area.position
    var room:=PINS.owner(scene.config,point)
    check(not room.is_empty(),"production safe death point belongs to an authored map room")
    if not room.is_empty():
        scene.story_flags[JOURNAL.KEY]={region:{"owned":true,"charted":{String(room.id):true},"pending":{}}}
    scene._toggle_map()
    check(scene.active_overlay=="map" and scene.player.ui_input_locked,"real map opening retains gameplay input ownership")
    var button:=scene.map_panel.get_node_or_null(MAP.BUTTON) as Button
    check(button!=null and scene.map_panel.get_global_rect().encloses(button.get_global_rect()),"actual region setup installs a bounded native recovery control")
    for child in scene.map_panel.get_children():
        if child is Control and child!=button and (child is Button or child.name=="SurveyMapTitle"):
            check(not button.get_global_rect().intersects(child.get_global_rect()),"recovery entry clears existing map title and controls: "+String(child.name))
    var count: int=scene.map_panel.get_child_count()
    MAP.setup(scene)
    check(scene.map_panel.get_child_count()==count,"repeated setup never duplicates recovery controls")
    var host: WeakRef=weakref(scene)
    var parent: WeakRef=weakref(scene.map_panel)
    var before:=resources(scene)
    var disk:=FileAccess.get_file_as_bytes(SAVE)
    button.pressed.emit()
    await process_frame
    var dialog:=scene.map_panel.get_node(MAP.WINDOW) as AcceptDialog
    check(dialog.visible and dialog.get_ok_button().has_focus() and scene.ui_shell.has_modal_window(),"opening native recovery report focuses the return action and blocks polled shortcuts")
    check(resources(scene)==before and FileAccess.get_file_as_bytes(SAVE)==disk,"opening report preserves actual resources, position, discovery and exact save bytes")
    check(dialog.get_node("RecoveryText").text.contains("50枚"),"native report reads the real live knot amount")
    var locate_button:=dialog.find_child("LocateKnot",true,false) as Button
    check(not locate_button.disabled,"inked production knot enables the view-only locate action")
    var pan: Vector2=scene.map_draw_root.position
    scene.world_state.data.death_cache.currency=49
    dialog.custom_action.emit("locate")
    check(dialog.visible and dialog.get_node("RecoveryText").text.contains("已变化") and scene.map_draw_root.position==pan,"stale report cannot act on a replacement knot before presenting its new value")
    before=resources(scene)
    dialog.custom_action.emit("locate")
    check(not dialog.visible and button.has_focus(),"fresh location centers actual map and returns focus to its source control")
    check(resources(scene)==before and FileAccess.get_file_as_bytes(SAVE)==disk,"location changes only viewport; wallet, physical knot, discovery, Player and disk stay unchanged")
    button.pressed.emit()
    dialog.custom_action.emit("refresh")
    check(dialog.get_node("RecoveryText").text.contains("49枚"),"manual refresh rebuilds from current data without reopening the map")
    var marker:=scene.map_draw_root.get_node_or_null("DeathRecoveryMarker") as Label
    check(marker!=null and marker.mouse_filter==Control.MOUSE_FILTER_IGNORE,"live knot marker labels the projected point without intercepting map input")
    var other: String="demo_ch02_rain_foundry_canal"
    var other_config:=ATLAS.configuration(other)
    var other_room: Dictionary=other_config.map_rooms[0]
    var rect: Array=other_room.get("layout_rect",other_room.get("play_rect",[]))
    var remote_point:=Vector2(rect[0]+rect[2]*0.5,rect[1]+rect[3]*0.5)
    var remote_owner:=PINS.owner(other_config,remote_point)
    scene.world_state.data.death_cache=cache(other,remote_point,49)
    dialog.custom_action.emit("refresh")
    check(locate_button.disabled and not dialog.get_node("RecoveryText").text.contains(String(other_config.chapter_name)),"unvisited region cannot be exposed by a forged or obsolete cache alone")
    check(scene.world_state.capture_region(other,{"visited_rooms":{String(remote_owner.id):true}}),"explicit visited-region fixture is accepted by production WorldState")
    scene.story_flags[JOURNAL.KEY][other]={"owned":true,"charted":{String(remote_owner.id):true},"pending":{}}
    dialog.custom_action.emit("refresh")
    check(not locate_button.disabled,"visited and inked cross-region knot can be located")
    before=resources(scene)
    dialog.custom_action.emit("locate")
    check(scene.world_map_view and not dialog.visible and scene.config.id==region,"cross-region locate switches to actual world overview without changing region")
    check(resources(scene)==before,"cross-region camera operation preserves all resources and physical Player position")
    marker=scene.map_draw_root.get_node_or_null("DeathRecoveryMarker") as Label
    var expected:=preload("res://scripts/map_player_pins_runtime.gd").project(scene,other,remote_point)
    check(marker!=null and marker.position.distance_to(expected-Vector2(10,14))<0.01,"world marker uses the actual authored world-coordinate projection")
    button.pressed.emit()
    scene.world_state.data.death_cache={}
    dialog.custom_action.emit("refresh")
    check(not scene.map_draw_root.has_node("DeathRecoveryMarker"),"cleared knot removes obsolete marker on refresh")
    check(locate_button.disabled and dialog.get_node("RecoveryText").text.contains("目前没有"),"collected knot disables locate and replaces obsolete amount with empty state")
    scene.world_state.data.death_cache=cache(region,point,49)
    scene._spawn_death_cache()
    scene.map_panel.hide()
    check(not dialog.visible,"closing map retires its exclusive recovery window")
    before=resources(scene)
    dialog.custom_action.emit("locate")
    check(resources(scene)==before,"captured actions from a hidden map cannot alter the current world")
    scene._close_overlays()
    scene.player.position=point
    scene.world_save_failure_injected_for_validation=true
    var knot: Area2D=scene.death_cache_area
    before=resources(scene)
    scene._recover_death_cache(knot)
    check(resources(scene)==before and scene.death_cache_area==knot,"failed physical recovery still preserves exact knot after map inspection")
    scene.world_save_failure_injected_for_validation=false
    scene._recover_death_cache(knot)
    check(scene.currency_count==100 and scene.world_state.data.death_cache.is_empty(),"existing physical pickup remains the only operation that returns the full current amount")
    var retired_panel: Control=scene.map_panel
    retired_panel.queue_free()
    check(not MAP.owns(host,parent),"queued map owner rejects deferred actions before destruction")
    RETIRE.retire_tree(scene)
    scene.queue_free()
    await process_frame
    check(not MAP.owns(host,parent),"freed World/map weak references reject late callbacks")
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"native World test retires all actual audio owners")
    print("DEATH_RECOVERY_MAP checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
