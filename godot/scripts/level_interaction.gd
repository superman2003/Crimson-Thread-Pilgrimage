extends RefCounted
## Choosing what the interact key acts on: nearby interactables, locked gates and sealed rooms.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CARTOGRAPHY_UI := preload("res://scripts/cartography_runtime.gd")

static func on_interactable_entered(level: Node, body: Node, area: Area2D) -> void:
    if level.world_loading:
        return
    if body != level.player:
        return
    level.nearby_interactable = area
    var exit_kind := String(area.get_meta("kind", ""))
    if (exit_kind == "chapter_exit" or exit_kind == "ending_exit") and level._chapter_exit_can_open(area):
        level._defer_region_call("_activate_chapter_exit", [area])


static func on_interactable_exited(level: Node, body: Node, area: Area2D) -> void:
    if level.world_loading:
        return
    if body != level.player:
        return
    if level.nearby_interactable == area:
        level.nearby_interactable = null
    if String(area.get_meta("kind", "")) in ["npc","history"] and level.dialogue_panel != null and level.dialogue_panel.visible:
        level._close_overlays()


static func can_interact_with_world(level: Node, allow_dialogue: bool = false) -> bool:
    if level.player == null or not is_instance_valid(level.player) or level.chapter_transitioning or level.world_loading:
        return false
    if level.player.hp <= 0 or level.player.death_timer > 0.0:
        return false
    return level.active_overlay.is_empty() or (allow_dialogue and level.active_overlay == "dialogue")


static func try_interact(level: Node) -> void:
    if not level._can_interact_with_world(true):
        return
    # Continue the visible speaker only while it is valid and in range.
    if level.active_overlay == "dialogue":
        if level.world_mode and level.dialogue_text_label != null and level.dialogue_text_label.visible_characters >= 0 and level.dialogue_text_label.visible_characters < level.dialogue_text_label.text.length():
            level.subtitle_elapsed = level.subtitle_seconds
            level.dialogue_text_label.visible_characters = -1
            return
        level._commit_world_dialogue()
        var speaker: Area2D = null
        if level.ui_shell != null and is_instance_valid(level.ui_shell.dialogue_area):
            speaker = level.ui_shell.dialogue_area
        if speaker != null and not speaker.is_queued_for_deletion() and level.player.global_position.distance_to(speaker.global_position) <= level.INTERACTION_REACH:
            level.nearby_interactable = speaker
        else:
            level._close_overlays()
    # Overlapping Areas cannot choose the target through body-enter order.
    if level.active_overlay != "dialogue":
        level.nearby_interactable = level.interaction_target()
    if level.nearby_interactable == null or not is_instance_valid(level.nearby_interactable):
        for lift in level.cave_lifts:
            if lift.request(level.player.global_position):
                level._toast(lift.last_request_text)
                return
        level._toast("附近没有可交互的人物或机关。")
        return
    if bool(level.nearby_interactable.get_meta("manual_pickup", false)):
        level._on_collectible_body_entered(level.player, level.nearby_interactable)
        level.nearby_interactable = null
        return
    var kind := String(level.nearby_interactable.get_meta("kind", ""))
    if kind == "lever":
        level._activate_lever(level.nearby_interactable)
    elif kind == "boss_gate":
        level._activate_boss_gate()
    elif kind == "npc":
        if level.world_mode and level.nearby_interactable.has_meta("map_seller_region") and level.active_overlay != "dialogue":
            CARTOGRAPHY_UI.open_shop(level, level.nearby_interactable)
        else:
            level._talk_to_npc(level.nearby_interactable)
    elif kind == "history":
        level._read_history_prop(level.nearby_interactable)
    elif kind == "save_point":
        level._activate_save_point(level.nearby_interactable)
    elif kind == "chapter_exit" or kind == "ending_exit":
        level._activate_chapter_exit(level.nearby_interactable)
    elif kind == "world_portal":
        level._activate_world_portal(level.nearby_interactable)
    elif kind == "ending_gate":
        preload("res://scripts/ending_story_desk.gd").open(level, level.nearby_interactable)
    elif kind == "challenge_shrine":
        level._activate_challenge_shrine(level.nearby_interactable)
    elif kind == "hunt_track":
        level._activate_hunt_track(level.nearby_interactable)


