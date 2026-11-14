extends RefCounted
## Sprite, part and hurtbox construction, animation selection and the procedural pose applied to an enemy each frame.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func build_shape(actor: Node) -> void:
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = actor.body_size if actor.body_size != Vector2.ZERO else (Vector2(132, 128) if actor.is_boss else Vector2(50, 46))
    shape.shape = rectangle
    if actor.original_visual:
        shape.position=actor.hurtbox_offset
    actor.add_child(shape)


static func build_sprite(actor: Node) -> void:
    if not actor.sprite_parts.is_empty():
        actor.sprite = actor._build_part_sprite()
    elif actor.asset_path.ends_with(".json"):
        # Presentation can select another manifest after configure (original
        # source poses, skins or prefab overrides). Do not carry choreography
        # capabilities from a different drawing set into the loaded actor.
        actor.authored_combat_sequences = actor.ORIGINAL_ART.manifest(actor.asset_path).get("authored_combat_sequences", []).duplicate()
        actor.animated_sprite = AnimatedSprite2D.new()
        actor.animated_sprite.name = "EnemyAnimatedSprite"
        actor.animated_sprite.sprite_frames = actor._load_enemy_sprite_frames(actor.asset_path)
        actor.frame_fit = actor.ORIGINAL_ART.frame_fit(actor.asset_path) if actor.asset_path.contains("original_creatures") else {}
        if not actor.frame_fit.is_empty():
            actor.animated_sprite.frame_changed.connect(actor._apply_frame_fit)
            actor.animated_sprite.animation_changed.connect(actor._apply_frame_fit)
        var wing_data = actor.ORIGINAL_ART.manifest(actor.WING_FLAP_PATH)
        actor.wing_flap = wing_data.get("creatures", {}).get(actor.kind, {}) if actor.asset_path.get_file() == String(wing_data.get("layer", "")) and actor.asset_path.get_base_dir().get_file() == actor.kind else {}
        if not actor.wing_flap.is_empty():
            actor.animated_sprite.frame_changed.connect(actor._apply_wing_flap)
            actor.animated_sprite.animation_changed.connect(actor._apply_wing_flap)
        actor.animated_sprite.animation_finished.connect(actor._on_motion_animation_finished)
        actor.animated_sprite.play("idle")
        actor.sprite = actor.animated_sprite
    else:
        var static_sprite := Sprite2D.new()
        static_sprite.name = "EnemySprite"
        static_sprite.texture = actor._load_texture_resource(actor.asset_path)
        if actor.sprite_region.size() >= 4:
            static_sprite.region_enabled = true
            static_sprite.region_rect = Rect2(float(actor.sprite_region[0]), float(actor.sprite_region[1]), float(actor.sprite_region[2]), float(actor.sprite_region[3]))
        actor.sprite = static_sprite
    actor.sprite.position = (Vector2(0, -30) if actor.is_boss else Vector2(0, -18)) + actor.visual_offset
    var scale_value = actor.visual_scale if actor.visual_scale > 0.0 else (1.45 if actor.is_boss else 0.78)
    actor.sprite.scale = Vector2(scale_value, scale_value)
    actor.sprite.modulate = actor.visual_modulate
    actor.sprite_base_position = actor.sprite.position
    actor.sprite_base_scale = actor.sprite.scale
    actor._apply_sprite_region("idle")
    actor.add_child(actor.sprite)
    actor._attach_flash_materials()
    actor._apply_frame_fit()
    actor._apply_wing_flap()


static func apply_frame_fit(actor: Node) -> void:
    if actor.frame_fit.is_empty() or actor.animated_sprite == null or actor.animated_sprite.sprite_frames == null:
        return
    var material = actor.animated_sprite.material as ShaderMaterial
    if material == null:
        return
    var fit := 1.0
    var pivot := Vector2.ZERO
    var animation = actor.animated_sprite.animation
    var rows: Array = actor.frame_fit.get(String(animation), [])
    var index = actor.animated_sprite.frame
    if index < rows.size() and rows.size() == actor.animated_sprite.sprite_frames.get_frame_count(animation):
        var row: Array = rows[index]
        fit = float(row[0])
        pivot = Vector2(-float(row[1]) if actor.animated_sprite.flip_h else float(row[1]), float(row[2]))
    if not actor.motion_transitions.active.is_empty() and actor.motion_transitions.has_start_texture and index == 0:
        fit = actor.motion_transitions.start_fit_scale
        pivot = actor.motion_transitions.start_fit_pivot
    if fit == actor.frame_fit_scale and pivot == actor.frame_fit_pivot:
        return
    actor.frame_fit_scale = fit
    actor.frame_fit_pivot = pivot
    material.set_shader_parameter("body_fit", fit)
    material.set_shader_parameter("body_fit_pivot", pivot)


