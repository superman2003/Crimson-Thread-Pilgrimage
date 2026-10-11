extends Node2D
## Original side-view sprites, independent parallax and preserved platform caps.

const ROCK := preload("res://scripts/world_rock_material.gd")
const ROOT := "res://assets/sprites/flat_maps/"
const INKS := {"moss_cavern": "173c3f", "rain_foundry": "183744", "salt_archive": "564c62", "string_greenhouse": "224939", "obsidian_pilgrim": "382f46", "silent_crown": "303953"}
const ACCENTS := {"moss_cavern": "8eab79", "rain_foundry": "9c9980", "salt_archive": "baa794", "string_greenhouse": "94b57e", "obsidian_pilgrim": "a2747a", "silent_crown": "a6aec3"}
var theme := "moss_cavern"
var manifest: Dictionary = {}
var platform_styles: Dictionary = {}
var texture_cache: Dictionary = {}


func configure(theme_id: String, chapter: Dictionary) -> void:
    name = "FlatMapArt"
    theme = theme_id
    var file := FileAccess.open(ROOT + theme + "/manifest.json", FileAccess.READ)
    if file != null:
        var parsed = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            manifest = parsed
    for platform in chapter.get("platforms", []):
        platform_styles[String(platform.get("id", ""))] = platform.get("art", {})
    _background_layers()
    _room_landmarks(chapter)


func ready_for_platforms() -> bool:
    return manifest.get("variants", []).size() == 12


func _texture(path: String) -> Texture2D:
    if texture_cache.has(path):
        return texture_cache[path] as Texture2D
    var texture: Texture2D
    if ResourceLoader.exists(path):
        texture = load(path) as Texture2D
    else:
        var image := Image.load_from_file(path)
        if image != null and not image.is_empty():
            texture = ImageTexture.create_from_image(image)
    texture_cache[path] = texture
    return texture


func _background_layers() -> void:
    var texture := _texture(ROOT + theme + "/background.png")
    if texture == null:
        return
    var layer := Parallax2D.new()
    layer.name = "PaintedBackdrop"
    layer.scroll_scale = Vector2(0.075, 0.06)
    layer.z_index = -116
    var scale_value := maxf(1.0, 960.0 / float(texture.get_height()))
    var tile_size := Vector2(texture.get_size()) * scale_value
    layer.repeat_size = Vector2(tile_size.x * 2, tile_size.y)
    layer.repeat_times = 3
    var fade := Shader.new()
    fade.code = "shader_type canvas_item; uniform vec4 edge_color : source_color; varying vec4 tint_color; void vertex() { tint_color = COLOR; } void fragment() { vec4 tex = texture(TEXTURE, UV); float fade = smoothstep(0.0, 0.08, UV.y) * smoothstep(0.0, 0.08, 1.0 - UV.y); COLOR = mix(edge_color, tex, fade) * tint_color; }"
    var shader_material := ShaderMaterial.new()
    shader_material.shader = fade
    shader_material.set_shader_parameter("edge_color", Color(INKS.get(theme, "173c3f")))
    for i in range(2):
        var sprite := Sprite2D.new()
        sprite.texture = texture
        sprite.centered = false
        sprite.position = Vector2(float(i) * tile_size.x, 0)
        sprite.scale = Vector2.ONE * scale_value
        sprite.flip_h = i == 1
        sprite.modulate = Color(0.60, 0.64, 0.65, 1)
        sprite.material = shader_material
        layer.add_child(sprite)
    add_child(layer)
    for i in range(2):
        var ornaments := Parallax2D.new()
        ornaments.name = "FlatMiddleDistance" if i == 0 else "FlatNearEdges"
        ornaments.scroll_scale = Vector2(0.24, 0.20) if i == 0 else Vector2(0.55, 0.40)
        ornaments.repeat_size = Vector2(2560, 1440)
        ornaments.repeat_times = 3
        ornaments.z_index = -109 if i == 0 else -101
        for j in range(4):
            var art := ornament(Vector2(240 + j * 26, 350 + j * 37), j + i * 11)
            art.position = Vector2(110 + j * 610, 25 + (j % 2) * 900)
            art.modulate.a = 0.21 if i == 0 else 0.33
            ornaments.add_child(art)
        add_child(ornaments)


func ornament(size_value: Vector2, seed_number: int) -> Node2D:
    var decorations: Array = manifest.get("decorations", [])
    if decorations.is_empty():
        return Node2D.new()
    var index := posmod(seed_number, decorations.size())
    var region: Array = decorations[index].get("region", [])
    var texture := _texture(ROOT + theme + "/decor_atlas.png")
    if texture == null or region.size() != 4:
        return Node2D.new()
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.centered = false
    sprite.region_enabled = true
    sprite.region_filter_clip_enabled = true
    sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
    sprite.scale = Vector2.ONE * minf(size_value.x / float(region[2]), size_value.y / float(region[3]))
    sprite.flip_h = posmod(seed_number, 2) == 1
    sprite.set_meta("decoration_variant", index)
    return sprite


func _room_landmarks(chapter: Dictionary) -> void:
    for room in chapter.get("map_rooms", []):
        var data: Dictionary = room.get("landmark_art", {})
        if data.is_empty():
            continue
        var point: Array = data.get("position", [0, 0])
        var dimensions: Array = data.get("size", [250, 360])
        var variant := int(data.get("variant", String(room.get("id", "")).hash()))
        var art := ornament(Vector2(dimensions[0], dimensions[1]), variant)
        art.name = "Landmark_" + String(room.get("id", ""))
        art.position = Vector2(point[0], point[1])
        art.modulate.a = clampf(float(data.get("opacity", 0.42)), 0.0, 1.0)
        art.z_index = -84
        add_child(art)


