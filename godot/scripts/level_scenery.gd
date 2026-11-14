extends RefCounted
## Region backdrop layers, cave and terrain backgrounds, and the platform/hazard visuals drawn over collision.
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func background(level: Node) -> void:
    for job in level._background_jobs():
        level.callv(job.method, job.args)


static func background_jobs(level: Node) -> Array:
    var jobs: Array = [
        {"method": "_background_base", "args": []},
        {"method": "_background_art", "args": []},
        {"method": "_background_terrain_metadata", "args": []}]
    for landform in level.config.get("terrain", []):
        jobs.append({"method": "_background_landform", "args": [landform]})
    jobs.append({"method": "_background_terrain_warm", "args": []})
    jobs.append({"method": "_background_cave", "args": []})
    jobs.append({"method": "_background_cave_surface", "args": []})
    jobs.append({"method": "_background_shade", "args": []})
    return jobs


static func background_base(level: Node) -> void:
    var bg := Polygon2D.new()
    bg.polygon = PackedVector2Array([Vector2(-300, -200), Vector2(level.world_width + 300, -200),
        Vector2(level.world_width + 300, level.world_height + 220), Vector2(-300, level.world_height + 220)])
    bg.color = level._theme_background_color()
    bg.z_index = -120
    level.add_child(bg)


static func background_art(level: Node) -> void:
    level.flat_map_art = level.FLAT_MAP_ART_SCRIPT.new()
    level.add_child(level.flat_map_art)
    level.flat_map_art.configure(level._art_theme_id(), level.config)


static func background_terrain_metadata(level: Node) -> void:
    level.chapter_terrain = level.TERRAIN_SCRIPT.new()
    level.add_child(level.chapter_terrain)
    level.chapter_terrain.prefetch = level.world_prefetch if level.world_mode else null
    level.chapter_terrain.region_id = String(level.config.get("id", ""))
    level.chapter_terrain.prepare_config(level.config, level._art_theme_id(), level.world_mode, level.world_mode)


static func background_landform(level: Node, data: Dictionary) -> void:
    level.chapter_terrain._build_landform(data)


static func background_terrain_warm(level: Node) -> void:
    if level.world_mode:
        level.chapter_terrain.warm_focus(level.entry_spawn_override if level.entry_spawn_override_enabled else level.active_spawn)


static func background_cave(level: Node) -> void:
    if not level.config.get("cave_world", {}).is_empty():
        level.cave_world = level.CAVE_WORLD_SCRIPT.new()
        level.add_child(level.cave_world)
        level.cave_world.prefetch = level.world_prefetch if level.world_mode else null
        level.cave_world.region_id = String(level.config.get("id", ""))
        level.cave_world.configure(level.config, level._art_theme_id(), level, level.world_mode, level.entry_spawn_override if level.entry_spawn_override_enabled else level.active_spawn, true)


static func background_cave_surface(level: Node) -> void:
    if level.cave_world != null and is_instance_valid(level.cave_world):
        level.cave_world.finish_surface()


static func background_shade(level: Node) -> void:
    var shade := Polygon2D.new()
    shade.polygon = PackedVector2Array([Vector2(-300, -200), Vector2(level.world_width + 300, -200),
        Vector2(level.world_width + 300, level.world_height + 220), Vector2(-300, level.world_height + 220)])
    shade.color = Color(0, 0, 0, 0.025)
    shade.z_index = -94
    level.add_child(shade)


static func theme_background_color(level: Node) -> Color:
    var theme: String = level._art_theme_id()
    if theme == "rain_foundry":
        return Color(0.065, 0.078, 0.080)
    if theme == "salt_archive":
        return Color(0.075, 0.070, 0.058)
    if theme == "string_greenhouse":
        return Color(0.043, 0.068, 0.052)
    if theme == "obsidian_pilgrim":
        return Color(0.052, 0.047, 0.052)
    if theme == "silent_crown":
        return Color(0.040, 0.045, 0.062)
    return Color(0.055, 0.065, 0.072)


static func background_layer(level: Node, node_name: String, sprite_key: String, z_value: int, tint: Color = Color.WHITE) -> void:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = level._load_texture_resource(level.SPRITES[sprite_key])
    sprite.centered = false
    sprite.position = Vector2(-180, -40)
    if sprite.texture != null and sprite.texture.get_width() > 0 and sprite.texture.get_height() > 0:
        sprite.scale = Vector2(1.12, 1.12)
        if sprite_key == "bg_far":
            sprite.position = Vector2(760, -50)
            sprite.modulate = Color(0.75, 0.88, 0.82, 0.42) * tint
        elif sprite_key == "bg_mid":
            sprite.position = Vector2(1700, -35)
            sprite.modulate = Color(0.70, 0.94, 0.82, 0.34) * tint
        elif sprite_key == "bg_near":
            sprite.position = Vector2(-120, -320)
            sprite.scale = Vector2(0.36, 0.36)
            sprite.modulate = Color(0.76, 0.98, 0.80, 0.46) * tint
        else:
            sprite.modulate = tint
    sprite.z_index = z_value
    level.add_child(sprite)


