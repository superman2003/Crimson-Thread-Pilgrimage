extends SceneTree
## Narrow acceptance probe: production loader, production actor, unchanged artwork.
## Run under real GL with --fixed-fps 60. Optional output: ENEMY_ATLAS_VALIDATION_DIR.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const KINDS := ["gear_sentinel", "page_duelist"]
const CANVAS := Vector2i(640, 360)
const ORIGIN := Vector2(320, 230)
const PAD := Vector2(192, 16)
var checks := 0
var failures := 0
var output_dir := ""
var summary: Dictionary = {"static_frames": [], "playbacks": [], "import_processing": []}

class Stage extends Node2D:
    var chapter_terrain: Node = null

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + label)

func _json(path: String) -> Dictionary:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    _check(value is Dictionary, "JSON dictionary: " + path)
    return value if value is Dictionary else {}

func _hash(data: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(data)
    return context.finish().hex_encode()

func _vec(value: Array) -> Vector2:
    return Vector2(float(value[0]), float(value[1]))

func _run() -> void:
    output_dir = OS.get_environment("ENEMY_ATLAS_VALIDATION_DIR")
    if output_dir.is_empty():
        output_dir = ProjectSettings.globalize_path("user://enemy_atlas_integrity")
    DirAccess.make_dir_recursive_absolute(output_dir.path_join("static"))
    root.size = CANVAS
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color(0.055, 0.065, 0.085, 1.0))
    _check(DisplayServer.get_name() != "headless", "real display is required")
    _check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "real compatibility renderer is required")
    _check(is_equal_approx(Engine.time_scale, 1.0), "normal game time scale")
    _check(Engine.physics_ticks_per_second == 60, "authored 60 Hz physics")
    summary["renderer"] = RenderingServer.get_video_adapter_name()
    summary["rendering_method"] = RenderingServer.get_current_rendering_method()
    summary["viewport"] = [CANVAS.x, CANVAS.y]
    summary["new_drawings"] = 0
    summary["interpolated_asset_frames"] = 0
    for kind in KINDS:
        await _validate_kind(kind)
    var file := FileAccess.open(output_dir.path_join("runtime-summary.json"), FileAccess.WRITE)
    _check(file != null, "summary opens")
    if file != null:
        summary["checks"] = checks
        summary["failures"] = failures
        file.store_string(JSON.stringify(summary, "  ") + "\n")
        file.close()
    print("ENEMY_ATLAS_INTEGRITY checks=%d failures=%d static_frames=%d playbacks=%d" % [checks, failures, summary.static_frames.size(), summary.playbacks.size()])
    quit(0 if failures == 0 else 1)

func _new_enemy(stage: Node2D, kind: String):
    var enemy = ENEMY.new()
    enemy.configure({"id": "atlas_integrity_" + kind, "kind": kind, "hp": 10}, "")
    # This probe protects the immutable, repaired source poses. Expanded motion
    # has a separate production acceptance suite and must not replace this check.
    var source_path := "res://assets/sprites/original_creatures/" + kind + "/manifest.json"
    var source := _json(source_path)
    enemy.asset_path = source_path
    enemy.visual_scale = float(source.visual_scale)
    enemy.visual_offset = _vec(source.visual_offset)
    enemy.position = ORIGIN
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.animated_sprite.pause()
    return enemy

