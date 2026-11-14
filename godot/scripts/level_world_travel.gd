extends RefCounted
## Wayfinding, world portals and grapple anchors, travelling between regions, region-owned tweens and deferred calls, and committing world dialogue.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func add_wayfinding(level: Node, area: Area2D) -> void:
    if area.has_node("Wayfinding"):
        return
    var marker = level.WAYFINDING.new()
    marker.name = "Wayfinding"
    marker.host = level
    marker.area = area
    var kind := String(area.get_meta("kind", ""))
    marker.symbol = "rest" if kind == "save_point" else "lever" if kind == "lever" else "talk" if kind == "npc" else "book" if kind == "history" else "passage"
    if kind == "world_portal":
        marker.configure_portal(area.get_meta("world_portal_data", {}), String(level.config.id))
        marker.position.y = 20
        marker.scale = Vector2(0.65, 0.65)
        marker.z_index = -1
    else:
        marker.visible = false
        marker.mount = "lantern" if kind == "save_point" else "wall" if kind == "npc" else "stone"
        marker.z_index = 20
    area.add_child(marker)


static func make_world_portal(level: Node, data: Dictionary) -> Area2D:
    var area := Area2D.new()
    area.name = String(data.get("id", "world_portal"))
    area.position = level._vec2(data.get("position", [0, 0]))
    area.set_meta("kind", "world_portal")
    area.set_meta("label", String(data.get("label", "旧通路")))
    area.set_meta("interaction_label", String(data.get("label", "旧通路")))
    area.set_meta("world_portal_data", data.duplicate(true))
    area.add_to_group("interactable")
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = level._vec2(data.get("interaction_size", [100, 100]))
    shape.shape = rectangle
    area.add_child(shape)
    var arch := Line2D.new()
    arch.name = "WorldPortalArch"
    # Route status belongs on the physical sign; the old luminous outline
    # duplicates it and makes each old connection look like a magic portal.
    arch.visible = false
    arch.width = 5.0
    arch.default_color = Color(0.40, 0.80, 0.88) if level._world_portal_missing(data).is_empty() else Color(0.93, 0.67, 0.30)
    for index in range(17):
        var angle := PI + PI * index / 16.0
        arch.add_point(Vector2(cos(angle) * 29.0, sin(angle) * 46.0))
    arch.add_point(Vector2(29, 17))
    area.add_child(arch)
    return area


static func world_portal(level: Node, data: Dictionary) -> void:
    var area: Area2D = level._take_gameplay_prefab("world_portal", data)
    if area == null: area = level._make_world_portal(data)
    var arch: Line2D = area.get_node("WorldPortalArch")
    arch.default_color = Color(0.40, 0.80, 0.88) if level._world_portal_missing(data).is_empty() else Color(0.93, 0.67, 0.30)
    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)


static func apply_world_npc_state(level: Node, area: Area2D) -> void:
    if not level.world_mode or level.world_narrative == null or not is_instance_valid(area):
        return
    var state: Dictionary = level.world_narrative.npc_world_state(String(area.get_meta("npc_id", "")), level.story_flags)
    if state.is_empty():
        return
    area.set_meta("world_location_state", String(state.get("id", "")))
    if state.has("position") and "demo_" + String(state.get("region", "")) == String(level.config.get("id", "")):
        area.position = level._vec2(state.position)
    if level.world_gameplay_residency != null:
        level.world_gameplay_residency.refresh_actor_position("npc", String(area.get_meta("npc_id", area.name)), area.position)


static func world_grapple_anchor(level: Node, data: Dictionary) -> void:
    var anchor := Node2D.new()
    anchor.name = String(data.get("id", "grapple_anchor"))
    anchor.position = level._vec2(data.get("position", [0, 0]))
    anchor.set_meta("required_ability", String(data.get("required_ability", "echo_hook")))
    anchor.set_meta("grapple_enabled", false)
    anchor.add_to_group("grapple_anchor")
    var ring := Line2D.new()
    ring.name = "CopperGrappleRing"
    ring.width = 3.0
    ring.default_color = Color(0.80, 0.62, 0.30)
    for index in range(25):
        ring.add_point(Vector2.from_angle(TAU * index / 24.0) * 13.0)
    anchor.add_child(ring)
    var chain := Line2D.new()
    chain.width = 2.0
    chain.default_color = Color(0.48, 0.43, 0.28)
    chain.add_point(Vector2(0, -45))
    chain.add_point(Vector2(0, -13))
    anchor.add_child(chain)
    level.add_child(anchor)


