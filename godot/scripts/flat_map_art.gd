extends Node2D
## Original side-view sprites, independent parallax and preserved platform caps.

const ROCK := preload("res://scripts/world_rock_material.gd")
const ROOT := "res://assets/sprites/flat_maps/"
const INKS := {"moss_cavern": "173c3f", "rain_foundry": "183744", "salt_archive": "564c62", "string_greenhouse": "224939", "obsidian_pilgrim": "382f46", "silent_crown": "303953"}
## V03: per theme, the atlas slices that read as the same ordinary ground ledge
## (chosen by eye per atlas; slot numbers do not mean the same thing across themes).
## Bridges, bronze sluices and boss floors keep their single slice.
const LEDGE_FAMILIES := {"moss_cavern": [0, 2, 3, 9], "rain_foundry": [0, 2, 3, 4, 10], "salt_archive": [0, 2, 4, 9], "string_greenhouse": [0, 2, 5, 9], "obsidian_pilgrim": [0, 2, 3, 9], "silent_crown": [0, 2, 9, 10]}
const ACCENTS := {"moss_cavern": "8eab79", "rain_foundry": "9c9980", "salt_archive": "baa794", "string_greenhouse": "94b57e", "obsidian_pilgrim": "a2747a", "silent_crown": "a6aec3"}
## V03: viewports the "expand" stretch produces from the 1280x720 base: 16:9,
## 64:27 ultrawide, 16:10 and 4:3. Parallax layouts cover every one of them.
const VIEWPORTS := [Vector2(1280, 720), Vector2(1706, 720), Vector2(1280, 800), Vector2(1280, 960)]
## Player.tscn camera zoom.
const CAMERA_ZOOM := 1.25
## main_level._configure_player_camera() limits around the region rect.
const CAMERA_LIMIT_MIN := Vector2(-40, -120)
const CAMERA_LIMIT_MAX_MARGIN := Vector2(80, 70)
const ORNAMENT_CELL := Vector2(1280, 720)
var theme := "moss_cavern"
var region_id := ""
var region_size := Vector2(4096, 720)
var manifest: Dictionary = {}
var platform_styles: Dictionary = {}
var texture_cache: Dictionary = {}
var ornament_materials: Dictionary = {}
## Shared by every region build so a rebuild never recompiles it.
static var ornament_shader: Shader


func configure(theme_id: String, chapter: Dictionary) -> void:
    name = "FlatMapArt"
    theme = theme_id
    region_id = String(chapter.get("id", ""))
    var world: Dictionary = chapter.get("world", {})
    region_size = Vector2(float(world.get("width", 4096.0)), float(world.get("height", 720.0)))
    var file := FileAccess.open(ROOT + theme + "/manifest.json", FileAccess.READ)
    if file != null:
        var parsed = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            manifest = parsed
    for platform in chapter.get("platforms", []):
        platform_styles[String(platform.get("id", ""))] = platform.get("art", {})
    _background_layers()
    _room_landmarks(chapter)


## Layer-local rect a Parallax2D layer shows while the camera roams the whole
## region at one viewport size. Godot's Parallax2D offsets the layer by the
## unzoomed screen position (centre - viewport/2), so a view's left edge lands at
## scroll * (centre - viewport/2) + viewport/2 - view/2 in layer space (measured
## in the formal World; `parallax_layout` checks it against the engine).
static func parallax_window(region: Vector2, scroll: Vector2, viewport: Vector2) -> Rect2:
    var half := viewport / (2.0 * CAMERA_ZOOM)
    var low := CAMERA_LIMIT_MIN + half
    var high := (region + CAMERA_LIMIT_MAX_MARGIN - half).max(low)
    var shift := viewport * 0.5 - half
    var start := scroll * (low - viewport * 0.5) + shift
    var finish := scroll * (high - viewport * 0.5) + shift + half * 2.0
    return Rect2(start, finish - start)


