extends SceneTree
## Per-frame body size correction (frame_fit.json, tools/build_creature_frame_fit.py):
## every roster creature applies its measured correction where the frame is
## drawn, the node's own scale and position never change, and under real GL the
## drawn body is resized about its feet by exactly the measured amount.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const BACKDROP := Color(.04, .05, .06)
var checks := 0
var failures := 0

class Stage extends Node2D:
    var chapter_terrain: Node = null

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("ENEMY_FRAME_FIT " + label)

func draw_frame() -> void:
    await process_frame
    await RenderingServer.frame_post_draw

## Rows and columns of the capture that are not backdrop: [top, bottom, left, right, count].
func body_extent(image: Image) -> Array:
    var top := image.get_height()
    var bottom := -1
    var left := image.get_width()
    var right := -1
    var count := 0
    for y in image.get_height():
        for x in image.get_width():
            var pixel := image.get_pixel(x, y)
            if absf(pixel.r - BACKDROP.r) + absf(pixel.g - BACKDROP.g) + absf(pixel.b - BACKDROP.b) > .12:
                top = mini(top, y); bottom = maxi(bottom, y); left = mini(left, x); right = maxi(right, x)
                count += 1
    return [top, bottom, left, right, count]

func run() -> void:
    var real_pixels := DisplayServer.get_name() != "headless"
    root.size = Vector2i(900, 700)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(BACKDROP)
    var stage := Stage.new()
    root.add_child(stage)
    var roster := ART.manifest("res://data/original_creature_designs.json")
    var kinds := 0
    var corrected_kinds := 0
    var corrected_frames := 0
    var drawn := 0
    for design: Dictionary in roster.designs:
        var kind := String(design.kind)
        var actor := ENEMY.new()
        actor.configure({"id": "fit_" + kind, "kind": kind, "hp": 100}, "", bool(design.boss))
        stage.add_child(actor)
        actor.position = Vector2(450, 420)
        actor.reset_physics_interpolation()
        actor.set_physics_process(false)
        var sprite: AnimatedSprite2D = actor.animated_sprite
        var material := sprite.material as ShaderMaterial
        var path := ART.character_manifest("original_creatures", kind)
        var table: Dictionary = ART.frame_fit(path)
        check(FileAccess.file_exists(path.get_base_dir() + "/frame_fit.json"), kind + " has a measured frame_fit.json")
        check(actor.frame_fit == table and material != null, kind + " actor loads the table measured for its drawing layer")
        var frames := sprite.sprite_frames
        var widest := 0.0
        var widest_animation := ""
        var widest_frame := 0
        var consistent := true
        for animation: String in table:
            var rows: Array = table[animation]
            if not frames.has_animation(animation) or frames.get_frame_count(animation) != rows.size():
                consistent = false
                continue
            for index in rows.size():
                var fit := float(rows[index][0])
                if fit < .87 or fit > 1.15: consistent = false
                if fit != 1.0: corrected_frames += 1
                if absf(fit - 1.0) > widest and not animation.ends_with("_left"):
                    widest = absf(fit - 1.0); widest_animation = animation; widest_frame = index
        check(consistent, kind + " table matches the loaded clips and stays within limits")
        if not widest_animation.is_empty():
            corrected_kinds += 1
            var row: Array = table[widest_animation][widest_frame]
            sprite.play(widest_animation)
            sprite.pause()
            sprite.frame = widest_frame
            check(is_equal_approx(float(material.get_shader_parameter("body_fit")), float(row[0])), kind + " draws the shown frame with its own correction")
            check(sprite.scale == actor.sprite_base_scale and sprite.position == actor.sprite_base_position, kind + " correction leaves node scale and position alone")
            var pivot: Vector2 = material.get_shader_parameter("body_fit_pivot")
            check(is_equal_approx(absf(pivot.x), absf(float(row[1]))) and is_equal_approx(pivot.y, float(row[2])), kind + " scales about the measured body point")
            var was_flipped := sprite.flip_h
            actor._set_sprite_flip(not actor.requested_sprite_flip)
            var mirrored: Vector2 = material.get_shader_parameter("body_fit_pivot")
            check(sprite.flip_h == was_flipped or is_equal_approx(mirrored.x, -pivot.x), kind + " mirrors the body point with the facing")
            actor._set_sprite_flip(not actor.requested_sprite_flip)
            if real_pixels and drawn < 8 and String(ART.manifest(path).get("motion", "ground")) in ["ground", "stationary"]:
                await draw_frame(); await draw_frame()
                var fitted := body_extent(root.get_texture().get_image())
                material.set_shader_parameter("body_fit", 1.0)
                await draw_frame(); await draw_frame()
                var plain := body_extent(root.get_texture().get_image())
                material.set_shader_parameter("body_fit", float(row[0]))
                var height_ratio := float(fitted[1] - fitted[0] + 1) / maxf(1.0, float(plain[1] - plain[0] + 1))
                check(int(plain[4]) > 200 and absf(height_ratio - float(row[0])) < .03, "%s drawn body height follows the correction (%.3f vs %.3f)" % [kind, height_ratio, float(row[0])])
                check(absi(int(fitted[1]) - int(plain[1])) <= 1, kind + " feet stay on the same ground line")
                drawn += 1
            # Hit feedback and the per-tick pose reset keep the correction.
            sprite.play(widest_animation); sprite.pause(); sprite.frame = widest_frame
            actor.take_hit(1, 1)
            actor._update_animation_motion(.03, actor.global_position, "active")
            check(sprite.frame != widest_frame or is_equal_approx(float(material.get_shader_parameter("body_fit")), float(row[0])), kind + " hit keeps the frame's correction")
            # A frame without correction returns to the plain drawing.
            for index in table[widest_animation].size():
                if float(table[widest_animation][index][0]) == 1.0:
                    sprite.frame = index
                    check(float(material.get_shader_parameter("body_fit")) == 1.0, kind + " uncorrected frame is drawn as authored")
                    break
        actor.take_hit(99999, 1)
        RETIRE.retire_tree(stage)
        if is_instance_valid(actor): actor.queue_free()
        await process_frame
        await process_frame
        ART.frame_cache.clear(); ART.textures.clear()
        kinds += 1
    check(kinds == 46 and corrected_kinds >= 40 and corrected_frames > 1000, "roster is covered (%d kinds, %d corrected, %d frames)" % [kinds, corrected_kinds, corrected_frames])
    check(not real_pixels or drawn == 8, "eight grounded creatures were measured on screen")
    await check_transition_start(stage)
    RETIRE.retire_tree(root)
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    RETIRE.retire_tree(stage); stage.queue_free()
    await process_frame; await process_frame
    check(await RETIRE.drain(self), "audio is released before exit")
    print("ENEMY_FRAME_FIT checks=%d failures=%d characters=%d corrected_frames=%d drawn=%d" % [checks, failures, kinds, corrected_frames, drawn])
    call_deferred("quit", 1 if failures else 0)

