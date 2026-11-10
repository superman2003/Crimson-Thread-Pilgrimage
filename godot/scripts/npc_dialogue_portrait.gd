extends TextureRect
## Show the same authored acting in the portrait, using one fixed crop per NPC.
var _speaker: WeakRef
var _portraits: Dictionary = {}
var _fallback: Texture2D

func bind_speaker(area: Area2D, fallback: Texture2D) -> void:
    var sprite := area.get_node_or_null("FriendlyFamilySprite") as AnimatedSprite2D if is_instance_valid(area) else null
    var previous: Node = _speaker.get_ref() if _speaker != null else null
    if sprite != previous: _portraits.clear()
    _speaker = weakref(sprite) if is_instance_valid(sprite) else null
    _fallback = fallback
    texture = fallback
    _refresh()

func release_speaker() -> void:
    _speaker = null
    _portraits.clear()
    _fallback = null
    texture = null

func _process(_delta: float) -> void:
    if is_visible_in_tree(): _refresh()

func _refresh() -> void:
    var sprite: AnimatedSprite2D = _speaker.get_ref() as AnimatedSprite2D if _speaker != null else null
    if not is_instance_valid(sprite) or not sprite.is_inside_tree() or sprite.is_queued_for_deletion():
        texture = _fallback
        return
    var frames := sprite.sprite_frames
    if frames == null or not frames.has_animation(sprite.animation) or frames.get_frame_count(sprite.animation) <= sprite.frame: return
    var source := frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
    if source == null: return
    var key := source.get_instance_id()
    if not _portraits.has(key):
        var canvas := source.get_size()
        # Crop the upper body around the rig's fixed centre, never around the
        # changing ink bounds. Every pose keeps the same portrait magnification.
        var width := minf(canvas.x, roundf(canvas.y * 1.05))
        var crop := Rect2(Vector2(roundf((canvas.x-width)*0.5), 0), Vector2(width, roundf(canvas.y*0.72)))
        var ink := Rect2(source.margin.position, source.region.size)
        var visible := ink.intersection(crop)
        if not visible.has_area(): return
        var portrait := AtlasTexture.new()
        portrait.atlas = source.atlas
        portrait.region = Rect2(source.region.position+visible.position-ink.position, visible.size)
        portrait.margin = Rect2(visible.position-crop.position, crop.size-visible.size)
        portrait.filter_clip = true
        _portraits[key] = portrait
    texture = _portraits[key]
