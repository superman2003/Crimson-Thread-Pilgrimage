extends RefCounted
## Builders for placed world props: collectibles, levers, boss doors, chapter exits, save points and NPCs.
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func collectible(level: Node, data: Dictionary) -> void:
    if level.world_mode and bool(level.world_collected_ids.get(String(data.get("id", "")), false)):
        return
    var area := Area2D.new()
    area.name = String(data.get("id", "collectible"))
    area.position = level._vec2(data.get("position", [0, 0]))
    var collectible_kind := String(data.get("kind", "bell_key"))
    var item_id := String(data.get("item_id", collectible_kind))
    area.set_meta("message", String(data.get("label", "取得钟钥。")))
    area.set_meta("kind", collectible_kind)
    area.set_meta("item_id", item_id)
    var amount_value: Variant=data.get("amount",1)
    area.set_meta("amount",int(amount_value) if level.WORLD_STATE_SCRIPT._whole(amount_value) else 0)
    area.set_meta("ability_name", String(data.get("ability_name", data.get("label", ""))))
    area.set_meta("object_id", "collectible/" + area.name)

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 18
    shape.shape = circle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = level.ORIGINAL_ART.item(item_id)
    if sprite.texture != null:
        sprite.scale=Vector2.ONE*(32.0/maxf(sprite.texture.get_width(),sprite.texture.get_height()))
    area.add_child(sprite)
    area.set_meta("manual_pickup",collectible_kind=="item" and level._is_story_key_item(item_id))
    if bool(area.get_meta("manual_pickup")):
        area.add_to_group("interactable")
        area.set_meta("interaction_label","收取 · "+level._item_display_name(item_id))
    else:
        area.body_entered.connect(level._on_collectible_body_entered.bind(area))
    level.add_child(area)
    if level.world_mode:
        var instance_id:=area.get_instance_id()
        level.world_pickup_leases[instance_id]={"node":weakref(area),"id":String(area.name),"region":String(level.config.get("id","")),
            "kind":collectible_kind,"item":item_id,"amount":data.get("amount",1),"point":area.position,
            "ability_name":String(data.get("ability_name",data.get("label",""))),"message":String(data.get("label","已拾取。"))}
        area.tree_exiting.connect(level._forget_world_pickup.bind(instance_id))
    if level.metsys_bridge != null:
        var room: Dictionary = level._room_for_position(area.global_position)
        level.metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


static func make_lever(level: Node, data: Dictionary) -> Area2D:
    var area := Area2D.new()
    area.name = String(data.get("id", "shortcut_lever"))
    area.position = level._vec2(data.get("position", [0, 0]))
    area.set_meta("kind", "lever")
    area.set_meta("label", String(data.get("label", "守门者通路机关" if level._combat_progression_enabled() else "捷径拉杆")))
    area.set_meta("object_id", "interactable/" + area.name)
    area.set_meta("requires_keys", int(data.get("requires_keys", level.max_bells)))
    area.set_meta("shortcut_id", String(data.get("shortcut_id", "")))
    area.set_meta("opens_connection", data.get("opens_connection", {}))

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(50, 72)
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = load(level.SPRITES["lever"])
    sprite.scale = Vector2(0.52, 0.52)
    sprite.name="LeverSprite"
    level._apply_original_prop(sprite,"lever_closed",83)
    area.add_child(sprite)
    return area


static func lever(level: Node, data: Dictionary) -> void:
    if level.world_mode and level.world_gameplay_residency != null and level.world_gameplay_residency.should_defer("lever", data, level):
        return
    var area: Area2D = level._take_gameplay_prefab("lever", data)
    if area == null: area = level._make_lever(data)
    area.set_meta("requires_keys", int(data.get("requires_keys", level.max_bells)))
    area.set_meta("label", String(data.get("label", "守门者通路机关" if level._combat_progression_enabled() else "捷径拉杆")))
    var lever_sprite = area.get_node_or_null("LeverSprite") as Sprite2D
    if lever_sprite != null and level._is_shortcut_open(String(data.get("shortcut_id", ""))):
        level._apply_original_prop(lever_sprite, "lever_open", 52)
    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)
    if level.world_mode and level.world_gameplay_residency != null:
        level.world_gameplay_residency.adopt("lever", String(data.get("id", "")), area)
    if level.metsys_bridge != null:
        var room: Dictionary = level._room_for_position(area.global_position)
        level.metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


