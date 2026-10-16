extends RefCounted
## Selection fixtures use production room/focus objects; no camera movement claim.
const ROOMS := preload("res://scripts/room_camera.gd")
const FOCUS := preload("res://scripts/camera_focus.gd")

func run(check: Callable) -> void:
    var focus := FOCUS.new()
    focus.region_bounds = Rect2(0,0,5000,3000)
    var rooms := ROOMS.new()
    for size in [Vector2(32,400),Vector2(400,32),Vector2(48,48),Vector2(8,8)]:
        var trigger := Rect2(Vector2(600,400),size)
        rooms.configure([
            {"id":"hall","layout_rect":[0,0,2000,2000],"camera_bounds":[0,0,2100,2100]},
            {"id":"narrow","visit_rects":[[600,400,size.x,size.y]],"camera_bounds":[400,200,1000,600]}
        ],focus)
        rooms.update(focus,Vector2(500,500))
        check.call(rooms.current.id=="hall","Narrow fixture starts in surrounding hall %s" % size)
        rooms.update(focus,trigger.position+Vector2.ONE,1.0/60)
        check.call(rooms.current.id=="hall","Entry edge retains doorway hysteresis %s" % size)
        rooms.update(focus,trigger.get_center(),1.0/60)
        check.call(rooms.current.id=="narrow","Thin trigger has a reachable decisive interior %s" % size)
        check.call(rooms.display_bounds.position.x>0 and rooms.display_bounds.position.x<400,"Thin room keeps eased limits %s" % size)
        rooms.update(focus,Vector2(trigger.end.x+8,trigger.get_center().y),1.0/60)
        check.call(rooms.current.id=="narrow","Exit edge retains current narrow view %s" % size)
        rooms.update(focus,Vector2(trigger.end.x+30,trigger.get_center().y),1.0/60)
        check.call(rooms.current.id=="hall","Leaving narrow room restores hall %s" % size)
    rooms.configure([],focus)
    check.call(rooms.current.is_empty() and not focus.locks.has(ROOMS.LOCK_ID),"Narrow room state is cleared on region reset")
