extends RefCounted
## A return network over actual visited regions and their latest authored shrine.
## No discovery, currency, HP, energy, equipment, or route flags are granted.
const ROUTES:=preload("res://scripts/world_routes.gd")
const ATLAS:=preload("res://scripts/world_atlas.gd")
const NAMES:=preload("res://scripts/save_inspector.gd").REGION_NAMES
const REQUEST:="shrine_return_request"
const MAX_REGIONS:=16
const REACH:=120.0

static func point(value: Variant) -> Vector2:
    if value is Vector2:return value if value.is_finite() else Vector2.INF
    if not value is Array or value.size()!=2:return Vector2.INF
    for component in value:
        if not (component is int or component is float) or not is_finite(float(component)):return Vector2.INF
    return Vector2(value[0],value[1])

static func station(region: String, saved: Dictionary, data: Dictionary) -> Dictionary:
    var id:=String(saved.get("checkpoint_id",""))
    if id.is_empty() or id in ["start","boss_trial"] or not NAMES.has(region):return {}
    var checkpoint:=point(saved.get("checkpoint",null))
    if not checkpoint.is_finite():return {}
    for save_point in data.get("save_points",[]):
        if String(save_point.get("id",""))!=id:continue
        var position:=point(save_point.get("position",null))
        if not position.is_finite() or checkpoint.distance_to(position)>0.5:return {}
        return {"key":region+":"+id,"region":region,"id":id,"position":position,
            "title":String(save_point.get("label",save_point.get("name","钟龛"))),"region_name":String(NAMES[region])}
    return {}

static func stations(level: Node) -> Array[Dictionary]:
    var rows: Array[Dictionary]=[]
    if not ROUTES.cache_is_current() or level.world_state==null:return rows
    var saved: Variant=level.world_state.data.get("regions",{})
    if not saved is Dictionary:return rows
    for region in NAMES:
        if rows.size()>=MAX_REGIONS:break
        if not saved.get(region) is Dictionary:continue
        var row:=station(region,saved[region],ATLAS.configuration(region))
        if not row.is_empty():rows.append(row)
    return rows

static func known_regions(level: Node) -> Array[String]:
    var known: Array[String]=[]
    if level.world_state==null:return known
    var saved: Variant=level.world_state.data.get("regions",{})
    if not saved is Dictionary:return known
    for region in NAMES:
        var record: Variant=saved.get(region,{})
        if not record is Dictionary:continue
        var visits: Variant=record.get("visited_rooms",{})
        if visits is Dictionary and visits.values().has(true):known.append(String(region))
        elif not station(region,record,ATLAS.configuration(region)).is_empty():known.append(String(region))
    var current:=String(level.config.get("id",""))
    if NAMES.has(current) and not known.has(current):known.append(current)
    return known

static func route(source: String, target: String, known: Array[String], inventory: Dictionary, flags: Dictionary) -> Array[String]:
    var empty: Array[String]=[]
    if not ROUTES.cache_is_current() or not known.has(source) or not known.has(target):return empty
    var queue: Array[String]=[source]
    var paths: Dictionary={source:[source]}
    while not queue.is_empty() and paths.size()<=MAX_REGIONS:
        var region: String=queue.pop_front()
        if region==target:
            var result: Array[String]=[]
            result.assign(paths[region])
            return result
        for portal in ATLAS.configuration(region).get("interactives",[]):
            if String(portal.get("kind",""))!="world_portal":continue
            var next:=String(portal.get("target_config_id",""))
            if not known.has(next) or paths.has(next):continue
            if not bool(ROUTES.access(portal,inventory,flags).open):continue
            paths[next]=paths[region]+[next]
            queue.append(next)
    return empty

static func unavailable(reason: String) -> Dictionary:return {"ok":false,"reason":reason}

