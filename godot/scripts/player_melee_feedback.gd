extends RefCounted
## Presentation only. Anchors are measured from this project's packaged hero
## frames (384 x 384) by tools/build_hero_supplement_motion.py; no borrowed
## effect assets or combat geometry live here.
## Authored contact pixels and measured weapon anchors; no emitted blade trail.

const CONTACT_ART := preload("res://scripts/player_contact_art.gd")
const VISUAL_POLICY := preload("res://scripts/combat_visual_policy.gd")

const SOURCE_SIZE := Vector2(384.0, 384.0)
const CONTACT_SECONDS := 0.065
const ANCHOR_FILE := "res://assets/sprites/player/generated_hero_motion_v4/runtime_supplement/blade_anchors.json"
## animation -> per-frame [root, tip]; an empty frame has no visible blade.
static var BLADE_ANCHORS: Dictionary = _load_blade_anchors()


static func _load_blade_anchors() -> Dictionary:
    var result := {}
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ANCHOR_FILE))
    if not data is Dictionary or not data.get("animations") is Dictionary:
        push_error("Blade anchors missing or invalid: " + ANCHOR_FILE)
        return result
    for animation: String in data.animations:
        var frames: Array = []
        for pair: Variant in data.animations[animation]:
            if pair is Array and pair.size() == 2:
                frames.append([Vector2(pair[0][0], pair[0][1]), Vector2(pair[1][0], pair[1][1])])
            else:
                frames.append([])
        result[StringName(animation)] = frames
    return result


static func blade_points(sprite: AnimatedSprite2D, frame_index: int, relative_to: Node2D) -> PackedVector2Array:
    if not is_instance_valid(sprite) or not is_instance_valid(relative_to):
        return PackedVector2Array()
    var frames: Array = BLADE_ANCHORS.get(sprite.animation, [])
    if frames.is_empty():
        return PackedVector2Array()
    var anchors: Array = frames[clampi(frame_index, 0, frames.size() - 1)]
    var result := PackedVector2Array()
    for anchor: Vector2 in anchors:
        var local := anchor
        if sprite.flip_h:
            local.x = SOURCE_SIZE.x - local.x
        if sprite.flip_v:
            local.y = SOURCE_SIZE.y - local.y
        if sprite.centered:
            local -= SOURCE_SIZE * 0.5
        local += sprite.offset
        result.append(relative_to.to_local(sprite.to_global(local)))
    return result


static func spawn_hit(parent_node: Node2D, world_position: Vector2, direction: Vector2, animation: StringName, preferences: Dictionary = {}, receiver: Node2D = null, contact_call: int = -1, effect_owner: Node = null) -> Node2D:
    if not is_instance_valid(parent_node):
        return null
    if is_instance_valid(receiver) and contact_call >= 0:
        return CONTACT_ART.refine_receiver(receiver, contact_call, world_position, direction, animation, preferences)
    var contact := ContactNick.new()
    contact.name = "HitConfirmVfx"
    contact.set_meta("delivered_contact_art", true)
    if is_instance_valid(effect_owner):
        contact.set_meta("contact_player_id", effect_owner.get_instance_id())
        contact.owner_ref = weakref(effect_owner)
    contact.strike_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
    contact.length = 16.0 if animation == &"attack_2" else 11.0
    contact.reduced_flash = not bool(preferences.get("flash_enabled", true))
    if not VISUAL_POLICY.attach_contact(parent_node, contact):
        return null
    contact.global_position = world_position
    return contact


class ContactNick extends Node2D:
    var owner_ref: WeakRef
    var strike_direction := Vector2.RIGHT
    var length := 11.0
    var reduced_flash := false
    var age := 0.0
    var sampled := false

    func _process(delta: float) -> void:
        if is_queued_for_deletion():
            return
        if owner_ref != null:
            var owner_node: Node = owner_ref.get_ref()
            if not is_instance_valid(owner_node) or owner_node.is_queued_for_deletion():
                visible = false
                queue_free()
                return
        if not is_finite(length) or length <= 0.0 or not strike_direction.is_finite():
            queue_free()
            return
        if not sampled:
            # As with the blade trace, a slow first process interval must not
            # consume the mark before its first valid draw opportunity.
            sampled = true
            age = 0.0
        else:
            age += maxf(0.0, delta)
            if age >= CONTACT_SECONDS:
                queue_free()
                return
        queue_redraw()

    func _draw() -> void:
        CONTACT_ART.paint_contact(self, age, CONTACT_SECONDS, strike_direction, length, reduced_flash)
