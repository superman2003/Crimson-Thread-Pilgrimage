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

func configure(rects: Array[Rect2], rock_material: ShaderMaterial, theme: String = "moss_cavern") -> void:
    solid_rects = rects
    material = rock_material
    rim_theme = theme
    rim_descriptors = RIMS.exposed(rects)
    body_rects = rects.duplicate()
    for edge in rim_descriptors:
        var inset := minf(12,float(edge.depth)*0.25)
        var cut := Rect2(edge.left-Vector2(0,inset if edge.ceiling else 0),Vector2(edge.right.x-edge.left.x,inset))
        var remaining: Array[Rect2] = []
        for rect in body_rects:
            remaining.append_array(RIMS.subtract_rect(rect,cut))
        body_rects = remaining
        var cursor: float = edge.left.x
        while cursor < edge.right.x-0.01:
            var finish := minf(edge.right.x,(floorf(cursor/RIM_CHUNK)+1)*RIM_CHUNK)
            if finish <= cursor: finish = minf(edge.right.x,cursor+RIM_CHUNK)
            var key := "%d:%d:%s:%s" % [rim_chunks.size(),floori(cursor/RIM_CHUNK),str(edge.left.y),str(edge.ceiling)]
            var left := Vector2(cursor,edge.left.y)
            var right := Vector2(finish,edge.left.y)
            rim_chunks[key] = {"left":left,"right":right,"ceiling":edge.ceiling,"depth":edge.depth,"bounds":Rect2(left-Vector2(0,edge.depth if edge.ceiling else 12),Vector2(finish-cursor,edge.depth+12))}
            cursor = finish
    _refresh_view()

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
