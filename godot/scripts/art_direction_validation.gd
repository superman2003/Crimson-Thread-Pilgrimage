extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    _assert(scene.player != null, "player exists")
    var player_sprite := scene.player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
    _assert(player_sprite != null and player_sprite.sprite_frames != null, "player sprite frames loaded")
    var player_debug: Dictionary = scene.player.get_player_debug_state()
    _assert(String(player_debug.get("player_manifest", "")).contains("generated_hero_v2"), "image2 generated hero manifest is active")
    _assert(player_sprite.sprite_frames.has_animation("dash"), "generated hero dash animation loaded")
    _assert(player_sprite.sprite_frames.has_animation("hook_throw"), "generated hero hook animation loaded")
    _assert(player_sprite.sprite_frames.get_frame_count("idle") == 1, "generated hero idle is a stable single frame")
    _assert(_animation_height(player_sprite, "run") == _animation_height(player_sprite, "idle"), "idle and run use matching frame height")
    _assert(_animation_bottom(player_sprite, "run") == _animation_bottom(player_sprite, "idle"), "idle and run share the same foot baseline")
    _assert(player_sprite.scale.x <= 0.70 and player_sprite.scale.y <= 0.70, "192px hero frames are scaled for platform readability")

    var start_ground := scene.get_node_or_null("start_ground")
    _assert(start_ground != null, "start platform exists")
    _assert(_has_texture_node(start_ground, "Material"), "platform uses public CH01 tile")
    _assert(_count_textured_sprites(start_ground) >= 4, "wide platform repeats public CH01 tile sprites")

    scene._toggle_map()
    await process_frame
    _assert(scene.map_panel.visible, "map overlay opens")
    _assert(scene.map_draw_root.get_node_or_null("MapRouteLine") != null, "map route line is drawn")
    _assert(_count_texture_rects(scene.map_draw_root) >= 7, "map rooms use public CH01 texture overlays")

    print("ART_DIRECTION_VALIDATION_PASS player=generated_hero_v2 platforms=public_ch01_tiles map=public_ch01_textures")
    quit(0)


func _animation_height(sprite: AnimatedSprite2D, animation: String) -> int:
    var box := _animation_bbox(sprite, animation)
    return int(box.size.y)


func _animation_bottom(sprite: AnimatedSprite2D, animation: String) -> int:
    var box := _animation_bbox(sprite, animation)
    return int(box.position.y + box.size.y - 1.0)


func _animation_bbox(sprite: AnimatedSprite2D, animation: String) -> Rect2:
    var frames := sprite.sprite_frames
    var merged := Rect2()
    var has_pixels := false
    for frame_index in range(frames.get_frame_count(animation)):
        var texture := frames.get_frame_texture(animation, frame_index)
        var image := texture.get_image()
        var box := _image_bbox(image)
        if box.size.x <= 0.0 or box.size.y <= 0.0:
            continue
        if not has_pixels:
            merged = box
            has_pixels = true
        else:
            merged = merged.merge(box)
    return merged


func _image_bbox(image: Image) -> Rect2:
    var min_x := image.get_width()
    var min_y := image.get_height()
    var max_x := -1
    var max_y := -1
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            if image.get_pixel(x, y).a <= 0.0:
                continue
            min_x = mini(min_x, x)
            min_y = mini(min_y, y)
            max_x = maxi(max_x, x)
            max_y = maxi(max_y, y)
    if max_x < min_x or max_y < min_y:
        return Rect2()
    return Rect2(float(min_x), float(min_y), float(max_x - min_x + 1), float(max_y - min_y + 1))


func _has_texture_node(parent: Node, child_name: String) -> bool:
    var sprite := parent.get_node_or_null(child_name) as Sprite2D
    return sprite != null and sprite.texture != null


func _count_named_children(parent: Node, child_name: String) -> int:
    var count := 0
    for child in parent.get_children():
        if String(child.name) == child_name:
            count += 1
    return count


func _count_children_with_prefix(parent: Node, child_prefix: String) -> int:
    var count := 0
    for child in parent.get_children():
        if String(child.name).begins_with(child_prefix):
            count += 1
    return count


func _count_textured_sprites(parent: Node) -> int:
    var count := 0
    for child in parent.get_children():
        var sprite := child as Sprite2D
        if sprite != null and sprite.texture != null:
            count += 1
    return count


func _count_texture_rects(parent: Node) -> int:
    var count := 0
    for child in parent.get_children():
        var texture_rect := child as TextureRect
        if texture_rect != null and texture_rect.texture != null:
            count += 1
    return count


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    quit(1)