static func make_boss_door(level: Node, data: Dictionary) -> Area2D:
    var area := Area2D.new()
    area.name = String(data.get("id", "boss_gate"))
    area.position = level._vec2(data.get("position", [0, 0]))
    area.set_meta("kind", "boss_gate")
    area.set_meta("label", "踏入钟门")
    area.set_meta("object_id", "interactable/" + area.name)

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(96, 126)
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.texture = load(level.SPRITES["boss_gate"])
    sprite.scale = Vector2(0.82, 0.82)
    level._apply_original_prop(sprite,"gate_closed",152)
    area.add_child(sprite)
    return area


static func boss_door(level: Node, data: Dictionary) -> void:
    var area: Area2D = level._take_gameplay_prefab("boss_gate", data)
    if area == null: area = level._make_boss_door(data)
    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)
    if level.metsys_bridge != null:
        var room: Dictionary = level._room_for_position(area.global_position)
        level.metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


static func chapter_exit(level: Node, data: Dictionary) -> void:
    var area := Area2D.new()
    area.name = String(data.get("id", "chapter_exit"))
    area.position = level._vec2(data.get("position", [0, 0]))
    var kind := String(data.get("kind", "chapter_exit"))
    area.set_meta("kind", kind)
    area.set_meta("label", String(data.get("label", "区域出口")))
    area.set_meta("object_id", "interactable/" + area.name)
    area.set_meta("next_runtime_config_id", String(data.get("next_runtime_config_id", "")))
    area.set_meta("next_config_path", String(data.get("next_config_path", "")))
    area.set_meta("requires_demo_complete", bool(data.get("requires_demo_complete", true)))

    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = level._vec2(data.get("interaction_size", [210, 156]))
    shape.shape = rectangle
    area.add_child(shape)

    var sprite := Sprite2D.new()
    sprite.name = "ChapterExitSprite"
    sprite.texture = load(level.SPRITES["boss_gate"])
    sprite.scale = Vector2(0.66, 0.66)
    sprite.modulate = Color(0.48, 1.0, 0.92, 0.84) if kind == "chapter_exit" else Color(1.0, 0.74, 0.96, 0.88)
    level._apply_original_prop(sprite,"gate_open",138)
    sprite.z_index = 7
    area.add_child(sprite)

    var glow := Line2D.new()
    glow.name = "ChapterExitGlow"
    glow.width = 3.0
    glow.closed = true
    glow.default_color = Color(0.42, 1.0, 0.92, 0.62) if kind == "chapter_exit" else Color(1.0, 0.54, 0.88, 0.70)
    glow.points = PackedVector2Array([
        Vector2(-36, -52), Vector2(36, -52), Vector2(46, 0), Vector2(30, 54), Vector2(-30, 54), Vector2(-46, 0)
    ])
    glow.z_index = 8
    area.add_child(glow)

    var tween: Tween = level._region_tween()
    tween.set_loops()
    tween.tween_property(glow, "scale", Vector2(1.12, 1.12), 0.8)
    tween.parallel().tween_property(glow, "modulate:a", 0.42, 0.8)
    tween.tween_property(glow, "scale", Vector2(0.96, 0.96), 0.8)
    tween.parallel().tween_property(glow, "modulate:a", 1.0, 0.8)

    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)
    if level.metsys_bridge != null:
        var room: Dictionary = level._room_for_position(area.global_position)
        level.metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


