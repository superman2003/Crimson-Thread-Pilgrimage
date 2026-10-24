extends RefCounted
## Authored danger pixels only. Combat clocks, geometry and damage stay in Enemy.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const MANIFEST := "res://assets/vfx/minor_enemy_skills/manifest.json"
const HAZARD_TYPES := ["beam", "pool", "rootline"]
static var data: Dictionary = {}

static func registry() -> Dictionary:
    if data.is_empty() and FileAccess.file_exists(MANIFEST):
        data = ART.manifest(MANIFEST)
    return data

static func matches(actor: Node, command: Dictionary) -> bool:
    if not is_instance_valid(actor) or bool(actor.get("is_boss")): return false
    var entry: Dictionary = registry().get("commands", {}).get(String(command.get("id", "")), {})
    return not entry.is_empty() and String(entry.get("kind", "")) == String(actor.get("kind"))

static func texture_path(kind: String) -> String:
    return String(registry().get("creatures", {}).get(kind, {}).get("texture", ""))

static func prepare(actor: Node) -> void:
    if bool(actor.get("is_boss")): return
    var path := texture_path(String(actor.get("kind")))
    if not path.is_empty():
        # Called during detached prefab preparation, after the world's threaded
        # character-art warm job. Direct demo fixtures may load during setup.
        actor.minor_skill_texture = ART.texture(path)

static func ready_for(actor: Node, command: Dictionary) -> bool:
    return matches(actor, command) and actor.get("minor_skill_texture") != null

static func clear(actor: Node, warnings_only: bool = false) -> void:
    for child in actor.get_children():
        if child.has_meta("minor_enemy_skill_art") and (not warnings_only or child.get_meta("minor_enemy_skill_art") == "warning"):
            child.visible = false
            child.queue_free()

static func spawn(actor: Node2D, command: Dictionary, mode: String) -> bool:
    if not ready_for(actor, command): return false
    var entry: Dictionary = registry().commands[String(command.id)]
    if mode == "execution":
        clear(actor, true)
        # Projectiles, waves, pools, roots and beams already have authored v1
        # execution art on their independent damaging effect objects.
        if not entry.has("execution"): return true
    elif String(command.get("type", "")) in HAZARD_TYPES:
        # One warning per actual ground mark/channel, never a fake caster disc.
        return true
    if not entry.has(mode): return false
    var source: Dictionary = entry[mode]
    var mark := SkillVisual.new()
    mark.name = "MinorEnemySkill_" + mode
    mark.set_meta("minor_enemy_skill_art", mode)
    mark.actor_ref = weakref(actor)
    mark.command = command.duplicate(true)
    mark.mode = mode
    mark.entry = source
    mark.direction = int(actor.attack_direction)
    mark.texture = actor.minor_skill_texture
    mark.paint = paint
    # A primary attack silhouette is danger communication, not an optional
    # cosmetic accent; crowd decoration budgets must never hide these cues.
    POLICY.place_danger(mark, mode == "warning")
    actor.add_child(mark)
    return true

static func spawn_departure(actor: Node2D, command: Dictionary) -> void:
    if not ready_for(actor,command): return
    var entry: Dictionary = registry().commands[String(command.id)]
    if not entry.has("execution"): return
    var mark := SkillVisual.new()
    mark.name = "MinorEnemyBlinkDeparture"
    mark.set_meta("minor_enemy_skill_art", "execution")
    mark.actor_ref = weakref(actor)
    mark.command = command.duplicate(true)
    mark.mode = "execution"
    mark.entry = entry.execution
    mark.direction = int(actor.attack_direction)
    mark.texture = actor.minor_skill_texture
    mark.paint = paint
    if not POLICY.attach_contact(actor,mark): return
    mark.top_level = true
    mark.global_position = actor.global_position

static func frame_for(progress: float, count: int = 3) -> int:
    return clampi(int(clampf(progress, 0, 1) * count), 0, maxi(0, count - 1))

static func source_rect(entry: Dictionary, frame: int) -> Rect2:
    var frames: Array = entry.get("frames", [])
    if frames.is_empty(): return Rect2()
    var r: Array = frames[clampi(frame, 0, frames.size() - 1)].atlas_rect
    return Rect2(r[0], r[1], r[2], r[3])

static func paint(host: Node2D, texture: Texture2D, entry: Dictionary, frame: int, center: Vector2, footprint: Vector2, direction: int, opacity: float = 1.0) -> void:
    var source := source_rect(entry, frame)
    if source.size == Vector2.ZERO or footprint.x <= 0 or footprint.y <= 0: return
    var size := footprint * (192.0 / 160.0)
    host.draw_set_transform(center, 0, Vector2(-1 if direction < 0 else 1, 1))
    host.draw_texture_rect_region(texture, Rect2(-size * .5, size), source, Color(1, 1, 1, opacity))
    host.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func hazard_entry(effect: Node) -> Dictionary:
    if not is_instance_valid(effect.get("owner_actor")): return {}
    var actor: Node = effect.owner_actor
    var command := {"id": String(effect.minor_command_id)}
    if not ready_for(actor, command): return {}
    var entry: Dictionary = registry().commands[command.id]
    var extra := _hazard_extra(effect)
    var source: Dictionary = extra.get("warning", entry.get("hazard_warning", entry.get("warning", {})))
    var topology := String(source.get("topology", ""))
    var required := "eruption" if effect.effect_kind == "eruption" else String(effect.effect_kind)
    return source if topology == required else {}