static func apply_wing_flap(actor: Node) -> void:
    if actor.wing_flap.is_empty() or actor.animated_sprite == null or actor.animated_sprite.sprite_frames == null:
        return
    var material = actor.animated_sprite.material as ShaderMaterial
    if material == null:
        return
    var animation = actor.animated_sprite.animation
    var wing: Dictionary = actor.wing_flap.get(String(animation), {})
    var atlas: AtlasTexture = null
    if not wing.is_empty() and actor.animated_sprite.frame < actor.animated_sprite.sprite_frames.get_frame_count(animation):
        atlas = actor.animated_sprite.sprite_frames.get_frame_texture(animation, actor.animated_sprite.frame) as AtlasTexture
    if atlas == null or (not actor.motion_transitions.active.is_empty() and actor.motion_transitions.has_start_texture):
        if actor.wing_flap_active:
            actor.wing_flap_active = false
            material.set_shader_parameter("wing_swing", 0.0)
        return
    if not actor.wing_flap_active or material.get_shader_parameter("wing_hinge") != actor._vec2(wing.hinge):
        material.set_shader_parameter("wing_swing", float(wing.swing))
        material.set_shader_parameter("wing_center", float(wing.get("center", 0.5)))
        material.set_shader_parameter("wing_shorten", float(wing.get("shorten", 1.0)))
        material.set_shader_parameter("wing_flex", float(wing.get("flex", 0.0)))
        material.set_shader_parameter("wing_hinge", actor._vec2(wing.hinge))
        material.set_shader_parameter("wing_sector", actor._vec2(wing.sector))
        material.set_shader_parameter("wing_radius", Vector3(float(wing.radius[0]), float(wing.radius[1]), float(wing.radius[2])))
        actor.wing_flap_active = true
    material.set_shader_parameter("frame_origin", atlas.region.position - atlas.margin.position)
    material.set_shader_parameter("frame_region", Vector4(atlas.region.position.x, atlas.region.position.y, atlas.region.size.x, atlas.region.size.y))


static func advance_wing_flap(actor: Node, delta: float) -> void:
    if not actor.wing_flap_active or actor.combat_visuals_paused or not actor.world_residency_active() or actor.dying or actor.is_queued_for_deletion():
        return
    actor.wing_flap_phase = fposmod(actor.wing_flap_phase + delta * TAU * float(actor.wing_flap.get("hz", 6.0)), TAU)
    (actor.animated_sprite.material as ShaderMaterial).set_shader_parameter("wing_phase", actor.wing_flap_phase)


static func attach_flash_materials(actor: Node) -> void:
    actor.flash_materials.clear()
    var targets: Array = []
    if actor.sprite is Sprite2D or actor.sprite is AnimatedSprite2D:
        targets.append(actor.sprite)
    else:
        for child in actor.sprite.get_children():
            if child is Sprite2D or child is AnimatedSprite2D:
                targets.append(child)
    for target_value in targets:
        var target := target_value as CanvasItem
        var material := ShaderMaterial.new()
        material.shader = actor.HIT_FLASH_SHADER
        target.material = material
        actor.flash_materials.append(material)


static func build_part_sprite(actor: Node) -> Node2D:
    var root := Node2D.new()
    root.name = "EnemyPartSprite"
    for part_value in actor.sprite_parts:
        if not (part_value is Dictionary):
            continue
        var part: Dictionary = part_value
        var path := String(part.get("path", ""))
        var texture: Texture2D = actor._load_texture_resource(path)
        if texture == null:
            continue
        var part_sprite := Sprite2D.new()
        part_sprite.name = String(part.get("name", "MonsterPart"))
        part_sprite.texture = texture
        part_sprite.position = actor._vec2(part.get("offset", [0, 0]))
        var scale_value := float(part.get("scale", 1.0))
        part_sprite.scale = Vector2(scale_value, scale_value)
        part_sprite.rotation_degrees = float(part.get("rotation", 0.0))
        part_sprite.z_index = int(part.get("z", 0))
        if part.has("modulate"):
            part_sprite.modulate = Color.html("#" + String(part.get("modulate", "ffffff")))
        root.add_child(part_sprite)
    return root


