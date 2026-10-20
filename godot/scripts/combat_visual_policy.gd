extends RefCounted
## World-space presentation only. Never admit/cull a damaging effect here.
## Absolute canvas Z keeps a parent's decorative offset from hiding a warning.
const DANGER_Z := 100
const WARNING_Z := 110
const CONTACT_Z := 80
const BLADE_Z := 60
const MAX_CONTACTS := 12
const CONTACT_GROUP := &"combat_contact_decoration"


static func place_danger(item: CanvasItem, warning: bool = false) -> void:
    item.z_as_relative = false
    item.z_index = WARNING_Z if warning else DANGER_Z


## Attach only cosmetic hit marks; rejected nodes are freed before any tween.
## SceneTree membership owns the budget, so retiring actors/scenes releases it.
static func attach_contact(host: Node, item: Node2D) -> bool:
    if not is_instance_valid(host) or not host.is_inside_tree() or host.is_queued_for_deletion():
        item.free()
        return false
    var count := 0
    for mark in host.get_tree().get_nodes_in_group(CONTACT_GROUP):
        if not mark.is_queued_for_deletion():
            count += 1
    if count >= MAX_CONTACTS:
        item.free()
        return false
    item.z_as_relative = false
    item.z_index = CONTACT_Z
    host.add_child(item)
    item.add_to_group(CONTACT_GROUP)
    return true