## Union of parallax_window() over every supported viewport.
static func parallax_reach(region: Vector2, scroll: Vector2) -> Rect2:
    var reach := parallax_window(region, scroll, VIEWPORTS[0])
    for viewport in VIEWPORTS:
        reach = reach.merge(parallax_window(region, scroll, viewport))
    return reach


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
    # V03: the second copy is mirrored so the plain repeat has no hard edge, but
    # each join is then a visible symmetry axis. Size and place the unmirrored
    # copy so everything the region can show (any supported viewport) stays
    # inside it; the mirrored copy only remains for views wider than those.
    var reach := parallax_reach(region_size, layer.scroll_scale)
    var main_view := parallax_window(region_size, layer.scroll_scale, VIEWPORTS[0])
    var scale_value := maxf(maxf(1.0, 960.0 / float(texture.get_height())), ceilf(reach.size.x + 2.0) / float(texture.get_width()))
    var tile_size := Vector2(texture.get_size()) * scale_value
    # Vertically the 16:9 view is centred on the painting (taller views reach the faded edges).
    var origin := Vector2(reach.get_center().x - tile_size.x * 0.5, main_view.get_center().y - tile_size.y * 0.5)
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
        sprite.position = origin + Vector2(float(i) * tile_size.x, 0)
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
        # The period now exceeds every view, so one copy on each side is enough.
        ornaments.repeat_times = 1
        ornaments.z_index = -109 if i == 0 else -101
        _scatter_ornaments(ornaments, i, 0.21 if i == 0 else 0.33)
        add_child(ornaments)


## V03: the layers used to repeat four evenly spaced ornaments every 2560x1440,
## so the same row came round as the camera crossed a region. Now one ornament
## per ORNAMENT_CELL (the same density), jittered by a seed from region and
## layer, over a repeat period wider than everything the layer can show in the
## region: normal play never sees the arrangement twice. Rebuilds are identical.
func _scatter_ornaments(layer: Parallax2D, layer_index: int, opacity: float) -> void:
    var reach := parallax_reach(region_size, layer.scroll_scale)
    var columns := int(ceil(reach.size.x / ORNAMENT_CELL.x)) + 1
    var rows := int(ceil(reach.size.y / ORNAMENT_CELL.y)) + 1
    layer.repeat_size = Vector2(columns, rows) * ORNAMENT_CELL
    var random := RandomNumberGenerator.new()
    random.seed = hash("%s|%s|%d" % [theme, region_id, layer_index])
    var count := maxi(manifest.get("decorations", []).size(), 1)
    var previous_row: Array = []
    for row in rows:
        var current_row: Array = []
        for column in columns:
            var variant := random.randi_range(0, count - 1)
            # Neighbouring cells never repeat the same ornament side by side or stacked.
            for attempt in 4:
                if count < 3 or (variant != (current_row[column - 1] if column > 0 else -1) and variant != (previous_row[column] if row > 0 else -1)):
                    break
                variant = random.randi_range(0, count - 1)
            current_row.append(variant)
            var size_value := Vector2(random.randf_range(240, 320), random.randf_range(350, 460))
            var art := ornament(size_value, variant)
            # ornament() ties the flip to the seed's parity; choose it independently.
            if art is Sprite2D:
                art.flip_h = random.randi_range(0, 1) == 1
            var free := (ORNAMENT_CELL - size_value).max(Vector2.ZERO)
            art.position = reach.position + Vector2(column, row) * ORNAMENT_CELL + Vector2(random.randf() * free.x, random.randf() * free.y)
            art.modulate.a = opacity
            layer.add_child(art)
        previous_row = current_row


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
    sprite.material = _ornament_feather(index, texture, sprite.region_rect)
    sprite.set_meta("decoration_variant", index)
    return sprite


