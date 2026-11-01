extends RefCounted
## Greedy maximum coverage on the occupied reference grid, with replayable gains.
const K := preload("res://journey/fieldwork/knowledge.gd")
const MAX_CELLS := 2048
const MAX_STATIONS := 8


static func valid_grid(grid: Dictionary) -> bool:
    if not grid.get("cells") is Array or grid.cells.size() > MAX_CELLS:
        return false
    for key in ["width", "height"]:
        if not grid.get(key) is int or grid[key] < 0:
            return false
    if grid.width * grid.height != grid.cells.size():
        return false
    for count in grid.cells:
        if not (count is int or count is float) or not is_finite(float(count)) or count < 0:
            return false
    return true


static func cells(grid: Dictionary) -> Array:
    var result := []
    if valid_grid(grid):
        for id in grid.cells.size():
            if grid.cells[id] > 0:
                result.append(id)
    return result


static func point(grid: Dictionary, id: int) -> Vector2i:
    return Vector2i(id % int(grid.width), id / int(grid.width))


static func distances(grid: Dictionary, start: int) -> Dictionary:
    if not valid_grid(grid) or start < 0 or start >= grid.cells.size() or grid.cells[start] <= 0:
        return {}
    var queue := [start]
    var distance := {start: 0}
    var cursor := 0
    while cursor < queue.size():
        var id: int = queue[cursor]
        cursor += 1
        var at := point(grid, id)
        for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var next: Vector2i = at + offset
            if next.x < 0 or next.y < 0 or next.x >= grid.width or next.y >= grid.height:
                continue
            var target: int = next.y * int(grid.width) + next.x
            if grid.cells[target] > 0 and not distance.has(target):
                distance[target] = int(distance[id]) + 1
                queue.append(target)
    return distance


static func footprint(grid: Dictionary, start: int, radius: int) -> Array:
    var result := []
    var distance := distances(grid, start)
    for id in distance:
        if int(distance[id]) <= radius:
            result.append(id)
    result.sort()
    return result


static func candidates(occupied: Array, maximum: int = 128) -> Array:
    if occupied.size() <= maximum:
        return occupied.duplicate()
    var result := []
    for i in maximum:
        result.append(occupied[int(floor(float(i) * occupied.size() / maximum))])
    return result


static func plan(grid: Dictionary, count: int = 4, radius: int = 3) -> Dictionary:
    if not valid_grid(grid) or count < 0 or count > MAX_STATIONS or radius < 0 or radius > 20:
        return {"ok": false, "reason": "网格或复查站点参数无效"}
    var occupied := cells(grid)
    var sampled := candidates(occupied)
    var cover := {}
    for id in sampled:
        cover[id] = footprint(grid, id, radius)
    var selected := []
    var covered := {}
    for step in count:
        var best := -1
        var gain := 0
        for id in sampled:
            if selected.has(id):
                continue
            var extra := 0
            for cell in cover[id]:
                if not covered.has(cell):
                    extra += 1
            if extra > gain:
                best = id
                gain = extra
        if best < 0:
            break
        selected.append(best)
        for cell in cover[best]:
            covered[cell] = true
    var uncovered := occupied.filter(func(id: int): return not covered.has(id))
    var rows := []
    var replay := {}
    for id in selected:
        var added := 0
        for cell in cover[id]:
            if not replay.has(cell):
                replay[cell] = true
                added += 1
        rows.append({
            "cell": id, "gain": added, "covered": replay.size(),
            "x": point(grid, id).x, "y": point(grid, id).y
        })
    return {
        "ok": true, "stations": rows, "covered": covered.keys(),
        "uncovered": uncovered, "total": occupied.size(), "candidates": sampled.size(),
        "sampled": sampled.size() < occupied.size(), "radius": radius
    }


static func certify(grid: Dictionary, result: Dictionary) -> bool:
    if not result.get("ok", false) or not valid_grid(grid):
        return false
    var covered := {}
    var seen := {}
    for row in result.stations:
        if seen.has(row.cell):
            return false
        seen[row.cell] = true
        var added := 0
        for id in footprint(grid, int(row.cell), int(result.radius)):
            if not covered.has(id):
                covered[id] = true
                added += 1
        if added != row.gain or covered.size() != row.covered:
            return false
    var a := covered.keys()
    var b: Array = result.covered.duplicate()
    a.sort()
    b.sort()
    var remainder := cells(grid).filter(func(id: int): return not covered.has(id))
    var claimed: Array = result.uncovered.duplicate()
    claimed.sort()
    remainder.sort()
    return a == b and claimed == remainder and result.total == cells(grid).size()


static func sections(_payload: Dictionary, grid: Dictionary) -> Array:
    var result := plan(grid)
    if not result.ok:
        return [K.notice("复查覆盖", result.reason)]
    var rows := []
    for row in result.stations:
        rows.append({
            "复查站": rows.size() + 1, "网格列": row.x, "网格行": row.y,
            "新增覆盖格": row.gain, "累计覆盖格": row.covered
        })
    var study := []
    for radius in [1, 2, 3, 5]:
        var trial := plan(grid, 4, radius)
        study.append({"参考半径格": radius, "覆盖格": trial.covered.size(), "剩余格": trial.uncovered.size()})
    return [
        K.notice("复查站点覆盖规划",
            "4个站点、四邻相接3格参考半径，覆盖%d/%d个占用格；候选%d个%s；增量证书%s。"
            % [result.covered.size(), result.total, result.candidates,
                "（均匀抽样）" if result.sampled else "",
                "通过" if certify(grid, result) else "未通过"]),
        K.table("贪心复查站点", ["复查站", "网格列", "网格行", "新增覆盖格", "累计覆盖格"], rows),
        K.table("站点半径敏感度", ["参考半径格", "覆盖格", "剩余格"], study,
            "覆盖仅指已知设计矩形网格。空格会隔断参考邻接；不是碰撞寻路、真实可见范围或探索完成率。候选超过128格时抽样，结果不声称全局最优。")
    ]
