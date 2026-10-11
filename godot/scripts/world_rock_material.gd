extends RefCounted
## One painted stone sample per region, anchored in world space across every face.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const SHADER := preload("res://shaders/world_rock.gdshader")
static var materials: Dictionary = {}

static func for_theme(theme: String) -> ShaderMaterial:
    if materials.has(theme): return materials[theme]
    var directory := "res://assets/sprites/flat_maps/"+theme+"/"
    var data: Dictionary = ART.manifest(directory+"manifest.json")
    var atlas: Texture2D = ART.texture(directory+"terrain_atlas.png")
    var regions: Array = data.get("terrain_regions",[])
    if atlas == null or regions.size()<2:
        push_error("Missing regional stone texture: "+theme)
        return null
    # Region 1 is the unadorned stone stratum. Keep its solid interior, excluding
    # grass, roots, transparent silhouettes and neighbouring atlas materials.
    var region := ART.rect(regions[1])
    var interior := Rect2(region.position+region.size*Vector2(0.18,0.22),region.size*Vector2(0.64,0.56))
    var result := ShaderMaterial.new()
    result.shader = SHADER
    result.set_shader_parameter("stone_atlas",atlas)
    result.set_shader_parameter("sample_rect",Vector4(interior.position.x/atlas.get_width(),interior.position.y/atlas.get_height(),interior.size.x/atlas.get_width(),interior.size.y/atlas.get_height()))
    result.set_shader_parameter("tile_size",Vector2(256,208))
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
