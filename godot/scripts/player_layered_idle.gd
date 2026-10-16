extends Node2D
## Presentation-only, fixed support + seven genuine cloth atlas regions.
## attach(sprite) once AFTER its material is assigned; sync_pose() at the end of
## Player's pose/offset sync. The original SpriteFrames and animation stay intact.
## This is the minimum cloth loop, not accepted full idle/breathing or transitions.

const ASSET_DIR := "res://assets/sprites/player/generated_hero_motion_v4/runtime_idle/"
const MANIFEST_PATH := ASSET_DIR + "manifest.json"
const FPS := 10.0
const FRAME_COUNT := 7
const SOURCE_ORDER := [1, 3, 2, 4, 5, 6, 7]
const CYCLE_SECONDS := FRAME_COUNT / FPS

var source_sprite: AnimatedSprite2D
var body: Sprite2D
var cloth: Sprite2D
var active := false
var elapsed := 0.0
var playback_index := 0
var _data: Dictionary = {}
var _regions: Array[AtlasTexture] = []
var _saved_self_modulate := Color.WHITE
var _saved_material: Material
var _saved_use_parent_material := false
var _ready_to_draw := false


func attach(target: AnimatedSprite2D, manifest_data: Dictionary = {}) -> bool:
    if not is_instance_valid(target) or source_sprite != null or get_parent() != null or not _regions.is_empty():
        return false
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) if manifest_data.is_empty() else manifest_data
    if not parsed is Dictionary or not _load_layers(parsed):
        return false # Leave the source visible if assets are unavailable.
    _data = parsed
    source_sprite = target
    name = "LayeredIdle"
    visible = false
    target.add_child(self)
    target.animation_changed.connect(sync_pose)
    _ready_to_draw = true
    sync_pose()
    return true


func sync_pose() -> void:
    if not _ready_to_draw or not is_instance_valid(source_sprite):
        return
    if source_sprite.animation != &"idle":
        _leave_idle()
        return
    if not active:
        _saved_self_modulate = source_sprite.self_modulate
        _saved_material = source_sprite.material
        _saved_use_parent_material = source_sprite.use_parent_material
        # Resolve the effective material before masking a use_parent_material source.
        material = _effective_source_material()
        active = true
        elapsed = 0.0
        playback_index = 0
    elif source_sprite.material != null:
        # A caller may replace the material while idle; preserve that new object.
        _saved_material = source_sprite.material
        material = _effective_source_material()
    # The existing hit_flash shader overrides COLOR (including its alpha). Merely
    # setting self_modulate.a=0 would not mask its source draw. Keep the original
    # material object on the layers, and use the default shader for the hidden
    # source only. No shader behavior or uniform values are rewritten here.
    source_sprite.material = null
    source_sprite.use_parent_material = false
    source_sprite.self_modulate = Color(_saved_self_modulate, 0.0)
    modulate = _saved_self_modulate
    use_parent_material = false
    visible = true
    # AnimatedSprite2D.flip_h/flip_v do not affect children. Mirror the WHOLE
    # composition around the same source-local origin, not each image's canvas.
    scale = Vector2(-1.0 if source_sprite.flip_h else 1.0,
        -1.0 if source_sprite.flip_v else 1.0)
    var reference: Dictionary = _data.reference
    var canvas := Vector2(reference.canvas[0], reference.canvas[1])
    var center := canvas * 0.5 if source_sprite.centered else Vector2.ZERO
    # Deliberately do not inherit the four-frame idle offset. It registers the old
    # moving poses; the fixed support is already registered to idle0's feet.
    var foot_target := Vector2(reference.foot_center_x, reference.foot_baseline) - center
    var support: Dictionary = _data.support
    var root_point := Vector2(support.registration_root[0], support.registration_root[1])
    body.scale = Vector2.ONE * float(support.raw_to_design)
    body.position = foot_target - root_point * body.scale
    cloth.scale = body.scale * float(_data.composition.cloth_source_to_support_source_scale)
    _apply_frame()