func add_environment_ornament(data: Dictionary) -> void:
    var block_id := String(data.get("id", ""))
    if block_id.contains("back_wall"):
        return
    var rect: Array = data.get("rect", [])
    if rect.size() < 4:
        return
    var dimensions := Vector2(minf(float(rect[2]), 840), minf(float(rect[3]), 1100))
    var art := ornament(dimensions, int(block_id.hash()))
    art.name = block_id
    art.position = Vector2(rect[0], rect[1]) + (Vector2(rect[2], rect[3]) - dimensions) * 0.5
    art.z_index = -110
    art.modulate.a = 0.25
    add_child(art)


func add_platform_visual(parent: Node2D, dimensions: Vector2, material_name: String) -> bool:
    if not ready_for_platforms():
        return false
    var variants: Array = manifest.get("variants", [])
    var style: Dictionary = platform_styles.get(String(parent.name), {})
    # Legacy per-tile variants mixed soil, masonry and roots inside one step.
    # Select the complete platform by material, with an explicit whole-object override.
    var family_variant := material_variant_for(material_name)
    var index := posmod(int(style.get("material_variant", family_variant)), variants.size())
    var variant: Dictionary = variants[index]
    var texture := _texture(ROOT + theme + "/platform_atlas.png")
    var region: Array = variant.get("region", [])
    if texture == null or region.size() != 4:
        return false
    var source := Rect2(region[0], region[1], region[2], region[3])
    var top_offset := float(variant.get("walk_y", 0))
    var y_scale := clampf((dimensions.y + 30) / maxf(source.size.y - top_offset, 1), 0.40, 0.90)
    var top := -dimensions.y * 0.5
    var flip := bool(style.get("material_flip_h", false))
    parent.set_meta("platform_art_variant", index)
    parent.set_meta("platform_art_asset", ROOT + theme + "/platform_atlas.png")
    parent.set_meta("platform_art_body_variants", [index])
    if dimensions.x <= source.size.x:
        _slice(parent, "Material", texture, source, Vector2(-dimensions.x * 0.5, top - top_offset * y_scale), Vector2(dimensions.x / source.size.x, y_scale), flip)
    else:
        var cap_width := minf(90, source.size.x * 0.22)
        var left_rect := Rect2(source.position, Vector2(cap_width, source.size.y))
        var right_rect := Rect2(source.position + Vector2(source.size.x - cap_width, 0), Vector2(cap_width, source.size.y))
        _slice(parent, "Material", texture, right_rect if flip else left_rect, Vector2(-dimensions.x * 0.5, top - top_offset * y_scale), Vector2(1, y_scale), flip)
        var cursor := -dimensions.x * 0.5 + cap_width
        var segment := 0
        var body_variants: Array = [index]
        while cursor < dimensions.x * 0.5 - cap_width:
            var middle_variant: Dictionary = variants[posmod(int(body_variants[segment % body_variants.size()]), variants.size())]
            var r: Array = middle_variant.get("region", region)
            var middle_source := Rect2(r[0], r[1], r[2], r[3])
            var middle_cap := minf(90, middle_source.size.x * 0.22)
            var body_width := middle_source.size.x - middle_cap * 2
            var body_top := float(middle_variant.get("walk_y", 0))
            var body_scale := clampf((dimensions.y + 30) / maxf(middle_source.size.y - body_top, 1), 0.40, 0.90)
            var draw_width := minf(body_width, dimensions.x * 0.5 - cap_width - cursor)
            _slice(parent, "PlatformBody%02d" % segment, texture, Rect2(middle_source.position + Vector2(middle_cap, 0), Vector2(body_width, middle_source.size.y)), Vector2(cursor, top - body_top * body_scale), Vector2(draw_width / body_width, body_scale), flip)
            cursor += draw_width
            segment += 1
        _slice(parent, "PlatformRightCap", texture, left_rect if flip else right_rect, Vector2(dimensions.x * 0.5 - cap_width, top - top_offset * y_scale), Vector2(1, y_scale), flip)
    if dimensions.y > 140 or material_name.contains("wall") or material_name.contains("gate"):
        var half := dimensions * 0.5
        var fill := ROCK.face(parent,PackedVector2Array([Vector2(-half.x,-half.y+14),Vector2(half.x,-half.y+14),Vector2(half.x,half.y),Vector2(-half.x,half.y)]),theme)
        fill.z_index = -5
    var edge := Line2D.new()
    edge.name = "WalkableEdge"
    edge.points = PackedVector2Array([Vector2(-dimensions.x * 0.5, top), Vector2(dimensions.x * 0.5, top)])
    edge.width = 1.5
    edge.default_color = Color(ACCENTS.get(theme, "8eab79"), 0.65)
    edge.antialiased = true
    edge.z_index = -2
    parent.add_child(edge)
    return true


static func material_variant_for(material_name: String) -> int:
    if material_name.contains("boss"):
        return 11
    if material_name.contains("bronze") or material_name.contains("sluice"):
        return 7
    if material_name.contains("bridge"):
        return 6
    return 2


func _slice(parent: Node2D, node_name: String, texture: Texture2D, region: Rect2, offset: Vector2, dimensions: Vector2, flip: bool) -> void:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = texture
    sprite.centered = false
    sprite.region_enabled = true
    sprite.region_filter_clip_enabled = true
    sprite.region_rect = region
    sprite.position = offset
    sprite.scale = dimensions
    sprite.flip_h = flip
    sprite.z_index = -3
    sprite.set_meta("original_map_asset", ROOT + theme + "/platform_atlas.png")
    parent.add_child(sprite)
