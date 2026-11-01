extends RefCounted
## Read-only recovery information. Location detail follows inked map knowledge;
## region adjacency and straight-line distance never promise a walkable route.
const STATE:=preload("res://scripts/world_state.gd")
const RECALL:=preload("res://scripts/death_recall.gd")
const PINS:=preload("res://scripts/map_player_pins.gd")
const FLOORS:=preload("res://scripts/map_floor_labels.gd")

static func describe(cache: Variant, flags: Dictionary, configs: Dictionary, current: String) -> Dictionary:
    var result:={"present":false,"locatable":false,"text":"目前没有留下碎钱的归途结。","fingerprint":""}
    if not STATE._valid_death_cache(cache):
        result.text="归途结记录不完整，暂不能定位；原记录保持不变。"
        return result
    if cache.is_empty() or int(cache.currency)<=0:return result
    var amount:=int(cache.currency)
    var region:=String(cache.region_id)
    var point:=Vector2(cache.position[0],cache.position[1])
    var lines: Array[String]=["遗留碎钱：%d枚；亲自触及归途结可全数收回。" % amount]
    result.present=true
    result.fingerprint=var_to_str(cache).sha256_text()
    if configs.get(region) is Dictionary:
        var config: Dictionary=configs[region]
        var where:=String(config.get("chapter_name","已知地区"))
        lines.append("所在地区：%s%s" % [where,"（本区）" if region==current else ""])
        if PINS.allowed(flags,region,config,point):
            var room:=PINS.owner(config,point)
            var detail:=FLOORS.annotate({"room_id":String(room.id)},room)
            lines.append("已补绘位置："+String(room.get("name",room.id))+" · "+String(detail.get("floor_name","")))
            result.locatable=true
            result.region=region
            result.point=point
        else:lines.append("落点尚未补绘到地图；不会据此揭开房间或秘密。")
    else:lines.append("地点尚无可靠的已知地区记录，暂不显示名称或坐标。")
    if RECALL.bosses_defeated(flags)>=RECALL.REQUIRED_BOSSES:
        var kept:=int(floor(amount*RECALL.KEEP_RATIO))
        lines.append("钟龛召回：保留%d枚，失去%d枚。请在钟龛安坐后另行确认。" % [kept,amount-kept])
    else:
        lines.append("击败%d位守门者后，可在钟龛选择保留六成的远程召回（当前%d/%d）。" % [RECALL.REQUIRED_BOSSES,RECALL.bosses_defeated(flags),RECALL.REQUIRED_BOSSES])
    lines.append("再次倒下会以新结替换旧结。能力与装备保留；查看地图不会收取或移动归途结。")
    lines.append("地图定位仅改变视野；路上的能力门、危险与未开放道路仍需自行判断。")
    result.text="\n\n".join(lines)
    return result
