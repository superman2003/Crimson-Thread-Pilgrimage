extends Node2D

const SWEEP := preload("res://scripts/attack_sweep.gd")
const VISUAL_POLICY := preload("res://scripts/combat_visual_policy.gd")
const BOSS_SKILL_ART := preload("res://scripts/boss_skill_art.gd")
var boss_command_id := ""
const MINOR_SKILL_ART := preload("res://scripts/minor_enemy_skill_art.gd")
var minor_command_id := ""

const WARNING_ALPHA_MIN := 0.45
const WARNING_ALPHA_MAX := 0.75
const WARNING_WIDTH := 3.0
const OUTLINE_COLOR := Color(0.07,0.05,0.04,0.85)
const OUTLINE_WIDTH := 1.5
const ORB_CORE_SCALE := 0.73

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
const BEAM_ART := preload("res://scripts/beam_art.gd")
const TERRAIN_ART := preload("res://scripts/terrain_attack_art.gd")
const GROUND_ART := preload("res://scripts/ground_hazard_art.gd")
const PROJECTILE_ART := preload("res://scripts/projectile_art.gd")

var travelled := 0.0
var impact_pool := false
var cancelled := false
var owner_required := false

func _ready() -> void:
    owner_required = is_instance_valid(owner_actor)
    add_to_group("hostile_attack")
    VISUAL_POLICY.place_danger(self)

