extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const VIEW := preload("res://journey/fieldwork/survey/view.gd")
const MAX_CELLS := 2048


static func introduction() -> String:
    return "把实际抵达房间的设计矩形转成有界参考网格，检查空间密度、边界和复查分区。网格不是碰撞地图，也不表示真实探索完成率。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var rooms := []
    for room in K.rooms(snapshot).slice(0, 120):
        var rect := K.rectangle(room.get("layout_rect"))
        if rect.size != Vector2.ZERO:
            rooms.append(
                {
                    "id": room.id,
                    "name": String(room.get("name", room.id)),
                    "bounds": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
                }
            )
    return {
        "rooms": rooms,
        "origin": snapshot.get("player", {}).get("position", [0, 0]),
        "cell_size": 200.0,
        "diagonal": false,
        "dense_threshold": 2.0,
        "region": String(snapshot.get("region", "")),
        "question": ""
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("rooms") is Array
        or payload.rooms.size() > 120
        or not V.point(payload.get("origin")).is_finite()
    ):
        return false
    if (
        not payload.get("diagonal") is bool
        or not payload.get("region") is String
        or not payload.get("question") is String
        or payload.question.length() > 500
    ):
        return false
    if not V.number(payload.get("cell_size")) or payload.cell_size < 20 or payload.cell_size > 2000:
        return false
    if not V.count(payload.get("dense_threshold"), 20) or payload.dense_threshold < 1:
        return false
    var seen := {}
    for room in payload.rooms:
        if (
            not room is Dictionary
            or not room.get("id") is String
            or not room.get("name") is String
            or seen.has(room.id)
        ):
            return false
        if room.name.length() > 200 or K.rectangle(room.get("bounds")) == Rect2():
            return false
        seen[room.id] = true
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(_payload: Dictionary) -> Array:
    return [
        {"id": "cell_size", "name": "请求网格边长", "kind": "number", "min": 20, "max": 2000, "step": 20},
        {"id": "diagonal", "name": "统计斜向相接", "kind": "toggle"},
        {"id": "dense_threshold", "name": "重叠密度阈值", "kind": "number", "min": 1, "max": 20},
        {"id": "question", "name": "本次复查问题", "max": 500}
    ]


static func summary(payload: Dictionary) -> String:
    return "%d 个已知空间矩形 · 请求网格边长 %.0f" % [payload.rooms.size(), payload.cell_size]


static func bounds(payload: Dictionary) -> Rect2:
    var result := Rect2()
    var initialized := false
    for room in payload.rooms:
        var rect := K.rectangle(room.bounds)
        result = result.merge(rect) if initialized else rect
        initialized = true
    return result


static func grid(payload: Dictionary) -> Dictionary:
    var rect := bounds(payload)
    if rect.size == Vector2.ZERO:
        return {
            "width": 0,
            "height": 0,
            "step": payload.cell_size,
            "bounds": [],
            "cells": [],
            "members": []
        }
    var step := float(payload.cell_size)
    var width := maxi(1, int(ceil(rect.size.x / step)))
    var height := maxi(1, int(ceil(rect.size.y / step)))
    while width * height > MAX_CELLS:
        step *= 1.1
        width = maxi(1, int(ceil(rect.size.x / step)))
        height = maxi(1, int(ceil(rect.size.y / step)))
    var cells := []
    var members := []
    for y in height:
        for x in width:
            var point := rect.position + Vector2(x + 0.5, y + 0.5) * step
            var owners := []
            for room in payload.rooms:
                if K.rectangle(room.bounds).has_point(point):
                    owners.append(room.id)
            cells.append(owners.size())
            members.append(owners)
    return {
        "width": width,
        "height": height,
        "step": step,
        "bounds": [rect.position.x, rect.position.y, width * step, height * step],
        "cells": cells,
        "members": members
    }


