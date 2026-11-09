extends Node2D
## Continuous identical short feet beneath eight painted cloth bodies. The baked cels remain
## available for ghosts/export; ordinary grounded running uses the actual phase.
const GAIT := preload("res://scripts/thread_doll_run_cycle.gd")
const FOLDER := "res://assets/sprites/player/thread_doll_v1/"
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
    var foot := image_texture(FOLDER + "foot.png")
    if foot == null: return false
    for index in 8:
        var frame := image_texture(FOLDER + "upper/run_upper_%02d.png" % index)
        if frame == null: return false
        upper_frames.append(frame)
    composition = Node2D.new()
    composition.position = Vector2(-192, -192)
    add_child(composition)
    legs.append(_make_foot(foot, false))
    legs.append(_make_foot(foot, true))
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

func _make_foot(texture: Texture2D, near: bool) -> Dictionary:
    var foot := Sprite2D.new()
    foot.texture = texture
    foot.centered = false
    foot.offset = -Vector2(texture.get_width() * .5, texture.get_height() - 1.0 - GAIT.FOOT_SOLE.y)
    foot.z_index = 0 if near else -10
    var material := ShaderMaterial.new()
    material.shader = PART_SHADER
    material.set_shader_parameter("shade", 1.0 if near else .86)
    foot.material = material
    _materials.append(material)
    composition.add_child(foot)
    return {"near": near, "foot": foot}

func apply_pose(phase: float, art_scale: float = 0.66, slope: float = 0.0) -> void:
    pose = GAIT.sample(phase, art_scale, slope)
    body.texture = upper_frames[posmod(int(floor(phase * 8.0)), 8)]
    body.position = pose.hip - GAIT.HIP + Vector2(0, -6)
    for leg in legs:
        var points: Dictionary = pose.near if leg.near else pose.far
        var foot: Sprite2D = leg.foot
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
