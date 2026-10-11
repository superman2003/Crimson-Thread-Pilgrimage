extends RefCounted
## One painted stone sample per region, anchored in world space across every face.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const SHADER := preload("res://shaders/world_rock.gdshader")
static var materials: Dictionary = {}

static func for_theme(theme: String) -> ShaderMaterial:
    if materials.has(theme): return materials[theme]
    var directory := "res://assets/sprites/flat_maps/"+theme+"/"
    var atlas: Texture2D = ART.texture(directory+"rock_mass_large.png")
    if atlas == null:
        push_error("Missing regional stone texture: "+theme)
        return null
    var result := ShaderMaterial.new()
    result.shader = SHADER
    result.set_shader_parameter("stone_atlas",atlas)
    # Native texel density avoids enlarging a 1254px mural to 4096 world pixels.
    result.set_shader_parameter("tile_size",Vector2(atlas.get_size()))
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
