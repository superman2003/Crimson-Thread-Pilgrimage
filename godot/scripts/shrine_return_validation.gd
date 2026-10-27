extends SceneTree
const NETWORK:=preload("res://scripts/shrine_return_network.gd")
const DIALOG:=preload("res://scripts/shrine_return_dialog.gd")
const ROUTES:=preload("res://scripts/world_routes.gd")
const ATLAS:=preload("res://scripts/world_atlas.gd")
const STATE:=preload("res://scripts/world_state.gd")
const UI:=preload("res://scripts/pilgrimage_interface.gd")
const LAYOUT:=preload("res://scripts/map_control_layout.gd")
const A:="demo_ch01_moss_bell_court"
const B:="demo_ch02_rain_foundry_canal"
var checks:=0
var failures:=0

class Player extends CharacterBody2D:
    var hp:=3
    var energy:=37
    var death_timer:=0.0
    var heal_timer:=0.0
    var attack_timer:=0.0
    var skill_timer:=0.0
    var dash_timer:=0.0
    var grapple_timer:=0.0
    var guard_timer:=0.0
    var phase_active:=false
    var heal_reserved_cost:=0
    var attack_cancel_lock:=0.0
    var hurt_timer:=0.0
    var practice_energy:=0
    var ui_input_locked:=false
    var handoffs:=0
    func prepare_region_handoff() -> void:handoffs+=1

class Loader extends "res://scripts/world_region_loader.gd":
    var requests:=0
    var destination: Vector2
    func request_shrine_return_transition(_host: Node,_key: String,_path: String,entry: Vector2,_fingerprint: String) -> RefCounted:
        requests+=1
        destination=entry
        return RefCounted.new()

class Host extends "res://scripts/main_level.gd":
    var saves:=0
    var save_ok:=true
    var notices: Array[String]=[]
    func _ready() -> void:pass
    func _process(_dt: float) -> void:pass
    func _physics_process(_dt: float) -> void:pass
    func _exit_tree() -> void:pass
    func _walking_world_passage() -> bool:return false
    func _toast(value: String) -> void:notices.append(value)
    func _play_sfx(_key: String,_volume: float=0.0) -> void:pass
    func _save_world() -> bool:saves+=1;return save_ok

class PreflightLoader extends "res://scripts/world_region_loader.gd":
    var evictions:=0
    var invalidate:=false
    func _show_loading_canvas(_host: Node) -> void:pass
    func _clear_loading_canvas() -> void:pass
    func _preflight_async(_path: String,_entry: Vector2,_prefetch: RefCounted,host: Node) -> Dictionary:
        await host.get_tree().process_frame
        if invalidate:host.story_flags["changed_during_preflight"]=true
        last_transition["preflight_route_generation"]=ROUTES.cached_generation()
        return {"id":B}
    func _evict_budgeted(_host: Node) -> bool:evictions+=1;return false

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func saved(region: String) -> Dictionary:
    var data:=ATLAS.configuration(region)
    var point: Dictionary=data.save_points[0]
    return {"checkpoint_id":point.id,"checkpoint":point.position,"visited_rooms":{"entry":true}}
func make_host() -> Node:
    var host:=Host.new()
    host.world_mode=true
    host.world_loading=false
    host.config=ATLAS.configuration(A)
    host.config_path=ROUTES.cached_config_path(A)
    host.world_state=STATE.new()
    host.world_state.data.regions={A:saved(A),B:saved(B)}
    host.world_loader=Loader.new()
    host.world_loader.generation=8
    host.player=Player.new()
    host.add_child(host.player)
    var record:=saved(A)
    host.active_save_point_id=record.checkpoint_id
    host.active_spawn=NETWORK.point(record.checkpoint)
    host.player.position=host.active_spawn
    host.player.velocity=Vector2(13,-4)
    var shrine:=Area2D.new()
    shrine.name=host.active_save_point_id
    shrine.position=host.active_spawn
    shrine.set_meta("kind","save_point")
    host.add_child(shrine)
    # Explicit permission fixtures, never an assertion of earned progression.
    for region in NETWORK.NAMES:
        for portal in ATLAS.configuration(region).get("interactives",[]):
            var ability:=String(portal.get("required_ability",""))
            if not ability.is_empty():host.inventory_counts[ability]=1
            var latch:=String(portal.get("requires_shortcut",""))
            if not latch.is_empty():host.story_flags["world_shortcut_"+latch]=true
    root.add_child(host)
    return host
