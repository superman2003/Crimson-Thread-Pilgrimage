extends RefCounted
## Attack telegraphs, wind-up and burst effects, and the command effects an enemy's attacks spawn.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ATTACK_EFFECT := preload("res://scripts/enemy_attack_effect.gd")
const BOSS_STYLE := preload("res://scripts/boss_combat_style.gd")
const CONTACT_ART := preload("res://scripts/player_contact_art.gd")
const MINOR_SKILL_ART := preload("res://scripts/minor_enemy_skill_art.gd")
const VISUAL_POLICY := preload("res://scripts/combat_visual_policy.gd")

const BOSS_SKILL_ART := preload("res://scripts/boss_skill_art.gd")

static func effect(actor: Node, effect_kind: String, point: Vector2, vel: Vector2, command: Dictionary, warning: float, lifetime: float) -> Node2D:
    if actor.dying or actor.is_queued_for_deletion() or not actor.is_inside_tree() or not actor.world_residency_active():
        return null
    var effect = ATTACK_EFFECT.new()
    effect.effect_kind=effect_kind
    effect.position=point
    effect.velocity=vel
    effect.heading=vel.normalized() if vel.length()>0 else Vector2(actor.attack_direction,0)
    if effect_kind in ["projectile","beam"] and not bool(command.get("remote_origin",false)):
        effect.launch_anchor=actor.body_center()
    effect.arm_delay=warning
    effect.duration=warning+lifetime
    effect.radius=float(command.get("radius",11))
    effect.length=float(command.get("beam_length",360))
    effect.beam_max_length=effect.length
    if effect_kind == "beam" and actor.is_inside_tree():
        if actor.get_parent().has_method("_ensure_collision_segment"):
            actor.get_parent()._ensure_collision_segment(point, point + effect.heading * effect.length)
        var query = PhysicsRayQueryParameters2D.create(point, point + effect.heading * effect.length, 1)
        query.collide_with_areas = false
        query.exclude = ATTACK_EFFECT.player_bodies(actor.get_tree())
        var obstruction = actor.get_world_2d().direct_space_state.intersect_ray(query)
        if actor.get_parent().has_method("_rock_ray_hit"):
            var rock: Dictionary = actor.get_parent()._rock_ray_hit(point, point + effect.heading * effect.length)
            if not rock.is_empty() and (obstruction.is_empty() or point.distance_squared_to(rock.position) < point.distance_squared_to(obstruction.position)):
                obstruction = rock
        if not obstruction.is_empty():
            effect.length = minf(effect.length, point.distance_to(obstruction.position))
    effect.set_meta("blockable", bool(command.get("blockable", true)))
    effect.damage=int(command.get("damage",actor.damage))
    effect.gravity=float(command.get("gravity",0))
    effect.snare=float(command.get("snare",0))
    effect.skin=String(command.get("skin","thorn"))
    effect.returning=bool(command.get("returning",false))
    effect.steering=float(command.get("steering",0))
    effect.impact_pool=bool(command.get("impact_pool",false))
    effect.owner_actor=actor
    effect.boss_command_id=String(command.get("id","")) if BOSS_SKILL_ART.matches(actor,command) else ""
    effect.minor_command_id=String(command.get("id","")) if MINOR_SKILL_ART.matches(actor,command) else ""
    # Freed Object references cannot be converted to a typed lambda argument.
    # Prune in place, retaining the typed array and never dereferencing stale nodes.
    for index in range(actor.owned_attack_effects.size() - 1, -1, -1):
        var previous = actor.owned_attack_effects[index]
        if not is_instance_valid(previous) or previous.is_queued_for_deletion():
            actor.owned_attack_effects.remove_at(index)
    actor.owned_attack_effects.append(effect)
    effect.tint=Color.html("#"+String(command.get("telegraph","c99558")))
    actor.get_parent().add_child(effect)
    return effect