func _physics_process(delta: float) -> void:
    if cancelled or is_queued_for_deletion() or (owner_required and not is_instance_valid(owner_actor)):
        cancel()
        return
    if is_instance_valid(owner_actor) and (not owner_actor.is_inside_tree() or owner_actor.is_queued_for_deletion() or (owner_actor.get("dying") == true) or (owner_actor.has_method("world_residency_active") and not owner_actor.world_residency_active())):
        cancel()
        return
    var target := get_tree().get_first_node_in_group("player") as CharacterBody2D
    if target != null and target.is_queued_for_deletion():
        target = null
    if target != null and (target.get("ui_input_locked") == true):
        return
    age += delta
    if age >= duration:
        # Fade is cosmetic and starts only after the existing damaging lifetime.
        # A skipped entire warning/lifetime or owner cancellation emits no fade.
        if effect_kind == "pool" and duration > arm_delay and age - delta >= arm_delay:
            GROUND_ART.spawn_fade(get_parent(), global_position, GROUND_ART.family_for(skin, owner_actor), radius, tint)
        if effect_kind in ["wave","eruption"] and duration > arm_delay and age - delta >= arm_delay:
            TERRAIN_ART.spawn_fade(get_parent(), global_position, TERRAIN_ART.family_for(effect_kind,skin,owner_actor), radius, velocity.x if effect_kind == "wave" else heading.x, tint)
        cancel()
        return
    if age < arm_delay:
        queue_redraw()
        return
    var previous := global_position
    var terrain_hit: Dictionary={}
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
            if not wall.is_empty() and (bool(wall.get("authored_rock",false)) or bool(wall.get("authored_static",false)) or wall.get("collider") is StaticBody2D):terrain_hit=wall
    if effect_kind=="projectile":
        if _resolve_swept_projectile(target,previous,global_position,terrain_hit):return
        if not terrain_hit.is_empty():
            if impact_pool:
                global_position=terrain_hit.position-Vector2(0,5)
                effect_kind="pool";velocity=Vector2.ZERO;gravity=0.0;radius=32.0;age=0.0;arm_delay=.55;duration=1.4
                queue_redraw();return
            _finish_impact(terrain_hit.position);return
        queue_redraw();return
    if reflected:
        for actor in get_tree().get_nodes_in_group("enemy"):
            if not is_instance_valid(actor) or actor.is_queued_for_deletion() or (actor.get("dying") == true): continue
            if actor.has_method("world_residency_active") and not actor.world_residency_active(): continue
            if actor is Node2D and actor.has_method("take_hit") and actor.global_position.distance_to(global_position)<44:
                _finish_impact(global_position)
                actor.take_hit(1,1 if velocity.x>0 else -1)
                return
    elif target != null:
        var center := target.global_position-Vector2(0,42)
        if not reflected and not hit_player and _hits_player(center):
            # Consume before callbacks: damage can synchronously re-enter or cancel us.
            hit_player=true
            if target.has_method("take_damage"):
                target.take_damage(damage,global_position,bool(get_meta("blockable",true)))
            if not cancelled and not is_queued_for_deletion() and is_instance_valid(target) and not target.is_queued_for_deletion() and snare>0 and target.has_method("apply_snare"):
                target.apply_snare(snare)
            if effect_kind=="projectile":
                _finish_impact(global_position)
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
    if age < arm_delay and (BOSS_SKILL_ART.draw_hazard_warning(self) or MINOR_SKILL_ART.draw_hazard_warning(self)):
        # Authored material is the main cue; the fine edge retains exact range.
        if effect_kind == "beam":
            _draw_beam_channel_outline(_beam_channel_corners(),Color(.98,.8,.46,.9),1.2)
        elif effect_kind == "pool":
            draw_arc(Vector2.ZERO,radius,0,TAU,32,Color(.98,.8,.46,.8),1.2,true)
        return
    if age >= arm_delay and MINOR_SKILL_ART.draw_hazard_execution(self):
        draw_arc(Vector2.ZERO,radius,0,TAU,32,Color(.98,.8,.46,.8),1.2,true)
        return
    if effect_kind in ["wave","eruption"]:
        var family := TERRAIN_ART.family_for(effect_kind,skin,owner_actor)
        var frame := TERRAIN_ART.frame_for(effect_kind,age,arm_delay)
        var direction := velocity.x if effect_kind == "wave" else heading.x
        if age < arm_delay:
            TERRAIN_ART.draw_frame(self,family,frame,radius,direction,Color(tint,.55))
        elif TERRAIN_ART.draw_frame(self,family,frame,radius,direction,Color(tint,1)):
            _draw_terrain_boundary()
            return
    if effect_kind == "pool":
        var family := GROUND_ART.family_for(skin, owner_actor)
        var frame := GROUND_ART.frame_for(age, arm_delay)
        if age < arm_delay:
            GROUND_ART.draw_frame(self, family, frame, radius, Color(tint, 0.55))
        elif GROUND_ART.draw_frame(self, family, frame, radius, Color(tint, 1.0)):
            # A flat painted footprint cannot express circular player collision.
            # Keep the existing radius explicit and fully readable until expiry.
            draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.07,0.05,0.04,0.9), 3.5, true)
            draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.98,0.76,0.4,0.95), 1.5, true)
            return
    if age<arm_delay:
        # Pulse never drops below a readable floor, so a glance mid-warning still sees the cue.
        var pulse := WARNING_ALPHA_MIN+(WARNING_ALPHA_MAX-WARNING_ALPHA_MIN)*(.5+.5*sin(age*18))
        var warning := Color(0.96,0.72,0.36,pulse)
        if effect_kind=="beam":
            var channel := _beam_channel_corners()
            draw_colored_polygon(channel,Color(warning,warning.a*.22))
            _draw_beam_channel_outline(channel,warning,WARNING_WIDTH)
            draw_line(Vector2.ZERO,heading*length,Color(1.0,0.91,0.71,pulse),WARNING_WIDTH,true)
        elif effect_kind=="eruption":
            draw_arc(Vector2.ZERO,radius,PI,TAU,24,warning,WARNING_WIDTH,true)
            draw_line(Vector2(-radius,0),Vector2(radius,0),warning,WARNING_WIDTH,true)
        else:
            draw_arc(Vector2.ZERO,radius,0,TAU,32,warning,WARNING_WIDTH,true)
        return
    var active_color := tint
    active_color.a=clampf((duration-age)/.18,0,1)
    if effect_kind == "beam":
        if BEAM_ART.draw_frame(self,BEAM_ART.family_for(skin,owner_actor),length,radius,heading,age-arm_delay):
            if length > 0:
                # Keep the exact channel visible for the entire damaging period.
                _draw_beam_channel_outline(_beam_channel_corners(),Color(.99,.91,.71,.9),1.5)
            return
    if effect_kind == "projectile":
        var axis := velocity.normalized() if velocity.length() > 1.0 else heading
        if PROJECTILE_ART.draw_frame(self, PROJECTILE_ART.family_for(skin, owner_actor), PROJECTILE_ART.flight_frame(age - arm_delay), radius, axis, active_color.a, reflected):
            return
    if effect_kind=="beam":
        draw_line(Vector2.ZERO,heading*length,Color(active_color,.15),radius*2+9,true)
        draw_line(Vector2.ZERO,heading*length,active_color,radius*2,true)
        draw_line(Vector2.ZERO,heading*length,Color(0.95,0.85,0.62,active_color.a),1.5,true)
        _draw_beam_channel_outline(_beam_channel_corners(),Color(0.99,0.91,0.71,active_color.a*.9),1.5)
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
        var outline := _outline_color(active_color.a)
        draw_arc(Vector2.ZERO,radius,PI*.55,PI*1.8,18,outline,4+OUTLINE_WIDTH*2,true)
        draw_line(Vector2(-radius,8),Vector2(radius,8),outline,2+OUTLINE_WIDTH*2,true)
        draw_arc(Vector2.ZERO,radius,PI*.55,PI*1.8,18,active_color,4,true)
        draw_line(Vector2(-radius,8),Vector2(radius,8),Color(0.96,0.85,0.58,active_color.a),2,true)
    else:
        var axis := velocity.normalized() if velocity.length()>1 else Vector2.RIGHT
        var side := axis.orthogonal()
        var outline := _outline_color(active_color.a)
        if skin in ["spore","pollen","light"]:
            var core := radius*ORB_CORE_SCALE
            draw_circle(Vector2.ZERO,radius,Color(active_color,.22))
            draw_circle(Vector2.ZERO,core+OUTLINE_WIDTH,outline)
            draw_circle(Vector2.ZERO,core,active_color)
            draw_circle(-axis*core*.36,core*.29,Color(1,.91,.69,active_color.a))
        elif skin=="page":
            var points := PackedVector2Array([-axis*radius-side*radius*.7,axis*radius-side*radius*.55,axis*radius*.8+side*radius*.65,-axis*radius+side*radius*.7])
            _draw_polygon_outline(points,outline)
            draw_colored_polygon(points,Color(0.88,0.83,0.66,active_color.a))
            draw_line(-axis*radius*.5,axis*radius*.65,active_color,2,true)
        elif skin=="key":
            draw_line(-axis*radius,axis*radius,outline,4+OUTLINE_WIDTH*2,true)
            draw_arc(-axis*radius,radius*.5,0,TAU,12,outline,2+OUTLINE_WIDTH*2,true)
            draw_line(axis*radius*.65,axis*radius*.65+side*radius*.55,outline,3+OUTLINE_WIDTH*2,true)
            draw_line(-axis*radius,axis*radius,active_color,4,true)
            draw_arc(-axis*radius,radius*.5,0,TAU,12,active_color,2,true)
            draw_line(axis*radius*.65,axis*radius*.65+side*radius*.55,active_color,3,true)
        else:
            var points := PackedVector2Array([axis*radius*1.5,-axis*radius+side*radius*.45,-axis*radius-side*radius*.45])
            _draw_polygon_outline(points,outline)
            draw_colored_polygon(points,active_color)
            draw_line(-axis*radius,axis*radius*1.4,Color(.95,.87,.67,active_color.a),1,true)