func _validate_kind(kind: String) -> void:
    var prefix := "res://assets/sprites/original_creatures/" + kind + "/"
    var manifest := _json(prefix + "manifest.json")
    var old := _json(prefix + "attack_source_manifest.json")
    var integrity := _json(prefix + "attack_integrity.json")
    var stage := Stage.new()
    root.add_child(stage)
    var enemy = _new_enemy(stage, kind)
    var sprite: AnimatedSprite2D = enemy.animated_sprite
    var frames: SpriteFrames = sprite.sprite_frames
    var old_frames: SpriteFrames = ART.frames(prefix + "attack_source_manifest.json")
    _check(enemy.original_visual, kind + " uses original production actor path")
    _check(enemy.asset_path == prefix + "manifest.json", kind + " uses new manifest")
    _check(sprite.position.is_equal_approx(Vector2(0, -18) + _vec(old.visual_offset)), kind + " original sprite offset")
    _check(sprite.scale.is_equal_approx(Vector2.ONE * float(old.visual_scale)), kind + " original sprite scale")
    _check(_vec(manifest.canvas) == _vec(old.canvas) + PAD * 2, kind + " symmetric expanded canvas")
    _validate_import(ART.texture(prefix + "atlas.png"), prefix + "atlas.png", kind + "-original-atlas")
    var unchanged_count := 0
    for animation_index in range(manifest.animations.size()):
        var animation: Dictionary = manifest.animations[animation_index]
        var old_animation: Dictionary = old.animations[animation_index]
        var name := String(animation.name)
        _check(frames.get_frame_count(name) == old_frames.get_frame_count(name), kind + " " + name + " frame count")
        _check(frames.get_animation_speed(name) == old_frames.get_animation_speed(name), kind + " " + name + " original fps")
        _check(frames.get_animation_loop(name) == old_frames.get_animation_loop(name), kind + " " + name + " original loop")
        for index in range(animation.frames.size()):
            var texture: AtlasTexture = frames.get_frame_texture(name, index) as AtlasTexture
            var old_texture: AtlasTexture = old_frames.get_frame_texture(name, index) as AtlasTexture
            _check(texture != null and texture.atlas != null, kind + " " + name + " loaded atlas")
            if texture == null or texture.atlas == null:
                continue
            _check(texture.get_size() == _vec(manifest.canvas), kind + " " + name + " runtime canvas")
            _check(texture.filter_clip, kind + " " + name + " filter clipping contract")
            _check(texture.region == ART.rect(animation.frames[index].region), kind + " " + name + " region loaded")
            _check(texture.margin == ART.rect(animation.frames[index].margin), kind + " " + name + " margin loaded")
            if name == "attack":
                _check(texture.margin == Rect2() and texture.region == Rect2(Vector2.ZERO, _vec(manifest.canvas)), kind + " isolated full canvas")
                _check(texture.atlas.resource_path == String(animation.frames[index].atlas), kind + " isolated texture loaded through ResourceLoader")
                _validate_import(texture.atlas, String(animation.frames[index].atlas), kind + "-attack-" + str(index))
            else:
                unchanged_count += 1
                _check(texture.atlas == old_texture.atlas and texture.region == old_texture.region, kind + " unchanged source/region " + name)
            for facing in [-1, 1]:
                var label := "%s-%s-%d-%s" % [kind, name, index, "left" if facing < 0 else "right"]
                enemy.direction = facing
                enemy.attack_direction = facing
                enemy._set_sprite_flip(facing < 0)
                _check(sprite.flip_h == (facing < 0), label + " actual flip_h")
                var old_frame: Dictionary = old_animation.frames[index]
                var source_anchor := Vector2(float(old_frame.region[0]), float(old_frame.region[1]))
                var old_local := source_anchor - ART.rect(old_frame.region).position + old_texture.margin.position - old_texture.get_size() * 0.5
                var new_local: Vector2
                if name == "attack":
                    new_local = source_anchor + _vec(integrity.frames[index].source_to_output_translation_xy) - texture.get_size() * 0.5
                else:
                    new_local = source_anchor - texture.region.position + texture.margin.position - texture.get_size() * 0.5
                old_local.x *= facing
                new_local.x *= facing
                _check(sprite.to_global(new_local).is_equal_approx(sprite.to_global(old_local)), label + " runtime source registration")
                sprite.sprite_frames = old_frames
                _show_frame(sprite, name, index)
                var before := await _capture()
                sprite.sprite_frames = frames
                _show_frame(sprite, name, index)
                var after := await _capture()
                var record: Dictionary = {"id": label, "kind": kind, "animation": name, "frame": index, "facing": facing, "before_rgba_sha256": _hash(before.get_data()), "after_rgba_sha256": _hash(after.get_data())}
                var static_path := output_dir.path_join("static/" + label)
                if name != "attack":
                    var identical := before.get_data() == after.get_data()
                    _check(identical, label + " exact production GPU pixels unchanged")
                    record["unchanged_gpu_rgba"] = identical
                else:
                    _check(before.save_png(static_path + "-before.png") == OK, label + " before image saved")
                    # Direct imported texture bypasses AtlasTexture region/margin.
                    # Source/import RGBA is checked above. No offline resampling/redraw.
                    var direct := Sprite2D.new()
                    direct.texture = texture.atlas
                    direct.position = sprite.position
                    direct.scale = sprite.scale
                    direct.material = sprite.material
                    direct.flip_h = sprite.flip_h
                    enemy.add_child(direct)
                    sprite.hide()
                    var expected := await _capture()
                    _check(after.get_data() == expected.get_data(), label + " full imported canvas equals production GPU pixels")
                    record["direct_full_canvas_gpu_equal"] = after.get_data() == expected.get_data()
                    direct.queue_free()
                    sprite.show()
                    _check(_visible_bounds(after).size.x > 80, label + " real visible artwork")
                    var bounds := _visible_bounds(after)
                    _check(bounds.position.x > 4 and bounds.position.y > 4 and bounds.end.x < CANVAS.x - 4 and bounds.end.y < CANVAS.y - 4, label + " framebuffer edge clearance")
                    record["visible_bounds"] = [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]
                _check(after.save_png(static_path + "-after.png") == OK, label + " image saved")
                summary.static_frames.append(record)
    _check(unchanged_count == 10, kind + " all ten unaffected frames checked in both facings")
    stage.queue_free()
    await _draw_frame()
    var combat: Dictionary = _json("res://data/original_creature_combat.json")[kind]
    for command in combat.attacks:
        for facing in [-1, 1]:
            await _play_attack(kind, command, facing)