static func source_station(level: Node, preflight: bool=false) -> Dictionary:
    if not is_instance_valid(level) or not level.is_inside_tree() or level.is_queued_for_deletion():return {}
    if not level.world_mode or level.boss_trial_mode or level.world_loading or level.chapter_transitioning or level.world_save_blocked:return {}
    if not is_instance_valid(level.player) or level.player.hp<=0 or level.player.death_timer>0:return {}
    if is_instance_valid(level.boss_arena_lock_body) or level._walking_world_passage():return {}
    var loader: Variant=level.world_loader
    if loader==null or loader.shutting_down or loader.phase!=("preflight" if preflight else "idle"):return {}
    if not preflight and level.world_portal_request_pending:return {}
    if bool(level.player.get("phase_active")):return {}
    # Do not cancel paid healing, attacks, guard or traversal to obtain transport.
    for name in ["heal_timer","attack_timer","skill_timer","dash_timer","grapple_timer","guard_timer","practice_energy","heal_reserved_cost","attack_cancel_lock","hurt_timer"]:
        var value: Variant=level.player.get(name)
        if (value is int or value is float) and float(value)>0.0:return {}
    var row:=station(String(level.config.get("id","")),{"checkpoint_id":level.active_save_point_id,"checkpoint":level.active_spawn},level.config)
    if row.is_empty() or level.player.global_position.distance_to(row.position)>REACH:return {}
    # A saved coordinate alone cannot impersonate the currently installed shrine.
    var area:=level.get_node_or_null(NodePath(String(row.id))) as Area2D
    if area==null or area.is_queued_for_deletion() or not area.is_visible_in_tree() or String(area.get_meta("kind",""))!="save_point":return {}
    if area.global_position.distance_to(row.position)>0.5:return {}
    return row

static func quote(level: Node, key: String, preflight: bool=false) -> Dictionary:
    if not ROUTES.cache_is_current():return unavailable("路线记录正在更新，请稍后重试。")
    var source:=source_station(level,preflight)
    if source.is_empty():return unavailable("请先在当前钟龛安坐，结束动作后在钟龛旁出发。")
    var selected: Dictionary={}
    for row in stations(level):
        if row.key==key:selected=row;break
    if selected.is_empty():return unavailable("这座钟龛尚无可靠的安坐记录。")
    if selected.region==source.region:return unavailable("你已经在本区；请沿现场道路前往其它钟龛。")
    var known:=known_regions(level)
    var path:=route(source.region,selected.region,known,level.inventory_counts,level.story_flags)
    if path.is_empty():return unavailable("已知道路的能力或门闩条件尚未满足，暂不能沿钟路返回。")
    var fingerprint:=var_to_str([source,selected,path,known,ROUTES.cached_generation(),level.inventory_counts,level.story_flags,level.player.hp,level.player.energy]).sha256_text()
    return {"ok":true,"source":source,"target":selected,"path":path,"cost":0,"fingerprint":fingerprint,
        "reason":"返回 %s · %s\n沿已知且条件已满足的钟路；不收碎钱，不补充生命、绯线或战具。" % [selected.region_name,selected.title]}

static func begin(level: Node, key: String, fingerprint: String) -> Dictionary:
    if level.has_meta(REQUEST):return unavailable("已有一程钟路正在准备。")
    var current:=quote(level,key)
    if not current.ok:return current
    if current.fingerprint!=fingerprint:return unavailable("道路或归途记录已变化，请重新核对这次行程。")
    level._close_overlays()
    level.active_overlay="shrine_return"
    level._sync_ui_input_lock()
    level.world_portal_request_pending=true
    var packet:={"key":key,"fingerprint":fingerprint,"generation":level.world_loader.generation}
    level.set_meta(REQUEST,packet)
    dispatch.call_deferred(weakref(level),packet)
    return {"ok":true}

static func dispatch(reference: WeakRef, packet: Dictionary) -> void:
    var level: Variant=reference.get_ref()
    if not is_instance_valid(level) or level.is_queued_for_deletion() or not level.is_inside_tree():return
    if level.get_meta(REQUEST,{})!=packet:return
    level.remove_meta(REQUEST)
    # Main survives region replacement. Never unlock a new generation's request.
    if level.world_loader==null or level.world_loader.generation!=packet.generation:return
    level.world_portal_request_pending=false
    if level.active_overlay=="shrine_return":level.active_overlay="";level._sync_ui_input_lock()
    var current:=quote(level,String(packet.key))
    if not current.ok or current.fingerprint!=packet.fingerprint:
        level._toast(String(current.get("reason","行程记录已变化，请重新核对。")))
        return
    level.world_portal_request_pending=true
    var token: Variant=level.world_loader.request_shrine_return_transition(level,String(packet.key),ROUTES.cached_config_path(current.target.region),current.target.position,String(packet.fingerprint))
    if token==null:
        level.world_portal_request_pending=false
        level._toast("钟路尚未准备好，请重新核对。")