func _outline_color(alpha: float) -> Color:
    return Color(OUTLINE_COLOR,OUTLINE_COLOR.a*alpha)

# Dark rim drawn under a projectile body so it separates from both pale and dark backgrounds.
func _draw_polygon_outline(points: PackedVector2Array, color: Color) -> void:
    var closed := points.duplicate()
    closed.append(points[0])
    draw_polyline(closed,color,OUTLINE_WIDTH*2,true)

func _beam_channel_corners() -> PackedVector2Array:
    var axis := heading.normalized() if heading.length_squared() > 0.0001 else Vector2.RIGHT
    var side := axis.orthogonal() * maxf(radius, 0.0)
    var endpoint := axis * maxf(length, 0.0)
    return PackedVector2Array([-side, side, endpoint + side, endpoint - side])

func _draw_beam_channel_outline(corners: PackedVector2Array, color: Color, width: float) -> void:
    if corners.size() < 3:
        return
    var outline := corners.duplicate()
    outline.append(corners[0])
    draw_polyline(outline, color, width, true)

func cancel() -> void:
    if cancelled:
        return
    cancelled = true
    hide()
    set_physics_process(false)
    remove_from_group("hostile_attack")
    queue_free()

# Hits retire the damaging object immediately. The four impact cels are a
# separate budgeted decoration; cancellation/expiry/owner death emit no hit.
func _finish_impact(point: Vector2) -> void:
    if cancelled or is_queued_for_deletion():
        return
    if effect_kind == "projectile":
        var host := get_parent() as Node2D
        var axis := velocity.normalized() if velocity.length() > 1.0 else heading
        PROJECTILE_ART.spawn_impact(host, point, PROJECTILE_ART.family_for(skin, owner_actor), radius, axis, reflected)
    cancel()