static func world_portal_missing(level: Node, data: Dictionary) -> String:
    return String(level.WORLD_ROUTES_SCRIPT.access(data, level.inventory_counts, level.story_flags).hint)


static func refresh_world_portals(level: Node) -> void:
    if not level.world_mode:
        return
    for data in level.config.get("interactives", []):
        if String(data.get("kind", "")) != "world_portal":
            continue
        var area = level.get_node_or_null(NodePath(String(data.get("id", ""))))
        if area == null:
            continue
        var status: Dictionary = level.WORLD_ROUTES_SCRIPT.access(data, level.inventory_counts, level.story_flags)
        area.set_meta("route_status", status.duplicate(true))
        var arch = area.get_node_or_null("WorldPortalArch") as Line2D
        if arch != null:
            arch.default_color = Color(0.40, 0.80, 0.88) if status.open else Color(0.93, 0.67, 0.30)
        var marker = area.get_node_or_null("Wayfinding")
        if marker != null:
            marker.gate_state = String(status.kind)
            marker.queue_redraw()
        var walk_glyph: String = level.WORLD_PASSAGE.glyph(String(level.config.id), String(data.get("id", "")))
        var prompt := " · 向右步行进入" if walk_glyph == "→" else " · 向左步行进入" if walk_glyph == "←" else " · F 通行"
        area.set_meta("interaction_label", String(data.get("label", "旧通路")) + (prompt if status.open else " · " + String(status.label)))


static func activate_world_portal(level: Node, area: Area2D) -> void:
    if not level.world_mode or not level._can_interact_with_world() or level.world_portal_request_pending or area == null or not is_instance_valid(area):
        return
    var data: Dictionary = area.get_meta("world_portal_data", {})
    if not level.WORLD_PASSAGE.endpoint(String(level.config.id), String(data.get("id", ""))).is_empty():
        level.world_passage.begin(String(data.id))
        return
    var missing: String = level._world_portal_missing(data)
    if not missing.is_empty():
        level._toast(missing)
        return
    var next_path = level.WORLD_ROUTES_SCRIPT.cached_config_path(String(data.get("target_config_id", "")))
    if next_path.is_empty() and level.world_loader != null:
        level.world_loader.request_manifest_refresh(level)
    var entry: Vector2 = level._vec2(data.get("target_spawn", [120, 500]))
    if next_path.is_empty() or not entry.is_finite() or not FileAccess.file_exists(next_path):
        level._toast("这条旧路尚未接通。")
        return
    if level.world_loader == null or level.world_loader.phase != "idle":
        level._toast("旧路暂未接通，仍留在当前区域。")
        return
    var shortcut := String(data.get("unlock_shortcut_id", ""))
    level.world_portal_request_pending = true
    level._defer_region_call("_request_world_travel", [next_path, entry, shortcut])


static func travel_world(level: Node, next_path: String, entry: Vector2) -> void:
    if level.world_loader != null and level.world_loader.phase != "idle":
        return
    level._save_world()
    if level.world_loader == null or not level.world_loader.replace_region(level, next_path, entry):
        level.chapter_transitioning = false
        if is_instance_valid(level.audio_director):
            level.audio_director.cancel_chapter_transition()
        level._toast("旧路暂未接通，仍留在当前区域。" + (level.world_loader.last_error if level.world_loader != null else ""))


