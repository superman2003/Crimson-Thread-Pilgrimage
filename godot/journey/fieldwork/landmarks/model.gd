extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const VIEW := preload("res://journey/fieldwork/landmarks/view.gd")
const DIRECTIONS := ["东", "东北", "北", "西北", "西", "西南", "南", "东南"]


static func introduction() -> String:
    return "以记录点和实际抵达房间的中心作为已知地标，比较方位、视角窗口与标签布局。方位线不判断墙体和跳跃可达性。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var markers := []
    for room in K.rooms(snapshot).slice(0, 120):
        var rect := K.rectangle(room.get("layout_rect"))
        if rect.size != Vector2.ZERO:
            markers.append(
                {
                    "id": room.id,
                    "name": String(room.get("name", room.id)),
                    "point": V.pair(rect.get_center()),
                    "kind": String(room.get("kind", "room"))
                }
            )
    return {
        "markers": markers,
        "origin": snapshot.get("player", {}).get("position", [0, 0]),
        "heading": 0.0,
        "fov": 90.0,
        "radius": 3000.0,
        "speed": 250.0,
        "separation": 10.0,
        "uncertainty": 2.0,
        "baseline": 200.0,
        "projection": "angular",
        "region": String(snapshot.get("region", ""))
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("markers") is Array
        or payload.markers.size() > 120
        or not V.point(payload.get("origin")).is_finite()
    ):
        return false
    if (
        not payload.get("region") is String
        or payload.get("projection") not in ["angular", "perspective"]
    ):
        return false
    var bounds := {
        "heading": [0, 360],
        "fov": [10, 180],
        "radius": [1, 100000],
        "speed": [1, 10000],
        "separation": [1, 45],
        "uncertainty": [0, 30],
        "baseline": [1, 10000]
    }
    for key in bounds:
        if (
            not V.number(payload.get(key))
            or float(payload[key]) < bounds[key][0]
            or float(payload[key]) > bounds[key][1]
        ):
            return false
    var known := {}
    for marker in payload.markers:
        if not marker is Dictionary or not marker.get("id") is String or known.has(marker.id):
            return false
        if (
            not marker.get("name") is String
            or marker.name.length() > 200
            or not marker.get("kind") is String
            or not V.point(marker.get("point")).is_finite()
        ):
            return false
        known[marker.id] = true
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(_payload: Dictionary) -> Array:
    return [
        {"id": "heading", "name": "参考朝向（0东90北）", "kind": "number", "min": 0, "max": 360, "step": 5},
        {"id": "fov", "name": "方位窗口角度", "kind": "number", "min": 10, "max": 180, "step": 5},
        {"id": "radius", "name": "参考半径", "kind": "number", "min": 1, "max": 100000, "step": 100},
        {"id": "speed", "name": "个人移动速度假设", "kind": "number", "min": 1, "max": 10000, "step": 10},
        {"id": "separation", "name": "标签最小角距", "kind": "number", "min": 1, "max": 45},
        {
            "id": "uncertainty",
            "name": "方位角误差假设",
            "kind": "number",
            "min": 0,
            "max": 30,
            "step": 0.5
        },
        {"id": "baseline", "name": "视差参考位移", "kind": "number", "min": 1, "max": 10000, "step": 20},
        {
            "id": "projection",
            "name": "方位条投影",
            "kind": "choice",
            "choices": [{"id": "angular", "name": "等角度"}, {"id": "perspective", "name": "透视角度"}]
        }
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d 个已知地标 · 朝向 %.0f° · 半径 %.0f" % [payload.markers.size(), payload.heading, payload.radius]
    )


static func angle(delta: Vector2) -> float:
    return fposmod(rad_to_deg(atan2(-delta.y, delta.x)), 360.0)


static func delta_angle(a: float, b: float) -> float:
    return fposmod(a - b + 180.0, 360.0) - 180.0


static func direction(degrees: float) -> String:
    return DIRECTIONS[int(floor(fposmod(degrees + 22.5, 360.0) / 45.0)) % 8]