func check_transition_start(stage: Node) -> void:
    var actor := ENEMY.new()
    actor.configure({"id":"fit_transition", "kind":"moss_larva", "hp":100}, "", false)
    stage.add_child(actor)
    actor.set_physics_process(false)
    actor.state = "patrol"
    var sprite: AnimatedSprite2D = actor.animated_sprite
    # A successful redraw may need no walking correction at all. Use a local
    # non-identity probe so this regression stays meaningful as art improves.
    actor.frame_fit = actor.frame_fit.duplicate(true)
    var rows: Array = []
    for i in sprite.sprite_frames.get_frame_count("walk"): rows.append([1.0,0,0])
    if rows.size() > 1: rows[1] = [0.93,7.0,37.0]
    actor.frame_fit["walk"] = rows
    check(rows.size() > 1, "transition fixture has a multi-frame walking clip")
    if not rows.is_empty():
        var index := 0
        for i in rows.size():
            if float(rows[i][0]) != 1.0: index = i; break
        sprite.play("walk"); sprite.pause(); sprite.frame = index
        var expected_scale: float = actor.frame_fit_scale
        var expected_pivot: Vector2 = actor.frame_fit_pivot
        var texture := sprite.sprite_frames.get_frame_texture("walk",index)
        actor.motion_transitions._begin(actor,&"turn",not sprite.flip_h,texture)
        actor._apply_frame_fit()
        check(is_equal_approx(actor.frame_fit_scale,expected_scale) and actor.frame_fit_pivot==expected_pivot,
            "turn retains the previous visible cel's fit instead of canonical frame zero")
        actor._set_enemy_animation("walk",true); sprite.pause(); sprite.frame = index
        actor.motion_transitions.tick(actor,Vector2(2,0),"patrol")
        expected_scale = actor.frame_fit_scale; expected_pivot = actor.frame_fit_pivot
        actor._set_enemy_animation("idle")
        actor.motion_transitions.tick(actor,Vector2.ZERO,"patrol")
        actor._apply_frame_fit()
        check(actor.motion_transitions.active==&"brake" and is_equal_approx(actor.frame_fit_scale,expected_scale)
            and actor.frame_fit_pivot==expected_pivot,"brake retains walking fit after idle has already been selected")
    RETIRE.retire_tree(actor); actor.queue_free()
    await process_frame; await process_frame