## V03: several atlas cells cut their art at the cell border (the moss arch's
## base, ginkgo leaves on the right edge), which showed as a straight hard line
## wherever the ornament stood. Fade every ornament out over its outer 7%.
func _ornament_feather(index: int, texture: Texture2D, region: Rect2) -> ShaderMaterial:
    if ornament_materials.has(index):
        return ornament_materials[index]
    if ornament_shader == null:
        ornament_shader = Shader.new()
        ornament_shader.code = "shader_type canvas_item; uniform vec4 region_uv; uniform float feather = 0.07; varying vec4 tint_color; void vertex() { tint_color = COLOR; } void fragment() { vec2 t = (UV - region_uv.xy) / (region_uv.zw - region_uv.xy); vec2 edge = min(t, 1.0 - t); vec4 tex = texture(TEXTURE, UV); COLOR = tex * tint_color; COLOR.a *= smoothstep(0.0, feather, edge.x) * smoothstep(0.0, feather, edge.y); }"
    var material := ShaderMaterial.new()
    material.shader = ornament_shader
    var size := Vector2(texture.get_size())
    material.set_shader_parameter("region_uv", Vector4(region.position.x / size.x, region.position.y / size.y, region.end.x / size.x, region.end.y / size.y))
    ornament_materials[index] = material
    return material


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
    var choice := platform_choice(theme, String(parent.name), material_name, style)
    var family_variant := int(choice.family)
    var index := posmod(int(choice.variant), variants.size())
    var variant: Dictionary = variants[index]
    var texture := _texture(ROOT + theme + "/platform_atlas.png")
    var region: Array = variant.get("region", [])
    if texture == null or region.size() != 4:
        return false
    var source := Rect2(region[0], region[1], region[2], region[3])
    var top_offset := float(variant.get("walk_y", 0))
    var y_scale := clampf((dimensions.y + 30) / maxf(source.size.y - top_offset, 1), 0.40, 0.90)
    var top := -dimensions.y * 0.5
    var flip := bool(choice.flip)
    parent.set_meta("platform_art_variant", index)
    parent.set_meta("platform_art_flip", flip)
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
    if family_variant == 2 and not material_name.contains("gate") and not material_name.contains("wall"):
        var half := dimensions*0.5
        var body := ROCK.face(parent,PackedVector2Array([Vector2(-half.x,-half.y+minf(12,half.y)),Vector2(half.x,-half.y+minf(12,half.y)),Vector2(half.x,half.y-minf(12,half.y)),Vector2(-half.x,half.y-minf(12,half.y))]),theme)
        body.z_index = -2
        for ceiling in [false,true]:
            var y := half.y if ceiling else -half.y
            var rim := ROCK.surface_rim(parent,Vector2(-half.x,y),Vector2(half.x,y),theme,ceiling,minf(half.y,96))
            rim.z_index = -1
    var edge := Line2D.new()
    edge.name = "WalkableEdge"
    edge.points = PackedVector2Array([Vector2(-dimensions.x * 0.5, top), Vector2(dimensions.x * 0.5, top)])
    edge.width = 1.5
    edge.default_color = Color(ACCENTS.get(theme, "8eab79"), 0.65)
    edge.antialiased = true
    edge.z_index = -2
    parent.add_child(edge)
    return true


## One whole slice and one orientation per platform, stable across rebuilds
## (streaming residency recreates platforms by id). An explicit material_* style
## wins; otherwise ordinary ledges pick from the theme family by id and keep the
## authored whole-platform flip_h when the level data has one. Other families
## stay unflipped unless material_flip_h says otherwise.
static func platform_choice(theme_id: String, platform_id: String, material_name: String, style: Dictionary = {}) -> Dictionary:
    var family := material_variant_for(material_name)
    var variant := family
    if style.has("material_variant"):
        variant = int(style.material_variant)
    elif family == 2:
        var options: Array = LEDGE_FAMILIES.get(theme_id, [2])
        variant = int(options[posmod((platform_id + "|slice").hash(), options.size())])
    var flip := false
    if style.get("material_flip_h") is bool:
        flip = style.material_flip_h
    elif family == 2:
        # Bridges, sluices and boss floors keep their single unflipped art;
        # only ordinary ledges take the authored flip_h or an id-derived one.
        flip = style.flip_h if style.get("flip_h") is bool else posmod((platform_id + "|flip").hash(), 2) == 1
    return {"family": family, "variant": variant, "flip": flip}


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
