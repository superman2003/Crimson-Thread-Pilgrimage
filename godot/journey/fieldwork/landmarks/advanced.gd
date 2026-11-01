extends RefCounted
## Weighted intersection of bearing lines in screen coordinates (north is -Y).
## This audits known geometry and hypothetical angle error, not real positioning.
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const MAX_OBSERVATIONS := 24
const CONDITION_LIMIT := 1000000.0


static func valid_observation(row: Variant) -> bool:
    if not row is Dictionary or not row.get("id") is String or row.id.is_empty():
        return false
    if not V.point(row.get("point")).is_finite():
        return false
    for key in ["bearing", "sigma"]:
        if not V.number(row.get(key)):
            return false
    return row.bearing >= 0 and row.bearing <= 360 and row.sigma > 0 and row.sigma <= 1000000


static func solve(observations: Array) -> Dictionary:
    if observations.size() < 2 or observations.size() > MAX_OBSERVATIONS:
        return {"ok": false, "reason": "需要2至24条不同地标的有效方位"}
    var ids := {}
    var xx := 0.0
    var xy := 0.0
    var yy := 0.0
    var bx := 0.0
    var by := 0.0
    for row in observations:
        if not valid_observation(row) or ids.has(row.id):
            return {"ok": false, "reason": "地标重复或方位误差无效"}
        ids[row.id] = true
        var direction := Vector2(cos(deg_to_rad(float(row.bearing))), -sin(deg_to_rad(float(row.bearing))))
        var normal := Vector2(-direction.y, direction.x)
        var point := V.point(row.point)
        var weight := 1.0 / pow(float(row.sigma), 2)
        var offset := normal.dot(point)
        xx += weight * normal.x * normal.x
        xy += weight * normal.x * normal.y
        yy += weight * normal.y * normal.y
        bx += weight * normal.x * offset
        by += weight * normal.y * offset
    var trace := xx + yy
    var discriminant := sqrt(maxf(0, (xx - yy) * (xx - yy) + 4 * xy * xy))
    var high := (trace + discriminant) * 0.5
    var low := (trace - discriminant) * 0.5
    var determinant := xx * yy - xy * xy
    if low <= 0 or determinant <= 0 or high / low > CONDITION_LIMIT:
        return {"ok": false, "reason": "方位几何近乎平行，位置无稳定解"}
    var point := Vector2((yy * bx - xy * by) / determinant, (xx * by - xy * bx) / determinant)
    if not point.is_finite():
        return {"ok": false, "reason": "定位结果超出有限数值范围"}
    var residuals := []
    var squared := 0.0
    var behind := 0
    for row in observations:
        var direction := Vector2(cos(deg_to_rad(float(row.bearing))), -sin(deg_to_rad(float(row.bearing))))
        var delta := V.point(row.point) - point
        var cross_error := direction.cross(delta)
        var standardized := cross_error / float(row.sigma)
        squared += standardized * standardized
        if delta.dot(direction) < 0:
            behind += 1
        residuals.append({
            "地标": row.id, "垂距残差": snappedf(cross_error, 0.001),
            "标准化残差": snappedf(standardized, 0.001),
            "正向": delta.dot(direction) >= 0
        })
    return {
        "ok": behind == 0, "point": [point.x, point.y], "condition": high / low,
        "major": sqrt(1.0 / low), "minor": sqrt(1.0 / high),
        "orientation": rad_to_deg(0.5 * atan2(2 * xy, xx - yy)) + 90,
        "residuals": residuals, "weighted_error": squared,
        "reason": "所有地标在正向方位上" if behind == 0 else "解与至少一条正向方位矛盾"
    }


static func observations(payload: Dictionary) -> Array:
    var result := []
    var origin := V.point(payload.origin)
    var candidates := []
    for marker in payload.markers:
        var delta := V.point(marker.point) - origin
        if delta.length() < 0.001 or delta.length() > float(payload.radius):
            continue
        candidates.append({"marker": marker, "distance": delta.length()})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary):
        if is_equal_approx(float(a.distance), float(b.distance)):
            return String(a.marker.id) < String(b.marker.id)
        return float(a.distance) < float(b.distance))
    for candidate in candidates.slice(0, MAX_OBSERVATIONS):
        var marker: Dictionary = candidate.marker
        var delta := V.point(marker.point) - origin
        result.append({
            "id": marker.id, "point": marker.point.duplicate(),
            "bearing": fposmod(rad_to_deg(atan2(-delta.y, delta.x)), 360),
            "sigma": maxf(0.001, delta.length() * tan(deg_to_rad(float(payload.uncertainty))))
        })
    return result


static func leave_one_out(rows: Array, baseline: Dictionary) -> Array:
    var result := []
    if not baseline.get("ok", false) or rows.size() < 3:
        return result
    for i in rows.size():
        var subset := rows.duplicate(true)
        subset.remove_at(i)
        var solved := solve(subset)
        result.append({
            "移除地标": rows[i].id, "仍可定位": solved.ok,
            "长轴误差尺度": snappedf(float(solved.get("major", 0)), 0.001) if solved.ok else "不可解",
            "条件数": snappedf(float(solved.get("condition", 0)), 0.01) if solved.ok else "不可解"
        })
    return result


static func sections(payload: Dictionary) -> Array:
    var rows := observations(payload)
    var result := solve(rows)
    if not result.ok:
        return [K.notice("多地标方位几何", result.reason)]
    return [
        K.notice("多地标加权方位定位",
            "%d个半径内已知地标；反算位置%s；条件数%.2f；长/短轴误差尺度%.3f/%.3f。"
            % [rows.size(), str(V.point(result.point)), result.condition, result.major, result.minor]),
        K.table("方位一致性残差", ["地标", "垂距残差", "标准化残差", "正向"], result.residuals),
        K.table("逐项移除稳定性", ["移除地标", "仍可定位", "长轴误差尺度", "条件数"], leave_one_out(rows, result)),
        K.notice("定位与误差前提", "方位来自当前记录点与已抵达房间中心的已知几何，不是新测量，也不会揭示未知地标。采用最近24个半径内地标；角误差转换为横向尺度并以加权最小二乘复核。零误差使用0.001数值下界，误差椭圆只是线性尺度，不是置信概率或实际寻路保证。")
    ]
