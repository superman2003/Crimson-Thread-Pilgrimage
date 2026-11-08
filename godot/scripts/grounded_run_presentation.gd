extends Node2D
## Continuous native rig with painted overlapping joints. The baked cels remain
## available for ghosts/export; ordinary grounded running uses the actual phase.
const GAIT := preload("res://scripts/grounded_run_cycle.gd")
const FOLDER := "res://assets/sprites/player/grounded_run_v1/"
const PART_SHADER := preload("res://shaders/grounded_run_part.gdshader")
var source_sprite: AnimatedSprite2D
var composition: Node2D
var body: Sprite2D
var upper_frames: Array[Texture2D] = []
var legs: Array[Dictionary] = []
var pose: Dictionary = {}
var active := false
var _saved_material: Material
var _materials: Array[ShaderMaterial] = []

static func image_texture(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        var imported := load(path) as Texture2D
        if imported != null:
            return imported
    var image := Image.load_from_file(path)
    if image == null:
        return null
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)

func setup() -> bool:
    if composition != null:
        return true
    var atlas := image_texture(FOLDER + "source/rig_parts.png")
    if atlas == null:
        return false
    for index in 16:
        var frame := image_texture(FOLDER + "upper/upper_%02d.png" % index)
        if frame == null:
            return false
        upper_frames.append(frame)
    var regions: Array = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "source/part_regions.json")).regions
    composition = Node2D.new()
    composition.position = Vector2(-192, -192)
    add_child(composition)
    legs.append(_make_leg(atlas, regions, false))
    legs.append(_make_leg(atlas, regions, true))
    body = Sprite2D.new()
    body.texture = upper_frames[0]
    body.centered = false
    body.z_index = 20
    var material := ShaderMaterial.new()
    material.shader = PART_SHADER
    material.set_shader_parameter("upper_body", true)
    material.set_shader_parameter("drawn_upper", true)
    body.material = material
    _materials.append(material)
    composition.add_child(body)
    return true

func attach(target: AnimatedSprite2D) -> bool:
    if source_sprite != null or not setup():
        return false
    source_sprite = target
    # Keep the original AnimatedSprite2D free of overlays. This sibling adopts
    # its exact transform only while running; idle/action ownership stays clear.
    target.get_parent().add_child(self)
    visible = false
    return true

func _part(atlas: Texture2D, region: Array, anchor: Vector2, scale_value: Vector2, layer: int, cap_cleanup: bool) -> Sprite2D:
    var frame := AtlasTexture.new()
    frame.atlas = atlas
    frame.region = Rect2(region[0], region[1], region[2], region[3])
    frame.filter_clip = true
    var sprite := Sprite2D.new()
    sprite.texture = frame
    sprite.centered = false
    sprite.offset = -anchor
    sprite.scale = scale_value
    sprite.z_index = layer
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var material := ShaderMaterial.new()
    material.shader = PART_SHADER
    material.set_shader_parameter("region", Vector4(frame.region.position.x / atlas.get_width(), frame.region.position.y / atlas.get_height(), frame.region.size.x / atlas.get_width(), frame.region.size.y / atlas.get_height()))
    material.set_shader_parameter("clean_caps", cap_cleanup)
    material.set_shader_parameter("shade", 0.86 if layer < 0 else 1.0)
    sprite.material = material
    _materials.append(material)
    composition.add_child(sprite)
    return sprite

func _make_leg(atlas: Texture2D, regions: Array, near: bool) -> Dictionary:
    # Use identical near/far shapes; darken the far leg instead of letting two
    # independently generated drawings change the apparent bone width.
    var thigh: Array = regions[1]
    var shin: Array = regions[2]
    var boot: Array = regions[3].duplicate()
    boot[1] += 65
    boot[3] -= 65
    var thigh_anchor := Vector2(float(thigh[2]) * .5, float(thigh[3]) * .09)
    var shin_anchor := Vector2(float(shin[2]) * .5, float(shin[3]) * .09)
    var foot_scale := 20.0 / float(boot[2])
    var foot_anchor := Vector2(float(boot[2]) * .275, float(boot[3]) - GAIT.FOOT_SOLE.y / foot_scale)
    var layer := 0 if near else -10
    return {"near": near,
        "thigh": _part(atlas, thigh, thigh_anchor, Vector2(16.0 / float(thigh[2]), GAIT.THIGH / (float(thigh[3]) * .82)), layer + 2, true),
        "shin": _part(atlas, shin, shin_anchor, Vector2(12.5 / float(shin[2]), GAIT.SHIN / (float(shin[3]) * .82)), layer + 1, true),
        "foot": _part(atlas, boot, foot_anchor, Vector2.ONE * foot_scale, layer, false)}

func apply_pose(phase: float, art_scale: float = 0.66, slope: float = 0.0) -> void:
    pose = GAIT.sample(phase, art_scale, slope)
    body.texture = upper_frames[posmod(int(floor(phase * 16.0)), 16)]
    body.position = pose.hip - GAIT.HIP
    for leg in legs:
        var points: Dictionary = pose.near if leg.near else pose.far
        var thigh: Sprite2D = leg.thigh
        var shin: Sprite2D = leg.shin
        var foot: Sprite2D = leg.foot
        thigh.position = points.hip
        thigh.rotation = (points.knee - points.hip).angle() - PI * .5
        shin.position = points.knee
        shin.rotation = (points.ankle - points.knee).angle() - PI * .5
        foot.position = points.ankle
        foot.rotation = points.foot_angle
    for material in _materials:
        material.set_shader_parameter("phase", phase)

func sync(phase: float, slope: float = 0.0) -> void:
    if not is_instance_valid(source_sprite):
        return
    if source_sprite.animation != &"run":
        if active:
            if _saved_material is ShaderMaterial:
                _saved_material.set_shader_parameter("hide_source", false)
        active = false
        visible = false
        return
    if not active:
        _saved_material = source_sprite.material
    if _saved_material is ShaderMaterial:
        _saved_material.set_shader_parameter("hide_source", true)
    active = true
    visible = true
    transform = source_sprite.transform
    scale *= Vector2(-1 if source_sprite.flip_h else 1, -1 if source_sprite.flip_v else 1)
    position += source_sprite.transform.basis_xform(source_sprite.offset)
    modulate = source_sprite.modulate
    apply_pose(phase, absf(source_sprite.scale.x), slope)
    _sync_materials()

func _process(_delta: float) -> void:
    if active:
        _sync_materials()

func _exit_tree() -> void:
    if _saved_material is ShaderMaterial:
        _saved_material.set_shader_parameter("hide_source", false)

func _sync_materials() -> void:
    for material in _materials:
        if _saved_material is ShaderMaterial:
            for key in ["presentation_alpha", "flash_amount", "flash_color"]:
                material.set_shader_parameter(key, _saved_material.get_shader_parameter(key))