static func load_enemy_sprite_frames(actor: Node, manifest_path: String) -> SpriteFrames:
    if manifest_path.contains("original_creatures"):
        return actor.ORIGINAL_ART.frames(manifest_path)
    var file := FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        return null
    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        return null
    var frames := SpriteFrames.new()
    if frames.has_animation("default"):
        frames.remove_animation("default")
    for animation in data.get("animations", []):
        if typeof(animation) != TYPE_DICTIONARY:
            continue
        var animation_name := String(animation.get("name", "idle"))
        frames.add_animation(animation_name)
        frames.set_animation_speed(animation_name, float(animation.get("fps", 8.0)))
        frames.set_animation_loop(animation_name, bool(animation.get("loop", true)))
        for frame_path in animation.get("frames", []):
            var texture: Texture2D = actor._load_texture_resource(String(frame_path))
            if texture != null:
                frames.add_frame(animation_name, texture)
    return frames


static func vec2(actor: Node, value: Variant) -> Vector2:
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return Vector2.ZERO
    return Vector2(float(value[0]), float(value[1]))


static func vec2_or(actor: Node, value: Variant, fallback: Vector2) -> Vector2:
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return fallback
    return Vector2(float(value[0]), float(value[1]))


static func load_texture_resource(actor: Node, path: String) -> Texture2D:
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


static func set_sprite_flip(actor: Node, flip_value: bool) -> void:
    actor.requested_sprite_flip = flip_value
    actor._apply_sprite_flip()


static func set_enemy_animation(actor: Node, animation_name: String, restart: bool = false) -> void:
    if actor.motion_transitions.request_loop(actor,animation_name,restart):return
    var next_animation: String = actor._resolve_directional_animation(animation_name)
    if actor.animated_sprite != null and actor.animated_sprite.sprite_frames != null and not actor.animated_sprite.sprite_frames.has_animation(next_animation):
        next_animation = "idle"
    actor.current_animation_has_explicit_direction = actor._is_directional_animation_name(next_animation) and actor._has_enemy_animation(next_animation)
    actor._apply_sprite_region(next_animation)
    actor._apply_sprite_flip(animation_name in ["idle","walk"] and not restart)
    if actor.motion_transitions.request_loop(actor,animation_name,restart):return
    if actor.animated_sprite == null or actor.animated_sprite.sprite_frames == null:
        return
    if animation_name in ["idle", "walk", "phase"]:
        actor.animated_sprite.speed_scale = 1.0
    if restart:
        actor.animated_sprite.stop()
    var changed = actor.animated_sprite.animation != next_animation or restart
    var resume_loop = animation_name in ["idle", "walk"] and not actor.animated_sprite.is_playing() and not actor.combat_visuals_paused
    if changed:
        actor.pose_holding_charge = false
        actor.pose_travel_stretch = false
        actor.pose_feedback_time = 0.0
        if actor.pose_feedback_was_active:
            actor.sprite.position = actor.sprite_base_position
            actor.sprite.scale = actor.sprite_base_scale
            actor.pose_feedback_was_active = false
    if changed or resume_loop:
        actor.animated_sprite.play(next_animation)


