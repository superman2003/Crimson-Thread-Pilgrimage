extends SceneTree
## Focused helper contracts. Pixel assertions require real GL; source/state checks
## do not imply artistic acceptance of full idle, breathing, or action transitions.

const HELPER := preload("res://scripts/player_layered_idle.gd")
const DIR := "res://assets/sprites/player/generated_hero_motion_v4/runtime_idle/"
const V3 := "res://assets/sprites/player/generated_hero_v3/frames/"
const ACTIONS := [&"idle", &"run", &"hurt", &"death", &"dash", &"attack_1"]
const ORDER := [1, 3, 2, 4, 5, 6, 7]
var checks := 0
var failures: Array[String] = []
var manifest: Dictionary
var stage: Node2D
var sprite: AnimatedSprite2D
var helper: Node2D
var original_frames: SpriteFrames
var original_material: ShaderMaterial
var original_color := Color(0.73, 0.84, 0.91, 0.43)
var viewport: SubViewport
var clock_probe: ClockProbe
var real_gl := false
var pixels_complete := false
var pixel_mask_checks := 0
var pixel_restore_checks := 0
var pixel_flash_checks := 0

class ClockProbe extends Node:
    var seconds := 0.0
    func _process(delta: float) -> void:
        seconds += delta


func _initialize() -> void:
    call_deferred("_run")


func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("LAYERED_IDLE_CHECK_FAILED " + label)