static func rows(payload: Dictionary) -> Array:
    var result := []
    var origin := V.point(payload.origin)
    for marker in payload.markers:
        var delta := V.point(marker.point) - origin
        var distance := delta.length()
        var bearing := angle(delta)
        var relative := delta_angle(bearing, float(payload.heading))
        var defined := distance > 0.001
        var inside := (
            defined
            and distance <= float(payload.radius)
            and absf(relative) <= float(payload.fov) * 0.5
        )
        result.append(
            {
                "id": marker.id,
                "地标": marker.name,
                "类型": marker.kind,
                "距离": distance,
                "方位度": bearing,
                "方向": direction(bearing) if defined else "重合",
                "bearing_defined": defined,
                "方位状态": "已定义" if defined else "与记录点重合，方位未定义",
                "相对角度": relative,
                "窗口内": inside,
                "直线估算秒": distance / float(payload.speed),
                "point": marker.point
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if is_equal_approx(float(a["距离"]), float(b["距离"])):
                return String(a.id) < String(b.id)
            return a["距离"] < b["距离"]
    )
    return result


static func visible(payload: Dictionary) -> Array:
    var result := []
    for row in rows(payload):
        if row["窗口内"]:
            result.append(row)
    return result


static func sector_counts(payload: Dictionary) -> Dictionary:
    var result := {}
    for name in DIRECTIONS:
        result[name] = 0
    result["重合"] = 0
    for row in rows(payload):
        if row["距离"] <= float(payload.radius):
            result[row["方向"]] += 1
    return result


static func circular_statistics(values: Array) -> Dictionary:
    if values.is_empty():
        return {"mean": 0.0, "concentration": 0.0, "spread": 0.0, "count": 0}
    var x := 0.0
    var y := 0.0
    for value in values:
        x += cos(deg_to_rad(float(value)))
        y += sin(deg_to_rad(float(value)))
    var concentration := Vector2(x, y).length() / values.size()
    var mean := fposmod(rad_to_deg(atan2(y, x)), 360.0) if concentration > 0.000001 else 0.0
    var spread := rad_to_deg(sqrt(maxf(0, -2 * log(maxf(concentration, 0.000001)))))
    return {"mean": mean, "concentration": concentration, "spread": spread, "count": values.size()}


static func angular_gaps(payload: Dictionary) -> Array:
    var ordered: Array = rows(payload).filter(func(row: Dictionary): return row.bearing_defined)
    ordered.sort_custom(func(a: Dictionary, b: Dictionary): return a["方位度"] < b["方位度"])
    var result := []
    if ordered.size() < 2:
        return result
    for i in ordered.size():
        var a: Dictionary = ordered[i]
        var b: Dictionary = ordered[(i + 1) % ordered.size()]
        var gap := fposmod(float(b["方位度"]) - float(a["方位度"]), 360)
        result.append(
            {
                "起侧地标": a["地标"],
                "终侧地标": b["地标"],
                "角间隔": gap,
                "中线方向": direction(float(a["方位度"]) + gap * 0.5)
            }
        )
    result.sort_custom(func(a: Dictionary, b: Dictionary): return a["角间隔"] > b["角间隔"])
    return result


static func heading_sweep(payload: Dictionary) -> Array:
    var result := []
    for i in 16:
        var sample := payload.duplicate(true)
        sample.heading = i * 22.5
        var current := visible(sample)
        var minimum := INF
        for row in current:
            minimum = minf(minimum, float(row["距离"]))
        result.append(
            {
                "朝向度": sample.heading,
                "方向": direction(sample.heading),
                "窗口内地标": current.size(),
                "最近距离": snappedf(minimum, 0.1) if is_finite(minimum) else "无"
            }
        )
    return result


static func label_layout(payload: Dictionary) -> Array:
    var candidates := visible(payload)
    var accepted := []
    var result := []
    for row in candidates:
        var overlapping := false
        for previous in accepted:
            if (
                absf(delta_angle(float(row["方位度"]), float(previous["方位度"])))
                < float(payload.separation)
            ):
                overlapping = true
                break
        if not overlapping:
            accepted.append(row)
        result.append(
            {
                "地标": row["地标"],
                "距离": row["距离"],
                "相对角度": row["相对角度"],
                "标签展示": "靠近地标占用同一角距" if overlapping else "可展示",
                "position":
                projection(float(row["相对角度"]), float(payload.fov), String(payload.projection))
            }
        )
    return result


static func projection(relative: float, fov: float, method: String) -> float:
    if not is_finite(relative) or not is_finite(fov) or fov <= 0:
        return 0.0
    var half := clampf(fov * 0.5, 1, 89.9)
    if method == "perspective":
        return clampf(tan(deg_to_rad(relative)) / tan(deg_to_rad(half)), -1, 1)
    return clampf(relative / maxf(1, half), -1, 1)


static func nearest_by_sector(payload: Dictionary) -> Array:
    var best := {}
    for row in rows(payload):
        var key := String(row["方向"])
        if not best.has(key):
            best[key] = row
    var result := []
    for name in DIRECTIONS:
        if best.has(name):
            result.append(
                {
                    "方向": name,
                    "最近地标": best[name]["地标"],
                    "距离": best[name]["距离"],
                    "方位度": best[name]["方位度"]
                }
            )
    return result


static func parallax(payload: Dictionary) -> Array:
    var origin := V.point(payload.origin)
    var heading := deg_to_rad(float(payload.heading))
    var shifted := origin + Vector2(cos(heading), -sin(heading)) * float(payload.baseline)
    var result := []
    for marker in payload.markers:
        var point := V.point(marker.point)
        var original := angle(point - origin)
        var changed := angle(point - shifted)
        result.append(
            {
                "地标": marker.name,
                "原方位度": original,
                "假设位移后方位": changed,
                "角变化": delta_angle(changed, original),
                "原距离": point.distance_to(origin),
                "假设位移后距离": point.distance_to(shifted)
            }
        )
    return result


static func pair_separation(payload: Dictionary) -> Array:
    var current := visible(payload)
    var result := []
    for i in current.size():
        for j in range(i + 1, current.size()):
            var a: Dictionary = current[i]
            var b: Dictionary = current[j]
            var difference := absf(delta_angle(float(a["方位度"]), float(b["方位度"])))
            if difference <= float(payload.separation) * 2:
                result.append(
                    {"地标甲": a["地标"], "地标乙": b["地标"], "角间距": difference, "标签阈值": payload.separation}
                )
    result.sort_custom(func(a: Dictionary, b: Dictionary): return a["角间距"] < b["角间距"])
    return result.slice(0, 60)


static func radius_study(payload: Dictionary) -> Array:
    var result := []
    for factor in [0.25, 0.5, 1.0, 1.5, 2.0]:
        var sample := payload.duplicate(true)
        sample.radius = minf(100000, float(payload.radius) * float(factor))
        var current := visible(sample)
        result.append(
            {
                "参考半径": sample.radius,
                "窗口内地标": current.size(),
                "最大参考旅行秒": sample.radius / float(payload.speed)
            }
        )
    return result


static func alignment(payload: Dictionary) -> Array:
    var rows := rows(payload)
    rows.sort_custom(
        func(a: Dictionary, b: Dictionary): return absf(float(a["相对角度"])) < absf(float(b["相对角度"]))
    )
    var result := []
    for row in rows.slice(0, 8):
        result.append(
            {
                "地标": row["地标"],
                "需转向度": row["相对角度"],
                "距离": row["距离"],
                "半径内": row["距离"] <= float(payload.radius)
            }
        )
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var all := rows(payload)
    var angles := []
    for row in all:
        if row.bearing_defined:
            angles.append(row["方位度"])
    var stats := circular_statistics(angles)
    return [
        K.notice("已知地标方位", summary(payload)),
        {"kind": "custom", "title": "已知地标罗盘", "view": VIEW, "data": payload},
        K.notice("参考坐标", "0°东、90°北、180°西、270°南。世界Y轴向下，方位计算已转换。"),
        K.table("地标读数", ["地标", "方向", "方位状态", "方位度", "距离", "相对角度", "窗口内", "直线估算秒"], all),
        K.bars("八方向分布", sector_counts(payload)),
        K.table("各方向最近地标", ["方向", "最近地标", "距离", "方位度"], nearest_by_sector(payload)),
        K.table("朝向窗口比较", ["朝向度", "方向", "窗口内地标", "最近距离"], heading_sweep(payload)),
        K.table(
            "方位标签布局", ["地标", "距离", "相对角度", "标签展示"], label_layout(payload), "标签重叠只是图面布局，与世界遮挡无关。"
        ),
        K.table("相近方位地标", ["地标甲", "地标乙", "角间距", "标签阈值"], pair_separation(payload)),
        K.table("最大角间隔", ["起侧地标", "终侧地标", "角间隔", "中线方向"], angular_gaps(payload).slice(0, 8)),
        K.notice(
            "方位分布",
            (
                "均值%.1f° · 集中度%.3f · 圆周离散度%.1f°；集中度接近0时均值没有稳定方向。"
                % [stats.mean, stats.concentration, stats.spread]
            )
        ),
        K.table(
            "假设位移的视差",
            ["地标", "原方位度", "假设位移后方位", "角变化", "假设位移后距离"],
            parallax(payload),
            "这是假设的数学位移，不表示角色可站到该位置。"
        ),
        K.table("半径敏感性", ["参考半径", "窗口内地标", "最大参考旅行秒"], radius_study(payload)),
        K.table("参考观察朝向集", ["观察序号", "参考朝向", "方向", "新覆盖地标数", "剩余地标数"], recommend_windows(payload)),
        K.table("角误差下的窗口稳定性", ["地标", "相对角度", "角误差假设", "窗口稳定性"], uncertainty_windows(payload)),
        K.table(
            "双地标几何稳定性",
            ["地标甲", "地标乙", "几何稳定系数", "假设角误差度", "交点位置误差"],
            bearing_stability(payload),
            "从已知记录点反推假设射线，只研究误差敏感性，不在游戏内定位或移动角色。"
        ),
        K.table("距离带统计", ["距离带", "地标数", "平均距离", "最近距离", "最远距离"], range_bands(payload)),
        K.table("参考位移敏感性", ["假设位移", "平均方位变化", "最大方位变化", "最小方位变化"], baseline_study(payload)),
        K.table("最接近参考朝向", ["地标", "需转向度", "距离", "半径内"], alignment(payload))
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var old := {}
    for row in rows(a):
        old[row.id] = row
    var changes := []
    for row in rows(b):
        if old.has(row.id):
            var previous: Dictionary = old[row.id]
            changes.append(
                {
                    "地标": row["地标"],
                    "距离变化": float(row["距离"]) - float(previous["距离"]),
                    "方位变化": delta_angle(float(row["方位度"]), float(previous["方位度"])),
                    "窗口变化": "相同" if row["窗口内"] == previous["窗口内"] else "变化"
                }
            )
    return [
        K.table("共同已知地标变化", ["地标", "距离变化", "方位变化", "窗口变化"], changes),
        K.notice("比较边界", "只比较两个样本共同记录的地标，不将缺失条目判断为世界删除。")
    ]


static func intersect_rays(a: Vector2, angle_a: float, b: Vector2, angle_b: float) -> Dictionary:
    if not a.is_finite() or not b.is_finite() or not is_finite(angle_a) or not is_finite(angle_b):
        return {"ok": false, "reason": "参考几何无效", "conditioning": 0.0}
    if maxf(maxf(absf(a.x), absf(a.y)), maxf(absf(b.x), absf(b.y))) > V.MAX_COORDINATE:
        return {"ok": false, "reason": "参考几何超出容量", "conditioning": 0.0}
    var u := Vector2(cos(deg_to_rad(angle_a)), -sin(deg_to_rad(angle_a)))
    var v := Vector2(cos(deg_to_rad(angle_b)), -sin(deg_to_rad(angle_b)))
    var denominator := u.cross(v)
    if absf(denominator) < 0.000001:
        return {"ok": false, "reason": "方向近乎平行", "conditioning": absf(denominator)}
    var offset := b - a
    var t := offset.cross(v) / denominator
    var s := offset.cross(u) / denominator
    var point := a + u * t
    if t < 0 or s < 0 or not point.is_finite():
        return {"ok": false, "reason": "交点在参考射线后方", "conditioning": absf(denominator)}
    return {"ok": true, "point": point, "conditioning": absf(denominator), "reason": "参考射线有正向交点"}


static func bearing_stability(payload: Dictionary) -> Array:
    var candidates: Array = (
        rows(payload).filter(func(row: Dictionary): return row.bearing_defined).slice(0, 10)
    )
    var origin := V.point(payload.origin)
    var result := []
    for i in candidates.size():
        for j in range(i + 1, candidates.size()):
            var a: Dictionary = candidates[i]
            var b: Dictionary = candidates[j]
            var p := V.point(a.point)
            var q := V.point(b.point)
            var angle_a := angle(origin - p)
            var angle_b := angle(origin - q)
            var exact := intersect_rays(p, angle_a, q, angle_b)
            var perturbed := intersect_rays(
                p, angle_a + float(payload.uncertainty), q, angle_b - float(payload.uncertainty)
            )
            var error: Variant = "方向退化"
            if perturbed.ok:
                error = perturbed.point.distance_to(origin)
            result.append(
                {
                    "地标甲": a["地标"],
                    "地标乙": b["地标"],
                    "几何稳定系数": exact.conditioning,
                    "假设角误差度": payload.uncertainty,
                    "交点位置误差": error
                }
            )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary): return float(a["几何稳定系数"]) > float(b["几何稳定系数"])
    )
    return result


