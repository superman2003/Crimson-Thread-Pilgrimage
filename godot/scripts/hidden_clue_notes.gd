extends RefCounted
## Public notes contain only noticed entrance observations, never reward ids or
## hidden-room identities. Map lookup adds the existing per-segment ink gate.
const ROUTES:=preload("res://scripts/world_routes.gd")
const PINS:=preload("res://scripts/map_player_pins.gd")
const REGIONS:=preload("res://scripts/save_inspector.gd").REGION_NAMES
const SEEN:="hidden_clue_seen_"
const FOUND:="hidden_found_"
const RETRY:="hidden_notice_retry_after"
const RETRY_MSEC:=5000

static func visible(plan: Array, flags: Dictionary) -> Array[Dictionary]:
    var rows: Array[Dictionary]=[]
    var ids:={}
    for entry in plan:
        if not entry is Dictionary or not entry.get("id") is String or not entry.get("region_id") is String:continue
        var id:=String(entry.id)
        if id.is_empty() or ids.has(id) or not REGIONS.has(entry.region_id):continue
        var earned: Variant=flags.get(SEEN+id,false)
        if not earned is bool or not earned:continue
        var clue: Variant=entry.get("clue")
        if not clue is Dictionary or not clue.get("line") is String or String(clue.line).strip_edges().is_empty():continue
        var found: Variant=flags.get(FOUND+id,false)
        rows.append({"id":id,"region":String(entry.region_id),"title":String(clue.get("title","入口观察")),"line":String(clue.line),"state":"found" if found is bool and found else "noticed"})
        ids[id]=true
    return rows

static func journal(plan: Array, flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    for row in visible(plan,flags):
        result.append({"id":"clue_note_"+String(row.id).sha256_text(),"record_kind":"guide","acquired":true,
            "title":"%s · %s" % [String(REGIONS[row.region]),row.title],
            "description":"已记下的入口观察 · %s\n\n%s\n\n%s\n若入口已购图并补绘，可在地图地点目录的入口线索类型中回看；不会自动揭开藏室或奖励。" % [String(REGIONS[row.region]),row.line,status_text(row.state)]})
    return result

static func status_text(state: String) -> String:
    return "已找到这处藏室。入口观察仍可回看，地图是否补绘按实际旅途记录。" if state=="found" else "尚未找到藏室，可沿这条已经观察到的线索回访；留意现场道路与落脚处。"

static func map_records(plan: Array, configs: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    var public:={}
    for row in visible(plan,flags):public[row.id]=row
    for entry in plan:
        if not entry is Dictionary or not public.has(entry.get("id","")):continue
        var row: Dictionary=public[entry.id]
        if not configs.get(row.region) is Dictionary:continue
        var point_value: Variant=entry.get("clue",{}).get("position")
        if not point_value is Array or point_value.size()!=2:continue
        if not preload("res://scripts/world_state.gd")._point(point_value):continue
        var point:=Vector2(point_value[0],point_value[1])
        var config: Dictionary=configs[row.region]
        if not PINS.allowed(flags,row.region,config,point):continue
        var room:=PINS.owner(config,point)
        result.append(preload("res://scripts/map_floor_labels.gd").annotate({"key":"clue:"+row.region+":"+String(row.id).sha256_text(),"kind":"clue","region":row.region,
            "region_name":String(REGIONS[row.region]),"room_id":String(room.id),"point":point,"title":"入口线索 · "+String(row.title),
            "clue_state":row.state,"detail":String(row.line)+"\n"+status_text(row.state)},room))
    return result

static func notice(level: Node) -> void:
    if not level.world_mode or not level.active_overlay.is_empty() or level.world_loading or level.world_save_blocked or level.world_state==null:return
    if not is_instance_valid(level.player) or level.player.hp<=0:return
    for clue in level.hidden_route_clues:
        if not is_instance_valid(clue) or clue.is_queued_for_deletion() or not clue.is_inside_tree() or clue.get_parent()!=level or clue.found:continue
        var entry: Dictionary=clue.get_meta("hidden_route",{})
        if String(entry.get("region_id",""))!=String(level.config.get("id","")):continue
        var flag:=SEEN+String(entry.get("id",""))
        if bool(level.story_flags.get(flag,false)) or level.player.global_position.distance_to(clue.global_position)>level.HIDDEN_CLUE_NOTICE_RANGE:continue
        var now:=Time.get_ticks_msec()
        if now<int(clue.get_meta(RETRY,0)):continue
        var flags: Dictionary=level.story_flags.duplicate(true)
        flags[flag]=true
        var saved: Dictionary=level._persist_world_change({"story_flags":flags})
        if not saved.ok:
            # Retain the old journal and checkpoint; don't retry disk I/O every
            # rendered frame while the player remains beside this same crack.
            clue.set_meta(RETRY,now+RETRY_MSEC)
            level._toast(String(entry.clue.line)+"\n线索暂未写入，将稍后重试；原记录保持不变。")
            return
        level.world_state.data=saved.candidate
        level.story_flags=flags
        if clue.has_meta(RETRY):clue.remove_meta(RETRY)
        level._toast(String(entry.clue.line))
        return