static func request_world_travel(level: Node, next_path: String, entry: Vector2, shortcut: String = "") -> void:
    if level.world_loader == null or level.world_loader.phase != "idle":
        level.world_portal_request_pending = false
        return
    var publish_flags: Dictionary = {}
    if not shortcut.is_empty():
        publish_flags["world_shortcut_" + shortcut] = true
    var token: RefCounted = level.world_loader.request_region_transition(level, next_path, entry, publish_flags)
    if token == null:
        level.world_portal_request_pending = false


static func region_tween(level: Node) -> Tween:
    for index in range(level.region_tweens.size() - 1, -1, -1):
        if not level.region_tweens[index].is_valid():
            level.region_tweens.remove_at(index)
    var tween = level.create_tween()
    level.region_tweens.append(tween)
    return tween


static func stop_region_tweens(level: Node) -> void:
    for tween in level.region_tweens:
        if tween.is_valid():
            tween.kill()
    level.region_tweens.clear()


static func defer_region_call(level: Node, method: StringName, arguments: Array = []) -> void:
    var generation = level.world_loader.generation if level.world_loader != null else 0
    level.call_deferred("_run_region_deferred", generation, method, arguments)


static func run_region_deferred(level: Node, generation: int, method: StringName, arguments: Array) -> void:
    var portal_request := method in ["_request_world_travel", "_travel_world_async"]
    if level._walking_world_passage():
        if portal_request:
            level.world_portal_request_pending = false
        return
    if level.world_loader != null and level.world_loader.generation != generation:
        if portal_request:
            level.world_portal_request_pending = false
        return
    for argument in arguments:
        if typeof(argument) == TYPE_OBJECT and not is_instance_valid(argument):
            return
    level.callv(method, arguments)


static func commit_world_dialogue(level: Node) -> void:
    if not level.world_mode or level.active_overlay != "dialogue" or level.ui_shell == null or level.dialogue_text_label == null:
        return
    if level.dialogue_text_label.visible_characters >= 0 and level.dialogue_text_label.visible_characters < level.dialogue_text_label.text.length():
        return
    var area: Area2D = level.ui_shell.dialogue_area
    if not is_instance_valid(area):
        return
    if bool(area.get_meta("world_line_committed", false)):
        return
    if String(area.get_meta("kind",""))=="history":
        level._commit_history_prop(area)
        return
    var flags_before = level.story_flags.duplicate(true)
    var currency_before = level.currency_count
    var world_before = level.world_state.data.duplicate(true)
    var build_before: Dictionary = level.build_system.serialize() if level.build_system != null else {}
    var state := String(area.get_meta("dialogue_state", "repeat"))
    var indices: Dictionary = area.get_meta("dialogue_state_indices", {}).duplicate(true)
    var indices_before := indices.duplicate(true)
    var displayed_index := int(area.get_meta("world_displayed_index", -1))
    indices[state] = displayed_index + 1
    area.set_meta("dialogue_state_indices", indices)
    if state == "first_meet" and displayed_index + 1 >= int(area.get_meta("world_displayed_total", 0)):
        level.story_flags["npc_met_%s" % String(area.get_meta("npc_id", area.name))] = true
    var result: Dictionary = area.get_meta("world_dialogue_result", {})
    if bool(level.story_flags.get("quest_bring_names_rewarded", false)):
        level.story_flags["reward_returned_names_claimed"] = true
    var recollection = preload("res://scripts/npc_recollections.gd").completion_marker(String(area.get_meta("npc_id",area.name)),area.get_meta("world_recollection_result",result),displayed_index,String(level.config.get("id","")))
    if not recollection.is_empty():level.story_flags[recollection]=true
    var response_memory = preload("res://scripts/protagonist_response_memory.gd").quote(String(area.get_meta("npc_id",area.name)),result,displayed_index,flags_before,String(level.config.get("id","")))
    var completion = level.WORLD_NARRATIVE_SCRIPT.completion_outcome(result, displayed_index, level.story_flags)
    var rewards: Dictionary = completion.get("rewards", {})
    var fresh_flags: Array = completion.get("flags", [])
    level.currency_count += int(rewards.get("currency", 0))
    for flag in fresh_flags:
        level.story_flags[String(flag)] = true
    if not response_memory.is_empty():level.story_flags[String(response_memory.marker)]=true
    if bool(level.story_flags.get("reward_returned_names_claimed", false)):
        level.story_flags["quest_bring_names_rewarded"] = true
    level._check_wish_board_rewards(false)
    if level.build_system != null:
        level.build_system.sync_progress(level.inventory_counts, String(level.config.get("id", "")), level.story_flags)
    if not level._save_world():
        level._rollback_narrative_transaction(flags_before, currency_before, world_before, build_before)
        area.set_meta("dialogue_state_indices", indices_before)
        level._toast("归途记录未能写入；本次交谈尚未确认，请重试。")
        return
    area.set_meta("world_line_committed", true)
    if level.ui_shell != null and level.ui_shell.has_method("forget_dialogue_reading"):
        level.ui_shell.forget_dialogue_reading()
    if not fresh_flags.is_empty():
        # Only a saved, fully read, fresh conversation earns a short response.
        # A toast never takes control or starts another dialogue/voice sequence.
        var response = level.WORLD_NARRATIVE_SCRIPT.completion_response(result,displayed_index,flags_before)
        if not response.is_empty():
            level._toast(response)
        elif not rewards.is_empty():
            level._toast("心愿达成 · 收到 %d 枚碎钱" % int(rewards.get("currency", 0)))
        level._apply_world_npc_state(area)
        level._sync_player_build()
        level._refresh_wish_board_overlay()
        level._refresh_hud()