func _process(delta: float) -> void:
    sync_pose()
    if not active or not source_sprite.is_playing() or not source_sprite.can_process():
        return
    if not is_finite(delta) or delta <= 0.0:
        return
    # Godot's process delta already includes Engine.time_scale and SceneTree
    # pause. get_playing_speed includes speed_scale/custom_speed and its sign.
    # Do not derive phase from the old four-frame loop: its 0.4s wrap must never
    # reset this seven-cel 0.7s cycle. Pause/resume preserves this independent age.
    elapsed = fposmod(elapsed + delta * source_sprite.get_playing_speed(), CYCLE_SECONDS)
    playback_index = floori(elapsed * FPS + 0.00000001) % FRAME_COUNT
    _apply_frame()


func _apply_frame() -> void:
    var record: Dictionary = _data.cloth.frames[playback_index]
    var attachment: Array = _data.composition.cloth_attachment_support_source_coordinates
    var anchor := Vector2(record.anchor[0], record.anchor[1])
    cloth.texture = _regions[playback_index]
    cloth.position = body.position + Vector2(attachment[0], attachment[1]) * body.scale - anchor * cloth.scale


func _leave_idle() -> void:
    visible = false
    if not active:
        return
    if is_instance_valid(source_sprite):
        source_sprite.self_modulate = _saved_self_modulate
        source_sprite.material = _saved_material
        source_sprite.use_parent_material = _saved_use_parent_material
    active = false
    elapsed = 0.0
    playback_index = 0


func _exit_tree() -> void:
    # Removing/freeing the helper must never strand an invisible player.
    _leave_idle()
    if is_instance_valid(source_sprite) and source_sprite.animation_changed.is_connected(sync_pose):
        source_sprite.animation_changed.disconnect(sync_pose)
    # Detached helpers may still be referenced by Player. They must never hide
    # its source again when the next frame/pose synchronization calls this API.
    _ready_to_draw = false
    source_sprite = null


func _effective_source_material() -> Material:
    if not _saved_use_parent_material:
        return _saved_material
    var ancestor := source_sprite.get_parent() as CanvasItem
    while ancestor != null and ancestor.use_parent_material:
        ancestor = ancestor.get_parent() as CanvasItem
    return ancestor.material if ancestor != null else null


func _finite_number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value))


func _numbers(value: Variant, count: int) -> bool:
    if not value is Array or value.size() != count:
        return false
    for number in value:
        if not _finite_number(number):
            return false
    return true


