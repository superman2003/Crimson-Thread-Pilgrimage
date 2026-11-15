extends RefCounted
## Building a region from its config: geometry jobs, lifts, platforms and gates, practice targets, history props, hidden-route clues and spawning the player.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CAVE_LIFT_SCRIPT := preload("res://scripts/cave_lift.gd")
const HISTORY_PROP := preload("res://scripts/scene_history_prop.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const SCENE_HISTORY := preload("res://scripts/scene_history.gd")
const WORLD_ROUTES_SCRIPT := preload("res://scripts/world_routes.gd")

static func build_world_from_config(level: Node) -> void:
    for job in level._region_build_jobs():
        level.callv(job.method, job.args)


static func region_build_jobs(level: Node) -> Array:
    var jobs: Array = level._background_jobs()
    if level.world_mode:
        for data in level.config.get("grapple_anchors", []):
            jobs.append({"method": "_world_grapple_anchor", "args": [data]})
    for data in level.config.get("cave_lifts", []):
        jobs.append({"method": "_region_lift", "args": [data]})
    for data in level.config.get("environment_blocks", []):
        if data is Dictionary:
            jobs.append({"method": "_environment_block", "args": [data]})
    for data in level.config.get("platforms", []):
        if not data.has("terrain_id"):
            jobs.append({"method": "_region_platform", "args": [data]})
    level.locked_gate_bodies.clear()
    for data in level.config.get("locked_gates", []):
        jobs.append({"method": "_region_gate", "args": [data]})
    level.collectible_total = 0
    for data in level.config.get("collectibles", []):
        if not level._combat_progression_enabled() or (data is Dictionary and (String(data.get("kind", "")) == "item" or (level.world_mode and String(data.get("kind", "")) == "currency"))):
            jobs.append({"method": "_collectible", "args": [data]})
            level.collectible_total += 1
    for data in level.config.get("interactives", []):
        var method: String = {"lever": "_lever", "boss_gate": "_boss_door", "world_portal": "_world_portal", "chapter_exit": "_chapter_exit", "ending_exit": "_chapter_exit", "challenge_shrine": "_challenge_shrine_from_interactive"}.get(String(data.get("kind", "")), "")
        if not String(method).is_empty():
            jobs.append({"method": method, "args": [data]})
    for data in level.config.get("optional_challenges", []):
        if data is Dictionary:
            jobs.append({"method": "_challenge_shrine", "args": [data]})
            for track in data.get("tracks", []):
                if track is Dictionary:
                    jobs.append({"method": "_hunt_track", "args": [data, track]})
    for data in level.config.get("save_points", []):
        jobs.append({"method": "_save_point", "args": [data]})
    for data in level.config.get("npcs", []):
        jobs.append({"method": "_npc", "args": [data]})
    for data in level.config.get("enemy_spawns", []):
        if data is Dictionary:
            jobs.append({"method": "_enemy", "args": [data]})
    if level.world_mode:
        jobs.append({"method": "_spawn_seal_practice_targets", "args": []})
        jobs.append({"method": "_spawn_tool_practice_targets", "args": []})

        jobs.append({"method": "_spawn_hidden_route_clues", "args": []})
        jobs.append({"method": "_spawn_ending_aftermath", "args": []})
        for entry in SCENE_HISTORY.region_entries(String(level.config.get("id",""))):
            jobs.append({"method":"_spawn_history_prop","args":[entry]})
    jobs.append({"method": "_finish_region_geometry", "args": []})
    return jobs


static func region_lift(level: Node, data: Dictionary) -> void:
    var lift = CAVE_LIFT_SCRIPT.new()
    level.add_child(lift)
    lift.configure(data, level)
    level.cave_lifts.append(lift)


static func region_platform(level: Node, data: Dictionary) -> void:
    if level.world_platforms != null and not level._is_post_boss_blocker(String(data.get("id", ""))):
        var focus = level.entry_spawn_override if level.entry_spawn_override_enabled else level.active_spawn
        level.world_platforms.register(level, data, focus)
    else:
        level._make_region_platform(data)


static func make_region_platform(level: Node, data: Dictionary) -> StaticBody2D:
    var warmed: StaticBody2D = level.world_prefetch.take_platform(String(level.config.id), data) if level.world_mode and level.world_prefetch != null else null
    return level._platform(String(data.get("id", "platform")), level._rect2(data.get("rect", [])),
        level._color(data.get("color", "333333")), String(data.get("material", "moss_stone")), String(data.get("collision_role", "")), warmed)


static func region_gate(level: Node, data: Dictionary) -> void:
    var gate = level._platform(String(data.get("id", "locked_gate")), level._rect2(data.get("rect", [])),
        level._color(data.get("color", "875f29")), String(data.get("material", "bronze_bridge")))
    gate.set_meta("required_ability", String(data.get("required_ability", "")))
    gate.set_meta("required_ability_name", String(data.get("required_ability_name", "")))
    gate.set_meta("requires_action", String(data.get("requires_action", "")))
    if String(data.get("requires_action", "")) == "lantern_phase":
        gate.add_to_group("phase_gate")
    if String(data.get("requires_action", "")) == "thorn_downstrike":
        gate.add_to_group("fragile_terrain")
        gate.set_meta("gate_size", level._rect2(data.get("rect", [])).size)
    var ability := String(data.get("required_ability", ""))
    if not ability.is_empty():
        var sign := Node2D.new()
        sign.set_script(level.ABILITY_GATE_SIGN)
        sign.name = "AbilityGateSign"
        sign.ability = ability
        sign.ability_name = String(data.get("required_ability_name", ""))
        sign.host = level
        # Eye height above the gate's floor end (tall walls) or centred (short ledges).
        var size = level._rect2(data.get("rect", [])).size
        sign.position = Vector2(0, maxf(0.0, size.y * 0.5 - 92.0))
        sign.z_index = 3
        gate.add_child(sign)
    level.locked_gate_bodies[String(data.get("id", "locked_gate"))] = gate


static func finish_region_geometry(level: Node) -> void:
    level.hazard_total = 0
    level.save_point_total = level.config.get("save_points", []).size()
    level.hidden_save_point_total = 0
    for point in level.config.get("save_points", []):
        if point is Dictionary and bool(point.get("hidden", false)):
            level.hidden_save_point_total += 1
    level.enemy_total = level.config.get("enemy_spawns", []).size()
    if level._combat_progression_enabled() and level._combat_goal_met():
        level._open_all_shortcuts(false)


static func spawn_seal_practice_targets(level: Node) -> void:
    for entry in WORLD_ROUTES_SCRIPT.cached_data().get("seal_practice_plan", []):
        if String(entry.get("region_id", "")) != String(level.config.get("id", "")):
            continue
        var target := Area2D.new()
        target.set_script(load("res://scripts/seal_training_target.gd"))
        target.name = String(entry.training_id)
        target.set_meta("practice_skill_id",String(entry.get("skill_id","")))
        target.position = level._vec2(entry.position)
        for platform in level.config.get("platforms", []):
            if String(platform.get("id", "")) == String(entry.room_id) + "_foundation":
                target.position.y = float(platform.rect[1]) - 23.0
                if level.world_platforms != null:
                    level._hold_actor_support(String(platform.id))
        target.configure({"id": String(entry.training_id), "kind": "seal_training", "hp": 30,
            "visual_scale": 0.7, "body_size": [50, 46], "hurtbox_size": [58, 56], "hurtbox_offset": [0, 0],
            "speed": 0, "damage": 0}, "res://assets/ui/seals/ward.svg", false, {"attacks": [], "locomotion": "stationary"})
        level.add_child(target)
        var label := Label.new()
        label.name="PracticeCaption"
        # Short title over its own rack; the tool puppet's caption sits lower,
        # so neighbouring racks never stack their captions.
        label.position = Vector2(-80, -175)
        label.size = Vector2(160, 44)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.add_theme_font_override("font", load("res://assets/fonts/GlobalTypeface.otf"))
        label.add_theme_font_size_override("font_size", 13)
        # T03: join the tree before the text is set; a detached label shapes
        # its wrapped caption first with the default font, then again.
        target.add_child(label)
        label.text = String(entry.get("label", "练针架：没有接触伤害，击倒后复位。"))
        label.set_meta("base_text",label.text)


static func spawn_tool_practice_targets(level: Node) -> void:
    # cached_data() deep-copies the whole route manifest, so read it once per
    # region and keep only this region's rooms for the per-cast / per-room checks.
    var routes: Dictionary = WORLD_ROUTES_SCRIPT.cached_data()
    level.tool_practice_rooms.clear()
    level.tool_encounter_hints.clear()
    for entry in routes.get("tool_encounter_plan", []):
        if String(entry.get("region_id", "")) == String(level.config.get("id", "")):
            level.tool_encounter_hints[String(entry.get("room_id", ""))] = entry
    for entry in routes.get("tool_practice_plan", []):
        if String(entry.get("region_id", "")) != String(level.config.get("id", "")):
            continue
        level.tool_practice_rooms[String(entry.get("room_id", ""))] = true
        var target := Area2D.new()
        target.set_script(load("res://scripts/tool_training_target.gd"))
        target.name = String(entry.training_id)
        target.position = level._vec2(entry.position)
        var floor_id := ""
        for platform in level.config.get("platforms", []):
            if String(platform.get("id", "")) == String(entry.room_id) + "_foundation":
                floor_id = String(platform.id)
                target.position.y = float(platform.rect[1]) - 23.0
                if level.world_platforms != null:
                    level._hold_actor_support(floor_id)
        var data := {"id": String(entry.training_id), "kind": "tool_training", "hp": 30,
            "visual_scale": 0.7, "body_size": [50, 46], "hurtbox_size": [58, 56], "hurtbox_offset": [0, 0],
            "damage": 0, "patrol": 40, "combat_resistance": {"trip_immune": false, "lure_immune": false, "snare_mult": 1.0}}
        target.configure(data, "res://assets/ui/seals/ward.svg", false, Dictionary(entry.get("puppet", {})).duplicate(true))
        target.set_meta("tool_practice_id", String(entry.get("tool_id", "")))
        target.set_meta("tool_practice_room", String(entry.room_id))
        var bounds: Array = level._enemy_platform_movement_bounds(floor_id, target.position, data)
        if bounds.size() >= 2:
            target.set_platform_movement_bounds(float(bounds[0]), float(bounds[1]))
        level.add_child(target)
        var label := Label.new()
        label.position = Vector2(-80, -118)
        label.size = Vector2(160, 22)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.add_theme_font_override("font", load("res://assets/fonts/GlobalTypeface.otf"))
        label.add_theme_font_size_override("font_size", 13)
        # T03: join the tree before the text is set (see seal practice labels).
        target.add_child(label)
        label.text = String(entry.get("label", "战具练习傀儡：没有伤害，击倒后复位。"))


static func in_tool_practice_room(level: Node) -> bool:
    return level.tool_practice_rooms.has(level.current_room_id)


static func show_tool_encounter_hint(level: Node) -> void:
    if level.build_system == null:
        return
    if level.tool_encounter_hints.has(level.current_room_id):
        var entry: Dictionary = level.tool_encounter_hints[level.current_room_id]
        var tool_id := String(entry.get("tool_id", ""))
        var flag = "tool_hint_%s_%s" % [String(level.config.get("id", "")), level.current_room_id]
        if bool(level.story_flags.get(flag, false)) or not level.build_system.state.unlocked_tools.has(tool_id) or not level.build_system.state.tools.has(tool_id):
            return
        level.story_flags[flag] = true
        level._toast("战具提示 · %s：%s" % [String(level.build_system.catalog.tools[tool_id].get("name", tool_id)), String(entry.get("note", ""))])


static func spawn_history_prop(level: Node, entry: Dictionary) -> void:
    var prop = HISTORY_PROP.new()
    prop.entry=entry.duplicate(true)
    prop.name="History_"+String(entry.id)
    prop.position=level._vec2(entry.position)
    prop.seen=SCENE_HISTORY.discovered(level.story_flags,String(entry.id))
    prop.set_meta("kind","history")
    prop.set_meta("label",String(entry.title))
    prop.set_meta("identity","环境痕迹 · 观察不会代替原始证词")
    prop.set_meta("interaction_label","查看 · "+String(entry.title))
    prop.set_meta("history_data",entry.duplicate(true))
    prop.body_entered.connect(level._on_interactable_entered.bind(prop))
    prop.body_exited.connect(level._on_interactable_exited.bind(prop))
    level.add_child(prop)
    level._add_wayfinding(prop)


static func read_history_prop(level: Node, area: Area2D) -> void:
    if level.active_overlay=="dialogue" and level.ui_shell.dialogue_area==area:
        if bool(area.get_meta("world_line_committed",false)):level._close_overlays()
        return
    area.set_meta("world_line_committed",false)
    area.set_meta("dialogue_state","history")
    area.set_meta("world_displayed_index",0)
    area.set_meta("world_displayed_total",1)
    level._show_dialogue(area,String(area.get_meta("history_data",{}).get("text","")))


static func commit_history_prop(level: Node, area: Area2D) -> void:
    if not area.is_inside_tree() or area.is_queued_for_deletion() or not area.is_visible_in_tree() or not area.accessible_from(level.player) or level.player.global_position.distance_to(area.global_position)>level.INTERACTION_REACH:
        return
    var entry: Dictionary=area.get_meta("history_data",{})
    if SCENE_HISTORY.discovered(level.story_flags,String(entry.id)):
        area.set_meta("world_line_committed",true)
        level.ui_shell.forget_dialogue_reading()
        return
    var flags_before = level.story_flags.duplicate(true)
    var world_before = level.world_state.data.duplicate(true)
    level.story_flags[SCENE_HISTORY.FLAG_PREFIX+String(entry.id)]=true
    if not level._save_world():
        level.story_flags=flags_before
        level.world_state.data=world_before
        level._toast("观察尚未记下；归途记录写入失败，请重试。")
        return
    area.set_meta("world_line_committed",true)
    area.mark_seen()
    level.ui_shell.forget_dialogue_reading()


static func spawn_hidden_route_clues(level: Node) -> void:
    level.hidden_route_clues.clear()
    for entry in WORLD_ROUTES_SCRIPT.cached_data().get("hidden_route_plan", []):
        if String(entry.get("region_id", "")) != String(level.config.get("id", "")):
            continue
        var clue := Node2D.new()
        clue.set_script(level.HIDDEN_ROUTE_CLUE_SCRIPT)
        clue.name = "HiddenClue_" + String(entry.id)
        clue.clue_id = String(entry.id)
        clue.found = bool(level.story_flags.get("hidden_found_" + String(entry.id), false))
        clue.position = level._vec2(entry.clue.position)
        clue.set_meta("hidden_route", entry)
        level.add_child(clue)
        level.hidden_route_clues.append(clue)
    level._sync_hidden_route_clues_with_visits()


static func sync_hidden_route_clues_with_visits(level: Node) -> void:
    for clue in level.hidden_route_clues:
        if not is_instance_valid(clue) or clue.found:
            continue
        var entry: Dictionary = clue.get_meta("hidden_route")
        if bool(level.visited_rooms.get(String(entry.get("hidden_room_id", "")), false)):
            clue.found = true
            level.story_flags["hidden_found_" + String(entry.id)] = true


static func notice_hidden_route_clues(level: Node) -> void:
    preload("res://scripts/hidden_clue_notes.gd").notice(level)


static func is_hidden_room(level: Node, room_id: String) -> bool:
    if not level.world_mode or room_id.is_empty():
        return false
    for entry in WORLD_ROUTES_SCRIPT._data().get("hidden_route_plan", []):
        if entry is Dictionary and String(entry.get("region_id", "")) == String(level.config.get("id", "")) and String(entry.get("hidden_room_id", "")) == room_id:
            return true
    return false


static func mark_hidden_route_found(level: Node) -> void:
    for clue in level.hidden_route_clues:
        if not is_instance_valid(clue) or clue.found:
            continue
        var entry: Dictionary = clue.get_meta("hidden_route")
        if String(entry.get("hidden_room_id", "")) != level.current_room_id:
            continue
        clue.found = true
        level.story_flags["hidden_found_" + String(entry.id)] = true


static func get_skill_practice_progress(level: Node, skill_id: String) -> Dictionary:
    var known: bool=level.build_system!=null and skill_id in level.build_system.state.unlocked_skills
    var completed: bool=known and level.story_flags.get("skill_practiced_"+skill_id,false)==true
    var count:=clampi(int(level.skill_practice_hits.get(skill_id,0)),0,level.SKILL_PRACTICE_HITS) if known else 0
    return {"known":known,"completed":completed,"count":level.SKILL_PRACTICE_HITS if completed else count,"required":level.SKILL_PRACTICE_HITS,"pending_save":not completed and count>=level.SKILL_PRACTICE_HITS}


static func on_skill_practice_hit(level: Node, skill_id: String, target: Area2D=null, serial: int=0, contact_kind: String="skill") -> void:
    if not level.world_mode or level.world_loading or level.player==null or level.build_system==null or level.player.hp<=0 or level.player.ui_input_locked:return
    if not is_instance_valid(target) or target.get_parent()!=level or not target.is_inside_tree() or not target.get_meta("seal_training_target",false):return
    if String(target.get_meta("practice_skill_id",""))!=skill_id or skill_id not in level.build_system.state.unlocked_skills:return
    if (skill_id=="ward" and contact_kind!="guard") or (skill_id!="ward" and contact_kind!="skill"):return
    if String(level.player.last_skill_cast)!=skill_id or serial<=0 or serial!=level.player.last_skill_cast_serial:return
    var age = Time.get_ticks_msec()-int(level.player.last_skill_cast_msec)
    if age<0 or age>level.SKILL_PRACTICE_WINDOW_MSEC or target.global_position.distance_to(level.player.global_position)>900:return
    if serial<=int(level.skill_practice_serials.get(skill_id,0)):return
    var flag:="skill_practiced_"+skill_id
    if bool(level.story_flags.get(flag,false)):return
    level.skill_practice_serials[skill_id]=serial
    level.skill_practice_hits[skill_id]=mini(level.SKILL_PRACTICE_HITS,int(level.skill_practice_hits.get(skill_id,0))+1)
    if int(level.skill_practice_hits[skill_id])<level.SKILL_PRACTICE_HITS:return
    var flags = level.story_flags.duplicate(true);flags[flag]=true
    var result: Dictionary = level._persist_world_change({"story_flags":flags})
    if not result.ok:level._toast("练习已达标，记录尚未写入；下次有效施放会重试。");return
    level.world_state.data=result.candidate;level.story_flags=flags
    level._toast("已练熟「%s」· 找工匠选方向" % String(level.build_system.catalog.skills[skill_id].get("name",skill_id)))


static func spawn_player(level: Node) -> void:
    if not is_instance_valid(level.player):
        level.player = PLAYER_SCENE.instantiate()
        level.add_child(level.player)
    level.player.global_position = level.active_spawn
    level.player.set_spawn(level.active_spawn)
    if not level.player.hp_changed.is_connected(level._on_hp_changed):
        level.player.hp_changed.connect(level._on_hp_changed)
        level.player.energy_changed.connect(level._on_energy_changed)
        level.player.player_respawned.connect(level._on_player_respawned)
        level.player.ability_action.connect(level._on_ability_action)
    if level.player.has_signal("gate_struck") and not level.player.gate_struck.is_connected(level._on_gate_struck):
        level.player.gate_struck.connect(level._on_gate_struck)
    if level.world_mode:
        level.player.build_system = level.build_system
        level._sync_player_build()
    # 材质化脚步（音频规格 §4.2）：按章节 art theme 指定脚步材质组。
    level.player.set("footstep_material", String(level.FOOTSTEP_MATERIAL_BY_THEME.get(level._art_theme_id(), "moss")))
    level._configure_player_camera()
    level._refresh_ability_gates()