static func recommend_windows(payload: Dictionary) -> Array:
    var candidates := []
    var remaining := {}
    for row in rows(payload):
        if row["距离"] <= float(payload.radius):
            remaining[row.id] = true
    for step in 24:
        var sample := payload.duplicate(true)
        sample.heading = float(step) * 15
        var ids := []
        for row in visible(sample):
            ids.append(row.id)
        candidates.append({"heading": sample.heading, "ids": ids})
    var result := []
    while not remaining.is_empty() and result.size() < 24:
        var winner := -1
        var best := 0
        for i in candidates.size():
            var count := 0
            for id in candidates[i].ids:
                if remaining.has(id):
                    count += 1
            if count > best:
                best = count
                winner = i
        if winner < 0:
            break
        var choice: Dictionary = candidates[winner]
        var captured := []
        for id in choice.ids:
            if remaining.has(id):
                captured.append(id)
                remaining.erase(id)
        result.append(
            {
                "观察序号": result.size() + 1,
                "参考朝向": choice.heading,
                "方向": direction(choice.heading),
                "新覆盖地标数": captured.size(),
                "剩余地标数": remaining.size()
            }
        )
        candidates.remove_at(winner)
    return result


static func uncertainty_windows(payload: Dictionary) -> Array:
    var result := []
    var tolerance := float(payload.uncertainty)
    for row in rows(payload):
        var delta := absf(float(row["相对角度"]))
        var half := float(payload.fov) * 0.5
        var stable := delta + tolerance <= half
        var possible := delta - tolerance <= half
        var state := "稳定在窗口外"
        if stable:
            state = "稳定在窗口内"
        elif possible:
            state = "误差范围跨过窗口边界"
        result.append({"地标": row["地标"], "相对角度": row["相对角度"], "角误差假设": tolerance, "窗口稳定性": state})
    return result