static func interaction_target(level: Node, prompt_candidate: Area2D = null) -> Area2D:
    # Both the prompt and the actual interaction use this availability/range.
    if not level._can_interact_with_world():
        return null
    # Distant markers reject themselves before the shared candidate scan.
    # Actual dispatch omits this optional hint and queries the complete range.
    if prompt_candidate != null:
        if prompt_candidate.is_queued_for_deletion() or not prompt_candidate.is_visible_in_tree():
            return null
        if level.player.global_position.distance_squared_to(prompt_candidate.global_position) > level.INTERACTION_REACH * level.INTERACTION_REACH:
            return null
    return level._nearest_interactable(level.INTERACTION_REACH)


static func nearest_interactable(level: Node, radius: float) -> Area2D:
    if level.player == null or not is_instance_valid(level.player) or not level.player.global_position.is_finite() or not is_finite(radius) or radius < 0.0:
        return null
    var best: Area2D = null
    var best_distance := radius * radius
    var preferred_best: Area2D = null
    var preferred_distance := best_distance
    for child in level.get_children():
        var area := child as Area2D
        if area == null or not is_instance_valid(area) or area.is_queued_for_deletion() or not area.is_visible_in_tree():
            continue
        var kind := String(area.get_meta("kind", ""))
        var manual_pickup:=bool(area.get_meta("manual_pickup",false))
        if not ["lever", "boss_gate", "npc", "save_point", "chapter_exit", "ending_exit", "ending_gate", "world_portal", "item", "death_cache", "history", "challenge_shrine", "hunt_track"].has(kind) and not manual_pickup:
            continue
        if kind in ["item","currency","bell_key"] and not manual_pickup:
            continue
        var distance: float = level.player.global_position.distance_squared_to(area.global_position)
        if not is_finite(distance) or distance > radius * radius:
            continue
        if kind=="history" and not area.accessible_from(level.player):
            continue
        if kind=="world_portal" and level._behind_locked_gate(area):
            continue
        if kind in ["chapter_exit", "ending_exit"] and level._chapter_exit_can_open(area) and level._better_interaction_target(area, distance, preferred_best, preferred_distance):
            preferred_best = area
            preferred_distance = distance
        if level._better_interaction_target(area, distance, best, best_distance):
            best = area
            best_distance = distance
    return preferred_best if preferred_best != null else best


static func behind_locked_gate(level: Node, portal: Area2D) -> bool:
    if level.locked_gate_bodies.is_empty() or not level.player.is_inside_tree():
        return false
    var data: Dictionary = portal.get_meta("world_portal_data", {})
    if String(data.get("target_config_id", "")) == String(level.config.get("id", "")):
        var spawn: Variant = data.get("target_spawn", [])
        if spawn is Array and spawn.size() == 2:
            var destination := String(level._room_for_position(Vector2(float(spawn[0]), float(spawn[1]))).get("id", ""))
            if level._room_sealed_by_gates(destination):
                return true
    var room_id := String(data.get("room_id", ""))
    if room_id.is_empty() or not level._room_has_standing_gate(room_id):
        return false
    var query = PhysicsRayQueryParameters2D.create(level.player.global_position - Vector2(0, 42), portal.global_position, 1, [level.player.get_rid()])
    return not level.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


static func room_has_standing_gate(level: Node, room_id: String) -> bool:
    for gate in level.config.get("locked_gates", []):
        if level.locked_gate_bodies.has(String(gate.get("id", ""))) and (String(gate.get("from", "")) == room_id or String(gate.get("to", "")) == room_id):
            return true
    return false


static func room_sealed_by_gates(level: Node, room_id: String) -> bool:
    if room_id.is_empty():
        return false
    for connection in level.config.get("connections", []):
        if String(connection.get("from", "")) != room_id and String(connection.get("to", "")) != room_id:
            continue
        if String(connection.get("type", "")) != "ability_gate":
            return false
    for gate in level.config.get("locked_gates", []):
        var from := String(gate.get("from", ""))
        var to := String(gate.get("to", ""))
        if from != to and (from == room_id or to == room_id) and level.locked_gate_bodies.has(String(gate.get("id", ""))):
            return true
    return false


static func better_interaction_target(level: Node, area: Area2D, distance: float, current: Area2D, current_distance: float) -> bool:
    # Authored IDs are sibling node names; identical distances must not depend
    # on body-enter callbacks, cached actor adoption or child insertion order.
    return current == null or distance < current_distance or (distance == current_distance and String(area.name) < String(current.name))