static func fit_animation_duration(actor: Node, duration: float, phase: String = "") -> void:
    if actor.animated_sprite == null or actor.animated_sprite.sprite_frames == null:
        return
    var frames = actor.animated_sprite.sprite_frames
    var animation_name = actor.animated_sprite.animation
    var authored_name := String(animation_name).trim_suffix("_left").trim_suffix("_right")
    if phase in ["windup", "recover"] and authored_name not in actor.authored_combat_sequences:
        if actor.animated_sprite.sprite_frames != actor.pose_owned_frames:
            actor.pose_source_frames = actor.animated_sprite.sprite_frames
            actor.pose_owned_frames = actor.pose_source_frames.duplicate(false) as SpriteFrames
            actor.animated_sprite.sprite_frames = actor.pose_owned_frames
            actor.animated_sprite.play(animation_name)
        frames = actor.pose_owned_frames
        var weights = actor.POSE_TIMING.weights(frames.get_frame_count(animation_name), duration, phase, frames.get_animation_speed(animation_name))
        for index in weights.size():
            frames.set_frame(animation_name, index, actor.pose_source_frames.get_frame_texture(animation_name, index), weights[index])
    elif frames == actor.pose_owned_frames and actor.pose_source_frames != null:
        for index in frames.get_frame_count(animation_name):
            frames.set_frame(animation_name, index, actor.pose_source_frames.get_frame_texture(animation_name, index), actor.pose_source_frames.get_frame_duration(animation_name, index))
    var natural: float = actor._animation_seconds(String(actor.animated_sprite.animation))
    actor.animated_sprite.speed_scale=natural/maxf(.01,duration) if natural>0.0 else 1.0


static func animation_seconds(actor: Node, name: String) -> float:
    if actor.animated_sprite==null or actor.animated_sprite.sprite_frames==null:return 0.0
    var frames = actor.animated_sprite.sprite_frames
    var resolved: String = actor._resolve_directional_animation(name)
    if not frames.has_animation(resolved):return 0.0
    var weight:=0.0
    for index in frames.get_frame_count(resolved):weight+=frames.get_frame_duration(resolved,index)
    return weight/maxf(.01,frames.get_animation_speed(resolved))


static func resolve_directional_animation(actor: Node, animation_name: String) -> String:
    if actor._is_directional_animation_name(animation_name):
        return animation_name
    var direction_suffix = "_left" if (actor.attack_direction if actor._is_attack_state() else actor.direction) < 0 else "_right"
    var directional_animation = animation_name + direction_suffix
    if actor._has_enemy_animation(directional_animation):
        return directional_animation
    return animation_name


static func attack_animation_base(actor: Node, command: Dictionary) -> String:
    var own := String(command.get("id", ""))
    if not own.is_empty() and (actor._has_enemy_animation(own) or actor._has_enemy_animation(own + "_windup")):
        return own
    return String(command.get("animation", "attack"))


static func advance_pose_loop(actor: Node) -> void:
    if actor.pose_loop_animation.is_empty() or actor.state_timer > actor.pose_loop_at+.000001:
        return
    var loop_name = actor.pose_loop_animation
    actor.pose_loop_animation = ""
    if actor.pose_loop_role == "windup" and actor.animated_sprite != null:
        var resolved: String = actor._resolve_directional_animation(loop_name)
        if actor.animated_sprite.sprite_frames.get_frame_count(resolved) <= 2:
            # Keep exactly the final wind-up drawing, not a different pair of
            # independently drawn charge silhouettes flashing back and forth.
            actor.animated_sprite.pause()
            actor.animated_sprite.set_frame_and_progress(actor.animated_sprite.sprite_frames.get_frame_count(actor.animated_sprite.animation) - 1, 1.0)
            actor.pose_holding_charge = true
            return
    actor._set_enemy_animation(loop_name, true)
    if actor.animated_sprite != null:
        actor.animated_sprite.speed_scale = 1.0
        if actor.pose_loop_fit > 0.0:
            actor._fit_animation_duration(actor.pose_loop_fit, "recover")
            # Seek past time already spent beyond the bridge boundary. The
            # shared recovery must still finish at the gameplay deadline.
            var frames = actor.animated_sprite.sprite_frames
            var cursor = actor.POSE_TIMING.cursor(frames, actor.animated_sprite.animation, actor.animated_sprite.speed_scale, maxf(0.0, actor.pose_loop_at - actor.state_timer))
            actor.animated_sprite.set_frame_and_progress(int(cursor.x), cursor.y)
        elif actor.pose_loop_role == "active":
            actor.pose_travel_stretch = actor.animated_sprite.sprite_frames.get_frame_count(actor.animated_sprite.animation) <= 2


static func has_enemy_animation(actor: Node, animation_name: String) -> bool:
    if actor.animated_sprite != null and actor.animated_sprite.sprite_frames != null and actor.animated_sprite.sprite_frames.has_animation(animation_name):
        return true
    return actor.sprite_regions.has(animation_name)