static func range_bands(payload: Dictionary) -> Array:
    var groups := [[], [], [], []]
    for row in rows(payload):
        var ratio := float(row["距离"]) / float(payload.radius)
        var index := mini(3, int(floor(ratio * 3)))
        groups[index].append(float(row["距离"]))
    var labels := ["半径前三分之一", "半径中段", "半径外三分之一", "参考半径以外"]
    var result := []
    for i in groups.size():
        var stats := K.distribution(groups[i])
        result.append(
            {
                "距离带": labels[i],
                "地标数": stats.count,
                "平均距离": stats.mean,
                "最近距离": stats.min,
                "最远距离": stats.max
            }
        )
    return result


static func baseline_study(payload: Dictionary) -> Array:
    var result := []
    var origin := V.point(payload.origin)
    var orientation := deg_to_rad(float(payload.heading))
    var axis := Vector2(cos(orientation), -sin(orientation))
    for factor in [0.25, 0.5, 1.0, 2.0]:
        var moved := origin + axis * float(payload.baseline) * float(factor)
        var changes := []
        for marker in payload.markers:
            var point := V.point(marker.point)
            changes.append(absf(delta_angle(angle(point - moved), angle(point - origin))))
        var stats := K.distribution(changes)
        result.append(
            {
                "假设位移": float(payload.baseline) * float(factor),
                "平均方位变化": stats.mean,
                "最大方位变化": stats.max,
                "最小方位变化": stats.min
            }
        )
    return result