func _validate_import(texture: Texture2D, source_path: String, label: String) -> void:
    var source := Image.new()
    _check(source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path)) == OK, label + " source PNG decodes")
    var imported := texture.get_image()
    _check(imported != null and source.get_size() == imported.get_size(), label + " import dimensions")
    if imported == null:
        return
    source.convert(Image.FORMAT_RGBA8)
    imported.convert(Image.FORMAT_RGBA8)
    var before := source.get_data()
    var after := imported.get_data()
    var alpha_changes := 0
    var opaque_rgb_changes := 0
    var nonzero_rgb_changes := 0
    for index in range(0, before.size(), 4):
        if before[index + 3] != after[index + 3]:
            alpha_changes += 1
        var rgb_changed := before[index] != after[index] or before[index + 1] != after[index + 1] or before[index + 2] != after[index + 2]
        if rgb_changed and before[index + 3] > 0:
            nonzero_rgb_changes += 1
        if rgb_changed and before[index + 3] == 255:
            opaque_rgb_changes += 1
    # Production's default texture importer performs this RGB edge treatment.
    # Verify the transformation exactly; never claim GPU/import bytes equal PNG.
    source.fix_alpha_edges()
    var matches_standard_import := source.get_data() == after
    _check(alpha_changes == 0, label + " importer preserves every alpha value")
    _check(opaque_rgb_changes == 0, label + " importer preserves all opaque RGB")
    _check(matches_standard_import, label + " imported RGBA exactly matches standard fix_alpha_edges")
    summary.import_processing.append({"id": label, "source_path": source_path, "alpha_changes": alpha_changes, "opaque_rgb_changes": opaque_rgb_changes, "nonzero_rgb_changes": nonzero_rgb_changes, "matches_standard_fix_alpha_edges": matches_standard_import, "source_rgba_sha256": _hash(before), "imported_rgba_sha256": _hash(after)})
    DirAccess.make_dir_recursive_absolute(output_dir.path_join("import"))
    imported.save_png(output_dir.path_join("import/" + label + "-imported.png"))

func _show_frame(sprite: AnimatedSprite2D, animation: String, index: int) -> void:
    sprite.play(animation)
    sprite.pause()
    sprite.set_frame_and_progress(index, 0.0)

func _draw_frame() -> void:
    await process_frame
    await RenderingServer.frame_post_draw

func _capture() -> Image:
    await _draw_frame()
    return root.get_texture().get_image()

func _visible_bounds(image: Image) -> Rect2i:
    var background := image.get_pixel(0, 0)
    var left := image.get_width()
    var top := image.get_height()
    var right := 0
    var bottom := 0
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            if image.get_pixel(x, y) != background:
                left = mini(left, x)
                top = mini(top, y)
                right = maxi(right, x + 1)
                bottom = maxi(bottom, y + 1)
    return Rect2i(left, top, maxi(0, right - left), maxi(0, bottom - top))

