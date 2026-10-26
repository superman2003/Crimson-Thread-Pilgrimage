extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const GRAPH := preload("res://journey/fieldwork/network/model.gd")
const BOARD := preload("res://journey/fieldwork/return_notes/board.gd")


static func introduction() -> String:
    return "为已经抵达的房间保留复访问题、个人优先级和已核对标记，比较两次观察中的已知通路规则。几何距离和复查排序不代表现场安全或最短路线。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var graph := GRAPH.capture(snapshot)
    var rooms := []
    var priorities := {}
    var questions := {}
    for node in graph.nodes:
        var links := []
        for edge in graph.edges:
            if edge.from == node.id:
                links.append({"to": edge.to, "open": edge.open, "reason": edge.reason})
        rooms.append(
            {
                "id": node.id,
                "name": node.name,
                "point": node.point,
                "kind": node.kind,
                "links": links
            }
        )
        priorities[node.id] = 1.0
        questions[node.id] = ""
    return {
        "region": String(snapshot.get("region", "")),
        "recorded": int(snapshot.get("timestamp", 0)),
        "origin": snapshot.get("player", {}).get("position", [0, 0]),
        "rooms": rooms,
        "room": String(graph.source) if not rooms.is_empty() else "",
        "priorities": priorities,
        "questions": questions,
        "reviewed": [],
        "distance_weight": 1.0,
        "show_reviewed": false,
        "tags": "",
        "question": ""
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("rooms") is Array
        or payload.rooms.size() > 120
        or not payload.get("region") is String
        or not payload.get("room") is String
    ):
        return false
    if (
        not V.count(payload.get("recorded"), 9999999999)
        or not V.point(payload.get("origin")).is_finite()
        or not payload.get("show_reviewed") is bool
    ):
        return false
    if (
        not V.number(payload.get("distance_weight"))
        or payload.distance_weight < 0
        or payload.distance_weight > 10
    ):
        return false
    for key in ["tags", "question"]:
        if not payload.get(key) is String or payload[key].length() > 1000:
            return false
    var ids := {}
    for row in payload.rooms:
        if (
            not row is Dictionary
            or not row.get("id") is String
            or ids.has(row.id)
            or not row.get("name") is String
            or not row.get("kind") is String
            or not V.point(row.get("point")).is_finite()
        ):
            return false
        if not row.get("links") is Array or row.links.size() > 120:
            return false
        ids[row.id] = true
    if (not payload.rooms.is_empty() and not ids.has(payload.room)) or (payload.rooms.is_empty() and not payload.room.is_empty()):
        return false
    for row in payload.rooms:
        for link in row.links:
            if (
                not link is Dictionary
                or not ids.has(link.get("to"))
                or not link.get("open") is bool
                or not link.get("reason") is String
            ):
                return false
    for key in ["priorities", "questions"]:
        if not payload.get(key) is Dictionary or payload[key].size() > 120:
            return false
        for id in payload[key]:
            if not ids.has(id):
                return false
            if (
                key == "priorities"
                and (
                    not V.number(payload[key][id]) or payload[key][id] < 0 or payload[key][id] > 100
                )
            ):
                return false
            if (
                key == "questions"
                and (not payload[key][id] is String or payload[key][id].length() > 1000)
            ):
                return false
    if not payload.get("reviewed") is Array or payload.reviewed.size() > 120:
        return false
    var seen := {}
    for id in payload.reviewed:
        if not ids.has(id) or seen.has(id):
            return false
        seen[id] = true
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    var focused := []
    for row in payload.rooms:
        choices.append({"id": row.id, "name": row.name})
        if row.id == payload.room:
            focused.append({"id": row.id, "name": row.name})
    return [
        {"id": "room", "name": "编辑哪个已知房间", "kind": "choice", "choices": choices},
        {"id": "questions", "name": "此房间的个人复访问题", "kind": "notes", "choices": focused, "max": 1000},
        {
            "id": "priorities",
            "name": "个人复访优先级",
            "kind": "weights",
            "choices": choices,
            "min": 0,
            "max": 100
        },
        {"id": "reviewed", "name": "个人已核对标记", "kind": "checklist", "choices": choices},
        {
            "id": "distance_weight",
            "name": "排序中的直线距离权重",
            "kind": "number",
            "min": 0,
            "max": 10,
            "step": 0.1
        },
        {"id": "show_reviewed", "name": "显示已核对条目", "kind": "toggle"},
        {"id": "tags", "name": "这份记录的个人标签", "max": 1000},
        {"id": "question", "name": "总体复查问题", "max": 1000}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d 个已抵达房间 · 已核对%d个 · %s"
        % [payload.rooms.size(), payload.reviewed.size(), V.date(int(payload.recorded))]
    )


