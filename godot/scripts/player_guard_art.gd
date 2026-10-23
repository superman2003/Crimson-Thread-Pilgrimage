extends RefCounted
## Cosmetic only: actual guard duration, side and hit resolution stay in Player.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/player_guard/player_guard.png")
const FAMILIES := ["raise", "block", "perfect"]
const CELL := 192.0

static func frame_rect(family: String, frame: int) -> Rect2:
    var row := FAMILIES.find(family)
    return Rect2(frame * CELL, row * CELL, CELL, CELL) if row >= 0 and frame >= 0 and frame < 6 else Rect2()

static func paint(host: Node2D, family: String, frame: int, direction: int, alpha: float) -> void:
    var size := 112.0 if family == "raise" else (104.0 if family == "perfect" else 80.0)
    host.draw_set_transform(Vector2.ZERO, 0, Vector2(-1 if direction < 0 else 1, 1))
    host.draw_texture_rect_region(ATLAS, Rect2(4, -size / 2, size, size), frame_rect(family, frame), Color(1, 1, 1, alpha))
    host.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func clear(player: Node) -> void:
    for node in player.get_children():
        if node.has_meta("player_guard_art"):
            node.visible = false
            node.queue_free()

static func start(player: Node2D) -> Node2D:
    clear(player)
    var node := GuardVisual.new()
    node.family = "raise"
    return _attach(player, node, false)

static func blocked(player: Node2D, perfect: bool) -> Node2D:
    clear(player)
    var node := GuardVisual.new()
    node.family = "perfect" if perfect else "block"
    return _attach(player, node, true)

static func _attach(player: Node2D, node: GuardVisual, contact: bool) -> Node2D:
    node.name = "PlayerGuardArt_" + node.family
    node.set_meta("player_guard_art", true)
    node.owner_ref = weakref(player)
    node.direction = player.facing
    if not bool(player.get_meta("accessibility", {}).get("flash_enabled", true)):
        node.frame = 3 if contact else 2
        node.opacity = .55 if contact else .65
    node.paint_frame = paint
    node.position = Vector2(0, -42)
    node.z_index = POLICY.BLADE_Z
    var admitted := POLICY.attach_contact(player, node) if contact else POLICY.attach_secondary(player, node, &"state", player)
    return node if admitted else null

class GuardVisual extends Node2D:
    var owner_ref: WeakRef
    var family := "raise"
    var direction := 1
    var age := 0.0
    var sampled := false
    var frame := 0
    var opacity := 1.0
    var paint_frame: Callable
    func _process(delta: float) -> void:
        var player: Node = owner_ref.get_ref()
        if not is_instance_valid(player) or player.is_queued_for_deletion() or player.death_timer > 0:
            visible = false
            queue_free()
            return
        if sampled: age += maxf(0, delta)
        else: sampled = true
        var reduced := not bool(player.get_meta("accessibility", {}).get("flash_enabled", true))
        if family == "raise":
            direction = player.facing
            if player.guard_timer <= 0:
                visible = false
                queue_free()
                return
            var elapsed: float = player.guard_initial_duration - player.guard_timer
            frame = 2 if reduced else (mini(3, int(elapsed * 30)) if player.guard_timer >= .05 else 4 + mini(1, int((.05 - player.guard_timer) * 40)))
            opacity = .65 if reduced else .9
        else:
            var duration := .22 if family == "perfect" else .18
            if age >= duration:
                queue_free()
                return
            frame = 3 if reduced else mini(5, int(age * 6 / duration))
            opacity = (.55 if reduced else .9) * clampf((duration - age) / .06, 0, 1)
        queue_redraw()
    func _draw() -> void:
        var player: Node = owner_ref.get_ref()
        if not is_instance_valid(player) or player.death_timer > 0 or (family == "raise" and player.guard_timer <= 0): return
        paint_frame.call(self, family, frame, player.facing if family == "raise" else direction, opacity)
