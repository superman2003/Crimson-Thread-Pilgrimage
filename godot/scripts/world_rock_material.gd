extends RefCounted
## Shared inked rock family, regional palettes; world-space alignment on every face.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const SHADER := preload("res://shaders/world_rock.gdshader")
const INK_ROCK := "res://assets/sprites/flat_maps/shared_ink/rock_mass_ink_v1.webp"
const TINTS := {"moss_cavern": Vector3(1,1,1), "rain_foundry": Vector3(0.78,0.95,1.12),
    "salt_archive": Vector3(1.13,0.98,1.15), "string_greenhouse": Vector3(0.90,1.13,0.82),
    "obsidian_pilgrim": Vector3(1.02,0.81,1.04), "silent_crown": Vector3(0.90,0.99,1.20)}
static var materials: Dictionary = {}

static func for_theme(theme: String) -> ShaderMaterial:
    if materials.has(theme): return materials[theme]
    var atlas: Texture2D = ART.texture(INK_ROCK)
    if atlas == null:
        push_error("Missing regional stone texture: "+theme)
        return null
    var result := ShaderMaterial.new()
    result.shader = SHADER
    result.set_shader_parameter("stone_atlas",atlas)
    # Preserve native density; broad inked planes replace photographic microdetail.
    result.set_shader_parameter("tile_size",Vector2(atlas.get_size()))
    result.set_shader_parameter("stone_tint",TINTS.get(theme,Vector3.ONE))
    materials[theme] = result
    return result

static func face(parent: Node, points: PackedVector2Array, theme: String) -> Polygon2D:
    var panel := Polygon2D.new()
    panel.name = "RegionalStoneFace"
    panel.polygon = points
    panel.material = for_theme(theme)
    panel.set_meta("material_family",theme+"/stone")
    panel.set_meta("material_variant",1)
    panel.set_meta("world_aligned_material",true)
    parent.add_child(panel)
    return panel

static func authored_edge(parent: Node2D, left: Vector2, right: Vector2, theme: String, ceiling: bool) -> Polygon2D:
    var kind := "ceiling" if ceiling else "floor"
    var atlas: Texture2D = ART.texture("res://assets/sprites/flat_maps/shared_ink/"+kind+"_ink_v1.webp")
    var metadata: Dictionary = ART.manifest("res://assets/sprites/flat_maps/shared_ink/edges.json")
    var material := ShaderMaterial.new()
    material.shader = preload("res://shaders/ink_cave_edge.gdshader")
    material.set_shader_parameter("edge_atlas",atlas)
    material.set_shader_parameter("silhouette_relief",1.0 if ceiling else 0.18)
    material.set_shader_parameter("edge_curve",ART.texture("res://assets/sprites/flat_maps/shared_ink/"+kind+"_edge_profile.png"))
    material.set_shader_parameter("surface_origin",parent.to_global(left))
    material.set_shader_parameter("slope",(right.y-left.y)/(right.x-left.x))
    material.set_shader_parameter("anchor_v",float(metadata.get(kind,{}).get("anchor_v",0.7 if ceiling else 0.3)))
    material.set_shader_parameter("stone_tint",TINTS.get(theme,Vector3.ONE))
    var face := Polygon2D.new()
    face.name = "AuthoredCeiling" if ceiling else "AuthoredFloor"
    face.polygon = PackedVector2Array([left+Vector2(0,-700 if ceiling else -160),right+Vector2(0,-700 if ceiling else -160),right+Vector2(0,160 if ceiling else 700),left+Vector2(0,160 if ceiling else 700)])
    face.material = material
    face.set_meta("independent_edge_art",kind)
    parent.add_child(face)
    return face

static func surface_rim(parent: Node2D, left: Vector2, right: Vector2, theme: String, ceiling: bool, depth: float = 96.0) -> Polygon2D:
    var rim := authored_edge(parent,left,right,theme,ceiling)
    var height := clampf(depth*2.4,60,220)
    var lip := minf(12,depth*0.25)
    rim.material.set_shader_parameter("art_height",height)
    rim.material.set_shader_parameter("silhouette_relief",0.45 if ceiling else 0.18)
    rim.material.set_shader_parameter("join_body",true)
    rim.material.set_shader_parameter("join_depth",maxf(8,depth*0.7))
    rim.material.set_shader_parameter("body_atlas",ART.texture(INK_ROCK))
    rim.polygon = PackedVector2Array([left+Vector2(0,-depth if ceiling else -lip),right+Vector2(0,-depth if ceiling else -lip),right+Vector2(0,lip if ceiling else depth),left+Vector2(0,lip if ceiling else depth)])
    return rim

static func stratum(parent: Node2D, left: Vector2, right: Vector2, depth: float, theme: String) -> Polygon2D:
    var inset := minf(12,depth*0.25)
    var face := face(parent,PackedVector2Array([left+Vector2(0,inset),right+Vector2(0,inset),right+Vector2(0,depth),left+Vector2(0,depth)]),theme)
    face.name = "HandPaintedStratum"
    face.z_index = -5
    var rim := surface_rim(parent,left,right,theme,false,minf(depth,96))
    rim.z_index = -4
    return face
