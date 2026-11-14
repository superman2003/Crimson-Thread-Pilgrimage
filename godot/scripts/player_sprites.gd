extends RefCounted
## Loading the player's sprite frames from the hero manifests.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func load_sprite_frames(player: Node) -> void:
    var file = FileAccess.open(player.PLAYER_MANIFEST, FileAccess.READ)
    if file == null:
        push_error("Missing player animation manifest.")
        return
    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid lumen animation manifest.")
        return

    player.use_layered_idle = false
    player.idle_foot_centers = data.get("idle_foot_center_x", player.IDLE_FOOT_CENTER_X).duplicate()
    player.grounded_pose_foot_centers = data.get("grounded_pose_foot_center_x", {}).duplicate(true)
    player.pose_thread_anchors = data.get("thread_origin_px", {}).duplicate(true)
    player.use_grounded_run = String(data.get("run_presentation", "")) == "thread_doll_v1"

    if data.has("frames"):
        player.sprite.sprite_frames = player._load_generated_hero_frames(data)
        player._play(&"idle")
        return

    var scale_value := float(data.get("sprite_scale", 0.66))
    player.sprite.scale = Vector2.ONE * scale_value
    var position_value: Array = data.get("sprite_position", [0, -50])
    player.sprite.position = Vector2(float(position_value[0]), float(position_value[1]))
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for anim in data.get("animations", []):
        var anim_name: StringName = StringName(anim.get("name", "idle"))
        if not frames.has_animation(anim_name):
            frames.add_animation(anim_name)
        frames.set_animation_speed(anim_name, float(anim.get("fps", 8)))
        frames.set_animation_loop(anim_name, bool(anim.get("loop", true)))
        for frame_path in anim.get("frames", []):
            var texture: Texture2D = player._load_texture_resource(String(frame_path))
            if texture != null:
                frames.add_frame(anim_name, texture)
    player.sprite.sprite_frames = frames
    player._play(&"idle")


static func load_generated_hero_frames(player: Node, data: Dictionary) -> SpriteFrames:
    var source_frames: Dictionary = data.get("frames", {})
    var frames := SpriteFrames.new()
    if frames.has_animation("default"):
        frames.remove_animation("default")
    var specs := [
        {"name": "idle", "fps": 1.0, "loop": false, "frames": ["idle_00"]},
        {"name": "run", "fps": 10.0, "loop": true, "frames": ["run_00", "run_01", "run_02", "run_03"]},
        {"name": "jump_start", "fps": 10.0, "loop": false, "frames": ["jump_00"]},
        {"name": "jump_loop", "fps": 8.0, "loop": true, "frames": ["jump_00"]},
        {"name": "fall", "fps": 8.0, "loop": true, "frames": ["fall_00"]},
        {"name": "land", "fps": 10.0, "loop": false, "frames": ["land_00"]},
        {"name": "dash", "fps": 12.0, "loop": false, "frames": ["dash_00"]},
        {"name": "wall_slide", "fps": 8.0, "loop": true, "frames": ["wall_cling_00"]},
        {"name": "attack_1", "fps": 14.0, "loop": false, "frames": ["attack_00", "attack_01", "attack_02", "attack_03"]},
        {"name": "attack_2", "fps": 14.0, "loop": false, "frames": ["attack_00", "skill_burst_00", "attack_02", "attack_03"]},
        {"name": "air_attack", "fps": 12.0, "loop": false, "frames": ["air_attack_00"]},
        {"name": "hook_throw", "fps": 12.0, "loop": false, "frames": ["hook_throw_00"]},
        {"name": "hurt", "fps": 8.0, "loop": false, "frames": ["hurt_00"]},
        {"name": "death", "fps": 8.0, "loop": false, "frames": ["death_00", "death_01", "death_02"]},
        {"name": "heal", "fps": 8.0, "loop": false, "frames": ["heal_00"]}
    ]
    for spec in specs:
        var animation_name := String(spec.get("name", "idle"))
        frames.add_animation(animation_name)
        frames.set_animation_speed(animation_name, float(spec.get("fps", 8.0)))
        frames.set_animation_loop(animation_name, bool(spec.get("loop", true)))
        for key in spec.get("frames", []):
            var texture: Texture2D = player._load_texture_resource(player._res_path_from_manifest(String(source_frames.get(String(key), ""))))
            if texture != null:
                frames.add_frame(animation_name, texture)
        if frames.get_frame_count(animation_name) == 0 and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
            frames.add_frame(animation_name, frames.get_frame_texture("idle", 0))
    return frames


static func res_path_from_manifest(player: Node, path: String) -> String:
    if path.begins_with("res://"):
        return path
    if path.begins_with("godot/"):
        return "res://" + path.substr("godot/".length())
    return path


static func load_texture_resource(player: Node, path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        var texture := load(path) as Texture2D
        if texture != null:
            return texture
    if not FileAccess.file_exists(path):
        return null
    var image := Image.load_from_file(path)
    if image == null:
        return null
    return ImageTexture.create_from_image(image)
