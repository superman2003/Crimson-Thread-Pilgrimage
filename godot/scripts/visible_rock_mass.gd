extends Node2D
## Camera-resident rock fill plus independent authored exposed rims.
const ROCK := preload("res://scripts/world_rock_material.gd")
const RIMS := preload("res://scripts/cave_rim_geometry.gd")
var solid_rects: Array[Rect2] = []
var painted_rects: Array[Rect2] = []
var body_rects: Array[Rect2] = []
var painted_body_rects: Array[Rect2] = []
var rim_descriptors: Array[Dictionary] = []
var rim_chunks: Dictionary = {}
var resident_rims: Dictionary = {}
var view_bounds := Rect2()
var rim_theme := "moss_cavern"
const MARGIN := 96.0
const QUANTUM := 128.0
const RIM_CHUNK := 512.0

## Rim edges, trimmed bodies and rim chunks depend only on the region's rock
## rects. A region is rebuilt on every arrival, so the result is kept: a revisit
## reuses it instead of recomputing 10-30 ms of geometry in one build frame.
## Entries are read-only and shared between instances.
const GEOMETRY_CACHE_LIMIT := 24
static var _geometry_cache: Dictionary = {}
var _pending_rects: Array[Rect2] = []

func configure(rects: Array[Rect2], rock_material: ShaderMaterial, theme: String = "moss_cavern") -> void:
    prepare(rects, rock_material, theme)
    finish()

## First half of configure: the exposed rim edges. The loader runs finish() as
## its own build job so a first visit spreads the geometry over two frames.
func prepare(rects: Array[Rect2], rock_material: ShaderMaterial, theme: String = "moss_cavern") -> void:
    solid_rects = rects
    material = rock_material
    rim_theme = theme
    _pending_rects = rects
    var cached: Dictionary = _geometry_cache.get(hash(rects), {})
    if cached.has("rects") and cached.rects == rects:
        rim_descriptors = cached.rim_descriptors
        body_rects = cached.body_rects
        rim_chunks = cached.rim_chunks
        return
    rim_descriptors = RIMS.exposed(rects)
    body_rects = []
    rim_chunks = {}

func geometry_ready() -> bool:
    return _pending_rects.is_empty()

func finish() -> void:
    if _pending_rects.is_empty():
        return
    var rects := _pending_rects
    _pending_rects = []
    if rim_chunks.is_empty() and body_rects.is_empty():
        _build_bodies_and_chunks(rects)
        if _geometry_cache.size() >= GEOMETRY_CACHE_LIMIT:
            _geometry_cache.erase(_geometry_cache.keys()[0])
        _geometry_cache[hash(rects)] = {"rects": rects.duplicate(),
            "rim_descriptors": rim_descriptors, "body_rects": body_rects, "rim_chunks": rim_chunks}
    # A frame may have passed since prepare(); the view must be clipped again
    # now that the bodies exist.
    view_bounds = Rect2()
    _refresh_view()

func _build_bodies_and_chunks(rects: Array[Rect2]) -> void:
    # Each rect is trimmed by the rim cuts in edge order, independently of the
    # others, so trimming per rect against only the cuts near it gives the same
    # pieces in the same order as trimming the whole list once per edge (that
    # full scan cost up to ~0.4 s of one region-build frame).
    var cuts: Array[Rect2] = []
    for edge in rim_descriptors:
        var inset := minf(12,float(edge.depth)*0.25)
        cuts.append(Rect2(edge.left-Vector2(0,inset if edge.ceiling else 0),Vector2(edge.right.x-edge.left.x,inset)))
    var cut_cells := RIMS.grid_index(cuts)
    body_rects = []
    for rect in rects:
        var pieces: Array[Rect2] = [rect]
        for cut_index in RIMS.grid_query(cut_cells,rect.grow(1.0)):
            var cut := cuts[cut_index]
            var remaining: Array[Rect2] = []
            for piece in pieces:
                if piece.intersects(cut):
                    remaining.append_array(RIMS.subtract_rect(piece,cut))
                else:
                    remaining.append(piece)
            pieces = remaining
        body_rects.append_array(pieces)
    for edge in rim_descriptors:
        var cursor: float = edge.left.x
        while cursor < edge.right.x-0.01:
            var finish := minf(edge.right.x,(floorf(cursor/RIM_CHUNK)+1)*RIM_CHUNK)
            if finish <= cursor: finish = minf(edge.right.x,cursor+RIM_CHUNK)
            var key := "%d:%d:%s:%s" % [rim_chunks.size(),floori(cursor/RIM_CHUNK),str(edge.left.y),str(edge.ceiling)]
            var left := Vector2(cursor,edge.left.y)
            var right := Vector2(finish,edge.left.y)
            rim_chunks[key] = {"left":left,"right":right,"ceiling":edge.ceiling,"depth":edge.depth,"bounds":Rect2(left-Vector2(0,edge.depth if edge.ceiling else 12),Vector2(finish-cursor,edge.depth+12))}
            cursor = finish

func _process(_delta: float) -> void:
    _refresh_view()
    _refresh_rims()

func _refresh_view() -> void:
    var inverse := get_global_transform_with_canvas().affine_inverse()
    var size := get_viewport_rect().size
    var bounds := Rect2(inverse*Vector2.ZERO,Vector2.ZERO)
    for corner in [Vector2(size.x,0),size,Vector2(0,size.y)]: bounds = bounds.expand(inverse*corner)
    bounds = bounds.grow(MARGIN)
    var start := (bounds.position/QUANTUM).floor()*QUANTUM
    var finish := (bounds.end/QUANTUM).ceil()*QUANTUM
    bounds = Rect2(start,finish-start)
    if bounds == view_bounds: return
    view_bounds = bounds
    painted_rects.clear()
    painted_body_rects.clear()
    for solid in solid_rects:
        var clipped := solid.intersection(bounds)
        if clipped.has_area(): painted_rects.append(clipped)
    for solid in body_rects:
        var clipped := solid.intersection(bounds)
        if clipped.has_area(): painted_body_rects.append(clipped)
    _refresh_rims(true)
    queue_redraw()

func _refresh_rims(eager: bool = false) -> void:
    var keep := view_bounds.grow(384)
    for key in resident_rims.keys():
        if not rim_chunks[key].bounds.intersects(keep):
            var node: Node = resident_rims[key]
            remove_child(node)
            node.free()
            resident_rims.erase(key)
    var created := 0
    for key in rim_chunks:
        if resident_rims.has(key) or not rim_chunks[key].bounds.intersects(view_bounds): continue
        if not eager and created >= 2: break
        var edge: Dictionary = rim_chunks[key]
        var rim := ROCK.surface_rim(self,edge.left,edge.right,rim_theme,edge.ceiling,edge.depth)
        rim.set_meta("rim_chunk",key)
        resident_rims[key] = rim
        created += 1

func _draw() -> void:
    for rect in painted_body_rects: draw_rect(rect,Color.WHITE)