static func make_save_point(level: Node, data: Dictionary) -> Area2D:
    var area := Area2D.new()
    area.name = String(data.get("id", "save_point"))
    area.position = level._vec2(data.get("position", level.active_spawn))
    area.set_meta("kind", "save_point")
    area.set_meta("label", String(data.get("label", "钟龛")))
    area.set_meta("hidden", bool(data.get("hidden", false)))
    area.set_meta("object_id", "save_point/" + area.name)
    area.set_meta("activated", false)

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 42 if bool(data.get("hidden", false)) else 52
    shape.shape = circle
    area.add_child(shape)

    var pedestal := Polygon2D.new()
    pedestal.name = "SavePointPedestal"
    pedestal.polygon = PackedVector2Array([
        Vector2(-32, 28),
        Vector2(-18, 8),
        Vector2(0, 0),
        Vector2(18, 8),
        Vector2(32, 28)
    ])
    pedestal.color = Color(0.13, 0.22, 0.20, 0.94)
    pedestal.z_index = 5
    area.add_child(pedestal)

    var marker := Sprite2D.new()
    marker.name = "SavePointSprite"
    marker.texture = load(level.SPRITES["save_point"])
    marker.position = Vector2(0, -18)
    marker.scale = Vector2(2.9, 2.9)
    marker.modulate = Color(0.70, 1.0, 0.82, 0.84) if bool(data.get("hidden", false)) else Color(0.92, 1.0, 0.62, 1.0)
    level._apply_original_prop(marker,"rest_root" if bool(data.get("hidden",false)) else "rest_bell",118)
    marker.z_index = 8
    area.add_child(marker)

    var ring := Line2D.new()
    ring.name = "SavePointHalo"
    ring.width = 3.0
    ring.default_color = Color(0.40, 1.0, 0.78, 0.48) if bool(data.get("hidden", false)) else Color(0.78, 1.0, 0.56, 0.72)
    ring.closed = true
    ring.z_index = 6
    ring.points = PackedVector2Array([
        Vector2(-24, 8), Vector2(-10, -13), Vector2(12, -15), Vector2(27, 7), Vector2(10, 24), Vector2(-14, 22)
    ])
    area.add_child(ring)

    return area


static func save_point(level: Node, data: Dictionary) -> void:
    if level.world_mode and level.world_gameplay_residency != null and level.world_gameplay_residency.should_defer("save_point", data, level):
        return
    var area: Area2D = level._take_gameplay_prefab("save_point", data)
    if area == null: area = level._make_save_point(data)
    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)
    var checkpoint_key := String(level.config.get("id", "")) + ":" + String(area.name)
    var was_activated := bool(level.save_point_residency_memory.get(checkpoint_key, false))
    if level.world_mode and (was_activated or String(area.name) == String(level.active_save_point_id)):
        level.save_point_residency_memory[checkpoint_key] = true
        area.set_meta("activated", true)
        var marker = area.get_node_or_null("SavePointSprite") as Sprite2D
        var ring = area.get_node_or_null("SavePointHalo") as Line2D
        if marker != null: marker.modulate = Color(1.0, 0.94, 0.78, 1.0)
        if ring != null: ring.default_color = Color(0.90, 1.0, 0.58, 0.95)
    if level.world_mode and level.world_gameplay_residency != null:
        level.world_gameplay_residency.adopt("save_point", String(data.get("id", "")), area)
    area.set_meta("residency_tweens", level._animate_save_point(area, area.get_node("SavePointSprite"), area.get_node("SavePointHalo")))
    if level.metsys_bridge != null:
        var room: Dictionary = level._room_for_position(area.global_position)
        level.metsys_bridge.register_object(area, String(area.get_meta("object_id")), String(room.get("id", "")))


