extends RefCounted
## Consume public directory rows and a conservative path callback. Never load
## another region, discover a hidden stop, or mark a planned leg as travelled.
static func collect(state: Dictionary, known: Array, region: String, current_room: String, position_allowed: bool, route: Callable) -> Array:
    var index: Dictionary={}
    for row in known:
        if row is Dictionary and row.get("key") is String:index[row.key]=row
    var result: Array=[]
    var previous: Dictionary={"region":region,"room_id":current_room,"title":"当前位置"} if position_allowed else {}
    for key in state.get("stops",[]).slice(0,6):
        var done: bool=state.get("done",[]).has(key)
        var deferred: bool=state.get("deferred",[]).has(key)
        if not index.has(key):
            result.append({"title":"地点暂不可见","state":"已勾选" if done else "暂缓" if deferred else "待核对","kind":"unavailable","rooms":[]})
            if not done and not deferred:previous={}
            continue
        var target: Dictionary=index[key]
        var leg: Dictionary={"title":String(target.get("title","已知地点")),"region_name":String(target.get("region_name","")),"state":"已勾选" if done else "暂缓" if deferred else "待前往","kind":"skipped","rooms":[]}
        if done or deferred:
            result.append(leg)
            continue
        if previous.is_empty():
            leg.kind="no_origin"
        elif previous.get("region")!=target.get("region"):
            leg.kind="cross_region"
            leg["from"]=String(previous.get("title","上一站"))
        elif target.get("region")!=region:
            leg.kind="other_region"
        elif route.is_valid():
            var path: Variant=route.call(String(previous.get("room_id","")),String(target.get("room_id","")))
            if path is Array and not path.is_empty():
                leg.kind="known_chain"
                leg.rooms=path.duplicate()
            else:leg.kind="no_chain"
            leg["from"]=String(previous.get("title","上一站"))
        else:leg.kind="no_chain"
        previous=target.duplicate(true)
        result.append(leg)
    return result

static func describe(legs: Array, names: Dictionary) -> String:
    var lines: Array[String]=["逐站行程核对", "只核对未勾选、未暂缓站点的计划顺序；不会传送或确认实际通行。"]
    var number:=0
    for leg in legs:
        number+=1
        lines.append("\n%d. %s · %s · %s" % [number,String(leg.get("region_name","")),String(leg.title),String(leg.state)])
        match String(leg.kind):
            "unavailable":lines.append("地点不在当前已补绘目录中；未显示其名称或路线。")
            "skipped":lines.append("此站不参与本次待行路线的连接。")
            "no_origin":lines.append("没有可公开的起点。装备罗盘或开启导航辅助后可核对当前位置至首站；后续两站之间仍可按已知地点核对。")
            "cross_region":lines.append("从「%s」跨区前往；不推测尚未核对的跨区通道。" % String(leg.get("from","上一站")))
            "other_region":lines.append("两站均在另一地区；需抵达该区后核对现场已知道路。")
            "no_chain":lines.append("从上一计划起点没有满足现有能力、捷径和完整补绘条件的邻接链。")
            "known_chain":
                var labels: Array[String]=[]
                for room in leg.rooms:labels.append(String(names.get(room,"已补绘房间")))
                lines.append("从「%s」：%s" % [String(leg.get("from","上一站"))," → ".join(labels)])
                lines.append("邻接%d段；落点、敌人与实时机关仍须现场确认。" % maxi(0,leg.rooms.size()-1))
    if legs.is_empty():lines.append("\n行程尚无站点，请先从已知地点加入。")
    lines.append("\n这份核对按打开时的地图与能力生成；改变行程或世界状态后，请关闭并重新核对。")
    return "\n".join(lines)
