extends RefCounted
## Authored attack identities share collision primitives, not identical patterns.
static var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_combat_styles.json"))

static func apply(kind: String, profile: Dictionary) -> Dictionary:
    var style: Dictionary=catalog.bosses.get(kind,{})
    if style.is_empty():return profile
    var known:=false
    for command in profile.get("attacks",[]):
        if style.moves.has(String(command.get("id",""))):known=true
    if not known:return profile
    var result:=profile.duplicate(true)
    result.merge(style.profile,true);result.combat_identity=style.identity
    for command in result.get("attacks",[]):command.merge(style.moves.get(String(command.get("id","")),{}),true)
    return result

static func remember(actor: Node, delta: float, target: Node2D) -> void:
    if actor.kind!="silent_pilgrim_commander" or target==null:return
    actor.boss_history_clock+=delta
    if actor.boss_history_clock<.15:return
    actor.boss_history_clock=0.0
    actor.boss_target_history.append(target.global_position-Vector2(0,42))
    while actor.boss_target_history.size()>9:actor.boss_target_history.pop_front()

static func floor_point(actor: Node2D, x: float, fallback_y: float) -> Vector2:
    var terrain: Node=actor.get_parent().get("chapter_terrain")
    if terrain!=null:
        var floor_y: float=terrain.floor_height(x,fallback_y,210)
        if is_finite(floor_y):fallback_y=floor_y
    return Vector2(x,fallback_y-5)

static func blink_destination(actor: Node2D, command: Dictionary) -> Vector2:
    var x:=clampf(actor.attack_target.x-actor.attack_direction*float(command.get("blink_offset",155)),actor.arena_min_x,actor.arena_max_x)
    return preload("res://scripts/enemy_motion_sweep.gd").constrain(actor,actor.global_position,Vector2(x,actor.global_position.y))

static func combo_stage(command: Dictionary, progress: float) -> Dictionary:
    var beats: Array=command.get("combo_beats",[])
    var width:=float(command.get("combo_beat_width",.17))
    var previous:=0.0
    for i in beats.size():
        var start:=float(beats[i]);var end:=minf(1.0,start+width)
        if progress<start:return {"key":"prepare"+str(i),"phase":"windup","index":i,"start":previous,"end":start,"contact":false}
        if progress<end:return {"key":"strike"+str(i),"phase":"active","index":i,"start":start,"end":end,"contact":true}
        previous=end
    return {"key":"settle","phase":"recover","index":beats.size(),"start":previous,"end":1.0,"contact":false}

static func spawn(actor: Node2D, command: Dictionary, warning: bool) -> bool:
    if not actor.is_boss:return false
    var pattern:=String(command.get("boss_pattern",""))
    var origin:=actor.global_position+Vector2(actor.attack_direction*18,-22)
    var count:=int(command.get("shot_count",1))
    var windup:=float(command.get("windup",.8)) if warning else 0.0
    var life:=float(command.get("hazard_life",.7))
    match pattern:
        "canopy_rain":
            for i in count:
                actor._effect("projectile",origin+Vector2(0,-24),Vector2(actor.attack_direction*(50+i*29),-float(command.get("projectile_speed",145))-i*9),command,0,2.8)
            return true
        "canopy_pulses", "crown_alternating_wheels":
            for i in count:
                var side: int=-1 if i%2==0 else 1
                var speed:=float(command.get("projectile_speed",180))+floori(i/2)*float(command.get("speed_step",0))
                actor._effect("wave",actor.global_position+Vector2(0,24),Vector2(side*speed,0),command,floori(i/2)*.24,2.5)
            return true
        "canopy_root_chase":
            for i in count:
                var x:=lerpf(actor.global_position.x,actor.attack_target.x,float(i+1)/count)
                actor._effect("eruption",floor_point(actor,x,actor.global_position.y+40),Vector2.ZERO,command,windup+float(command.get("warning",.55))+i*.17,life)
            return true
        "scissor_crosscut":
            var heading:=Vector2(actor.attack_direction,-.1).normalized()
            actor._effect("beam",origin,heading,command,windup,life)
            return true
        "scissor_knot_row":
            for i in count:
                var x: float=actor.global_position.x+actor.attack_direction*(100+i*float(command.get("spacing",125)))
                actor._effect("pool",floor_point(actor,x,actor.global_position.y+40),Vector2.ZERO,command,windup+float(command.get("warning",.65)),life)
            return true
        "garden_staggered_roots":
            var order:=[0,3,1,2]
            for step in mini(count,order.size()):
                var lane: int=order[step]
                var x: float=actor.attack_target.x+(lane-1.5)*float(command.get("spacing",120))
                actor._effect("eruption",floor_point(actor,x,actor.attack_target.y+42),Vector2.ZERO,command,windup+float(command.get("warning",.65))+step*.2,life)
            return true
        "garden_side_cage":
            for offset: float in [-240.0,-125.0,125.0,240.0]:
                actor._effect("pool",floor_point(actor,actor.attack_target.x+offset,actor.attack_target.y+42),Vector2.ZERO,command,windup+float(command.get("warning",.85)),life)
            return true
        "mirror_position_echo":
            var history: Array=actor.boss_attack_history
            for i in count:
                var position: Vector2=history[maxi(0,history.size()-1-i*2)] if not history.is_empty() else actor.attack_target+Vector2((i-1)*float(command.get("spacing",135)),0)
                actor._effect("pool",floor_point(actor,position.x,position.y+42),Vector2.ZERO,command,windup+float(command.get("warning",.85))+i*.22,life)
            return true
        "mirror_committed_shift":
            preload("res://scripts/boss_skill_art.gd").spawn_departure(actor,command)
            actor.global_position=preload("res://scripts/enemy_motion_sweep.gd").constrain(actor,actor.global_position,actor.boss_blink_destination)
            actor.attack_direction=-1 if actor.attack_target.x<actor.global_position.x else 1
            actor.direction=actor.attack_direction;actor._set_sprite_flip(actor.direction<0)
            origin=actor.global_position+Vector2(actor.attack_direction*20,-24)
            actor._effect("projectile",origin,origin.direction_to(actor.attack_target)*float(command.get("projectile_speed",290)),command,.12,2.2)
            return true
        "crown_gate_corridor":
            var remote:=command.duplicate(true);remote.remote_origin=true
            for offset: float in [-145.0,145.0]:
                var x:=clampf(actor.attack_target.x+offset,actor.arena_min_x+22,actor.arena_max_x-22)
                var floor:=floor_point(actor,x,actor.global_position.y)
                actor._effect("beam",floor-Vector2(0,float(command.get("beam_length",210))),Vector2.DOWN,remote,windup,life)
            return true
    return false