static func valid_cell(data: Dictionary, x: int, y: int) -> bool:
    return x >= 0 and y >= 0 and x < int(data.width) and y < int(data.height)


static func cell_id(data: Dictionary, x: int, y: int) -> int:
    return y * int(data.width) + x if valid_cell(data, x, y) else -1


static func coordinates(data: Dictionary, id: int) -> Vector2i:
    if data.width == 0:
        return Vector2i(-1, -1)
    return Vector2i(id % int(data.width), id / int(data.width))


static func point_cell(data: Dictionary, point: Vector2) -> int:
    if data.bounds.is_empty():
        return -1
    var local := point - Vector2(float(data.bounds[0]), float(data.bounds[1]))
    return cell_id(
        data, int(floor(local.x / float(data.step))), int(floor(local.y / float(data.step)))
    )


static func neighbors(data: Dictionary, id: int, diagonal: bool = false) -> Array:
    var result := []
    var current := coordinates(data, id)
    var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
    if diagonal:
        directions += [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
    for direction in directions:
        var point: Vector2i = current + direction
        var next := cell_id(data, point.x, point.y)
        if next >= 0:
            result.append(next)
    return result


static func occupied(data: Dictionary) -> Array:
    var result := []
    for id in data.cells.size():
        if int(data.cells[id]) > 0:
            result.append(id)
    return result


static func components(data: Dictionary, diagonal: bool, empty: bool = false) -> Array:
    var seen := {}
    var result := []
    for id in data.cells.size():
        if seen.has(id) or (int(data.cells[id]) == 0) != empty:
            continue
        var queue := [id]
        var cursor := 0
        var group := []
        seen[id] = true
        while cursor < queue.size():
            var current := int(queue[cursor])
            cursor += 1
            group.append(current)
            for next in neighbors(data, current, diagonal):
                if not seen.has(next) and (int(data.cells[next]) == 0) == empty:
                    seen[next] = true
                    queue.append(next)
        result.append(group)
    result.sort_custom(func(a: Array, b: Array): return a.size() > b.size())
    return result


static func perimeter(data: Dictionary) -> Dictionary:
    var edge_cells := []
    var edge_count := 0
    for id in occupied(data):
        var count := 4
        for next in neighbors(data, id):
            if int(data.cells[next]) > 0:
                count -= 1
        if count > 0:
            edge_cells.append(id)
            edge_count += count
    return {"cells": edge_cells, "edges": edge_count, "length": edge_count * float(data.step)}


static func distances(data: Dictionary, source: int, diagonal: bool) -> Dictionary:
    if source < 0 or source >= data.cells.size() or int(data.cells[source]) == 0:
        return {}
    var result := {str(source): 0}
    var queue := [source]
    var cursor := 0
    while cursor < queue.size():
        var id := int(queue[cursor])
        cursor += 1
        for next in neighbors(data, id, diagonal):
            var key := str(next)
            if int(data.cells[next]) > 0 and not result.has(key):
                result[key] = int(result[str(id)]) + 1
                queue.append(next)
    return result


static func holes(data: Dictionary) -> Array:
    var result := []
    for group in components(data, false, true):
        var border := false
        for id in group:
            var point := coordinates(data, int(id))
            if (
                point.x == 0
                or point.y == 0
                or point.x == int(data.width) - 1
                or point.y == int(data.height) - 1
            ):
                border = true
                break
        if not border:
            result.append({"留白格数": group.size(), "示意面积": group.size() * pow(float(data.step), 2)})
    return result


static func prefix(data: Dictionary) -> Array:
    var width := int(data.width) + 1
    var sums := []
    sums.resize(width * (int(data.height) + 1))
    sums.fill(0)
    for y in range(1, int(data.height) + 1):
        for x in range(1, width):
            var value := 1 if int(data.cells[(y - 1) * int(data.width) + x - 1]) > 0 else 0
            sums[y * width + x] = (
                value
                + int(sums[(y - 1) * width + x])
                + int(sums[y * width + x - 1])
                - int(sums[(y - 1) * width + x - 1])
            )
    return sums


static func query(data: Dictionary, sums: Array, rect: Rect2i) -> int:
    if not V.count(data.get("width"), MAX_CELLS):
        return 0
    if not V.count(data.get("height"), MAX_CELLS):
        return 0
    if sums.size() != (int(data.width) + 1) * (int(data.height) + 1):
        return 0
    if rect.size.x <= 0 or rect.size.y <= 0:
        return 0
    var a := Vector2i(
        clampi(rect.position.x, 0, data.width), clampi(rect.position.y, 0, data.height)
    )
    var b := Vector2i(clampi(rect.end.x, 0, data.width), clampi(rect.end.y, 0, data.height))
    var width := int(data.width) + 1
    if b.x < a.x or b.y < a.y:
        return 0
    return (
        int(sums[b.y * width + b.x])
        - int(sums[a.y * width + b.x])
        - int(sums[b.y * width + a.x])
        + int(sums[a.y * width + a.x])
    )


static func quadrants(data: Dictionary) -> Array:
    var result := []
    var sums := prefix(data)
    var half_x := int(data.width) / 2
    var half_y := int(data.height) / 2
    var areas := [
        Rect2i(0, 0, half_x, half_y),
        Rect2i(half_x, 0, int(data.width) - half_x, half_y),
        Rect2i(0, half_y, half_x, int(data.height) - half_y),
        Rect2i(half_x, half_y, int(data.width) - half_x, int(data.height) - half_y)
    ]
    var names := ["西北", "东北", "西南", "东南"]
    for i in areas.size():
        var amount := query(data, sums, areas[i])
        var area: int = areas[i].get_area()
        result.append(
            {"分区": names[i], "矩形覆盖格": amount, "分区格数": area, "比例": float(amount) / maxf(1, area)}
        )
    return result


static func room_density(payload: Dictionary, data: Dictionary) -> Array:
    var result := []
    for room in payload.rooms:
        var cells := 0
        var overlap := 0
        for i in data.members.size():
            if data.members[i].has(room.id):
                cells += 1
                overlap += 1 if int(data.cells[i]) > 1 else 0
        result.append(
            {
                "房间": room.name,
                "采样中心格": cells,
                "与其它矩形重叠格": overlap,
                "采样示意面积": cells * pow(float(data.step), 2)
            }
        )
    return result


static func layer_counts(data: Dictionary, threshold: int) -> Dictionary:
    var result := {"留白": 0, "单矩形": 0, "重叠矩形": 0, "达到密度阈值": 0}
    for value in data.cells:
        if int(value) == 0:
            result["留白"] += 1
        elif int(value) == 1:
            result["单矩形"] += 1
        else:
            result["重叠矩形"] += 1
        if int(value) >= threshold:
            result["达到密度阈值"] += 1
    return result


static func farthest(payload: Dictionary, data: Dictionary) -> Array:
    var source := point_cell(data, V.point(payload.origin))
    if source < 0 or int(data.cells[source]) == 0:
        var candidates := occupied(data)
        var origin := V.point(payload.origin)
        candidates.sort_custom(func(a: int, b: int): return cell_center(data, a).distance_squared_to(origin) < cell_center(data, b).distance_squared_to(origin))
        source = int(candidates[0]) if not candidates.is_empty() else -1
    var levels := distances(data, source, bool(payload.diagonal))
    var rows := []
    for id in levels:
        var point := coordinates(data, int(id))
        rows.append(
            {"网格列": point.x, "网格行": point.y, "示意跳数": levels[id], "覆盖矩形数": data.cells[int(id)]}
        )
    rows.sort_custom(func(a: Dictionary, b: Dictionary): return a["示意跳数"] > b["示意跳数"])
    return rows.slice(0, 12)


static func resolution_study(payload: Dictionary) -> Array:
    var result := []
    for factor in [0.5, 1.0, 2.0]:
        var sample := payload.duplicate(true)
        sample.cell_size = clampf(float(payload.cell_size) * float(factor), 20, 2000)
        var data := grid(sample)
        result.append(
            {
                "请求边长": sample.cell_size,
                "实际边长": data.step,
                "网格总数": data.cells.size(),
                "矩形覆盖格": occupied(data).size(),
                "示意面积": occupied(data).size() * pow(float(data.step), 2)
            }
        )
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var data := grid(payload)
    if data.cells.is_empty():
        return [K.notice("没有可测绘样本", "先实际抵达一个具有地图设计矩形的房间。")]
    var boundary := perimeter(data)
    var groups := components(data, bool(payload.diagonal))
    var group_rows := []
    for i in groups.size():
        group_rows.append(
            {
                "分组": i + 1,
                "覆盖格": groups[i].size(),
                "示意面积": groups[i].size() * pow(float(data.step), 2)
            }
        )
    return [
        K.notice("已知空间栅格", summary(payload)),
        K.notice(
            "采样容量",
            (
                "实际网格边长 %.1f · %d × %d · 上限%d格。容量不足时自动放大网格。"
                % [data.step, data.width, data.height, MAX_CELLS]
            )
        ),
        {"kind": "custom", "title": "已知矩形覆盖示意", "view": VIEW, "data": data},
        K.bars("采样密度", layer_counts(data, int(payload.dense_threshold))),
        K.table("几何相接分组", ["分组", "覆盖格", "示意面积"], group_rows),
        K.notice(
            "矩形外边界", "边界格%d · 估算外周长%.1f。矩形采样精度会影响此数值。" % [boundary.cells.size(), boundary.length]
        ),
        K.table("四分区密度", ["分区", "矩形覆盖格", "分区格数", "比例"], quadrants(data)),
        K.table("房间采样贡献", ["房间", "采样中心格", "与其它矩形重叠格", "采样示意面积"], room_density(payload, data)),
        K.table("几何围合留白", ["留白格数", "示意面积"], holes(data), "只是已知矩形之间的留白，不是隐藏房间或碰撞通路。"),
        K.table("从记录点出发的示意远端", ["网格列", "网格行", "示意跳数", "覆盖矩形数"], farthest(payload, data)),
        K.table("网格分辨率比较", ["请求边长", "实际边长", "网格总数", "矩形覆盖格", "示意面积"], resolution_study(payload)),
        K.table("矩形并集面积审计", ["指标", "值"], room_overlap_audit(payload)),
        K.table("采样误差检查", ["方法", "示意面积", "对矩形并集误差", "相对误差"], approximation_audit(payload, data)),
        K.notice("个人复查问题", String(payload.question)),
        K.notice("读图边界", "所有覆盖、周长与距离均来自已知地图矩形的采样，没有模拟真实落脚和碰撞。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := grid(a)
    var right := grid(b)
    return [
        K.table(
            "测绘样本比较",
            ["样本", "已知矩形", "实际网格边长", "覆盖格", "示意面积"],
            [
                {
                    "样本": "记录",
                    "已知矩形": a.rooms.size(),
                    "实际网格边长": left.step,
                    "覆盖格": occupied(left).size(),
                    "示意面积": occupied(left).size() * pow(float(left.step), 2)
                },
                {
                    "样本": "当前",
                    "已知矩形": b.rooms.size(),
                    "实际网格边长": right.step,
                    "覆盖格": occupied(right).size(),
                    "示意面积": occupied(right).size() * pow(float(right.step), 2)
                }
            ],
            "比较时需同时核对网格边长。"
        )
    ]


static func interval_union(intervals: Array) -> float:
    if intervals.is_empty():
        return 0.0
    var ordered := intervals.duplicate(true)
    ordered.sort_custom(func(a: Array, b: Array): return float(a[0]) < float(b[0]))
    var start := float(ordered[0][0])
    var finish := float(ordered[0][1])
    var total := 0.0
    for i in range(1, ordered.size()):
        var a := float(ordered[i][0])
        var b := float(ordered[i][1])
        if a <= finish:
            finish = maxf(finish, b)
        else:
            total += finish - start
            start = a
            finish = b
    return total + finish - start


static func exact_union_area(payload: Dictionary) -> float:
    var events := []
    for room in payload.rooms:
        var rect := K.rectangle(room.bounds)
        events.append(rect.position.x)
        events.append(rect.end.x)
    events.sort()
    var total := 0.0
    for i in range(1, events.size()):
        var left := float(events[i - 1])
        var right := float(events[i])
        if right <= left:
            continue
        var center := (left + right) * 0.5
        var intervals := []
        for room in payload.rooms:
            var rect := K.rectangle(room.bounds)
            if center >= rect.position.x and center < rect.end.x:
                intervals.append([rect.position.y, rect.end.y])
        total += (right - left) * interval_union(intervals)
    return total


static func fractional_area(payload: Dictionary, data: Dictionary) -> Dictionary:
    var occupied_area := 0.0
    var uncertain := 0
    var step := float(data.step)
    var origin := Vector2(float(data.bounds[0]), float(data.bounds[1]))
    for id in data.cells.size():
        var point := coordinates(data, id)
        var base := origin + Vector2(point.x, point.y) * step
        var hits := 0
        for y in 3:
            for x in 3:
                var sample := base + Vector2((x + 0.5) / 3.0, (y + 0.5) / 3.0) * step
                for room in payload.rooms:
                    if K.rectangle(room.bounds).has_point(sample):
                        hits += 1
                        break
        occupied_area += float(hits) / 9.0 * step * step
        if hits > 0 and hits < 9:
            uncertain += 1
    return {"area": occupied_area, "boundary_cells": uncertain}


static func approximation_audit(payload: Dictionary, data: Dictionary) -> Array:
    var exact := exact_union_area(payload)
    var center := occupied(data).size() * pow(float(data.step), 2)
    var refined := fractional_area(payload, data)
    var result := []
    for row in [
        {"name": "矩形并集精确面积", "value": exact},
        {"name": "网格中心采样", "value": center},
        {"name": "每格九点采样", "value": refined.area}
    ]:
        var error := float(row.value) - exact
        result.append(
            {"方法": row.name, "示意面积": row.value, "对矩形并集误差": error, "相对误差": error / maxf(1, exact)}
        )
    result.append(
        {"方法": "九点混合边界格", "示意面积": refined.boundary_cells, "对矩形并集误差": "格数统计", "相对误差": "不适用"}
    )
    return result


static func room_overlap_audit(payload: Dictionary) -> Array:
    var exact := exact_union_area(payload)
    var sum := 0.0
    var largest := 0.0
    var smallest := INF
    for room in payload.rooms:
        var area := K.rectangle(room.bounds).get_area()
        sum += area
        largest = maxf(largest, area)
        smallest = minf(smallest, area)
    var envelope := bounds(payload).get_area()
    return [
        {"指标": "矩形面积相加", "值": sum},
        {"指标": "矩形并集面积", "值": exact},
        {"指标": "重复覆盖面积", "值": maxf(0, sum - exact)},
        {"指标": "已知外框填充率", "值": exact / maxf(1, envelope)},
        {"指标": "最大房间矩形面积", "值": largest},
        {"指标": "最小房间矩形面积", "值": smallest if is_finite(smallest) else 0}
    ]


static func cell_center(data: Dictionary, id: int) -> Vector2:
    var cell := coordinates(data, id)
    return Vector2(float(data.bounds[0]), float(data.bounds[1])) + Vector2(cell.x + 0.5, cell.y + 0.5) * float(data.step)
