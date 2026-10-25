extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")


static func introduction() -> String:
    return "为实际到过的房间建立现场档案，保存空间、当前位置与个人复访问题；不会显示未抵达房间或更改地图知识。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var result := {
        "rooms": [],
        "origin": snapshot.get("player", {}).get("position", [0, 0]),
        "radius": 50000.0,
        "order": "name",
        "focus": "all",
        "region": String(snapshot.get("region", "")),
        "room": String(snapshot.get("room", "")),
        "recorded": int(snapshot.get("timestamp", 0)),
        "question": ""
    }
    for source in K.rooms(snapshot).slice(0, 600):
        var rect := K.rectangle(source.get("layout_rect", []))
        if rect.size == Vector2.ZERO:
            continue
        result.rooms.append(
            {
                "id": source.id,
                "name": String(source.get("name", source.id)),
                "kind": String(source.get("kind", "room")),
                "bounds": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
                "objective": String(source.get("objective", "")),
                "danger": String(source.get("danger", ""))
            }
        )
    return result


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("rooms") is Array
        or payload.rooms.size() > 600
        or not V.point(payload.get("origin")).is_finite()
    ):
        return false
    if (
        not payload.get("region") is String
        or not payload.get("room") is String
        or not V.count(payload.get("recorded"), 9999999999)
    ):
        return false
    if (
        payload.get("order") not in ["name", "distance", "area"]
        or payload.get("focus") not in ["all", "entry", "boss", "hub", "room"]
    ):
        return false
    if (
        not V.number(payload.get("radius"))
        or float(payload.radius) < 1
        or float(payload.radius) > 100000
    ):
        return false
    if not payload.get("question") is String or payload.question.length() > 500:
        return false
    var ids := {}
    for row in payload.rooms:
        if not row is Dictionary or not row.get("id") is String or ids.has(row.id):
            return false
        for field in ["name", "kind", "objective", "danger"]:
            if not row.get(field) is String or row[field].length() > 2000:
                return false
        if K.rectangle(row.get("bounds")) == Rect2():
            return false
        ids[row.id] = true
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(_payload: Dictionary) -> Array:
    return [
        {"id": "radius", "name": "邻近参考半径", "kind": "number", "min": 1, "max": 100000, "step": 100},
        {
            "id": "order",
            "name": "档案排序",
            "kind": "choice",
            "choices":
            [
                {"id": "name", "name": "房间名称"},
                {"id": "distance", "name": "离记录点距离"},
                {"id": "area", "name": "空间面积"}
            ]
        },
        {
            "id": "focus",
            "name": "房间类型",
            "kind": "choice",
            "choices":
            [
                {"id": "all", "name": "全部已抵达"},
                {"id": "entry", "name": "入口"},
                {"id": "boss", "name": "首领空间"},
                {"id": "hub", "name": "枢纽"},
                {"id": "room", "name": "普通空间"}
            ]
        },
        {"id": "question", "name": "复访问题", "max": 500}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d 个已抵达房间 · %s · %s"
        % [payload.rooms.size(), payload.region, V.date(int(payload.recorded))]
    )


static func rows(payload: Dictionary) -> Array:
    var result := []
    var origin := V.point(payload.origin)
    for room in payload.rooms:
        if payload.focus != "all" and room.kind != payload.focus:
            continue
        var rect := K.rectangle(room.bounds)
        var distance := origin.distance_to(rect.get_center())
        if distance > float(payload.radius):
            continue
        result.append(
            {
                "房间": room.name,
                "类型": room.kind,
                "宽": rect.size.x,
                "高": rect.size.y,
                "面积": rect.get_area(),
                "中心距离": snappedf(distance, 0.1),
                "目标": room.objective,
                "风险札记": room.danger,
                "id": room.id
            }
        )
    var key: String = {"name": "房间", "distance": "中心距离", "area": "面积"}[payload.order]
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if a[key] == b[key]:
                return String(a.id) < String(b.id)
            return a[key] < b[key]
    )
    return result


