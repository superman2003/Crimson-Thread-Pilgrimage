extends RefCounted
## World-space presentation only. Never admit/cull a damaging effect here.
## Absolute canvas Z keeps a parent's decorative offset from hiding a warning.
const DANGER_Z := 100
const WARNING_Z := 110
const CONTACT_Z := 80
const BLADE_Z := 60
const MAX_CONTACTS := 12
const CONTACT_GROUP := &"combat_contact_decoration"
const MAX_ACTION_TRACES := 8
const ACTION_TRACE_GROUP := &"combat_action_decoration"
const SECONDARY_GROUP := &"combat_secondary_decoration"
const MAX_SECONDARY_UNITS := 24
const SECONDARY_LIMITS := {&"motion": 12, &"state": 12, &"environment": 8}
const SECONDARY_MAX_Z := 75


## Admission only takes ownership of fresh detached nodes. Rejecting a
## borrowed/attached node must never destroy an existing actor or warning.
static func _fresh(item: Node) -> bool:
    return is_instance_valid(item) and not item.is_inside_tree() and item.get_parent() == null and not item.is_queued_for_deletion()

static func _discard_fresh(items: Array) -> void:
    for item in items:
        if is_instance_valid(item) and _fresh(item):item.free()

## Actor-local caps do not bound a crowd. Only harmless action traces share
## this pool; unblockable cues retain their warning layer and admission.
static func attach_action_trace(host: Node, item: Node2D, warning: bool = false) -> bool:
    if not _fresh(item):return false
    if not is_instance_valid(host) or not host.is_inside_tree() or host.is_queued_for_deletion():
        item.free()
        return false
    if not warning:
        var count := 0
        for trace in host.get_tree().get_nodes_in_group(ACTION_TRACE_GROUP):
            if not trace.is_queued_for_deletion(): count += 1
        if count >= MAX_ACTION_TRACES:
            item.free()
            return false
    item.z_as_relative = false
    item.z_index = WARNING_Z if warning else BLADE_Z
    host.add_child(item)
    if not warning: item.add_to_group(ACTION_TRACE_GROUP)
    return true


static func place_danger(item: CanvasItem, warning: bool = false) -> void:
    if not is_instance_valid(item) or item.is_queued_for_deletion():return
    item.z_as_relative = false
    item.z_index = WARNING_Z if warning else DANGER_Z


## Attach only cosmetic hit marks; rejected nodes are freed before any tween.
## SceneTree membership owns the budget, so retiring actors/scenes releases it.
static func attach_contact(host: Node, item: Node2D) -> bool:
    if not _fresh(item):return false
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


## Only newly allocated, harmless accents belong here. The actual weapon,
## grapple connection, damaging effects and danger warnings never use this API.
## A batch admits all of its pieces together, before any tween is created.
static func attach_secondary(host: Node, item: Node2D, category: StringName, owner_node: Node = null) -> bool:
    return attach_secondary_batch(host, [item], category, owner_node)

static func attach_secondary_batch(host: Node, items: Array[Node2D], category: StringName, owner_node: Node = null) -> bool:
    var valid := is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and SECONDARY_LIMITS.has(category) and not items.is_empty()
    if owner_node != null:
        valid = valid and is_instance_valid(owner_node) and owner_node.is_inside_tree() and not owner_node.is_queued_for_deletion()
        if valid:valid = owner_node.get_tree() == host.get_tree()
    var units := 0
    var identities: Dictionary = {}
    for item in items:
        if not _fresh(item):
            valid = false
            continue
        if identities.has(item.get_instance_id()): valid = false
        identities[item.get_instance_id()] = true
        units += _secondary_units(item)
    if valid:
        var total := 0
        var family := 0
        for accent in host.get_tree().get_nodes_in_group(SECONDARY_GROUP):
            if accent.is_queued_for_deletion(): continue
            var cost := int(accent.get_meta("secondary_units", 1))
            total += cost
            if accent.get_meta("secondary_category", &"") == category: family += cost
        valid = total + units <= MAX_SECONDARY_UNITS and family + units <= int(SECONDARY_LIMITS[category])
    if not valid:
        _discard_fresh(items)
        return false
    var owner_id := owner_node.get_instance_id() if is_instance_valid(owner_node) else host.get_instance_id()
    for item in items:
        item.set_meta("secondary_units", _secondary_units(item))
        item.set_meta("secondary_category", category)
        item.set_meta("secondary_owner", owner_id)
        _place_secondary(item)
        host.add_child(item)
        item.add_to_group(SECONDARY_GROUP)
    return true

static func _secondary_units(item: Node) -> int:
    var units := 1 if item is CanvasItem else 0
    for child in item.get_children(): units += _secondary_units(child)
    return units

static func _place_secondary(item: Node) -> void:
    if item is CanvasItem:
        item.z_as_relative = false
        item.z_index = mini(item.z_index, SECONDARY_MAX_Z)
    for child in item.get_children(): _place_secondary(child)

## Player-owned accents can be siblings under the World (dash ghosts/trails).
## Clear by a scalar owner ID when traversal resets; never retain actor refs.
static func clear_secondary(owner_node: Node) -> void:
    if not is_instance_valid(owner_node) or not owner_node.is_inside_tree(): return
    for accent in owner_node.get_tree().get_nodes_in_group(SECONDARY_GROUP):
        if int(accent.get_meta("secondary_owner", 0)) == owner_node.get_instance_id(): accent.queue_free()