func key() -> String:return B+":"+String(saved(B).checkpoint_id)

func run() -> void:
    ROUTES._data()
    station_checks()
    quote_checks()
    await dispatch_checks()
    await source_save_checks()
    await dialog_checks()
    print("SHRINE_RETURN checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func station_checks() -> void:
    for region in NETWORK.NAMES:
        var config:=ATLAS.configuration(region)
        for shrine in config.save_points:
            var record:={"checkpoint_id":shrine.id,"checkpoint":shrine.position}
            var row:=NETWORK.station(region,record,config)
            check(not row.is_empty() and row.position==NETWORK.point(shrine.position),"every authored shrine validates at its exact original position")
            for invalid in [null,true,[true,2],[1],"start",[INF,0],[NAN,0]]:
                check(NETWORK.station(region,{"checkpoint_id":shrine.id,"checkpoint":invalid},config).is_empty(),"invalid checkpoint data cannot publish a station")
            for id in ["start","boss_trial","nonexistent"]:
                check(NETWORK.station(region,{"checkpoint_id":id,"checkpoint":shrine.position},config).is_empty(),"default/practice/unknown station IDs are excluded")
            var displaced:=NETWORK.point(shrine.position)+Vector2(4,0)
            check(NETWORK.station(region,{"checkpoint_id":shrine.id,"checkpoint":displaced},config).is_empty(),"moved or forged checkpoint cannot authorize arrival")
    check(NETWORK.station("unknown",saved(A),ATLAS.configuration(A)).is_empty(),"unknown region cannot disclose a station")

func quote_checks() -> void:
    var host:=make_host()
    var flags: Dictionary=host.story_flags.duplicate(true)
    var state: Dictionary=host.world_state.data.duplicate(true)
    var counts: Dictionary=host.inventory_counts.duplicate(true)
    var quote:=NETWORK.quote(host,key())
    check(quote.ok and quote.cost==0 and quote.path==[A,B],"known open route returns a zero-fare quote between actual shrine records")
    check(quote.target.position==NETWORK.point(saved(B).checkpoint),"arrival uses authored destination, never arbitrary UI coordinates")
    check(host.world_state.data==state and host.story_flags==flags and host.inventory_counts==counts and host.saves==0,"listing and quoting never change progress, inventory or disk")
    check(NETWORK.quote(host,A+":"+String(saved(A).checkpoint_id)).ok==false,"same-region fast travel is not offered")
    check(not NETWORK.quote(host,"unknown:secret").ok,"unvisited stations cannot be guessed through string IDs")
    var rows:=NETWORK.stations(host)
    check(rows.size()==2,"only exact activated shrine records appear, no six-region catalogue leak")
    rows[0].title="changed"
    check(NETWORK.stations(host)[0].title!="changed","public station rows do not expose borrowed config/state containers")
    host.player.position+=Vector2(121,0)
    check(not NETWORK.quote(host,key()).ok,"standing outside source interaction range blocks travel")
    host.player.position=host.active_spawn
    for name in ["heal_timer","attack_timer","skill_timer","dash_timer","grapple_timer","guard_timer","practice_energy","death_timer","heal_reserved_cost","attack_cancel_lock","hurt_timer"]:
        host.player.set(name,1)
        check(not NETWORK.quote(host,key()).ok,"pending resource/action state blocks departure: "+name)
        host.player.set(name,0)
    host.world_save_blocked=true
    check(not NETWORK.quote(host,key()).ok,"unwritable journey blocks departure before scheduling")
    host.world_save_blocked=false
    host.boss_trial_mode=true
    check(not NETWORK.quote(host,key()).ok,"practice worlds never enter the return network")
    host.boss_trial_mode=false
    host.world_loader.phase="loading"
    check(not NETWORK.quote(host,key()).ok,"busy loader cannot accept a competing request")
    host.world_loader.phase="idle"
    host.world_state.data.regions.erase(B)
    check(not NETWORK.quote(host,key()).ok,"deleted destination record invalidates a cached choice")
    # Exact official edge predicate remains the permission oracle.
    var known: Array[String]=[A,B]
    for region in known:
        for portal in ATLAS.configuration(region).get("interactives",[]):
            if String(portal.get("target_config_id","")) not in known:continue
            check(ROUTES.access(portal,counts,flags).open,"positive fixture satisfies actual authored portal conditions")
    check(NETWORK.route(A,B,[A],counts,flags).is_empty(),"unknown intermediate/target region cannot bridge a route")
    var crown:="demo_ch06_silent_crown_core"
    var obsidian:="demo_ch05_obsidian_pilgrim_road"
    var pair: Array[String]=[obsidian,crown]
    check(NETWORK.route(obsidian,crown,pair,{},{}).is_empty(),"known crown station still requires the actual phase ability")
    check(NETWORK.route(obsidian,crown,pair,{"lantern_phase":0},{}).is_empty(),"zero-quantity ability cannot unlock transport")
    check(NETWORK.route(obsidian,crown,pair,{"lantern_phase":1},{})==pair,"real positive ability unlocks the exact known corridor")
    var archive:="demo_ch03_saltwhite_archive"
    var shortcut: Array[String]=[A,archive]
    check(NETWORK.route(A,archive,shortcut,{"double_thread_jump":1},{}).is_empty(),"ability alone cannot replace the authored far-side latch")
    check(NETWORK.route(A,archive,shortcut,{}, {"world_shortcut_archive_return":true}).is_empty(),"open latch alone cannot replace the required ability")
    check(NETWORK.route(A,archive,shortcut,{"double_thread_jump":1},{"world_shortcut_archive_return":true})==shortcut,"actual shortcut requires both permission components")
    host.world_state.data.regions[B]=saved(B)
    check(NETWORK.quote(host,key()).ok,"phase negative control starts from a valid source and target")
    host.player.phase_active=true
    check(not NETWORK.quote(host,key()).ok,"phase traversal cannot be cancelled into transport")
    host.player.phase_active=false
    host.free()

func dispatch_checks() -> void:
    var host:=make_host()
    var quote:=NETWORK.quote(host,key())
    var first:=NETWORK.begin(host,key(),quote.fingerprint)
    check(first.ok and host.world_portal_request_pending and host.player.ui_input_locked,"accepted request owns the input lock until deferred dispatch")
    check(not NETWORK.begin(host,key(),quote.fingerprint).ok,"double confirm cannot queue duplicate transitions")
    var loader: RefCounted=host.world_loader
    await process_frame
    await process_frame
    check(loader.requests==1 and loader.destination==quote.target.position,"exactly one owned request delegates to existing region loader")
    check(host.player.hp==3 and host.player.energy==37 and host.player.velocity==Vector2(13,-4),"dispatch does not heal, refill or change physics")
    host.free()
    host=make_host()
    quote=NETWORK.quote(host,key())
    host.story_flags["state_changed"]=true
    check(not NETWORK.begin(host,key(),quote.fingerprint).ok,"changed quote must be reviewed again")
    quote=NETWORK.quote(host,key())
    NETWORK.begin(host,key(),quote.fingerprint)
    loader=host.world_loader
    host.story_flags["deferred_change"]=true
    await process_frame
    await process_frame
    check(loader.requests==0 and not host.world_portal_request_pending and not host.player.ui_input_locked,"changed deferred authorization cancels and releases only its own lock")
    host.free()
    host=make_host()
    quote=NETWORK.quote(host,key())
    NETWORK.begin(host,key(),quote.fingerprint)
    loader=host.world_loader
    host.world_loader.generation+=1
    host.active_overlay="other_request"
    await process_frame
    await process_frame
    check(loader.requests==0 and host.active_overlay=="other_request" and host.world_portal_request_pending,"obsolete generation cannot unlock or dispatch a newer region's action")
    host.free()
    host=make_host()
    quote=NETWORK.quote(host,key())
    NETWORK.begin(host,key(),quote.fingerprint)
    loader=host.world_loader
    host.free()
    await process_frame
    await process_frame
    check(loader.requests==0,"queued callback holds no strong scene owner and survives immediate destruction")

func source_save_checks() -> void:
    for invalidate in [false,true]:
        var host:=make_host()
        var loader:=PreflightLoader.new()
        host.world_loader=loader
        loader.invalidate=invalidate
        host.save_ok=false
        var quote:=NETWORK.quote(host,key())
        host.world_portal_request_pending=true
        var token: RefCounted=loader.request_shrine_return_transition(host,key(),ROUTES.cached_config_path(B),quote.target.position,quote.fingerprint)
        check(token!=null and loader.phase=="preflight","actual loader owns asynchronous destination preflight")
        await process_frame
        await process_frame
        check(token.finished and not token.succeeded,"failed source checkpoint or changed authorization rejects the real transition token")
        check(loader.evictions==0 and host.player.handoffs==0,"failed source write never tears down source or cancels Player state")
        check(host.player.velocity==Vector2(13,-4) and host.player.hp==3 and host.player.energy==37,"failed preflight preserves source velocity and resources exactly")
        check(loader.phase=="idle" and host.process_mode==Node.PROCESS_MODE_INHERIT and not host.world_portal_request_pending,"failed strict departure restores process mode and clears owned pending state")
        check(host.saves==(0 if invalidate else 1),"authorization is rechecked after asynchronous preflight before the one source write")
        host.free()
        await process_frame

func dialog_checks() -> void:
    var host:=make_host()
    var ui:=UI.new()
    ui.theme=Theme.new()
    ui.theme.default_font=UI.FONT
    ui.theme.default_font_size=18
    ui._install_theme(ui.theme)
    host.add_child(ui)
    host.ui_shell=ui
    host.map_panel=ColorRect.new()
    host.map_panel.size=Vector2(1176,640)
    ui.add_child(host.map_panel)
    host.active_overlay="map"
    DIALOG.setup(host)
    DIALOG.setup(host)
    await process_frame
    var button:=host.map_panel.get_node(DIALOG.BUTTON) as Button
    check(button.position==Vector2(710,550) and button.size==Vector2(134,32),"travel control occupies the reserved gap between pins and itinerary")
    for rect in [LAYOUT.TOOLBAR,LAYOUT.EXPEDITION,LAYOUT.DIRECTORY,LAYOUT.VIEW,LAYOUT.HELP]:
        check(not button.get_rect().intersects(rect),"travel control never overlaps existing map controls or canvas")
    button.pressed.emit()
    var window:=host.map_panel.get_node(DIALOG.WINDOW) as ConfirmationDialog
    check(window.visible and window.get_cancel_button().has_focus(),"native return window opens with safe cancel focused")
    var list:=window.find_child("Stations",true,false) as ItemList
    check(list.item_count==2,"actual UI shows only previously activated shrine rows")
    list.select(1)
    list.item_selected.emit(1)
    check(not window.get_ok_button().disabled,"known destination enables explicit confirmation")
    var loader: RefCounted=host.world_loader
    window.hide()
    window.canceled.emit()
    check(button.has_focus() and loader.requests==0,"cancel returns focus without moving, saving or charging")
    await process_frame
    button.pressed.emit()
    host.map_panel.hide()
    check(not window.visible,"closing map closes its native return window")
    host.free()
    await process_frame
