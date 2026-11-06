extends RefCounted
## A group request carries record identities, never trusted coordinates. The
## runtime resolves them against the current public directory before projecting.
const MAX_TARGETS := 512
const MAX_KEY_LENGTH := 256
const POINT_MARGIN := 6.0

static func valid_key(value: Variant) -> bool:
    if not value is String or value.is_empty() or value.length()>MAX_KEY_LENGTH:
        return false
    for character in value:
        if character.unicode_at(0)<32 or character.unicode_at(0)==127:
            return false
    return true

static func resolve(current_rows: Array, candidate: Dictionary) -> Dictionary:
    var keys: Variant=candidate.get("keys")
    if not keys is Array or keys.is_empty() or keys.size()>MAX_TARGETS:
        return {"ok":false,"reason":"当前筛选没有可框取的已知地点。"}
    var requested := {}
    for key in keys:
        if not valid_key(key) or requested.has(key):
            return {"ok":false,"reason":"地点列表已变化，请重新筛选。"}
        requested[key]=true
    var found := {}
    for row in current_rows:
        if not row is Dictionary or not requested.has(row.get("key")):
            continue
        var key: String=row.key
        if found.has(key) or not row.get("region") is String or row.region.is_empty():
            return {"ok":false,"reason":"已知地点记录不完整，请重新打开目录。"}
        var point: Variant=row.get("point")
        if not point is Vector2 or not point.is_finite():
            return {"ok":false,"reason":"已知地点暂时无法在地图中查看。"}
        found[key]=row
    if found.size()!=requested.size():
        return {"ok":false,"reason":"部分地点已不在已购且已补绘的记录中，请重新筛选。"}
    var resolved: Array[Dictionary]=[]
    for key in keys:resolved.append(found[key].duplicate(true))
    return {"ok":true,"rows":resolved}

static func needs_world(rows: Array, current_region: String) -> bool:
    return rows.any(func(row):return String(row.region)!=current_region)

static func projected_bounds(rows: Array, project: Callable, paper: Rect2) -> Dictionary:
    if rows.is_empty() or rows.size()>MAX_TARGETS or not project.is_valid() or not valid_rect(paper):
        return {"ok":false}
    var bounds := Rect2()
    var count := 0
    for row in rows:
        if not row is Dictionary or not row.get("region") is String or not row.get("point") is Vector2 or not row.point.is_finite():
            return {"ok":false}
        var point: Variant=project.call(String(row.region),row.point)
        if not point is Vector2 or not point.is_finite() or not paper.has_point(point):
            return {"ok":false}
        bounds=Rect2(point,Vector2.ZERO) if count==0 else bounds.expand(point)
        count+=1
    # Use only known anchors, including the known section of a partially charted
    # room. Never include its unknown full geometry just to make a larger frame.
    bounds=bounds.grow(POINT_MARGIN).intersection(paper)
    return {"ok":valid_rect(bounds),"bounds":bounds,"count":count}

static func valid_rect(rect: Rect2) -> bool:
    return rect.position.is_finite() and rect.size.is_finite() and rect.size.x>0 and rect.size.y>0