static func _hazard_extra(effect: Node) -> Dictionary:
    if effect.effect_kind != "pool": return {}
    var key := "wax_trail" if effect.minor_command_id == "wax_charge" else "pipe_impact" if effect.minor_command_id == "pipe_mortar" else ""
    return registry().get("extras", {}).get(key, {})

static func draw_hazard_execution(host: Node2D) -> bool:
    if host.effect_kind != "pool" or not is_instance_valid(host.owner_actor): return false
    if not ready_for(host.owner_actor, {"id":String(host.minor_command_id)}): return false
    var extra := _hazard_extra(host)
    var entry: Dictionary = extra.get("execution", {})
    if entry.is_empty(): return false
    var progress: float = (host.age-host.arm_delay)/maxf(.001,host.duration-host.arm_delay)
    paint(host,host.owner_actor.minor_skill_texture,entry,frame_for(progress,entry.frames.size()),Vector2.ZERO,Vector2.ONE*host.radius*2,1)
    return true

static func start_support(actor: Node2D) -> bool:
    if actor.kind != "ash_banner_imp" or actor.minor_skill_texture == null: return false
    var entries: Dictionary = registry().get("extras", {}).get("support", {})
    if not entries.has("channel") or not entries.has("link"): return false
    var mark := SupportVisual.new()
    mark.name = "MinorEnemySupportChannel"
    mark.set_meta("minor_enemy_skill_art", "support")
    mark.actor_ref = weakref(actor)
    mark.entries = entries
    mark.texture = actor.minor_skill_texture
    mark.paint = paint
    mark.paint_link = draw_link
    POLICY.place_danger(mark,true)
    actor.add_child(mark)
    return true

static func release_support(actor: Node2D, ally: Node2D) -> void:
    if actor.kind != "ash_banner_imp" or actor.minor_skill_texture == null: return
    var entry: Dictionary = registry().get("extras", {}).get("support", {}).get("release", {})
    if entry.is_empty(): return
    var mark := SupportRelease.new()
    mark.name = "MinorEnemySupportRelease"
    mark.set_meta("minor_enemy_support_release", true)
    mark.ally_ref = weakref(ally)
    mark.entry = entry
    mark.texture = actor.minor_skill_texture
    mark.paint = paint
    # The restored HP is already committed. Its release motes are cosmetic.
    if not POLICY.attach_contact(ally,mark): return
    mark.position = Vector2(0,-40)

static func draw_link(host: Node2D, texture: Texture2D, entry: Dictionary, frame: int, start: Vector2, finish: Vector2, thickness: float) -> void:
    var length := start.distance_to(finish)
    if length <= .001: return
    var source := source_rect(entry,frame)
    source = Rect2(source.position+Vector2(16,16),Vector2(160,160))
    var width := 40.0
    host.draw_set_transform(start,start.angle_to_point(finish),Vector2.ONE)
    for index in range(ceili(length/width)):
        var x := index*width
        var span := minf(width,length-x)
        var clipped := Rect2(source.position,Vector2(source.size.x*span/width,source.size.y))
        host.draw_texture_rect_region(texture,Rect2(x,-thickness*.5,span,thickness),clipped)
    host.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

static func draw_hazard_warning(host: Node2D) -> bool:
    if host.effect_kind not in ["beam", "pool", "eruption"]: return false
    var entry := hazard_entry(host)
    if entry.is_empty(): return false
    var texture: Texture2D = host.owner_actor.minor_skill_texture
    var frame := frame_for(host.age / maxf(.001,host.arm_delay), entry.frames.size())
    if host.effect_kind == "beam":
        if host.length <= 0: return true
        var source := source_rect(entry, frame)
        # The registered central material is a continuous tile. Clip the final
        # source/destination pair, so no warning extends through an obstruction.
        source = Rect2(source.position + Vector2(16,16), Vector2(160,160))
        var tile_width: float = maxf(48, host.radius * 6)
        var count := ceili(host.length / tile_width)
        var axis: Vector2 = host.heading.normalized() if host.heading.length_squared() > .0001 else Vector2.RIGHT
        host.draw_set_transform(Vector2.ZERO, axis.angle(), Vector2.ONE)
        for index in range(count):
            var x := index * tile_width
            var width: float = minf(tile_width, host.length - x)
            var clipped := Rect2(source.position, Vector2(source.size.x * width / tile_width, source.size.y))
            host.draw_texture_rect_region(texture, Rect2(x,-host.radius,width,host.radius*2), clipped)
        host.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
    else:
        var height: float = host.radius * 2 if host.effect_kind == "pool" else host.radius * .8
        var center := Vector2.ZERO if host.effect_kind == "pool" else Vector2(0,5-height*.5)
        paint(host, texture, entry, frame, center, Vector2(host.radius*2,height), 1)
    return true

