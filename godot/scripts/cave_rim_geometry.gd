extends RefCounted
## Exposed horizontal edges of the authoritative rectangle union.
static func subtract_span(spans: Array, cut: Vector2) -> Array:
    var result: Array = []
    for span in spans:
        if cut.y <= span.x or cut.x >= span.y:
            result.append(span)
        else:
            if cut.x > span.x: result.append(Vector2(span.x,minf(cut.x,span.y)))
            if cut.y < span.y: result.append(Vector2(maxf(cut.y,span.x),span.y))
    return result

static func exposed(rects: Array[Rect2]) -> Array[Dictionary]:
    var edges: Array[Dictionary] = []
    for index in range(rects.size()):
        var rect := rects[index]
        for ceiling in [false,true]:
            var y := rect.end.y if ceiling else rect.position.y
            var probe := y + (0.05 if ceiling else -0.05)
            var spans: Array = [Vector2(rect.position.x,rect.end.x)]
            for other_index in range(rects.size()):
                if other_index == index: continue
                var other := rects[other_index]
                var other_y := other.end.y if ceiling else other.position.y
                var blocks := probe > other.position.y and probe < other.end.y
                var duplicate := other_index < index and is_equal_approx(other_y,y)
                if blocks or duplicate:
                    spans = subtract_span(spans,Vector2(other.position.x,other.end.x))
                if spans.is_empty(): break
            for span in spans:
                if span.y-span.x > 0.1:
                    edges.append({"left":Vector2(span.x,y),"right":Vector2(span.y,y),"ceiling":ceiling,"depth":minf(96,rect.size.y*0.5)})
    # Merge touching collinear pieces only; never join across an opening.
    edges.sort_custom(func(a,b):
        if a.ceiling != b.ceiling: return not a.ceiling
        if a.left.y != b.left.y: return a.left.y < b.left.y
        return a.left.x < b.left.x)
    var merged: Array[Dictionary] = []
    for edge in edges:
        if not merged.is_empty():
            var previous: Dictionary = merged[-1]
            if previous.ceiling == edge.ceiling and is_equal_approx(previous.left.y,edge.left.y) and is_equal_approx(previous.right.x,edge.left.x):
                previous.right = edge.right
                previous.depth = minf(previous.depth,edge.depth)
                continue
        merged.append(edge.duplicate())
    return merged

static func subtract_rect(rect: Rect2, cut: Rect2) -> Array[Rect2]:
    var hit := rect.intersection(cut)
    if not hit.has_area(): return [rect]
    var result: Array[Rect2] = []
    for piece in [Rect2(rect.position,Vector2(rect.size.x,hit.position.y-rect.position.y)),
        Rect2(Vector2(rect.position.x,hit.end.y),Vector2(rect.size.x,rect.end.y-hit.end.y)),
        Rect2(Vector2(rect.position.x,hit.position.y),Vector2(hit.position.x-rect.position.x,hit.size.y)),
        Rect2(Vector2(hit.end.x,hit.position.y),Vector2(rect.end.x-hit.end.x,hit.size.y))]:
        if piece.has_area(): result.append(piece)
    return result