static func index(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in payload.rooms:
        result[row.id] = row
    return result


static func ranked(payload: Dictionary) -> Array:
    var result := []
    var origin := V.point(payload.origin)
    var farthest := 1.0
    for room in payload.rooms:
        farthest = maxf(farthest, origin.distance_to(V.point(room.point)))
    for room in payload.rooms:
        var done: bool = payload.reviewed.has(room.id)
        if done and not payload.show_reviewed:
            continue
        var distance := origin.distance_to(V.point(room.point))
        var priority := float(payload.priorities.get(room.id, 1))
        var note := String(payload.questions.get(room.id, ""))
        var score := priority - float(payload.distance_weight) * distance / farthest
        if not note.strip_edges().is_empty():
            score += 1
        if done:
            score -= 1
        result.append(
            {
                "id": room.id,
                "房间": room.name,
                "类型": room.kind,
                "个人优先级": priority,
                "直线距离": distance,
                "个人复查问题": note,
                "已核对": done,
                "排序分": score,
                "当前允许出边": room.links.filter(func(edge: Dictionary): return edge.open).size()
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if not is_equal_approx(float(a["排序分"]), float(b["排序分"])):
                return float(a["排序分"]) > float(b["排序分"])
            return String(a.id) < String(b.id)
    )
    return result


static func changes(a: Dictionary, b: Dictionary) -> Array:
    if a.region != b.region:
        return []
    var old := index(a)
    var result := []
    var current := index(b)
    for room in a.rooms:
        if not current.has(room.id):
            result.append({"房间": room.name, "变化": "本次未包含房间", "详情": "原观察中的房间已不在本次样本"})
    for room in b.rooms:
        if not old.has(room.id):
            result.append({"房间": room.name, "变化": "新增已抵达房间", "详情": "旧观察没有包含此房间"})
            continue
        var before: Dictionary = old[room.id]
        if before.point != room.point:
            result.append(
                {
                    "房间": room.name,
                    "变化": "设计参考中心变化",
                    "详情": str(before.point) + " → " + str(room.point)
                }
            )
        var links := {}
        for edge in before.links:
            links[edge.to] = edge
        var current_links := {}
        for edge in room.links:
            current_links[edge.to] = true
            if not links.has(edge.to):
                result.append(
                    {
                        "房间": room.name,
                        "变化": "新增已知规则",
                        "详情": String(index(b).get(edge.to, {}).get("name", "已知空间"))
                    }
                )
            elif bool(links[edge.to].open) != bool(edge.open):
                result.append({"房间": room.name, "变化": "当前通行规则变化", "详情": String(edge.reason)})
        for target in links:
            if not current_links.has(target):
                result.append({"房间": room.name, "变化": "已知规则移除", "详情": String(old.get(target, {}).get("name", target))})
    return result


static func question_rows(payload: Dictionary) -> Array:
    var result := []
    var rooms := index(payload)
    for id in payload.questions:
        var text := String(payload.questions[id]).strip_edges()
        if text.is_empty():
            continue
        result.append(
            {
                "房间": rooms[id].name,
                "个人复访问题": text,
                "字符数": text.length(),
                "个人优先级": float(payload.priorities.get(id, 1)),
                "已核对": payload.reviewed.has(id)
            }
        )
    return result


static func rule_rows(payload: Dictionary) -> Array:
    var nodes := index(payload)
    var result := []
    for room in payload.rooms:
        for edge in room.links:
            result.append(
                {
                    "起点": room.name,
                    "已知终点": nodes[edge.to].name,
                    "当前规则允许": edge.open,
                    "规则说明": edge.reason
                }
            )
    return result


static func histogram(payload: Dictionary) -> Dictionary:
    var result := {"已有个人问题": 0, "尚无个人问题": 0, "个人已核对": 0, "个人未核对": 0}
    for room in payload.rooms:
        result["已有个人问题" if not String(payload.questions.get(room.id, "")).strip_edges().is_empty() else "尚无个人问题"] += 1
        result["个人已核对" if payload.reviewed.has(room.id) else "个人未核对"] += 1
    return result


static func compass_data(payload: Dictionary) -> Dictionary:
    var markers := []
    var radius := 1.0
    var origin := V.point(payload.origin)
    for room in payload.rooms:
        if payload.reviewed.has(room.id) and not payload.show_reviewed:
            continue
        markers.append({"id": room.id, "name": room.name, "point": room.point, "kind": room.kind})
        radius = maxf(radius, origin.distance_to(V.point(room.point)))
    return {
        "markers": markers, "origin": payload.origin, "radius": radius, "heading": 0.0, "fov": 90.0
    }


static func priority_study(payload: Dictionary) -> Array:
    var result := []
    for weight in [0.0, 0.5, 1.0, 2.0, 5.0]:
        var sample := payload.duplicate(true)
        sample.distance_weight = float(weight)
        var rows := ranked(sample)
        var names: Array[String] = []
        for row in rows.slice(0, 3):
            names.append(row["房间"])
        result.append({"个人距离权重": weight, "前三个参考目标": " → ".join(names), "待复查房间": payload.rooms.filter(func(room: Dictionary): return not payload.reviewed.has(room.id)).size()})
    return result


static func history(records: Array, region: String) -> Array:
    var result := []
    for record in records.slice(0, 60):
        var payload: Dictionary = record.get("payload", {})
        if validate(payload) and payload.region == region:
            result.append(
                {
                    "id": record.id,
                    "name": record.title,
                    "time": payload.recorded,
                    "payload": payload
                }
            )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if int(a.time) == int(b.time):
                return int(a.id) < int(b.id)
            return int(a.time) < int(b.time)
    )
    return result


static func history_sections(records: Array, current: Dictionary) -> Array:
    var observations := history(records, String(current.region))
    var rows := []
    for record in observations:
        var changed := changes(record.payload, current)
        rows.append(
            {
                "记录": record.name,
                "记录时间": V.date(int(record.time)),
                "与当前不同的已知规则条目": changed.size(),
                "已知房间": record.payload.rooms.size(),
                "个人已核对": record.payload.reviewed.size()
            }
        )
    var latest_changes := []
    if not observations.is_empty():
        latest_changes = changes(observations[-1].payload, current)
    return [
        K.table("同地区已存观察", ["记录", "记录时间", "与当前不同的已知规则条目", "已知房间", "个人已核对"], rows),
        K.table("最近同区观察之后", ["房间", "变化", "详情"], latest_changes),
        K.notice("历史边界", "观察记录不是实际录像；这里只能确认两个快照之间存在差异，不能确定差异发生时刻。")
    ]


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    return [
        K.notice("个人复访台", summary(payload)),
        {
            "kind": "custom",
            "title": "个人待复查问题与方位",
            "view": BOARD,
            "data": {"payload": payload, "rows": ranked(payload), "compass": compass_data(payload)}
        },
        K.table(
            "个人复访排序", ["房间", "类型", "个人优先级", "直线距离", "个人复查问题", "已核对", "当前允许出边"], ranked(payload)
        ),
        K.table("个人问题清单", ["房间", "个人复访问题", "字符数", "个人优先级", "已核对"], question_rows(payload)),
        K.table("当前已知通路规则", ["起点", "已知终点", "当前规则允许", "规则说明"], rule_rows(payload)),
        K.bars("个人复查状态", histogram(payload)),
        K.table("个人排序参数比较", ["个人距离权重", "前三个参考目标", "待复查房间"], priority_study(payload)),
        K.notice("个人标签", String(payload.tags)),
        K.notice("总体问题", String(payload.question)),
        K.notice("复查边界", "只引用已抵达房间与两端已知的规则。个人核对不是游戏完成标记；方位与排序没有模拟实际路径、碰撞和危险。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    if a.region != b.region:
        return [K.notice("地区不同", "不同地区不按同名房间标识合并。请从记录库选择同地区观察。")]
    var result := changes(a, b)
    var old := index(a)
    var questions := []
    for room in b.rooms:
        if old.has(room.id) and a.questions.get(room.id, "") != b.questions.get(room.id, ""):
            questions.append(
                {
                    "房间": room.name,
                    "旧个人问题": String(a.questions.get(room.id, "")),
                    "新个人问题": String(b.questions.get(room.id, ""))
                }
            )
    return [
        K.table("已知空间与规则变化", ["房间", "变化", "详情"], result),
        K.table("个人复访问题变化", ["房间", "旧个人问题", "新个人问题"], questions)
    ]
