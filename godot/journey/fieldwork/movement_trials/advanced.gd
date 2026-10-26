extends RefCounted
## Segment-preserving dynamic time warping of relative observed positions.
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const MAX_POINTS := 80
const BAND := 24


static func groups(samples: Array) -> Array:
    var result := []
    var current := -1
    for sample in samples:
        if int(sample.segment) != current:
            result.append([])
            current = int(sample.segment)
        result[-1].append(sample)
    return result


static func reduce_samples(samples: Array, maximum: int = MAX_POINTS) -> Array:
    if samples.size() <= maximum:
        return samples.duplicate(true)
    var result := []
    for i in maximum:
        var index := int(round(float(i) * (samples.size() - 1) / (maximum - 1)))
        result.append(samples[index].duplicate(true))
    return result


static func align(left: Array, right: Array, origin_a: Vector2, origin_b: Vector2) -> Dictionary:
    if left.is_empty() or right.is_empty() or not origin_a.is_finite() or not origin_b.is_finite():
        return {"ok": false, "reason": "两侧都需要有效采样"}
    var a := reduce_samples(left)
    var b := reduce_samples(right)
    var costs := {}
    var previous := {}
    for i in a.size():
        var center := int(round(float(i) * (b.size() - 1) / maxi(1, a.size() - 1)))
        for j in range(maxi(0, center - BAND), mini(b.size(), center + BAND + 1)):
            var delta := (V.point(a[i].position) - origin_a) - (V.point(b[j].position) - origin_b)
            var local := delta.length_squared()
            var key := Vector2i(i, j)
            if i == 0 and j == 0:
                costs[key] = local
                continue
            var best := INF
            var parent := Vector2i(-1, -1)
            for offset in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1)]:
                var at: Vector2i = key + offset
                if costs.has(at) and float(costs[at]) < best:
                    best = float(costs[at])
                    parent = at
            if is_finite(best):
                costs[key] = best + local
                previous[key] = parent
    var end := Vector2i(a.size() - 1, b.size() - 1)
    if not costs.has(end):
        return {"ok": false, "reason": "受限对齐窗口内没有完整路径"}
    var pairs := []
    var cursor := end
    while true:
        pairs.push_front({"left": cursor.x, "right": cursor.y})
        if cursor == Vector2i.ZERO:
            break
        cursor = previous[cursor]
    var lag := 0.0
    var ground_mismatch := 0
    var maximum := 0.0
    var rows := []
    for pair in pairs:
        var x: Dictionary = a[pair.left]
        var y: Dictionary = b[pair.right]
        var distance := ((V.point(x.position) - origin_a) - (V.point(y.position) - origin_b)).length()
        maximum = maxf(maximum, distance)
        lag += float(y.time) - float(x.time)
        if bool(x.grounded) != bool(y.grounded):
            ground_mismatch += 1
        rows.append({
            "记录秒": x.time, "当前秒": y.time, "相对位移差": snappedf(distance, 0.01),
            "时间差": snappedf(float(y.time) - float(x.time), 0.001),
            "着地一致": bool(x.grounded) == bool(y.grounded)
        })
    return {
        "ok": true, "pairs": pairs, "rows": rows, "left": a, "right": b,
        "cost": costs[end], "rms": sqrt(float(costs[end]) / pairs.size()),
        "maximum": maximum, "mean_lag": lag / pairs.size(), "ground_mismatch": ground_mismatch,
        "reduced": a.size() < left.size() or b.size() < right.size()
    }


static func compare(a: Dictionary, b: Dictionary) -> Dictionary:
    if a.region != b.region:
        return {"ok": false, "reason": "地区不同，不对齐两地轨迹"}
    var left := groups(a.samples)
    var right := groups(b.samples)
    if left.is_empty() or left.size() != right.size():
        return {"ok": false, "reason": "需要相同数量的有效采样分段；不会跨菜单间隙拼接"}
    var results := []
    for i in left.size():
        var result := align(left[i], right[i], V.point(a.origin), V.point(b.origin))
        if not result.ok:
            return result
        result["segment"] = i + 1
        results.append(result)
    return {"ok": true, "segments": results}


static func certify(result: Dictionary, origin_a: Vector2, origin_b: Vector2) -> bool:
    if not result.get("ok", false) or result.pairs.is_empty():
        return false
    var previous := Vector2i(-1, -1)
    var cost := 0.0
    for pair in result.pairs:
        var at := Vector2i(pair.left, pair.right)
        if previous.x >= 0:
            var delta := at - previous
            if delta not in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
                return false
        var a := V.point(result.left[at.x].position) - origin_a
        var b := V.point(result.right[at.y].position) - origin_b
        cost += a.distance_squared_to(b)
        previous = at
    return result.pairs[0] == {"left": 0, "right": 0} and previous == Vector2i(result.left.size() - 1, result.right.size() - 1) and absf(cost - float(result.cost)) < 0.001


static func sections(a: Dictionary, b: Dictionary) -> Array:
    var result := compare(a, b)
    if not result.ok:
        return [K.notice("轨迹分段时间对齐", result.reason)]
    var summary := []
    var pairs := []
    for segment in result.segments:
        summary.append({
            "分段": segment.segment, "匹配对": segment.pairs.size(),
            "均方根位移差": snappedf(float(segment.rms), 0.01),
            "最大位移差": snappedf(float(segment.maximum), 0.01),
            "平均时间差": snappedf(float(segment.mean_lag), 0.001),
            "复核": "通过" if certify(segment, V.point(a.origin), V.point(b.origin)) else "未通过"
        })
        for row in segment.rows.slice(0, 16):
            var item: Dictionary = row.duplicate()
            item["分段"] = segment.segment
            pairs.append(item)
    return [
        K.table("逐段动态时间对齐", ["分段", "匹配对", "均方根位移差", "最大位移差", "平均时间差", "复核"], summary),
        K.table("每段前16个对齐点", ["分段", "记录秒", "当前秒", "相对位移差", "时间差", "着地一致"], pairs),
        K.notice("对齐解释", "两侧各自减去记录起点，比较相对空间轨迹。每段最多80个含首尾样本，采用24点窗口的累计平方距离最优路径；均方根是该路径摘要。抽样、停顿、环境和操作差异均会影响结果，不能据此断定输入延迟或物理性能。")
    ]
