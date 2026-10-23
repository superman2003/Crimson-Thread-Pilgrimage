extends RefCounted
## Presentation reads the combat clock; it never moves an actor or applies damage.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/boss_skills/manifest.json"))

static func matches(actor: Node, command: Dictionary) -> bool:
    var entry: Dictionary = data.commands.get(String(command.get("id", "")), {})
    return is_instance_valid(actor) and actor.is_boss and not entry.is_empty() and entry.boss == actor.kind

static func texture_for(kind: String) -> Texture2D:
    var path := String(data.bosses.get(kind, {}).get("texture", ""))
    return load(path) as Texture2D if not path.is_empty() else null

static func clear(actor: Node, warnings_only: bool = false) -> void:
    for child in actor.get_children():
        if child.has_meta("boss_skill_art") and (not warnings_only or child.get_meta("boss_skill_art") == "warning"):
            child.visible = false
            child.queue_free()

static func spawn(actor: Node2D, command: Dictionary, mode: String) -> bool:
    if not matches(actor, command): return false
    if actor.boss_skill_texture == null: actor.boss_skill_texture = texture_for(actor.kind)
    if actor.boss_skill_texture == null: return false
    var entry: Dictionary = data.commands[String(command.id)]
    var hazard := String(command.get("type", "")) in ["beam", "pool", "rootline"]
    if mode == "execution":
        clear(actor, true)
        # These commands already render authored projectiles/terrain/beam pixels.
        if not entry.has("execution"): return true
    var source: Dictionary = data.charges[actor.kind] if mode == "warning" and hazard else entry[mode]
    _attach(actor, command, mode, source, hazard)
    return true

static func spawn_phase(actor: Node2D) -> void:
    if not data.charges.has(actor.kind): return
    if actor.boss_skill_texture == null: actor.boss_skill_texture = texture_for(actor.kind)
    if actor.boss_skill_texture != null: _attach(actor, {}, "phase", data.charges[actor.kind], true)

static func spawn_departure(actor: Node2D, command: Dictionary) -> void:
    if not matches(actor, command): return
    var entry: Dictionary = data.commands[String(command.id)]
    if not entry.has("execution") or actor.boss_skill_texture == null: return
    var mark := _attach(actor, command, "execution", entry.execution, true)
    mark.top_level = true
    mark.global_position = actor.global_position

static func _attach(actor: Node2D, command: Dictionary, mode: String, source: Dictionary, local_cue: bool) -> Node2D:
    var mark := SkillVisual.new()
    mark.name = "BossSkill_" + mode
    mark.set_meta("boss_skill_art", mode)
    mark.actor_ref = weakref(actor)
    mark.command = command.duplicate(true)
    mark.mode = mode
    mark.entry = source
    mark.local_cue = local_cue or String(source.topology) == "source"
    mark.texture = actor.boss_skill_texture
    mark.direction = actor.attack_direction
    mark.paint = paint
    POLICY.place_danger(mark, mode == "warning" or mode == "phase")
    actor.add_child(mark)
    return mark

static func frame_for(progress: float) -> int:
    return clampi(int(clampf(progress, 0, 1) * 6), 0, 5)

static func source_rect(entry: Dictionary, frame: int) -> Rect2:
    var r: Array = entry.frames[clampi(frame, 0, 5)].atlas_rect
    return Rect2(r[0], r[1], r[2], r[3])

static func paint(host: Node2D, texture: Texture2D, entry: Dictionary, frame: int, center: Vector2, footprint: Vector2, direction: int, opacity: float = 1.0) -> void:
    # The measured material occupies the middle 160 pixels of each 192px cel.
    var size := footprint * (192.0 / 160.0)
    host.draw_set_transform(center, 0, Vector2(-1 if direction < 0 else 1, 1))
    host.draw_texture_rect_region(texture, Rect2(-size * .5, size), source_rect(entry, frame), Color(1, 1, 1, opacity))
    host.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func draw_hazard_warning(host: Node2D) -> bool:
    if host.effect_kind not in ["beam", "pool", "eruption"]: return false
    if not is_instance_valid(host.owner_actor): return false
    var actor: Node = host.owner_actor
    var cid := String(host.boss_command_id)
    var command: Dictionary = {"id": cid}
    if not matches(actor, command) or actor.boss_skill_texture == null: return false
    var entry: Dictionary = data.commands[cid].warning
    var frame := frame_for(host.age / maxf(.001, host.arm_delay))
    if host.effect_kind == "beam":
        if host.length <= 0: return true
        var r := source_rect(entry, frame)
        # Use only the material footprint, so transparent cel gutters never
        # introduce gaps in a continuous, obstruction-clipped warning channel.
        r = Rect2(r.position + Vector2(16,16), Vector2(160,160))
        var tile_width := maxf(48, host.radius * 6)
        var count := ceili(host.length / tile_width)
        host.draw_set_transform(Vector2.ZERO, host.heading.angle(), Vector2.ONE)
        for i in range(count):
            var x := i * tile_width
            var width := minf(tile_width, host.length - x)
            var clipped := Rect2(r.position, Vector2(r.size.x * width / tile_width, r.size.y))
            host.draw_texture_rect_region(actor.boss_skill_texture, Rect2(x,-host.radius,width,host.radius*2), clipped)
        host.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
    else:
        var height: float = host.radius * 2 if host.effect_kind == "pool" else host.radius * .8
        var center := Vector2.ZERO if host.effect_kind == "pool" else Vector2(0,5-height*.5)
        paint(host, actor.boss_skill_texture, entry, frame, center, Vector2(host.radius*2,height), 1)
    return true

class SkillVisual extends Node2D:
    var actor_ref: WeakRef
    var command: Dictionary
    var mode := "warning"
    var entry: Dictionary
    var local_cue := false
    var direction := 1
    var texture: Texture2D
    var paint: Callable

    func _valid(actor: Node) -> bool:
        if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.dying or not actor.world_residency_active(): return false
        if mode == "phase": return actor.phase_pause > 0
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
        var progress: float = 1.0-actor.phase_pause/.9 if mode == "phase" else (1.0-actor.state_timer/maxf(.001,float(command.get("windup",.5))) if mode == "warning" else actor.attack_elapsed/maxf(.001,float(command.get("active",.24))))
        var frame := clampi(int(clampf(progress,0,1)*6),0,5)
        var footprint := Vector2(float(command.get("hit_width",80)),float(command.get("hit_height",70)))
        var center := Vector2(direction*float(command.get("offset",44)),float(command.get("offset_y",-26)))
        if local_cue:
            footprint = Vector2(82,82) if mode == "phase" else Vector2(64,64)
            center = Vector2(direction*52,-42)
        var reduced := false
        var player := get_tree().get_first_node_in_group("player")
        if player != null: reduced = not bool(player.get_meta("accessibility",{}).get("flash_enabled",true))
        if reduced and mode == "warning": frame = 2
        paint.call(self,texture,entry,frame,center,footprint,direction,.8 if reduced else 1.0)
