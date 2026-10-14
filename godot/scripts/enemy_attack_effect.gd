extends Node2D

var effect_kind := "projectile"
var velocity := Vector2.ZERO
var gravity := 0.0
var radius := 10.0
var length := 260.0
var duration := 2.5
var arm_delay := 0.0
var damage := 1
var snare := 0.0
var age := 0.0
var hit_player := false
var reflected := false
var returning := false
var turn_after := 0.65
var steering := 0.0
var heading := Vector2.RIGHT
var tint := Color(0.84,0.33,0.25)
var skin := "thorn"
var owner_actor: Node2D
var travelled := 0.0
var impact_pool := false
var cancelled := false

func _ready() -> void:
    add_to_group("hostile_attack")
    z_index = 7

func _physics_process(delta: float) -> void:
    if cancelled or (is_instance_valid(owner_actor) and (owner_actor.is_queued_for_deletion() or bool(owner_actor.get("dying")))):
        cancel()
        return
    var target := get_tree().get_first_node_in_group("player") as CharacterBody2D
    if target != null and bool(target.get("ui_input_locked")):
        return
    age += delta
    if age >= duration:
        queue_free()
        return
    if age < arm_delay:
        queue_redraw()
        return
    var previous := global_position
    if effect_kind == "projectile" or effect_kind == "wave":
        if returning and age > turn_after and is_instance_valid(owner_actor):
            velocity = velocity.move_toward((owner_actor.global_position-global_position).normalized()*velocity.length(),delta*900.0)
        if steering>0 and age<0.8 and target!=null:
            var desired := (target.global_position-Vector2(0,42)-global_position).normalized()*velocity.length()
            velocity=velocity.move_toward(desired,steering*delta)
        velocity.y += gravity*delta
        position += velocity*delta
        travelled += global_position.distance_to(previous)
        if effect_kind == "wave":
            var level := get_parent()
            var terrain: Node = level.get("chapter_terrain")
            if terrain != null:
                var floor_y: float = terrain.floor_height(global_position.x,global_position.y+18,150)
                if is_finite(floor_y):
                    global_position.y=floor_y-18
        else:
            if get_parent().has_method("_ensure_collision_segment"):
                get_parent()._ensure_collision_segment(previous, global_position)
            var query := PhysicsRayQueryParameters2D.create(previous,global_position,1)
            query.collide_with_areas=false
            var wall := get_world_2d().direct_space_state.intersect_ray(query)
            if get_parent().has_method("_rock_ray_hit"):
                var rock: Dictionary = get_parent()._rock_ray_hit(previous, global_position)
                if not rock.is_empty() and (wall.is_empty() or previous.distance_squared_to(rock.position) < previous.distance_squared_to(wall.position)):
                    wall = rock
            if not wall.is_empty() and (bool(wall.get("authored_rock", false)) or bool(wall.get("authored_static", false)) or wall.get("collider") is StaticBody2D):
                if impact_pool:
                    global_position=wall.position-Vector2(0,5)
                    effect_kind="pool"
                    velocity=Vector2.ZERO
                    gravity=0.0
                    radius=32.0
                    age=0.0
                    arm_delay=.55
                    duration=1.4
                    queue_redraw()
                    return
                queue_free()
                return
    if reflected:
        for actor in get_tree().get_nodes_in_group("enemy"):
            if actor.has_method("world_residency_active") and not actor.world_residency_active(): continue
            if actor is Node2D and actor.has_method("take_hit") and actor.global_position.distance_to(global_position)<44:
                actor.take_hit(1,1 if velocity.x>0 else -1)
                queue_free()
                return
    elif target != null:
        var center := target.global_position-Vector2(0,42)
        # Straight projectiles can be deflected by a facing slash; waves and hazards require movement.
        if effect_kind=="projectile" and bool(get_meta("blockable",true)) and target.has_method("can_deflect_projectile") and target.can_deflect_projectile() and center.distance_to(global_position)<72:
            var facing := int(target.get("facing"))
            if (global_position.x-center.x)*facing>0:
                reflected=true
                velocity=Vector2(facing*maxf(250,velocity.length()),velocity.y*.35)
                tint=Color(0.94,0.86,0.61)
        if not reflected and not hit_player and _hits_player(center):
            if target.has_method("take_damage"):
                target.take_damage(damage,global_position,bool(get_meta("blockable",true)))
            if snare>0 and target.has_method("apply_snare"):
                target.apply_snare(snare)
            hit_player=true
            if effect_kind=="projectile":
                queue_free()
    queue_redraw()