static func spawn_command_effects(actor: Node, command: Dictionary, warning: bool) -> void:
    if BOSS_STYLE.spawn(actor,command,warning):return
    var type := String(command.get("type","melee"))
    var origin = actor.global_position+Vector2(actor.attack_direction*18,-22)
    var aim = (actor.attack_target-origin).normalized()
    var count := int(command.get("shot_count",1))
    var projectile_speed := float(command.get("projectile_speed",220))
    if type in ["projectile","fan","nova","mortar","wave"]:
        for i in range(count):
            var velocity_value = aim*projectile_speed
            if type=="fan":
                var spread := float(command.get("spread",.5))
                velocity_value=aim.rotated((float(i)/maxi(1,count-1)-.5)*spread)*projectile_speed
            elif type=="nova":
                velocity_value=Vector2.from_angle(float(i)/count*TAU)*projectile_speed
            elif type=="mortar":
                velocity_value=Vector2(actor.attack_direction*(projectile_speed+i*52),-260-i*30)
            elif type=="wave":
                velocity_value=Vector2((-1 if i%2==0 else 1)*(projectile_speed+floori(i/2)*float(command.get("speed_step",0))),0)
            var point = actor.global_position+Vector2(0,24) if type=="wave" else origin
            actor._effect("wave" if type=="wave" else "projectile",point,velocity_value,command,0,3.0)
    elif type=="beam":
        var warn := float(command.get("windup",.6)) if warning else .05
        actor._effect("beam",origin,aim,command,warn,float(command.get("hazard_life",.4)))
    elif type in ["pool","rootline"]:
        for i in range(count):
            var x = actor.attack_target.x+(i-(count-1)*.5)*float(command.get("spacing",90))
            var floor_y = actor.attack_target.y+42
            if type=="rootline" and not bool(command.get("targeted",false)):
                x=actor.global_position.x+actor.attack_direction*(i+1)*float(command.get("spacing",90))
                floor_y=actor.global_position.y+40
            var terrain: Node=actor.get_parent().get("chapter_terrain")
            if terrain!=null:
                var sampled: float=terrain.floor_height(x,floor_y,210)
                if is_finite(sampled):floor_y=sampled
            var delay: float = (float(command.get("windup",.6)) if warning else 0.0)+float(command.get("warning",.65))+i*(.12 if type=="rootline" else 0.0)
            actor._effect("eruption" if type=="rootline" else "pool",Vector2(x,floor_y-5),Vector2.ZERO,command,delay,float(command.get("hazard_life",.7)))
    elif type=="blink":
        BOSS_SKILL_ART.spawn_departure(actor,command)
        MINOR_SKILL_ART.spawn_departure(actor,command)
        var x = actor.attack_target.x-actor.attack_direction*float(command.get("blink_offset",115))
        actor.global_position.x=clampf(x,actor.platform_min_x,actor.platform_max_x)
        actor.reset_physics_interpolation()
        var target: CharacterBody2D = actor._target_player()
        if target!=null:actor._face_target(target)
        origin=actor.global_position+Vector2(actor.direction*20,-24)
        actor._effect("projectile",origin,(actor.attack_target-origin).normalized()*projectile_speed,command,.12,2.5)


static func show_telegraph(actor: Node, command: Dictionary) -> void:
    actor._clear_telegraph()
    if BOSS_SKILL_ART.matches(actor, command): return
    if MINOR_SKILL_ART.ready_for(actor,command): return
    if actor.original_visual:
        return
    var attack_type := String(command.get("type", "melee"))
    actor.telegraph = Polygon2D.new()
    var color := Color.html("#" + String(command.get("telegraph", "d66b3d")))
    color.a = 0.34
    var width := float(command.get("hit_width", 84.0))
    var height := float(command.get("hit_height", 58.0))
    var dir = actor.attack_direction if actor._is_attack_state() else actor.direction
    var offset = dir * float(command.get("offset", 44.0))
    if attack_type == "aoe":
        offset = 0.0
        width = float(command.get("hit_width", 150.0))
        height = float(command.get("hit_height", 88.0))
    elif attack_type == "shockwave":
        offset = dir * float(command.get("offset", 102.0))
        width = float(command.get("hit_width", 220.0))
        height = float(command.get("hit_height", 42.0))
    elif attack_type == "retreat":
        offset = dir * float(command.get("offset", 64.0))
        width = float(command.get("hit_width", 118.0))
        height = float(command.get("hit_height", 64.0))
    elif attack_type == "feint":
        offset = dir * float(command.get("offset", 54.0))
        width = float(command.get("hit_width", 104.0))
        height = float(command.get("hit_height", 72.0))
    actor.telegraph.polygon = PackedVector2Array([
        Vector2(offset - width * 0.5, -26.0 - height * 0.5),
        Vector2(offset + width * 0.5, -26.0 - height * 0.5),
        Vector2(offset + width * 0.5, -26.0 + height * 0.5),
        Vector2(offset - width * 0.5, -26.0 + height * 0.5)
    ])
    actor.telegraph.color = color
    VISUAL_POLICY.place_danger(actor.telegraph, true)
    actor.add_child(actor.telegraph)
    actor._add_attack_type_signature(actor.telegraph, command, Vector2(offset, -26.0), width, height, dir)
    actor.telegraph_tween = actor._combat_tween()
    actor.telegraph_tween.set_loops(3)
    actor.telegraph_tween.tween_property(actor.telegraph, "scale", Vector2(1.08, 1.08), 0.08)
    actor.telegraph_tween.tween_property(actor.telegraph, "scale", Vector2(1.0, 1.0), 0.08)


