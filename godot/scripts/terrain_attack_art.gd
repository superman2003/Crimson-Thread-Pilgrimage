extends RefCounted
## Drawing only. Original wave movement and eruption collision remain authoritative.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/terrain_attacks/terrain_attacks.png")
const FAMILIES := ["chime","quake","surge","roots","spears"]
const FPS := 12.0
const EMERGE_SECONDS := .2
const FADE_SECONDS := 2.0/FPS
const OWNERS := {
    "corridor_heavy":"quake", "rust_crown_guardian":"quake",
    "bellroot_acolyte":"chime", "silent_bugbler":"chime", "obsidian_bellwheel":"chime",
    "echo_waterwheel_knight":"chime", "silent_crown_core":"chime", "rust_diver":"surge"
}
const ROOT_OWNERS := ["vine_crawler","thorn_sentinel","thorn_bloom_mote","echo_thorn_sentinel","rust_crown_guardian","broken_string_gardener"]

static func is_wave(family: String) -> bool: return family in ["chime","quake","surge"]

static func family_for(kind: String, skin: String, owner_node: Node = null) -> String:
    var family := skin
    if skin == "thorn":
        var owner_kind := String(owner_node.get("kind")) if is_instance_valid(owner_node) and "kind" in owner_node else ""
        if kind == "wave": family = String(OWNERS.get(owner_kind,""))
        elif owner_kind == "echo_pilgrim_commander_minor": family = "spears"
        elif owner_kind in ROOT_OWNERS: family = "roots"
    if not FAMILIES.has(family): return ""
    if kind == "wave" and is_wave(family): return family
    if kind == "eruption" and not is_wave(family): return family
    return ""

static func frame_for(kind: String, age: float, arm_delay: float) -> int:
    if age < arm_delay:
        if kind == "wave": return -1
        var span := minf(EMERGE_SECONDS,arm_delay)
        var start := arm_delay-span
        return -1 if age < start else clampi(int((age-start)/maxf(span,.001)*2),0,1)
    var elapsed := maxf(0,age-arm_delay)
    if kind == "eruption": return 2+int(elapsed*FPS)%2
    var frame := int(elapsed*FPS)
    return frame if frame < 2 else 2+(frame-2)%4

static func atlas_rect(family: String, frame: int) -> Rect2:
    var row := FAMILIES.find(family)
    var count := 8 if is_wave(family) else 6
    if row < 0 or frame < 0 or frame >= count: return Rect2()
    if row < 3: return Rect2(frame*128,row*128,128,128)
    return Rect2(frame*192,384+(row-3)*320,192,320)

static func draw_frame(host: Node2D, family: String, frame: int, radius: float, direction: float, tint: Color) -> bool:
    var source := atlas_rect(family,frame)
    if source.size == Vector2.ZERO or not is_finite(radius) or radius <= 0: return false
    var wave := is_wave(family)
    var scale := Vector2.ONE*(radius*2/64.0) if wave else Vector2(radius*2/128.0,97.0/224.0)
    var anchor := Vector2(64,96) if wave else Vector2(96,272)
    var floor_offset := Vector2(0,18 if wave else 5)
    var mirror := -1.0 if wave and direction < 0 else 1.0
    host.draw_set_transform(Vector2.ZERO,0,Vector2(mirror,1))
    var color := tint if family == "chime" else Color(1,1,1,tint.a)
    host.draw_texture_rect_region(ATLAS,Rect2(floor_offset-anchor*scale,source.size*scale),source,color)
    host.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
    return true

static func spawn_fade(host: Node, point: Vector2, family: String, radius: float, direction: float, tint: Color) -> Node2D:
    if not FAMILIES.has(family): return null
    var mark := Fade.new()
    mark.name = "TerrainAttackFadeVfx"
    mark.family = family
    mark.radius = radius
    mark.direction = direction
    mark.tint = tint
    mark.paint = draw_frame
    if not POLICY.attach_contact(host,mark): return null
    mark.global_position = point
    return mark

class Fade extends Node2D:
    var family := ""
    var radius := 24.0
    var direction := 1.0
    var tint := Color.WHITE
    var age := 0.0
    var sampled := false
    var paint: Callable
    func _process(delta: float) -> void:
        if is_queued_for_deletion(): return
        if not sampled: sampled = true
        else: age += maxf(0,delta)
        if age >= FADE_SECONDS:
            queue_free()
            return
        queue_redraw()
    func _draw() -> void:
        var first := 6 if family in ["chime","quake","surge"] else 4
        var color := tint
        color.a = clampf((FADE_SECONDS-age)*FPS,0,1)
        paint.call(self,family,first+clampi(int(age*FPS),0,1),radius,direction,color)