func _hits_player(center: Vector2) -> bool:
    if effect_kind=="beam":
        var local := center-global_position
        var along := local.dot(heading)
        return along>=0 and along<=length and absf(local.cross(heading))<radius+19
    if effect_kind=="eruption":
        return Rect2(global_position-Vector2(radius,92),Vector2(radius*2,100)).has_point(center)
    return center.distance_to(global_position)<radius+23

func _draw() -> void:
    if age<arm_delay:
        var pulse := .35+.35*sin(age*18)
        var warning := Color(0.96,0.72,0.36,pulse)
        if effect_kind=="beam":
            draw_line(Vector2.ZERO,heading*length,warning,2.0,true)
        elif effect_kind=="eruption":
            draw_arc(Vector2.ZERO,radius,PI,TAU,24,warning,2.0,true)
            draw_line(Vector2(-radius,0),Vector2(radius,0),warning,2.0,true)
        else:
            draw_arc(Vector2.ZERO,radius,0,TAU,32,warning,2.0,true)
        return
    var active_color := tint
    active_color.a=clampf((duration-age)/.18,0,1)
    if effect_kind=="beam":
        draw_line(Vector2.ZERO,heading*length,Color(active_color,.15),radius*2+9,true)
        draw_line(Vector2.ZERO,heading*length,active_color,radius*2,true)
        draw_line(Vector2.ZERO,heading*length,Color(0.95,0.85,0.62,active_color.a),1.5,true)
    elif effect_kind=="eruption":
        for i in range(5):
            var x := (i-2)*radius*.36
            var h := 56.0+25.0*sin(i*2.1+age*3)
            draw_colored_polygon(PackedVector2Array([Vector2(x-8,0),Vector2(x+5,0),Vector2(x+7,-h)]),active_color)
            draw_line(Vector2(x,-2),Vector2(x+7,-h),Color(0.93,0.86,0.65,active_color.a),1,true)
    elif effect_kind=="pool":
        draw_circle(Vector2.ZERO,radius,Color(active_color,.18))
        draw_arc(Vector2.ZERO,radius,0,TAU,28,active_color,2,true)
        for i in range(5):
            var v := Vector2.from_angle(i*TAU/5+age)*radius*.6
            draw_circle(v,3.0,Color(0.9,0.78,0.5,active_color.a*.6))
    elif effect_kind=="wave":
        draw_arc(Vector2.ZERO,radius,PI*.55,PI*1.8,18,active_color,4,true)
        draw_line(Vector2(-radius,8),Vector2(radius,8),Color(0.96,0.85,0.58,active_color.a),2,true)
    else:
        var axis := velocity.normalized() if velocity.length()>1 else Vector2.RIGHT
        var side := axis.orthogonal()
        if skin in ["spore","pollen","light"]:
            draw_circle(Vector2.ZERO,radius,Color(active_color,.22))
            draw_circle(Vector2.ZERO,radius*.56,active_color)
            draw_circle(-axis*radius*.2,radius*.16,Color(1,.91,.69,active_color.a))
        elif skin=="page":
            var points := PackedVector2Array([-axis*radius-side*radius*.7,axis*radius-side*radius*.55,axis*radius*.8+side*radius*.65,-axis*radius+side*radius*.7])
            draw_colored_polygon(points,Color(0.88,0.83,0.66,active_color.a))
            draw_line(-axis*radius*.5,axis*radius*.65,active_color,2,true)
        elif skin=="key":
            draw_line(-axis*radius,axis*radius,active_color,4,true)
            draw_arc(-axis*radius,radius*.5,0,TAU,12,active_color,2,true)
            draw_line(axis*radius*.65,axis*radius*.65+side*radius*.55,active_color,3,true)
        else:
            draw_colored_polygon(PackedVector2Array([axis*radius*1.5,-axis*radius+side*radius*.45,-axis*radius-side*radius*.45]),active_color)
            draw_line(-axis*radius,axis*radius*1.4,Color(.95,.87,.67,active_color.a),1,true)

func cancel() -> void:
    cancelled = true
    set_physics_process(false)
    remove_from_group("hostile_attack")
    queue_free()
