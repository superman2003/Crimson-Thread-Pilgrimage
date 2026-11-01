extends RefCounted
const RANGE:=650.0
const COOLDOWN_MS:=12000
const GLOBAL_GAP_MS:=4000
const RETRY_MS:=500

static func choose(rows: Array,played: Dictionary,now: int) -> int:
    var selected:=-1
    var oldest:=9223372036854775807
    var closest:=INF
    var selected_id:=""
    for index in rows.size():
        var row: Variant=rows[index]
        if not row is Dictionary or not row.get("id") is String or String(row.id).is_empty():continue
        var distance: Variant=row.get("distance")
        if not (distance is float or distance is int) or not is_finite(float(distance)) or distance<0 or distance>RANGE:continue
        var last:=int(played.get(row.id,-COOLDOWN_MS-1))
        if now-last<COOLDOWN_MS:continue
        if last<oldest or (last==oldest and (float(distance)<closest or (float(distance)==closest and String(row.id)<selected_id))):
            selected=index;oldest=last;closest=float(distance);selected_id=String(row.id)
    return selected