# The hand-painted silhouette can be smaller than collision during rise/sway.
# Retain an explicit, stable cue until the original damaging object expires.
func _draw_terrain_boundary() -> void:
    var dark := Color(.07,.05,.04,.9)
    var pale := Color(.98,.76,.4,.9)
    if effect_kind == "wave":
        draw_arc(Vector2.ZERO,radius,0,TAU,28,dark,3,true)
        draw_arc(Vector2.ZERO,radius,0,TAU,28,pale,1,true)
    else:
        var corners := [Vector2(-radius,-92),Vector2(radius,-92),Vector2(radius,8),Vector2(-radius,8)]
        for i in range(4):
            var point: Vector2 = corners[i]
            var inward := Vector2(1 if i in [0,3] else -1,1 if i < 2 else -1)
            var marker := PackedVector2Array([point+Vector2(inward.x*6,0),point,point+Vector2(0,inward.y*7)])
            draw_polyline(marker,dark,3,true)
            draw_polyline(marker,pale,1,true)

func _resolve_swept_projectile(target: Node2D,start: Vector2,finish: Vector2,wall: Dictionary) -> bool:
    var limit:=SWEEP.fraction(start,finish,wall.position) if not wall.is_empty() else INF
    if reflected:
        var chosen: Node2D
        var time:=INF
        for actor in get_tree().get_nodes_in_group("enemy"):
            if not is_instance_valid(actor) or not actor is Node2D or actor.is_queued_for_deletion() or actor.get("dying")==true or not actor.has_method("take_hit"):continue
            if actor.has_method("world_residency_active") and not actor.world_residency_active():continue
            var contact:=SWEEP.circle_time(start,finish,actor.global_position,44.0)
            if contact<time:chosen=actor;time=contact
        if chosen==null or time>=limit:return false
        var direction:=1 if velocity.x>0 else -1
        _finish_impact(start.lerp(finish,time))
        if is_instance_valid(chosen) and not chosen.is_queued_for_deletion():chosen.take_hit(1,direction)
        return true
    if not is_instance_valid(target) or hit_player:return false
    var center:=target.global_position-Vector2(0,42)
    if bool(get_meta("blockable",true)) and target.has_method("can_deflect_projectile") and target.can_deflect_projectile():
        var time:=SWEEP.circle_time(start,finish,center,72.0)
        if time<limit and time<=1:
            var contact:=start.lerp(finish,time)
            var facing:=int(target.get("facing"))
            if (contact.x-center.x)*facing>0:
                global_position=contact;reflected=true
                velocity=Vector2(facing*maxf(250,velocity.length()),velocity.y*.35)
                tint=Color(0.94,0.86,0.61);queue_redraw();return true
    var time:=SWEEP.circle_time(start,finish,center,radius+23)
    if time>=limit or time>1:return false
    global_position=start.lerp(finish,time);hit_player=true
    if target.has_method("take_damage"):target.take_damage(damage,global_position,bool(get_meta("blockable",true)))
    if not cancelled and not is_queued_for_deletion() and is_instance_valid(target) and not target.is_queued_for_deletion() and snare>0 and target.has_method("apply_snare"):target.apply_snare(snare)
    if not cancelled and not is_queued_for_deletion():_finish_impact(global_position)
    return true