static func extent(payload: Dictionary) -> Rect2:
    var first := true
    var rect := Rect2()
    for room in payload.rooms:
        var item := K.rectangle(room.bounds)
        rect = item if first else rect.merge(item)
        first = false
    return rect


static func overlaps(payload: Dictionary) -> Array:
    var result := []
    for i in payload.rooms.size():
        var a: Dictionary = payload.rooms[i]
        for j in range(i + 1, payload.rooms.size()):
            var b: Dictionary = payload.rooms[j]
            var overlap := K.rectangle(a.bounds).intersection(K.rectangle(b.bounds))
            if overlap.get_area() <= 0:
                continue
            result.append({"房间甲": a.name, "房间乙": b.name, "空间交叠": overlap.get_area()})
            if result.size() >= 80:
                return result
    return result


static func nearest(payload: Dictionary, count: int = 5) -> Array:
    var sample := payload.duplicate(true)
    sample.order = "distance"
    sample.focus = "all"
    sample.radius = 100000.0
    return rows(sample).slice(0, clampi(count, 1, 20))


static func aspect(payload: Dictionary) -> Dictionary:
    var result := {"横向": 0, "纵向": 0, "近方形": 0}
    for room in payload.rooms:
        var size := K.rectangle(room.bounds).size
        if size.x > size.y * 1.5:
            result["横向"] += 1
        elif size.y > size.x * 1.5:
            result["纵向"] += 1
        else:
            result["近方形"] += 1
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var values := rows(payload)
    var areas := []
    for row in values:
        areas.append(row["面积"])
    var spread := K.distribution(areas)
    var bounds := extent(payload)
    return [
        K.notice("现场档案", summary(payload)),
        K.notice(
            "记录点与范围",
            "记录点 %s · 已知空间外框 %s；几何距离不表示可行走路径。" % [str(V.point(payload.origin)), str(bounds)]
        ),
        K.table("已抵达房间", ["房间", "类型", "宽", "高", "中心距离", "目标", "风险札记"], values),
        K.bars("已知空间形态", aspect(payload)),
        K.notice("面积分布", "样本%d · 中位面积%.1f · 平均面积%.1f" % [spread.count, spread.median, spread.mean]),
        K.table("离记录点最近的档案", ["房间", "中心距离", "类型"], nearest(payload)),
        K.table("已知空间交叠", ["房间甲", "房间乙", "空间交叠"], overlaps(payload), "交叠来自房间设计矩形，不推断碰撞、门户或秘密通路。"),
        K.notice(
            "个人复访问题",
            (
                String(payload.question)
                if not String(payload.question).is_empty()
                else "可在候选中填写下一次复访想确认的现象。"
            )
        )
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var old := {}
    var added := []
    var changed := []
    for room in a.rooms:
        old[room.id] = room
    for room in b.rooms:
        if not old.has(room.id):
            added.append({"房间": room.name, "类型": room.kind})
        elif old[room.id] != room:
            changed.append(
                {
                    "房间": room.name,
                    "旧面积": K.rectangle(old[room.id].bounds).get_area(),
                    "当前面积": K.rectangle(room.bounds).get_area()
                }
            )
        old.erase(room.id)
    var missing := []
    for room in old.values():
        missing.append({"房间": room.name})
    return [
        K.table("新增已知档案", ["房间", "类型"], added),
        K.table("设计资料变化", ["房间", "旧面积", "当前面积"], changed),
        K.table("本次样本未包含", ["房间"], missing, "跨地区或不同采样范围会造成样本变化，不代表房间从世界消失。")
    ]


static func svg(payload: Dictionary) -> String:
    var document := preload("res://journey/fieldwork/vector.gd").new("实际抵达房间档案", 1100, 1000)
    document.paragraph(summary(payload))
    document.table("已抵达空间", ["房间", "类型", "宽", "高", "中心距离"], rows(payload))
    document.bars("空间形态", aspect(payload))
    document.table("近邻参考", ["房间", "中心距离"], nearest(payload))
    document.paragraph("个人复访问题：" + String(payload.question))
    return document.finish("只含已抵达矩形。几何距离不证明现场可通行。")