func _hash(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()


func _image(path: String) -> Image:
    var result := Image.new()
    result.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
    result.convert(Image.FORMAT_RGBA8)
    return result


func _texture(path: String) -> Texture2D:
    if ResourceLoader.exists(path, "Texture2D"):
        return load(path) as Texture2D
    return ImageTexture.create_from_image(_image(path))


func _bottom(image: Image, roi: Rect2i) -> int:
    var bottom := -1
    for y in range(roi.position.y, roi.end.y):
        for x in range(roi.position.x, roi.end.x):
            if roundi(image.get_pixel(x, y).a * 255.0) > 128:
                bottom = maxi(bottom, y)
    return bottom


func _source_checks() -> void:
    manifest = JSON.parse_string(FileAccess.get_file_as_string(DIR + "manifest.json"))
    var schema_probe := HELPER.new()
    _check(schema_probe._valid_manifest(manifest), "Production JSON numeric arrays are valid schema input")
    schema_probe.free()
    var support := _image(DIR + String(manifest.support.file))
    var atlas := _image(DIR + String(manifest.cloth.file))
    _check(FileAccess.get_sha256(DIR + String(manifest.support.file)) == manifest.support.sha256,
        "Fixed support PNG is byte-identical to imagegen source")
    _check(FileAccess.get_sha256(DIR + String(manifest.cloth.file)) == manifest.cloth.sha256,
        "Cloth PNG is byte-identical to imagegen source")
    _check(support.get_size() == Vector2i(1254, 1254) and atlas.get_size() == Vector2i(1774, 887),
        "Both original RGBA canvases retained")
    var unique_hashes: Dictionary = {}
    var unique_regions: Dictionary = {}
    _check(manifest.cloth.frames.size() == 7, "Exactly seven selected real cels")
    for index in range(7):
        var record: Dictionary = manifest.cloth.frames[index]
        var region := Rect2i(record.region[0], record.region[1], record.region[2], record.region[3])
        var cell := atlas.get_region(region)
        var sha := _hash(cell.get_data())
        unique_hashes[sha] = true
        unique_regions[str(region)] = true
        _check(int(record.source_cel) == ORDER[index] and int(record.playback_index) == index,
            "Cel %d retains reviewed playback order" % index)
        _check(sha == record.rgba_region_sha256, "Cel %d preserves exact source RGBA pixels" % index)
        var maximum_edge_alpha := 0
        for x in range(cell.get_width()):
            maximum_edge_alpha = maxi(maximum_edge_alpha, roundi(cell.get_pixel(x, 0).a * 255.0))
            maximum_edge_alpha = maxi(maximum_edge_alpha, roundi(cell.get_pixel(x, cell.get_height() - 1).a * 255.0))
        for y in range(cell.get_height()):
            maximum_edge_alpha = maxi(maximum_edge_alpha, roundi(cell.get_pixel(0, y).a * 255.0))
            maximum_edge_alpha = maxi(maximum_edge_alpha, roundi(cell.get_pixel(cell.get_width() - 1, y).a * 255.0))
        _check(maximum_edge_alpha == int(record.alpha.edge_max) and maximum_edge_alpha < 128,
            "Cel %d has recorded near-transparent edges without strong-alpha clipping" % index)
    _check(unique_hashes.size() == 7 and unique_regions.size() == 7, "Seven different regions AND decoded RGBA hashes")
    var v3 := _image(V3 + "idle_00.png")
    _check(_bottom(v3, Rect2i(150, 250, 35, 40)) == 281 and _bottom(v3, Rect2i(185, 250, 35, 40)) == 279,
        "V3 idle0 actual two-foot bottom rows average baseline 280")
    _check(_bottom(support, Rect2i(500, 850, 120, 100)) == 934 and _bottom(support, Rect2i(620, 850, 130, 100)) == 928,
        "Fixed support actual two-foot bottom rows average 931")


func _make_fixture() -> void:
    viewport = SubViewport.new()
    viewport.size = Vector2i(460, 360)
    viewport.transparent_bg = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    stage = Node2D.new()
    viewport.add_child(stage)
    sprite = AnimatedSprite2D.new()
    sprite.position = Vector2(230, 240) + Vector2(0, -58.08)
    sprite.scale = Vector2.ONE * 0.66
    sprite.modulate = Color(0.8, 0.9, 0.75, 0.7)
    sprite.self_modulate = original_color
    original_material = ShaderMaterial.new()
    original_material.shader = load("res://shaders/hit_flash.gdshader")
    sprite.material = original_material
    original_frames = SpriteFrames.new()
    original_frames.remove_animation(&"default")
    for action in ACTIONS:
        original_frames.add_animation(action)
        original_frames.set_animation_speed(action, 12.0 if action == &"run" else 10.0)
        original_frames.set_animation_loop(action, action in [&"idle", &"run"])
        for index in range(4):
            original_frames.add_frame(action, _texture(V3 + "%s_%02d.png" % [String(action), index]))
    sprite.sprite_frames = original_frames
    stage.add_child(sprite)
    sprite.play(&"idle")
    helper = HELPER.new()
    _check(helper.attach(sprite), "Helper attaches to the original AnimatedSprite2D")
    helper.set_process(false)
    clock_probe = ClockProbe.new()
    clock_probe.set_process(false)
    stage.add_child(clock_probe)


func _malformed_manifest_checks() -> void:
    var cases: Array[Dictionary] = []
    var bad: Dictionary = manifest.duplicate(true)
    bad.reference.erase("canvas")
    cases.append({"label": "missing reference canvas", "data": bad})
    bad = manifest.duplicate(true)
    bad.support.registration_root = [1]
    cases.append({"label": "short root vector", "data": bad})
    bad = manifest.duplicate(true)
    bad.cloth.frames[0].anchor = [NAN, 2]
    cases.append({"label": "nonfinite cloth anchor", "data": bad})
    bad = manifest.duplicate(true)
    bad.support.raw_to_design = 0.0
    cases.append({"label": "zero support scale", "data": bad})
    bad = manifest.duplicate(true)
    bad.composition.cloth_source_to_support_source_scale = -0.1
    cases.append({"label": "negative cloth scale", "data": bad})
    bad = manifest.duplicate(true)
    bad.cloth.frames[0].region = [1770, 0, 443, 444]
    cases.append({"label": "atlas region outside source", "data": bad})
    bad = manifest.duplicate(true)
    bad.cloth.frames[1].source_cel = 1
    cases.append({"label": "duplicate cel in seven sequence", "data": bad})
    bad = manifest.duplicate(true)
    bad.cloth.frames[1].region = bad.cloth.frames[0].region
    cases.append({"label": "duplicate atlas region", "data": bad})
    bad = manifest.duplicate(true)
    bad.reference.erase("foot_baseline")
    cases.append({"label": "missing foot baseline", "data": bad})
    bad = manifest.duplicate(true)
    bad.composition = []
    cases.append({"label": "invalid composition object", "data": bad})
    bad = manifest.duplicate(true)
    bad.cloth.frames.resize(6)
    cases.append({"label": "short frame sequence", "data": bad})
    bad = manifest.duplicate(true)
    bad.support.dimensions = [INF, 1254]
    cases.append({"label": "nonfinite source canvas", "data": bad})
    bad = manifest.duplicate(true)
    bad.reference.foot_baseline = true
    cases.append({"label": "boolean instead of number", "data": bad})
    bad = manifest.duplicate(true)
    bad.cloth.frames[0].region[0] = 0.5
    cases.append({"label": "fractional atlas pixels", "data": bad})
    var target := AnimatedSprite2D.new()
    target.position = Vector2(-1000, -1000)
    target.sprite_frames = original_frames
    target.material = original_material
    target.self_modulate = original_color
    stage.add_child(target)
    target.play(&"idle")
    for entry in cases:
        var candidate := HELPER.new()
        _check(not candidate.attach(target, entry.data), "Malformed manifest rejects " + String(entry.label))
        _check(target.material == original_material and target.self_modulate == original_color and target.visible and target.sprite_frames == original_frames and candidate.get_parent() == null,
            "Rejected " + String(entry.label) + " preserves the untouched original sprite")
        candidate.free()
    target.free()


func _registration_checks() -> void:
    _check(sprite.sprite_frames == original_frames and sprite.animation == &"idle",
        "Presentation preserves original SpriteFrames and animation")
    _check(sprite.visible and is_zero_approx(sprite.self_modulate.a) and helper.visible,
        "Source alone is masked without hiding its children")
    _check(sprite.material == null and helper.material == original_material,
        "Original live flash material belongs to the visible composition")
    var body: Sprite2D = helper.body
    var cloth: Sprite2D = helper.cloth
    var body_texture := body.texture
    var expected_scale := Vector2.ONE * float(manifest.support.raw_to_design)
    var foot_center := Vector2(manifest.reference.foot_center_x, 280) - Vector2(192, 192)
    var raw_root := Vector2(manifest.support.registration_root[0], manifest.support.registration_root[1])
    var base_body_position := body.position
    var base_sprite_transform := sprite.transform
    for flipped in [false, true]:
        sprite.flip_h = flipped
        for index in range(7):
            sprite.set_frame_and_progress(index % 4, 0.37)
            # Emulate the existing old-sprite-only registration correction.
            sprite.offset = Vector2(7.0 - index, 0)
            helper.sync_pose()
            _check(body.texture == body_texture and body.position == base_body_position and body.scale == expected_scale,
                "Fixed support never moves/rescales across cel %d facing %s" % [index, str(flipped)])
            _check(sprite.transform == base_sprite_transform and sprite.offset == Vector2(7.0 - index, 0),
                "Helper does not change gameplay sprite transform/offset")
            var sign_x := -1.0 if flipped else 1.0
            var actual_root := sprite.to_local(body.to_global(raw_root))
            _check(actual_root.distance_to(foot_center * Vector2(sign_x, 1.0)) < 0.0001,
                "Both-facing fixed feet map exactly to v3 idle0 ground reference")
            var record: Dictionary = manifest.cloth.frames[helper.playback_index]
            var anchor := Vector2(record.anchor[0], record.anchor[1])
            var attachment := Vector2(610, 632)
            _check(cloth.to_global(anchor).distance_to(body.to_global(attachment)) < 0.0001,
                "Cloth attachment and body mirror as one registered composition")
            var rect := cloth.texture as AtlasTexture
            _check(rect != null and rect.filter_clip and rect.atlas != null,
                "Each visible cel uses an actual clipped AtlasTexture region")
            helper._process(0.1)
    sprite.flip_h = false
    sprite.offset = Vector2.ZERO
    sprite.rotation = 0.19
    sprite.scale = Vector2(0.81, 0.57)
    helper.sync_pose()
    _check(body.to_global(raw_root).distance_to(sprite.to_global(foot_center)) < 0.0001,
        "Parent rotation/nonuniform scale/world position compose around the same fixed feet")
    sprite.transform = base_sprite_transform
    helper.sync_pose()


func _timing_checks() -> void:
    sprite.play(&"run")
    sprite.play(&"idle")
    var visited: Array[int] = []
    for tick in range(15):
        var snapshot: Dictionary = helper.get_presentation_snapshot()
        visited.append(snapshot.source_cel)
        _check(snapshot.playback_index == tick % 7 and snapshot.source_cel == ORDER[tick % 7],
            "10fps true seven-cel order at tick %d, including closure" % tick)
        sprite.set_frame_and_progress(tick % 4, 0.0)
        helper.sync_pose()
        helper._process(0.1)
    _check(visited.slice(0, 7) == ORDER, "First complete cycle contains seven genuine cels")
    sprite.play(&"run")
    sprite.play(&"idle")
    helper._process(0.099)
    _check(helper.playback_index == 0, "First cel holds for its full 100ms")
    helper._process(0.001)
    _check(helper.playback_index == 1, "Exact 100ms boundary selects the next cel")
    helper._process(0.29)
    sprite.set_frame_and_progress(0, 0.0)
    helper.sync_pose()
    helper._process(0.01)
    _check(helper.playback_index == 4, "Old four-frame idle wrap does not reset seven-cel age")
    var before: float = helper.elapsed
    sprite.pause()
    helper._process(0.31)
    _check(is_equal_approx(helper.elapsed, before), "AnimatedSprite.pause freezes cloth phase")
    sprite.play(&"idle")
    helper._process(0.1)
    _check(helper.playback_index == 5, "Resume continues the frozen cloth phase")
    before = helper.elapsed
    sprite.speed_scale = 0.0
    helper._process(0.5)
    _check(is_equal_approx(helper.elapsed, before), "Zero playback speed freezes cloth phase")
    sprite.speed_scale = 1.0
    sprite.play(&"run")
    sprite.play(&"idle", 2.0)
    helper._process(0.05)
    _check(helper.playback_index == 1, "AnimatedSprite custom speed is respected exactly once")
    sprite.play(&"run")
    sprite.play(&"idle", -1.0)
    helper._process(0.1)
    _check(helper.playback_index == 6, "Reverse playback wraps the actual seven-cel cycle")
    sprite.play(&"idle", 1.0)


func _state_checks() -> void:
    for action in ACTIONS:
        if action == &"idle":
            continue
        sprite.play(&"idle")
        helper.sync_pose()
        sprite.play(action)
        # No process-frame wait: animation_changed must restore immediately.
        _check(not helper.active and not helper.visible, "idle to %s immediately hides all layered art" % action)
        _check(sprite.material == original_material and sprite.self_modulate == original_color,
            "idle to %s immediately restores original material and alpha" % action)
        _check(sprite.sprite_frames == original_frames and sprite.visible and sprite.animation == action,
            "%s retains its original animation, resources and visible sprite" % action)
    sprite.play(&"idle")
    original_material.set_shader_parameter("flash_amount", 0.75)
    _check(helper.material == original_material and helper.material.get_shader_parameter("flash_amount") == 0.75,
        "Layers share live flash parameters instead of copying a stale material")
    original_material.set_shader_parameter("flash_amount", 0.0)


func _clock_checks() -> void:
    sprite.play(&"run")
    sprite.play(&"idle")
    helper.set_process(true)
    clock_probe.seconds = 0.0
    clock_probe.set_process(true)
    Engine.time_scale = 0.25
    for index in range(18):
        await process_frame
    var expected := fposmod(clock_probe.seconds, 0.7)
    _check(absf(helper.elapsed - expected) < 0.0001,
        "Real process delta/time_scale advances cloth once, without double scaling")
    _check(clock_probe.seconds > 0.0, "Scaled real process clock was actually exercised")
    var before: float = helper.elapsed
    paused = true
    for index in range(6):
        await process_frame
    _check(is_equal_approx(helper.elapsed, before), "SceneTree pause freezes layered presentation")
    paused = false
    sprite.pause()
    before = helper.elapsed
    for index in range(6):
        await process_frame
    _check(is_equal_approx(helper.elapsed, before), "Real processing honors source animation pause")
    sprite.play(&"idle")
    for index in range(6):
        await process_frame
    _check(not is_equal_approx(helper.elapsed, before), "Real processing resumes after animation pause")
    Engine.time_scale = 1.0
    helper.set_process(false)
    clock_probe.set_process(false)
    sprite.pause()


func _capture() -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    return viewport.get_texture().get_image()


func _reference_composite() -> Node2D:
    # No AnimatedSprite2D source draw exists in this independent reference tree.
    # Match only transforms/materials of the two known visible layer sprites.
    var reference := Node2D.new()
    reference.transform = sprite.transform
    reference.modulate = sprite.modulate
    var layers := Node2D.new()
    layers.transform = helper.transform
    layers.modulate = helper.modulate
    layers.material = helper.material
    reference.add_child(layers)
    for source in [helper.cloth, helper.body]:
        var copy := Sprite2D.new()
        copy.texture = source.texture
        copy.centered = source.centered
        copy.transform = source.transform
        copy.texture_filter = source.texture_filter
        copy.use_parent_material = true
        layers.add_child(copy)
    stage.add_child(reference)
    return reference


func _different_pixels(a: Image, b: Image) -> int:
    if a.get_size() != b.get_size():
        return 1000000
    var different := 0
    for y in range(a.get_height()):
        for x in range(a.get_width()):
            if a.get_pixel(x, y) != b.get_pixel(x, y):
                different += 1
    return different


func _pixel_checks() -> void:
    var method := RenderingServer.get_current_rendering_method()
    var driver := RenderingServer.get_current_rendering_driver_name()
    var api := RenderingServer.get_video_adapter_api_version()
    var adapter := RenderingServer.get_video_adapter_name()
    real_gl = DisplayServer.get_name() != "headless" and method == "gl_compatibility" and driver.begins_with("opengl3") and not api.is_empty() and not adapter.is_empty()
    print("LAYERED_IDLE_RENDERER " + JSON.stringify({"display": DisplayServer.get_name(), "method": method, "driver": driver, "api": api, "adapter": adapter, "real_gl": real_gl}))
    if not real_gl:
        print("LAYERED_IDLE_PIXELS SKIPPED no verified actual OpenGL adapter; no masking pass claimed")
        return
    var failures_before_pixels := failures.size()
    var baseline_images: Dictionary = {}
    # Capture unlayered references for restoration under the actual old shader.
    for action in [&"run", &"hurt", &"death", &"dash"]:
        sprite.play(action)
        sprite.pause()
        sprite.set_frame_and_progress(0, 0.0)
        baseline_images[action] = await _capture()
    var first_mask_hash := ""
    for amount in [0.0, 0.75]:
        original_material.set_shader_parameter("flash_amount", amount)
        for alpha in [0.43, 0.0]:
            sprite.play(&"run")
            sprite.self_modulate = Color(original_color, alpha)
            sprite.play(&"idle")
            sprite.pause()
            helper.sync_pose()
            for flipped in [false, true]:
                sprite.flip_h = flipped
                helper.sync_pose()
                var actual := await _capture()
                sprite.visible = false
                var reference := _reference_composite()
                var expected := await _capture()
                var mismatch := _different_pixels(actual, expected)
                pixel_mask_checks += 1
                print("LAYERED_IDLE_PIXEL_MASK flash=%.2f alpha=%.2f flip=%s different_pixels=%d" % [amount, alpha, str(flipped), mismatch])
                _check(mismatch == 0,
                    "Real GL masks original sprite exactly: flash=%.2f alpha=%.2f flip=%s difference=%d" % [amount, alpha, str(flipped), mismatch])
                if amount == 0.0 and alpha == 0.43 and not flipped:
                    first_mask_hash = _hash(actual.get_data())
                if amount == 0.75 and alpha == 0.43 and not flipped:
                    pixel_flash_checks += 1
                    _check(_hash(actual.get_data()) != first_mask_hash,
                        "Nonzero flash visibly reaches both retained original-material layers")
                reference.queue_free()
                await process_frame
                sprite.visible = true
    sprite.flip_h = false
    original_material.set_shader_parameter("flash_amount", 0.0)
    sprite.play(&"run")
    sprite.self_modulate = original_color
    for action in [&"run", &"hurt", &"death", &"dash"]:
        sprite.play(&"idle")
        sprite.play(action)
        sprite.pause()
        sprite.set_frame_and_progress(0, 0.0)
        var actual := await _capture()
        var mismatch := _different_pixels(actual, baseline_images[action])
        pixel_restore_checks += 1
        print("LAYERED_IDLE_PIXEL_RESTORE animation=%s different_pixels=%d" % [action, mismatch])
        _check(mismatch == 0,
            "Real GL idle to %s exactly restores original rendered frame" % action)
    pixels_complete = pixel_mask_checks == 8 and pixel_flash_checks == 1 and pixel_restore_checks == 4 and failures.size() == failures_before_pixels
    print("LAYERED_IDLE_PIXELS masks=%d flash=%d restores=%d complete=%s" % [pixel_mask_checks, pixel_flash_checks, pixel_restore_checks, str(pixels_complete)])


func _real_player_lifecycle_checks() -> void:
    var scene := load("res://scenes/Player.tscn") as PackedScene
    var player := scene.instantiate()
    root.add_child(player)
    player.set_physics_process(false)
    var production_sprite: AnimatedSprite2D = player.sprite
    var production_material: Material = player.flash_material
    var production_helper: Node2D = player.layered_idle
    var saved_color: Color = production_helper._saved_self_modulate
    _check(production_helper.active and production_helper.material == production_material,
        "Real Player ready installs a live layered idle with original flash object")
    production_sprite.remove_child(production_helper)
    player._sync_sprite_pose_anchor()
    _check(not production_helper.active and production_sprite.material == production_material and production_sprite.self_modulate == saved_color,
        "Real Player pose sync cannot reactivate a detached helper or hide its source")
    for index in range(8):
        await process_frame
        player._sync_sprite_pose_anchor()
    _check(production_sprite.is_visible_in_tree() and production_sprite.material == production_material and production_sprite.self_modulate == saved_color,
        "Detached-helper source stays visible across actual frame/pose synchronization")
    production_helper.free()
    _check(not is_instance_valid(player.layered_idle), "Real Player retains an actual freed helper reference in the probe")
    player._sync_sprite_pose_anchor()
    _check(production_sprite.material == production_material and production_sprite.self_modulate == saved_color,
        "Real Player is_instance_valid guard tolerates detached-then-freed helper")
    player._play(&"hurt")
    _check(production_sprite.animation == &"hurt" and production_sprite.material == production_material,
        "Real Player continues normal hurt poses after helper removal")
    player.free()
    player = scene.instantiate()
    root.add_child(player)
    player.set_physics_process(false)
    production_sprite = player.sprite
    production_material = player.flash_material
    production_helper = player.layered_idle
    saved_color = production_helper._saved_self_modulate
    _check(production_helper.active, "Second real Player exercises direct free while helper is active")
    production_helper.free()
    _check(production_sprite.material == production_material and production_sprite.self_modulate == saved_color and production_sprite.is_visible_in_tree(),
        "Directly freeing active real Player helper synchronously restores original draw")
    player._sync_sprite_pose_anchor()
    player._play(&"dash")
    _check(production_sprite.animation == &"dash" and production_sprite.material == production_material,
        "Real Player continues synchronization and dash after direct helper free")
    player.free()


func _run() -> void:
    _source_checks()
    _make_fixture()
    if not helper.active:
        _check(false, "Fixture initialization must activate helper")
        helper.free()
    else:
        _malformed_manifest_checks()
        _registration_checks()
        _timing_checks()
        _state_checks()
        await _clock_checks()
        await _pixel_checks()
        await _real_player_lifecycle_checks()
        sprite.play(&"idle")
        sprite.remove_child(helper)
        _check(sprite.material == original_material and sprite.self_modulate == original_color,
            "Removing active helper restores source material/self_modulate synchronously")
        helper.free()
    viewport.queue_free()
    await process_frame
    await process_frame
    print("PLAYER_LAYERED_IDLE_VALIDATION checks=%d failures=%d real_gl=%s pixels_complete=%s" % [checks, failures.size(), str(real_gl), str(pixels_complete)])
    print("LAYERED_IDLE_SCOPE structural/state/pixel contracts only; full idle/breathing and product transitions OPEN")
    for failure in failures:
        print("FAIL: " + failure)
    quit(0 if failures.is_empty() else 1)