func _play_attack(kind: String, command: Dictionary, facing: int) -> void:
    var label := "%s-%s-%s" % [kind, command.id, "left" if facing < 0 else "right"]
    var folder := output_dir.path_join("playback/" + label)
    DirAccess.make_dir_recursive_absolute(folder)
    var stage := Stage.new()
    root.add_child(stage)
    var enemy = _new_enemy(stage, kind)
    enemy.direction = facing
    enemy._set_sprite_flip(facing < 0)
    var sprite: AnimatedSprite2D = enemy.animated_sprite
    enemy._begin_attack(command.duplicate(true))
    _check(enemy.active_attack == command, label + " unmodified authored command")
    _check(sprite.animation == &"windup", label + " production windup path")
    _check(is_equal_approx(sprite.speed_scale, 2.0 / (6.0 * float(command.windup))), label + " authored windup playback speed")
    var start_tick := Engine.get_physics_frames()
    var records: Array = []
    var phases: Array[String] = []
    var poses: Dictionary = {}
    var transitions: Dictionary = {"windup": 0}
    var first_recover_x := 0.0
    enemy.set_physics_process(true)
    for capture_index in range(240):
        await _draw_frame()
        var phase: String = enemy.state
        var tick := Engine.get_physics_frames() - start_tick
        if not transitions.has(phase):
            transitions[phase] = tick
        if phases.is_empty() or phases.back() != phase:
            phases.append(phase)
        var pose_key := "%s/%s/%d" % [phase, sprite.animation, sprite.frame]
        poses[pose_key] = true
        if phase == "active":
            _check(sprite.animation == &"attack", label + " production active animation")
            _check(is_equal_approx(sprite.speed_scale, 2.0 / (10.0 * float(command.active))), label + " authored active playback speed")
        elif phase == "recover":
            _check(sprite.animation == &"idle" and is_equal_approx(sprite.speed_scale, 1.0), label + " production idle recovery")
            if is_zero_approx(first_recover_x):
                first_recover_x = enemy.position.x
        _check(sprite.flip_h == (facing < 0), label + " playback keeps requested facing")
        _check(sprite.scale == enemy.sprite_base_scale and sprite.position == enemy.sprite_base_position, label + " original art scale/offset during playback")
        var image := root.get_texture().get_image()
        var file_name := "%04d.png" % capture_index
        _check(image.save_png(folder.path_join(file_name)) == OK, label + " playback frame saves")
        records.append({"file": file_name, "physics_tick": tick, "state": phase, "animation": String(sprite.animation), "frame": sprite.frame, "progress": sprite.frame_progress, "speed_scale": sprite.speed_scale, "actor_position": [enemy.position.x, enemy.position.y]})
        if phase == "patrol":
            enemy.set_physics_process(false)
            break
    _check(phases == ["windup", "active", "recover", "patrol"], label + " complete real phase sequence")
    for phase in ["windup", "active"]:
        var animation := "windup" if phase == "windup" else "attack"
        for index in [0, 1]:
            _check(poses.has("%s/%s/%d" % [phase, animation, index]), label + " real playback presents " + phase + str(index))
    if transitions.has("active") and transitions.has("recover") and transitions.has("patrol"):
        var windup_ticks := int(transitions.active)
        var active_ticks := int(transitions.recover) - int(transitions.active)
        var recover_ticks := int(transitions.patrol) - int(transitions.recover)
        for pair in [[windup_ticks, command.windup], [active_ticks, command.active], [recover_ticks, command.recover]]:
            _check(absf(float(pair[0]) / 60.0 - float(pair[1])) <= 2.0 / 60.0, label + " authored duration within physics quantization")
    _check(enemy.active_attack.is_empty(), label + " attack command cleared")
    _check(not is_instance_valid(enemy.telegraph) and not is_instance_valid(enemy.windup_vfx), label + " warning cleanup")
    if String(command.type) == "combo":
        var expected_travel := float(command.lunge_speed) * (float(transitions.get("recover", 0)) - float(transitions.get("active", 0))) / 60.0
        _check(absf(absf(first_recover_x - ORIGIN.x) - expected_travel) <= 3.0, label + " original combo lunge speed")
    elif String(command.type) in ["guard", "melee"]:
        _check(is_equal_approx(enemy.position.x, ORIGIN.x), label + " stationary authored attack position")
    var record: Dictionary = {"id": label, "command": command, "facing": facing, "phases": phases, "transition_physics_ticks": transitions, "frames": records, "observed_poses": poses.keys(), "original_visual_scale": enemy.visual_scale, "original_visual_offset": [enemy.visual_offset.x, enemy.visual_offset.y]}
    summary.playbacks.append(record)
    var file := FileAccess.open(folder.path_join("timeline.json"), FileAccess.WRITE)
    _check(file != null, label + " timeline opens")
    if file != null:
        file.store_string(JSON.stringify(record, "  ") + "\n")
        file.close()
    stage.queue_free()
    await _draw_frame()
