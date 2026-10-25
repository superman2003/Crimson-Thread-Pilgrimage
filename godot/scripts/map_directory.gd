extends RefCounted
## An index of already inked places. No player position or travel operation.
const JOURNAL = preload("res://scripts/pilgrimage_cartography.gd")
const KNOWLEDGE = preload("res://scripts/survey_map_knowledge.gd")
const PINS = preload("res://scripts/map_player_pins.gd")
const SURVEY = preload("res://scripts/cartography_runtime.gd")

static func records(configs: Dictionary, flags: Dictionary, inventory: Dictionary, opened: Dictionary) -> Array:
    var result: Array = []
    var safe := flags.duplicate(true)
    for region in configs:
        var journals: Variant = safe.get(JOURNAL.KEY,{})
        if not journals is Dictionary or not journals.get(region) is Dictionary:continue
        var journal: Dictionary = journals[region]
        if not journal.get("owned") is bool or not journal.owned:continue
        var config: Dictionary = configs[region]
        var known := {}
        var anchors := {}
        for room in config.get("map_rooms",[]):
            if not JOURNAL.charted_any(safe,region,room):continue
            var point := _room_anchor(config,safe,region,room)
            if not point.is_finite():continue
            known[String(room.id)] = room
            anchors[String(room.id)]=point
        for id in known:
            result.append(_record("room",id,region,config,known[id],anchors[id],_known_neighbors(config,known,id)))
        var markers: Array = KNOWLEDGE.marker_records(config,safe,region,inventory)
        markers.append_array(KNOWLEDGE.shortcut_records(config,safe,region,opened))
        for marker in markers:
            if not known.has(marker.room_id):continue
            var point: Vector2 = marker.rect.get_center()
            if not PINS.allowed(safe,region,config,point):continue
            var room: Dictionary = known[marker.room_id]
            var item := _record(String(marker.kind),String(marker.id),region,config,room,point,String(marker.tooltip))
            item.title = {"hazard":"已知危险","gate":"能力门","shortcut":"捷径"}.get(marker.kind,marker.kind) + " · " + String(room.get("name",room.id))
            result.append(item)
    for pin in PINS.visible(safe,configs):
        var config: Dictionary = configs[pin.region_id]
        var point := Vector2(pin.position[0],pin.position[1])
        var room := PINS.owner(config,point)
        var item := _record("pin",str(pin.id),pin.region_id,config,room,point,"玩家自己的已知标记；查看不会移动角色。")
        item.title = "%s图钉 #%d · %s" % [PINS.NAMES[PINS.KINDS.find(pin.kind)],int(pin.id),String(room.get("name",room.id))]
        result.append(item)
    return result

static func _known_neighbors(config: Dictionary, known: Dictionary, id: String) -> String:
    var lines: Array[String]=["已补绘房间 · "+String(known[id].get("name",id))]
    var seen:={}
    for connection in config.get("connections",[]):
        var a:=String(connection.get("from",""));var b:=String(connection.get("to",""))
        var target:=b if a==id else a if b==id else ""
        if not known.has(target) or target==id or seen.has(target):continue
        seen[target]=true
        var delta:=SURVEY.room_rect(known[target]).get_center().y-SURVEY.room_rect(known[id]).get_center().y
        lines.append(("↑ 较高" if delta < -64 else "↓ 较低" if delta > 64 else "↔ 同高")+"："+String(known[target].get("name",target)))
    lines.append("只列已补绘邻室；邻接不代表道路已经开放。")
    return "\n".join(lines)

static func _room_anchor(config: Dictionary, flags: Dictionary, region: String, room: Dictionary) -> Vector2:
    for part in JOURNAL.charted_parts(flags,region,room):
        for ratio in [Vector2(0.5,0.5),Vector2(0.25,0.25),Vector2(0.75,0.75)]:
            var point: Vector2 = part.position + part.size * ratio
            var owner := PINS.owner(config,point)
            if not owner.is_empty() and owner.id == room.id and PINS.allowed(flags,region,config,point):return point
    return Vector2.INF

static func _record(kind: String, id: String, region: String, config: Dictionary, room: Dictionary, point: Vector2, detail: String) -> Dictionary:
    return {"key":kind+":"+region+":"+id,"kind":kind,"region":region,"region_name":String(config.get("chapter_name",region)),
        "room_id":String(room.get("id","")),"title":String(room.get("name",room.get("id",""))),"point":point,"detail":detail}

static func search(rows: Array, query: String, kind: String = "all") -> Array:
    var result: Array = []
    var tokens := query.left(64).to_lower().strip_edges().split(" ",false)
    for row in rows:
        if kind != "all" and row.kind != kind:continue
        var text := (String(row.title)+" "+String(row.region_name)+" "+String(row.detail)).to_lower()
        var matches := true
        for token in tokens:
            if not text.contains(token):matches=false;break
        if matches:result.append(row)
    return result