static func is_directional_animation_name(actor: Node, animation_name: String) -> bool:
    return animation_name.ends_with("_left") or animation_name.ends_with("_right")


static func apply_sprite_flip(actor: Node, allow_motion: bool = true) -> void:
    if actor.sprite == null:
        return
    if actor.current_animation_has_explicit_direction:
        actor.sprite.set("flip_h", false)
        actor._apply_frame_fit()
        return
    var wanted = not actor.requested_sprite_flip if actor.sprite_faces_left else actor.requested_sprite_flip
    if not actor.motion_transitions.request_flip(actor,wanted,allow_motion):
        actor.sprite.set("flip_h",wanted)
    actor._apply_frame_fit()


static func on_motion_animation_finished(actor: Node) -> void:
    actor.motion_transitions.completed(actor)
    actor._apply_frame_fit()


static func apply_sprite_region(actor: Node, animation_name: String) -> void:
    if actor.sprite == null or not (actor.sprite is Sprite2D):
        return
    var sprite_2d = actor.sprite as Sprite2D
    var region_value: Array = []
    if actor.sprite_regions.has(animation_name):
        region_value = actor.sprite_regions.get(animation_name, [])
    elif animation_name == "walk" and actor.sprite_regions.has("move"):
        region_value = actor.sprite_regions.get("move", [])
    elif animation_name == "hurt" and actor.sprite_regions.has("hit"):
        region_value = actor.sprite_regions.get("hit", [])
    elif animation_name == "death" and actor.sprite_regions.has("dead"):
        region_value = actor.sprite_regions.get("dead", [])
    elif actor.sprite_regions.has("idle"):
        region_value = actor.sprite_regions.get("idle", [])
    else:
        region_value = actor.sprite_region
    if region_value.size() < 4:
        return
    sprite_2d.region_enabled = true
    sprite_2d.region_rect = Rect2(float(region_value[0]), float(region_value[1]), float(region_value[2]), float(region_value[3]))


