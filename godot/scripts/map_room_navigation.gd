extends RefCounted
## Focus follows rendered, public rectangles. It does not calculate travel paths.
const ROOM_META := "map_room_navigation"

static func score(source: Rect2, target: Rect2, direction: Vector2) -> float:
    if not source.position.is_finite() or not target.position.is_finite() or source.size.x<=0 or source.size.y<=0 or target.size.x<=0 or target.size.y<=0:return INF
    var offset:=target.get_center()-source.get_center()
    var forward:=offset.dot(direction)
    if forward<=0.5:return INF
    var sideways:=absf(offset.dot(Vector2(-direction.y,direction.x)))
    var overlap:=minf(source.end.y,target.end.y)-maxf(source.position.y,target.position.y) if direction.x!=0 else minf(source.end.x,target.end.x)-maxf(source.position.x,target.position.x)
    # Prefer the same row/column; diagonal rooms remain reachable at row ends.
    return forward+sideways*2.0+(0.0 if overlap>0 else 10000.0)

static func neighbor(source: Control, direction: Vector2) -> Control:
    if not is_instance_valid(source) or not source.is_inside_tree():return null
    var chosen: Control
    var best:=INF
    for child in source.get_parent().get_children():
        if not child is Control or child==source or not child.has_meta(ROOM_META):continue
        if not child.is_visible_in_tree() or child.is_queued_for_deletion():continue
        var value:=score(source.get_global_rect(),child.get_global_rect(),direction)
        if value<best or (is_equal_approx(value,best) and chosen!=null and String(child.name)<String(chosen.name)):
            chosen=child;best=value
    return chosen

static func reveal(outline: Control) -> void:
    if not is_instance_valid(outline) or not outline.is_inside_tree():return
    var content:=outline.get_parent() as Control
    if content==null:return
    var view:=content.get_parent() as Control
    if view==null or not view.has_method("center_on"):return
    var viewport:=view.get_global_rect().grow(-8)
    if not viewport.encloses(outline.get_global_rect()):
        view.center_on(outline.position+outline.size*0.5,1.0)

static func bind(outline: Control) -> void:
    if outline.has_meta(ROOM_META):return
    outline.set_meta(ROOM_META,true)
    var reference: WeakRef=weakref(outline)
    outline.gui_input.connect(func(event: InputEvent):
        var owner:=reference.get_ref() as Control
        if not is_instance_valid(owner) or not owner.has_focus():return
        var direction:=Vector2.ZERO
        for pair in [["ui_left",Vector2.LEFT],["ui_right",Vector2.RIGHT],["ui_up",Vector2.UP],["ui_down",Vector2.DOWN]]:
            if event.is_action_pressed(pair[0]):direction=pair[1];break
        if direction==Vector2.ZERO:return
        var next:=neighbor(owner,direction)
        if next!=null:next.grab_focus();reveal(next)
        owner.accept_event())
    outline.focus_entered.connect(func():
        var owner:=reference.get_ref() as Control
        if is_instance_valid(owner):owner.queue_redraw();reveal(owner))
    outline.focus_exited.connect(outline.queue_redraw)
    outline.draw.connect(func():
        var owner:=reference.get_ref() as Control
        if is_instance_valid(owner) and owner.has_focus():
            owner.draw_rect(Rect2(Vector2.ONE,owner.size-Vector2(2,2)),Color("b44e43"),false,2.0))
