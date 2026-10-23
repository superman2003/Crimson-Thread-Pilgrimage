extends RefCounted
## Presentation only. The Player owns the paid reservation and every settlement.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/player_heal/player_heal.png")
const FAMILIES := ["channel", "complete", "interrupt"]
const COUNTS := [8, 6, 6]
static func frame_rect(family: String, frame: int) -> Rect2:
    var row := FAMILIES.find(family)
    return Rect2(frame * 192, row * 192, 192, 192) if row >= 0 and frame >= 0 and frame < COUNTS[row] else Rect2()
static func paint(host: Node2D, family: String, frame: int, direction: int, alpha: float) -> void:
    var size := 108.0 if family == "channel" else 112.0
    host.draw_set_transform(Vector2.ZERO,0,Vector2(direction,1))
    host.draw_texture_rect_region(ATLAS,Rect2(-size/2,-size/2,size,size),frame_rect(family,frame),Color(1,1,1,alpha))
    host.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
static func clear(player: Node) -> void:
    for node in player.get_children():
        if node.has_meta("player_heal_art"):
            node.visible = false
            node.queue_free()
static func start(player: Node2D) -> Node2D: return _attach(player,"channel")
static func completed(player: Node2D) -> Node2D: return _attach(player,"complete")
static func interrupted(player: Node2D) -> Node2D: return _attach(player,"interrupt")
static func _attach(player: Node2D, family: String) -> Node2D:
    clear(player)
    var node := HealVisual.new()
    node.set_meta("player_heal_art",true)
    node.name = "PlayerHealArt_" + family
    node.family = family
    node.owner_ref = weakref(player)
    node.reservation = player.heal_reservation_generation
    node.direction = player.facing
    node.position = Vector2(0,-42)
    node.z_index = 45
    node.paint_frame = paint
    node.reduced = not bool(player.get_meta("accessibility",{}).get("flash_enabled",true))
    node.update_opacity()
    if node.reduced: node.frame = 2 if family == "channel" else 3
    return node if POLICY.attach_secondary(player,node,&"state",player) else null
class HealVisual extends Node2D:
    var owner_ref: WeakRef
    var reservation := 0
    var family := "channel"
    var direction := 1
    var frame := 0
    var opacity := 0.5
    var age := 0.0
    var sampled := false
    var reduced := false
    var paint_frame: Callable
    func update_opacity() -> void:
        opacity = (.34 if reduced else .50) if family == "channel" else (.4 if reduced else .75)
    func valid_owner(player: Node) -> bool:
        if not is_instance_valid(player) or player.is_queued_for_deletion() or player.death_timer > 0: return false
        return family != "channel" or (player.heal_timer > 0 and player.heal_reserved_cost > 0 and player.heal_reservation_generation == reservation)
    func _process(delta: float) -> void:
        var player: Node = owner_ref.get_ref()
        if not valid_owner(player):
            visible = false; queue_free(); return
        reduced = not bool(player.get_meta("accessibility",{}).get("flash_enabled",true))
        update_opacity()
        if family == "channel":
            var progress: float = clampf(1 - player.heal_timer / player.heal_duration,0,1)
            frame = 2 if reduced else (mini(1,int(progress/.075)) if progress < .15 else (2 + int((progress-.15)/.7*8)%4 if progress < .85 else 6 + mini(1,int((progress-.85)/.075))))
        else:
            if sampled: age += maxf(0,delta)
            else: sampled = true
            var duration := .30 if family == "complete" else .24
            if age >= duration: visible = false; queue_free(); return
            frame = 3 if reduced else mini(5,int(age*6/duration))
            opacity *= clampf((duration-age)/.08,0,1)
        queue_redraw()
    func _draw() -> void:
        var player: Node = owner_ref.get_ref()
        if valid_owner(player): paint_frame.call(self,family,frame,direction,opacity)