static func pose_sprite(actor: Node, pose_name: String, command: Dictionary = {}) -> void:
    if actor.sprite == null:
        return
    if actor.original_visual:
        actor.pose_holding_charge = false
        actor.pose_travel_stretch = false
        actor.pose_feedback_time = 0.0
        actor.pose_loop_role = pose_name
        actor.pose_visual_clock = 0.0
        actor.sprite.position=actor.sprite_base_position
        actor.sprite.scale=actor.sprite_base_scale
        actor.sprite.rotation=0
        actor.sprite.modulate.a = .24 if pose_name=="windup" and bool(command.get("burrow",false)) else 1.0
        var animation_name := pose_name
        var requested: String = actor._attack_animation_base(command)
        var loop_name := ""
        if pose_name=="windup":
            animation_name=requested+"_windup" if actor._has_enemy_animation(requested+"_windup") else "windup"
            loop_name=requested+"_charge" if animation_name!="windup" else "charge"
        elif pose_name=="active":
            animation_name=requested if actor._has_enemy_animation(requested) else "attack"
            loop_name=requested+"_travel" if animation_name!="attack" else "travel"
        elif pose_name=="recover":
            animation_name=requested+"_recover" if actor._has_enemy_animation(requested+"_recover") else ("recover" if actor._has_enemy_animation("recover") else "idle")
            # A move whose last strike cel is far from the shared recovery draws a
            # short bridge into it; a bridge already ending upright settles into idle.
            if animation_name=="recover" and actor._has_enemy_animation(requested+"_bridge"):
                animation_name=requested+"_bridge"
                loop_name="recover"
            elif animation_name=="recover" and actor._has_enemy_animation(requested+"_settle"):
                animation_name=requested+"_settle"
                loop_name="idle"
        if animation_name in actor.authored_combat_sequences:loop_name=""
        actor.pose_loop_animation = ""
        actor.pose_loop_fit = 0.0
        actor._set_enemy_animation(animation_name, pose_name in ["windup", "active", "recover", "hurt", "death"])
        if actor.animated_sprite!=null:
            actor.animated_sprite.speed_scale=1.0
            if pose_name in ["windup","active","recover"] and animation_name != "idle":
                var duration := float(command.get(pose_name, .3))
                var lead := float(actor.POSE_LOOP_LEAD.get(pose_name, 0.0))
                if pose_name=="recover" and loop_name=="recover" and actor._has_enemy_animation(loop_name):
                    var bridge_seconds: float = actor._animation_seconds(animation_name)
                    var settle_seconds: float = actor._animation_seconds(loop_name)
                    if bridge_seconds+settle_seconds>0.0:
                        lead=clampf(duration*bridge_seconds/(bridge_seconds+settle_seconds),.04,maxf(.04,duration-.04))
                if not loop_name.is_empty() and actor._has_enemy_animation(loop_name) and duration > lead + 0.12:
                    actor._fit_animation_duration(lead, pose_name)
                    actor.pose_loop_animation = loop_name
                    actor.pose_loop_at = duration - lead
                    actor.pose_loop_fit = duration - lead if loop_name == "recover" else 0.0
                else:
                    actor._fit_animation_duration(duration, pose_name)
        return
    actor._apply_sprite_region("attack" if pose_name == "windup" or pose_name == "active" else pose_name)
    var attack_type := String(command.get("type", "melee"))
    var pose_direction = actor.attack_direction if pose_name == "windup" or pose_name == "active" or pose_name == "recover" else actor.direction
    var lunge_bias := 10.0 if attack_type == "lunge" or attack_type == "melee" else 0.0
    var slam_bias := 10.0 if attack_type == "aoe" else 0.0
    var shock_bias := 14.0 if attack_type == "shockwave" else 0.0
    var power := float(command.get("pose_power", 1.25 if actor.is_boss else 1.0))
    var target_position = actor.sprite_base_position
    var target_scale = actor.sprite_base_scale
    var target_rotation := 0.0
    var time := 0.10
    if pose_name == "windup":
        target_position += actor._pose_offset(command, "windup_offset", Vector2(-pose_direction * 12.0 * power, -7.0 - slam_bias * 0.45))
        target_scale = actor.sprite_base_scale * actor._pose_scale(command, "windup_scale", Vector2(1.05 + 0.02 * power, 0.94))
        target_rotation = deg_to_rad(float(command.get("windup_rotation", -pose_direction * (6.0 + shock_bias * 0.30) * power)))
        time = float(command.get("windup", 0.22)) * 0.45
    elif pose_name == "active":
        target_position += actor._pose_offset(command, "active_offset", Vector2(pose_direction * (22.0 + lunge_bias + shock_bias) * power, slam_bias + 2.0))
        target_scale = actor.sprite_base_scale * actor._pose_scale(command, "active_scale", Vector2(1.16 + 0.03 * power, 0.86))
        target_rotation = deg_to_rad(float(command.get("active_rotation", pose_direction * (11.0 + shock_bias * 0.24) * power)))
        time = 0.08
    elif pose_name == "recover":
        target_position += actor._pose_offset(command, "recover_offset", Vector2(-pose_direction * 8.0 * power, 3.0))
        target_scale = actor.sprite_base_scale * actor._pose_scale(command, "recover_scale", Vector2(0.96, 1.04))
        target_rotation = deg_to_rad(float(command.get("recover_rotation", -pose_direction * 4.0 * power)))
        time = 0.12
    elif pose_name == "hurt":
        target_position += Vector2(-pose_direction * 8.0, -2.0)
        target_rotation = deg_to_rad(-pose_direction * 8.0)
        time = 0.06
    else:
        time = 0.12
    var tween: Tween = actor._combat_tween()
    tween.set_parallel(true)
    tween.tween_property(actor.sprite, "position", target_position, maxf(0.04, time)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(actor.sprite, "scale", target_scale, maxf(0.04, time)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(actor.sprite, "rotation", target_rotation, maxf(0.04, time)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func pose_offset(actor: Node, command: Dictionary, key: String, fallback: Vector2) -> Vector2:
    if not command.has(key):
        return fallback
    var value = command.get(key)
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return fallback
    var x := float(value[0])
    var y := float(value[1])
    if bool(command.get("mirror_pose_offset", true)):
        x *= float(actor.attack_direction)
    return Vector2(x, y)


static func pose_scale(actor: Node, command: Dictionary, key: String, fallback: Vector2) -> Vector2:
    if not command.has(key):
        return fallback
    var value = command.get(key)
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return fallback
    return Vector2(float(value[0]), float(value[1]))