func _valid_manifest(data: Dictionary) -> bool:
    # Validate this small schema before creating layers or touching the source.
    # The optional in-memory attach input supports focused malformed-data tests.
    for key in ["support", "cloth", "reference", "composition"]:
        if not data.get(key) is Dictionary:
            return false
    var support: Dictionary = data.support
    var cloth_data: Dictionary = data.cloth
    var reference: Dictionary = data.reference
    var composition: Dictionary = data.composition
    if support.get("file") != "fixed_support.png" or cloth_data.get("file") != "cloth_eight_phase_rebalanced.png":
        return false
    if not _numbers(support.get("dimensions"), 2) or not _numbers(cloth_data.get("dimensions"), 2):
        return false
    if Vector2(support.dimensions[0], support.dimensions[1]) != Vector2(1254, 1254) or Vector2(cloth_data.dimensions[0], cloth_data.dimensions[1]) != Vector2(1774, 887):
        return false
    if not _numbers(support.get("registration_root"), 2) or not _finite_number(support.get("raw_to_design")) or float(support.raw_to_design) <= 0.0:
        return false
    if not _numbers(reference.get("canvas"), 2) or not _finite_number(reference.get("foot_center_x")) or not _finite_number(reference.get("foot_baseline")):
        return false
    if float(reference.canvas[0]) <= 0.0 or float(reference.canvas[1]) <= 0.0 or float(reference.foot_center_x) < 0.0 or float(reference.foot_center_x) > float(reference.canvas[0]) or float(reference.foot_baseline) < 0.0 or float(reference.foot_baseline) > float(reference.canvas[1]):
        return false
    if not _numbers(composition.get("cloth_attachment_support_source_coordinates"), 2) or not _finite_number(composition.get("cloth_source_to_support_source_scale")) or float(composition.cloth_source_to_support_source_scale) <= 0.0:
        return false
    for point in [support.registration_root, composition.cloth_attachment_support_source_coordinates]:
        if float(point[0]) < 0.0 or float(point[1]) < 0.0 or float(point[0]) > float(support.dimensions[0]) or float(point[1]) > float(support.dimensions[1]):
            return false
    if not _finite_number(cloth_data.get("fps")) or float(cloth_data.fps) != FPS or cloth_data.get("loop") != true:
        return false
    if not _numbers(cloth_data.get("selected_source_cel_order"), FRAME_COUNT):
        return false
    for index in range(FRAME_COUNT):
        if float(cloth_data.selected_source_cel_order[index]) != float(SOURCE_ORDER[index]):
            return false
    var records = cloth_data.get("frames")
    if not records is Array or records.size() != FRAME_COUNT:
        return false
    var regions: Dictionary = {}
    for index in range(FRAME_COUNT):
        var record = records[index]
        if not record is Dictionary or record.get("source_cel") != SOURCE_ORDER[index] or record.get("playback_index") != index:
            return false
        if not _numbers(record.get("region"), 4) or not _numbers(record.get("anchor"), 2):
            return false
        var values: Array = record.region
        for value in values:
            if float(value) != floorf(float(value)):
                return false
        var rect := Rect2(values[0], values[1], values[2], values[3])
        if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.end.x > float(cloth_data.dimensions[0]) or rect.end.y > float(cloth_data.dimensions[1]) or regions.has(rect):
            return false
        if float(record.anchor[0]) < 0.0 or float(record.anchor[1]) < 0.0 or float(record.anchor[0]) > rect.size.x or float(record.anchor[1]) > rect.size.y:
            return false
        regions[rect] = true
    return true


func _load_layers(data: Dictionary) -> bool:
    if not _valid_manifest(data):
        return false
    var records: Array = data.cloth.frames
    var support_texture := _load_texture(ASSET_DIR + String(data.support.file))
    var cloth_texture := _load_texture(ASSET_DIR + String(data.cloth.file))
    if support_texture == null or cloth_texture == null:
        return false
    if support_texture.get_size() != Vector2(data.support.dimensions[0], data.support.dimensions[1]) or cloth_texture.get_size() != Vector2(data.cloth.dimensions[0], data.cloth.dimensions[1]):
        return false
    for record in records:
        var region := AtlasTexture.new()
        region.atlas = cloth_texture
        region.region = Rect2(record.region[0], record.region[1], record.region[2], record.region[3])
        region.filter_clip = true
        _regions.append(region)
    cloth = Sprite2D.new()
    cloth.name = "Cloth"
    body = Sprite2D.new()
    body.name = "Support"
    body.texture = support_texture
    for layer in [cloth, body]:
        layer.centered = false
        layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        layer.use_parent_material = true
        add_child(layer) # Cloth behind the invariant support, including collar.
    return true


func _load_texture(path: String) -> Texture2D:
    if ResourceLoader.exists(path, "Texture2D"):
        return load(path) as Texture2D
    # Also permit a source checkout's focused validation before editor import.
    var source := Image.load_from_file(path)
    return null if source == null or source.is_empty() else ImageTexture.create_from_image(source)


func get_presentation_snapshot() -> Dictionary:
    return {"active": active, "elapsed": elapsed, "playback_index": playback_index,
        "source_cel": int(_data.cloth.frames[playback_index].source_cel) if _ready_to_draw else -1,
        "fps": FPS, "cycle_seconds": CYCLE_SECONDS, "real_region_count": _regions.size()}