static func platform(level: Node, node_name: String, rect: Rect2, color: Color, material: String = "moss_stone", collision_role: String = "", warmed: StaticBody2D = null) -> StaticBody2D:
    var body: StaticBody2D = warmed if warmed != null else level.PLATFORM_BODY.create(node_name, rect, collision_role)
    if level.flat_map_art != null and level.flat_map_art.ready_for_platforms():
        level.flat_map_art.add_platform_visual(body,rect.size,material)
    else:
        level._add_platform_readability_base(body,rect.size,material,color)
    level.add_child(body)
    return body


static func add_platform_readability_base(level: Node, parent: Node, size_value: Vector2, material: String, fallback_color: Color) -> void:
    var body_color: Color = level._platform_body_color(material, fallback_color)
    var edge_color: Color = level._platform_edge_color(material)
    level._add_platform_plate(parent, Vector2(0, 6.0), size_value + Vector2(10.0, 18.0), body_color, -6)
    level._add_platform_plate(parent, Vector2(0, -size_value.y * 0.5 + 4.0), Vector2(size_value.x + 12.0, 8.0), edge_color, -2)
    level._add_platform_plate(parent, Vector2(0, size_value.y * 0.5 - 3.0), Vector2(size_value.x + 8.0, 5.0), Color(0.015, 0.026, 0.024, 0.82), -2)


static func platform_body_color(level: Node, material: String, fallback_color: Color) -> Color:
    var theme: String = level._art_theme_id()
    var color := Color(0.15, 0.22, 0.18, 0.98)
    if theme == "rain_foundry":
        color = Color(0.19, 0.24, 0.24, 0.98)
    elif theme == "salt_archive":
        color = Color(0.26, 0.23, 0.20, 0.98)
    elif theme == "string_greenhouse":
        color = Color(0.17, 0.24, 0.17, 0.98)
    elif theme == "obsidian_pilgrim":
        color = Color(0.19, 0.17, 0.20, 0.98)
    elif theme == "silent_crown":
        color = Color(0.20, 0.21, 0.27, 0.98)
    if material.contains("wall") or material.contains("gate"):
        color = color.darkened(0.18)
    return color


static func platform_edge_color(level: Node, material: String) -> Color:
    var theme: String = level._art_theme_id()
    if theme == "rain_foundry":
        return Color(0.44, 0.61, 0.60, 0.96)
    if theme == "salt_archive":
        return Color(0.72, 0.63, 0.44, 0.96)
    if theme == "string_greenhouse":
        return Color(0.44, 0.62, 0.34, 0.96)
    if theme == "obsidian_pilgrim":
        return Color(0.52, 0.40, 0.36, 0.96)
    if theme == "silent_crown":
        return Color(0.59, 0.62, 0.75, 0.96)
    return Color(0.45, 0.60, 0.33, 0.96)


static func add_platform_plate(level: Node, parent: Node, local_center: Vector2, plate_size: Vector2, plate_color: Color, z_value: int) -> Polygon2D:
    var plate := Polygon2D.new()
    var half := plate_size * 0.5
    plate.polygon = PackedVector2Array([
        local_center + Vector2(-half.x, -half.y),
        local_center + Vector2(half.x, -half.y),
        local_center + Vector2(half.x, half.y),
        local_center + Vector2(-half.x, half.y)
    ])
    plate.color = plate_color
    plate.z_index = z_value
    parent.add_child(plate)
    return plate


static func hazard(level: Node, _data: Dictionary) -> void:
    # Legacy level data cannot recreate graphics, colliders or damage triggers.
    pass


static func add_hazard_visual(level: Node, _area: Area2D, _kind: String, _size: Vector2) -> void:
    pass


static func apply_original_prop(level: Node, sprite: Sprite2D, key: String, height: float) -> void:
    var props = level.ORIGINAL_ART.manifest("res://assets/sprites/original_interactables/manifest.json")
    var texture = level.ORIGINAL_ART.frame(props.get(key,{}))
    if texture==null:return
    sprite.texture=texture
    sprite.scale=Vector2.ONE*(height/texture.get_height())
    sprite.position=Vector2(0,40-height*.5)
    sprite.modulate=Color.WHITE