class SkillVisual extends Node2D:
    var actor_ref: WeakRef
    var command: Dictionary
    var mode := "warning"
    var entry: Dictionary
    var direction := 1
    var texture: Texture2D
    var paint: Callable

    func _valid(actor: Node) -> bool:
        if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.dying or not actor.world_residency_active(): return false
        return String(actor.active_attack.get("id", "")) == String(command.get("id", "")) and actor.state == ("windup" if mode == "warning" else "active")

    func _process(_delta: float) -> void:
        var actor: Node = actor_ref.get_ref()
        if not _valid(actor):
            visible = false
            queue_free()
            return
        queue_redraw()

    func _draw() -> void:
        var actor: Node = actor_ref.get_ref()
        if not _valid(actor): return
        var progress: float = 1.0-actor.state_timer/maxf(.001,float(command.get("windup",.5))) if mode == "warning" else actor.attack_elapsed/maxf(.001,float(command.get("active",.24)))
        var frame := clampi(int(clampf(progress,0,1)*entry.frames.size()),0,entry.frames.size()-1)
        var strike: Rect2 = actor.contact_attack_rect(command)
        var footprint := strike.size
        var center: Vector2 = to_local(strike.get_center())
        if String(entry.get("topology", "")) == "source":
            # Local charge/displacement cues do not promise a projectile path,
            # a future landing target or an arena-sized damaging area.
            var size: float = clampf(float(actor.get_meta("spawn_visual_height",70)) * .6,34,62)
            footprint = Vector2(size,size)
            center = Vector2(direction*24,-28)
        var reduced := false
        var player := get_tree().get_first_node_in_group("player")
        if player != null: reduced = not bool(player.get_meta("accessibility",{}).get("flash_enabled",true))
        if reduced and mode == "warning": frame = mini(1,entry.frames.size()-1)
        paint.call(self,texture,entry,frame,center,footprint,direction,.8 if reduced else 1.0)

class SupportVisual extends Node2D:
    var actor_ref: WeakRef
    var entries: Dictionary
    var texture: Texture2D
    var paint: Callable
    var paint_link: Callable

    func _ally(actor: Node) -> Node2D:
        if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.dying or not actor.world_residency_active() or actor.state != "support": return null
        var ally: Node2D = actor.support_target.get_ref() as Node2D if actor.support_target != null else null
        return ally if is_instance_valid(ally) and not ally.is_queued_for_deletion() and actor._support_ally_valid(ally) else null

    func _process(_delta: float) -> void:
        if _ally(actor_ref.get_ref()) == null:
            visible = false
            queue_free()
            return
        queue_redraw()

    func _draw() -> void:
        var actor: Node = actor_ref.get_ref()
        var ally := _ally(actor)
        if ally == null: return
        var progress: float = 1.0-actor.state_timer/actor.SUPPORT_WINDUP
        var frame := clampi(int(clampf(progress,0,1)*entries.channel.frames.size()),0,entries.channel.frames.size()-1)
        paint.call(self,texture,entries.channel,frame,Vector2(0,-48),Vector2(44,44),int(actor.attack_direction))
        paint_link.call(self,texture,entries.link,frame,Vector2(0,-48),to_local(ally.global_position+Vector2(0,-54)),6.0)

class SupportRelease extends Node2D:
    var ally_ref: WeakRef
    var entry: Dictionary
    var texture: Texture2D
    var paint: Callable
    var age := 0.0
    var sampled := false
    const DURATION := .24

    func _process(delta: float) -> void:
        var ally: Node = ally_ref.get_ref()
        if not is_instance_valid(ally) or ally.is_queued_for_deletion() or ally.dying or not ally.world_residency_active():
            visible = false
            queue_free()
            return
        var player := get_tree().get_first_node_in_group("player")
        if player != null and player.get("ui_input_locked") == true: return
        if sampled: age += maxf(0,delta)
        else: sampled = true
        if age >= DURATION:
            queue_free()
            return
        queue_redraw()

    func _draw() -> void:
        var ally: Node = ally_ref.get_ref()
        if not is_instance_valid(ally) or ally.is_queued_for_deletion() or ally.dying or not ally.world_residency_active(): return
        var frame := clampi(int(age/DURATION*entry.frames.size()),0,entry.frames.size()-1)
        paint.call(self,texture,entry,frame,Vector2.ZERO,Vector2(48,48),1,clampf((DURATION-age)/.06,0,1))