static func add_attack_type_signature(actor: Node, parent: Node2D, command: Dictionary, center: Vector2, width: float, height: float, dir: int) -> Line2D:
    var signature := Line2D.new()
    signature.name = "AttackTypeSignature"
    signature.width = 2.0
    signature.default_color = Color(1.0, 0.93, 0.72, 0.92)
    signature.z_index = 1
    var mark_width := minf(width * 0.18, 24.0)
    var mark_height := minf(height * 0.18, 14.0)
    match String(command.get("type", "melee")):
        "aoe":
            signature.points = PackedVector2Array([
                center + Vector2(0.0, -mark_height),
                center + Vector2(mark_width, 0.0),
                center + Vector2(0.0, mark_height),
                center + Vector2(-mark_width, 0.0),
                center + Vector2(0.0, -mark_height)
            ])
        "wave":
            signature.points = PackedVector2Array([
                center + Vector2(-mark_width, 0.0),
                center + Vector2(-mark_width * 0.5, -mark_height),
                center,
                center + Vector2(mark_width * 0.5, mark_height),
                center + Vector2(mark_width, 0.0)
            ])
        "shockwave":
            signature.points = PackedVector2Array([
                center + Vector2(-mark_width, mark_height * 0.35),
                center + Vector2(-mark_width * 0.5, -mark_height * 0.35),
                center + Vector2(0.0, mark_height * 0.35),
                center + Vector2(mark_width * 0.5, -mark_height * 0.35),
                center + Vector2(mark_width, mark_height * 0.35)
            ])
        "lunge":
            signature.points = PackedVector2Array([
                center + Vector2(-dir * mark_width, -mark_height),
                center + Vector2(dir * mark_width, 0.0),
                center + Vector2(-dir * mark_width, mark_height)
            ])
        "retreat":
            signature.points = PackedVector2Array([
                center + Vector2(-mark_width, -mark_height),
                center + Vector2(-mark_width * 0.5, mark_height),
                center + Vector2(0.0, -mark_height),
                center + Vector2(mark_width * 0.5, mark_height),
                center + Vector2(mark_width, -mark_height)
            ])
        "feint":
            signature.points = PackedVector2Array([
                center + Vector2(-mark_width, mark_height),
                center + Vector2(0.0, -mark_height),
                center + Vector2(mark_width, mark_height)
            ])
        "projectile":
            signature.points = PackedVector2Array([Vector2(-1, 0), Vector2(1, 0), Vector2(0.4, -0.6), Vector2(1, 0), Vector2(0.4, 0.6)])
        "fan":
            signature.points = PackedVector2Array([Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(1, 1)])
        "combo":
            signature.points = PackedVector2Array([Vector2(-1, 1), Vector2(-0.3, -1), Vector2(0.3, 1), Vector2(1, -1)])
        "guard":
            signature.points = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(0.7, 0.5), Vector2(0, 1), Vector2(-0.7, 0.5), Vector2(-1, -1)])
        "dive":
            signature.points = PackedVector2Array([Vector2(-1, -1), Vector2(1, 1), Vector2(0.2, 0.8), Vector2(1, 1), Vector2(0.8, 0.2)])
        "vault":
            signature.points = PackedVector2Array([Vector2(-1, 1), Vector2(-0.5, -0.5), Vector2(0, -1), Vector2(0.5, -0.5), Vector2(1, 1)])
        "rootline":
            signature.points = PackedVector2Array([Vector2(-1, 1), Vector2(-1, 0), Vector2(0, 0), Vector2(0, -1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
        "pool":
            signature.points = PackedVector2Array([Vector2(-1, 0), Vector2(-0.5, -0.7), Vector2(0.5, -0.7), Vector2(1, 0), Vector2(0.5, 0.7), Vector2(-0.5, 0.7), Vector2(-1, 0)])
        "mortar":
            signature.points = PackedVector2Array([Vector2(-1, 1), Vector2(-0.5, -0.6), Vector2(0, -1), Vector2(0.5, -0.6), Vector2(1, 1), Vector2(0.5, 1)])
        "beam":
            signature.points = PackedVector2Array([Vector2(-1, -0.4), Vector2(1, -0.4), Vector2(1, 0.4), Vector2(-1, 0.4)])
        "nova":
            signature.points = PackedVector2Array([Vector2(0, -1), Vector2(0.3, -0.3), Vector2(1, 0), Vector2(0.3, 0.3), Vector2(0, 1), Vector2(-0.3, 0.3), Vector2(-1, 0), Vector2(-0.3, -0.3), Vector2(0, -1)])
        "blink":
            signature.points = PackedVector2Array([Vector2(-1, -1), Vector2(-0.3, -1), Vector2(-0.3, 1), Vector2(0.3, -1), Vector2(0.3, 1), Vector2(1, 1)])
        "melee":
            signature.points = PackedVector2Array([
                center + Vector2(-mark_width, mark_height),
                center + Vector2(mark_width, -mark_height)
            ])
        _:
            # Neutral dot for future/unknown types; never imply a melee attack.
            signature.points = PackedVector2Array([Vector2(-0.12, 0), Vector2(0.12, 0)])
    if String(command.get("type", "melee")) not in ["melee", "lunge", "aoe", "wave", "shockwave", "retreat", "feint"]:
        for index in range(signature.points.size()):
            signature.set_point_position(index, center + signature.points[index] * Vector2(mark_width * dir, mark_height))
    parent.add_child(signature)
    return signature


static func clear_telegraph(actor: Node) -> void:
    BOSS_SKILL_ART.clear(actor)
    MINOR_SKILL_ART.clear(actor)
    actor.support_target = null
    if actor.telegraph_tween != null and is_instance_valid(actor.telegraph_tween) and actor.telegraph_tween.is_valid():
        actor.telegraph_tween.kill()
    actor.telegraph_tween = null
    if actor.telegraph != null and is_instance_valid(actor.telegraph):
        actor.telegraph.queue_free()
    actor.telegraph = null
    if actor.windup_vfx_tween != null and is_instance_valid(actor.windup_vfx_tween) and actor.windup_vfx_tween.is_valid():
        actor.windup_vfx_tween.kill()
    actor.windup_vfx_tween = null
    if actor.windup_vfx != null and is_instance_valid(actor.windup_vfx):
        actor.windup_vfx.queue_free()
    actor.windup_vfx = null


static func original_attack_arc(actor: Node, command: Dictionary, warning: bool) -> void:
    var type := String(command.get("type", "melee"))
    if type in ["beam", "pool", "rootline"] and not warning: return
    var line := Line2D.new()
    line.name = "OriginalAttackWarning" if warning else "OriginalAttackArc"
    line.width = 1.6 if warning else 3.5
    line.default_color = Color(.95,.77,.45,.68) if warning else Color(.86,.33,.25,.85)
    VISUAL_POLICY.place_danger(line, warning)
    var points := PackedVector2Array()
    var reach := float(command.get("hit_width",80))*.62
    if type in ["beam", "pool", "rootline"]:
        # These attacks keep their specialized range cues; add only the type mark.
        points = PackedVector2Array()
    elif type in ["projectile", "fan", "mortar", "nova"]:
        var aim = (actor.attack_target-actor.global_position-Vector2(0,-22)).normalized()
        points=PackedVector2Array([Vector2(0,-22),Vector2(0,-22)+aim*48,Vector2(0,-22)+aim*40+aim.orthogonal()*8])
    else:
        for i in range(18):
            var angle := lerpf(-1.25,1.25,float(i)/17)
            points.append(Vector2(actor.attack_direction*(20+cos(angle)*reach),-26+sin(angle)*float(command.get("hit_height",70))*.55))
    line.points=points
    if warning:
        var attack_type := String(command.get("type", "melee"))
        var width := float(command.get("hit_width", 80.0))
        var height := float(command.get("hit_height", 70.0))
        var center := Vector2(actor.attack_direction * float(command.get("offset", 44.0)), -26.0)
        if attack_type == "aoe":
            center.x = 0.0
            width = float(command.get("hit_width", 150.0))
            height = float(command.get("hit_height", 88.0))
        elif attack_type == "shockwave":
            center.x = actor.attack_direction * float(command.get("offset", 102.0))
            width = float(command.get("hit_width", 220.0))
            height = float(command.get("hit_height", 42.0))
        elif attack_type == "retreat":
            center.x = actor.attack_direction * float(command.get("offset", 64.0))
            width = float(command.get("hit_width", 118.0))
            height = float(command.get("hit_height", 64.0))
        elif attack_type == "feint":
            center.x = actor.attack_direction * float(command.get("offset", 54.0))
            width = float(command.get("hit_width", 104.0))
            height = float(command.get("hit_height", 72.0))
        actor._add_attack_type_signature(line, command, center, width, height, actor.attack_direction)
    actor.add_child(line)
    var tween: Tween = actor._combat_tween()
    tween.tween_property(line,"modulate:a",0.0,float(command.get("windup",.5)) if warning else .22)
    tween.finished.connect(line.queue_free)
    if warning:
        actor.windup_vfx = line
        actor.windup_vfx_tween = tween


static func spawn_windup_vfx(actor: Node, command: Dictionary) -> void:
    if BOSS_SKILL_ART.spawn(actor, command, "warning"): return
    if MINOR_SKILL_ART.spawn(actor,command,"warning"): return
    if actor.original_visual:
        actor._original_attack_arc(command, true)
        return
    var warning := Line2D.new()
    warning.name = "EnemyWindupVfx"
    actor.windup_vfx = warning
    var width := float(command.get("hit_width", 84.0))
    var height := float(command.get("hit_height", 58.0))
    var dir = actor.attack_direction if actor._is_attack_state() else actor.direction
    var offset = dir * float(command.get("offset", 44.0))
    var attack_type := String(command.get("type", "melee"))
    if attack_type == "aoe":
        offset = 0.0
    elif attack_type == "shockwave":
        offset = dir * float(command.get("offset", 102.0))
        width = float(command.get("hit_width", 220.0))
        height = float(command.get("hit_height", 42.0))
    elif attack_type == "retreat":
        offset = dir * float(command.get("offset", 64.0))
        width = float(command.get("hit_width", 118.0))
        height = float(command.get("hit_height", 64.0))
    elif attack_type == "feint":
        offset = dir * float(command.get("offset", 54.0))
        width = float(command.get("hit_width", 104.0))
        height = float(command.get("hit_height", 72.0))
    warning.points = PackedVector2Array([
        Vector2(offset - width * 0.5, -26.0 - height * 0.5),
        Vector2(offset + width * 0.5, -26.0 - height * 0.5),
        Vector2(offset + width * 0.5, -26.0 + height * 0.5),
        Vector2(offset - width * 0.5, -26.0 + height * 0.5),
        Vector2(offset - width * 0.5, -26.0 - height * 0.5)
    ])
    warning.width = 3.0 if actor.is_boss else 2.0
    warning.default_color = Color(1.0, 0.72, 0.28, 0.92)
    VISUAL_POLICY.place_danger(warning, true)
    actor.add_child(warning)
    actor.windup_vfx_tween = actor._combat_tween()
    actor.windup_vfx_tween.tween_property(warning, "scale", Vector2(1.16, 1.16), float(command.get("windup", 0.25)))
    actor.windup_vfx_tween.parallel().tween_property(warning, "modulate:a", 0.0, float(command.get("windup", 0.25)))
    actor.windup_vfx_tween.finished.connect(Callable(warning, "queue_free"))


static func spawn_attack_burst_vfx(actor: Node, command: Dictionary) -> void:
    if BOSS_SKILL_ART.spawn(actor, command, "execution"): return
    if MINOR_SKILL_ART.spawn(actor,command,"execution"): return
    if actor.original_visual:
        actor._original_attack_arc(command, false)
        return
    var burst := Line2D.new()
    burst.name = "BossAttackBurstVfx" if actor.is_boss else "EnemyAttackBurstVfx"
    var attack_type := String(command.get("type", "melee"))
    var width := float(command.get("hit_width", 88.0))
    var height := float(command.get("hit_height", 58.0))
    var dir = actor.attack_direction if actor._is_attack_state() else actor.direction
    var offset = dir * float(command.get("offset", 48.0))
    if attack_type == "aoe":
        offset = 0.0
    elif attack_type == "shockwave":
        offset = dir * float(command.get("offset", 102.0))
        width = float(command.get("hit_width", 220.0))
        height = float(command.get("hit_height", 42.0))
    elif attack_type == "retreat":
        offset = dir * float(command.get("offset", 64.0))
        width = float(command.get("hit_width", 118.0))
        height = float(command.get("hit_height", 64.0))
    elif attack_type == "feint":
        offset = dir * float(command.get("offset", 54.0))
        width = float(command.get("hit_width", 104.0))
        height = float(command.get("hit_height", 72.0))
    burst.width = 5.0 if actor.is_boss else 3.0
    burst.default_color = Color(1.0, 0.34, 0.22, 0.88) if actor.is_boss else Color(1.0, 0.78, 0.34, 0.86)
    VISUAL_POLICY.place_danger(burst)
    if attack_type == "aoe":
        var points := PackedVector2Array()
        for step in range(26):
            var angle := TAU * float(step) / 26.0
            points.append(Vector2(cos(angle) * width * 0.46, sin(angle) * height * 0.46 - 26.0))
        burst.points = points
        burst.closed = true
    elif attack_type == "shockwave":
        burst.width = 6.0 if actor.is_boss else 4.0
        burst.points = PackedVector2Array([
            Vector2(offset - width * 0.5, -14.0),
            Vector2(offset - width * 0.22, -30.0),
            Vector2(offset + width * 0.08, -8.0),
            Vector2(offset + width * 0.34, -28.0),
            Vector2(offset + width * 0.5, -12.0)
        ])
    elif attack_type == "retreat":
        burst.points = PackedVector2Array([
            Vector2(offset + width * 0.45, -62.0),
            Vector2(offset - width * 0.1, -36.0),
            Vector2(offset + width * 0.4, -10.0),
            Vector2(offset - width * 0.3, 2.0)
        ])
    elif attack_type == "feint":
        burst.points = PackedVector2Array([
            Vector2(offset - width * 0.35, -55.0),
            Vector2(offset + width * 0.28, -40.0),
            Vector2(offset - width * 0.08, -18.0),
            Vector2(offset + width * 0.42, 0.0)
        ])
    else:
        burst.points = PackedVector2Array([
            Vector2(offset - width * 0.48, -38.0),
            Vector2(offset, -18.0),
            Vector2(offset + width * 0.52, -42.0),
            Vector2(offset + width * 0.22, 4.0)
        ])
    actor.add_child(burst)
    var tween: Tween = actor._combat_tween()
    tween.tween_property(burst, "scale", Vector2(1.35, 1.35), 0.18)
    tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.18)
    tween.finished.connect(Callable(burst, "queue_free"))


static func spawn_hit_spark(actor: Node, hit_direction: int, contact_call: int = -1) -> void:
    if contact_call < 0:
        contact_call = CONTACT_ART.begin_receiver_call(actor)
    CONTACT_ART.receiver_hit(actor, hit_direction, contact_call)


static func cancel_attack_effects(actor: Node) -> void:
    for effect in actor.owned_attack_effects:
        if is_instance_valid(effect) and not effect.is_queued_for_deletion():
            effect.cancel()
    actor.owned_attack_effects.clear()


static func cancel_unarmed_attack_effects(actor: Node) -> void:
    # Interruptions cancel owned effect objects only while age < arm_delay.
    # This includes visible warning shapes and delayed floor hazards; a
    # projectile/wave with arm_delay == 0 is already emerged and remains live.
    # Death, respawn and owner retirement still use _cancel_attack_effects().
    for index in range(actor.owned_attack_effects.size() - 1, -1, -1):
        var effect = actor.owned_attack_effects[index]
        if not is_instance_valid(effect) or effect.is_queued_for_deletion():
            actor.owned_attack_effects.remove_at(index)
        elif float(effect.get("age")) < float(effect.get("arm_delay")):
            effect.cancel()
            actor.owned_attack_effects.remove_at(index)
