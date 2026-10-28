extends RefCounted
## Persistent effects use their casting player's current journey generation.
const ACTIVE := 0
const PAUSED := 1
const RETIRED := 2
static func generation(player: Node) -> int:
    var value: Variant = player.get("combat_effect_generation")
    return int(value) if value is int else 0
static func state(player: Node2D, host: Node, expected: int) -> int:
    if not is_instance_valid(player) or player.is_queued_for_deletion() or not player.is_inside_tree() or player.get_parent() != host:
        return RETIRED
    if generation(player) != expected: return RETIRED
    var hp: Variant = player.get("hp")
    var death: Variant = player.get("death_timer")
    if (hp != null and float(hp) <= 0) or (death != null and float(death) > 0): return RETIRED
    if host.get("world_loading") == true or host.get("chapter_transitioning") == true: return RETIRED
    if player.has_method("world_residency_active") and not player.world_residency_active(): return RETIRED
    if player.get("ui_input_locked") == true or player.get_tree().paused: return PAUSED
    return ACTIVE