static func animate_save_point(level: Node, area: Area2D, marker: Sprite2D, ring: Line2D) -> Array:
    # Bind looping visuals to the shrine itself so any external/tree teardown
    # also retires them, even when the residency owner cannot inspect freed meta.
    var pulse: Tween = level._region_tween()
    pulse.bind_node(area)
    pulse.set_loops()
    pulse.tween_property(ring, "scale", Vector2(1.22, 1.22), 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    pulse.parallel().tween_property(ring, "modulate:a", 0.35, 0.95)
    pulse.tween_property(ring, "scale", Vector2(0.92, 0.92), 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    pulse.parallel().tween_property(ring, "modulate:a", 0.95, 0.95)

    var blink: Tween = level._region_tween()
    blink.bind_node(area)
    blink.set_loops()
    blink.tween_property(area, "modulate:a", 0.82, 1.25)
    blink.tween_property(area, "modulate:a", 1.0, 1.25)
    return [pulse, blink]


static func play_save_point_activation(level: Node, area: Area2D) -> void:
    area.set_meta("activated", true)
    var sprite := area.get_node_or_null("SavePointSprite") as Sprite2D
    var ring := area.get_node_or_null("SavePointHalo") as Line2D
    if sprite != null:
        sprite.modulate = Color(1.0, 0.94, 0.78, 1.0)
        var base_scale := sprite.scale
        var flash: Tween = level._region_tween()
        flash.bind_node(sprite)
        flash.tween_property(sprite, "scale", base_scale*1.08, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        flash.tween_property(sprite, "scale", base_scale, 0.18)
    if ring != null:
        ring.default_color = Color(0.90, 1.0, 0.58, 0.95)
    for index in range(3):
        var echo := Line2D.new()
        echo.name = "SavePointActivationRing"
        echo.global_position = area.global_position + Vector2(0, -10)
        echo.closed = true
        echo.width = 3.0
        echo.default_color = Color(0.74, 1.0, 0.70, 0.78)
        echo.z_index = 90
        var points := PackedVector2Array()
        for step in range(32):
            var angle := TAU * float(step) / 32.0
            points.append(Vector2(cos(angle), sin(angle)) * (24.0 + float(index) * 8.0))
        echo.points = points
        if not level.VISUAL_POLICY.attach_secondary(level, echo, &"environment", level): continue
        var tween: Tween = level._region_tween()
        tween.bind_node(echo)
        tween.tween_interval(float(index) * 0.07)
        tween.tween_property(echo, "scale", Vector2(2.15, 2.15), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(echo, "modulate:a", 0.0, 0.38)
        tween.finished.connect(Callable(echo, "queue_free"))


static func make_npc(level: Node, data: Dictionary) -> Area2D:
    var area := Area2D.new()
    area.name = String(data.get("id", "npc"))
    area.position = level._vec2(data.get("position", [0, 0]))
    var role := String(data.get("role", ""))
    area.set_meta("kind", "npc")
    area.add_to_group("npc_sound_landmark")
    area.set_meta("label", level._npc_display_name(data))
    area.set_meta("dialogue", level._npc_dialogue(data))
    area.set_meta("dialogue_index", 0)
    area.set_meta("npc_id", String(data.get("id", "")))
    area.set_meta("story_dialogue", data.get("story_dialogue", {}))
    area.set_meta("dialogue_meta", data.get("dialogue_meta", {}))
    area.set_meta("dialogue_state", "")
    area.set_meta("dialogue_state_indices", {})
    area.set_meta("identity", String(data.get("identity", "")))
    area.set_meta("help", String(data.get("help", "")))

    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 34
    shape.shape = circle
    area.add_child(shape)

    var art_id = level.ORIGINAL_ART.npc_art_id(String(data.get("id","")))
    var manifest_path = level.ORIGINAL_ART.character_manifest("original_npcs", art_id)
    var art_data = level.ORIGINAL_ART.manifest(manifest_path)
    var npc_frames = level.ORIGINAL_ART.frames(manifest_path)
    if npc_frames != null:
        var sprite := AnimatedSprite2D.new()
        sprite.set_script(preload("res://scripts/npc_dialogue_motion.gd"))
        sprite.name="FriendlyFamilySprite"
        sprite.sprite_frames=npc_frames
        sprite.play("idle")
        sprite.scale=Vector2.ONE*float(art_data.get("visual_scale",.3))
        sprite.position=level._vec2(art_data.get("visual_offset",[0,-24]))
        sprite.z_index=3
        area.add_child(sprite)
    area.add_to_group("interactable")
    area.set_meta("portrait_id",art_id)
    area.set_meta("dialogue_topics",data.get("dialogue_topics",{}))
    return area


static func npc(level: Node, data: Dictionary) -> void:
    if level.world_mode and level.world_gameplay_residency != null and level.world_gameplay_residency.should_defer("npc", data, level):
        return
    var area: Area2D = level._take_gameplay_prefab("npc", data)
    if area == null: area = level._make_npc(data)
    var memory_key := String(level.config.get("id", "")) + ":" + String(data.get("id", ""))
    var memory: Dictionary = level.npc_residency_memory.get(memory_key, {})
    if memory.has("dialogue_index"):
        area.set_meta("dialogue_index", int(memory.dialogue_index))
        area.set_meta("dialogue_state_indices", memory.get("dialogue_state_indices", {}).duplicate(true))
    level._add_wayfinding(area)
    area.body_entered.connect(level._on_interactable_entered.bind(area))
    area.body_exited.connect(level._on_interactable_exited.bind(area))
    level.add_child(area)
    level._apply_world_npc_state(area)
    if level.world_mode and level.world_gameplay_residency != null:
        level.world_gameplay_residency.adopt("npc", String(data.get("id", "")), area)
    if level.world_platforms != null:
        level._hold_actor_support(level._platform_under_position(area.position, 100))