static func rollback_narrative_transaction(level: Node, flags_before: Dictionary, currency_before: int, world_before: Dictionary, build_before: Dictionary) -> void:
    level.story_flags = flags_before.duplicate(true)
    level.currency_count = currency_before
    if level.world_state != null:
        level.world_state.data = world_before.duplicate(true)
    if level.build_system != null:
        level.build_system.restore(build_before)


static func add_world_portal_map_pins(level: Node, bounds: Rect2, draw_size: Vector2, draw_width: float, base_y: float, depth_step: float) -> void:
    for data in level.config.get("interactives", []):
        if String(data.get("kind", "")) != "world_portal":
            continue
        var position_value: Vector2 = level._vec2(data.get("position", [0, 0]))
        var room: Dictionary = level._room_for_position(position_value)
        if not level._room_is_visited(String(room.get("id", ""))):
            continue
        var color := Color(0.35, 0.83, 1.0) if level._world_portal_missing(data).is_empty() else Color(1.0, 0.68, 0.24)
        level._add_map_pin(position_value, draw_width, base_y, depth_step, color, Vector2(13, 13), bounds, draw_size)


static func world_exploration_hint(level: Node) -> String:
    var region_id := String(level.config.get("id", ""))
    if region_id.contains("ch01"):
        if level.inventory_counts.has("double_thread_jump"):
            return "双线跃已会：返回运书索道，穿过盐风封门，带回失名证词。"
        return "盐风口暂不可通。沿下庭排水钟管去雨渠，也可先探索庭内捷径。"
    if region_id.contains("ch02"):
        if level.inventory_counts.has("silk_wall_grip"):
            return "攀壁已会：雨溢立管通向书库；排水钟管随时可以返回钟庭。"
        return "寻找低处检修台遗留的攀壁线爪；雨溢立管在上方，钟庭在来路。"
    if region_id.contains("ch03"):
        if level.inventory_counts.has("double_thread_jump"):
            return "双线跃使旧地生出新路：阅览台旁的运书线通回钟庭。"
        return "沿烛台阅览支线寻找双线跃；先前的雨渠入口仍可返回。"
    if region_id.contains("ch04"):
        return "根须影管通向王冠，需要灯影相位；先去黑曜营地，或沿来路回书库。"
    if region_id.contains("ch05"):
        return "营地的灯影相位接通冠脊索道；旧补给索道可从营地开启，返回雨渠。"
    if region_id.contains("ch06"):
        return "王冠与温室、黑曜两路汇合；取得共鸣后，可回旧区检修钟门寻找反证。"
    return "来路与返程都已标在地图上。继续探索，或带着新证据返回旧地。"
