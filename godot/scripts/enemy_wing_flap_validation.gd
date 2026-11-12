extends SceneTree
## Wing beat of redrawn hover loops (data/creature_wing_flap.json): the sprite
## shader swings the wing about its root while the body stays where it was
## drawn. Clips and creatures without an entry are drawn exactly as authored.
## Set WING_FLAP_SHEET=<png path> to save what was captured.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const BACKDROP := Color(.04, .05, .06)
const VIEW := Vector2i(360, 300)
var checks := 0
var failures := 0

class Stage extends Node2D:
    var chapter_terrain: Node = null

class PausePlayer extends Node2D:
    var ui_input_locked := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("ENEMY_WING_FLAP " + label)

func capture() -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func solid(image: Image, x: int, y: int) -> bool:
    var pixel := image.get_pixel(x, y)
    return absf(pixel.r - BACKDROP.r) + absf(pixel.g - BACKDROP.g) + absf(pixel.b - BACKDROP.b) > .12

## [changed pixels, pixels solid in b but outside a's bounding box, solid pixels in a]
func compare(a: Image, b: Image) -> Array:
    var low := Vector2i(a.get_width(), a.get_height())
    var high := Vector2i(-1, -1)
    var count := 0
    for y in a.get_height():
        for x in a.get_width():
            if solid(a, x, y):
                low = Vector2i(mini(low.x, x), mini(low.y, y)); high = Vector2i(maxi(high.x, x), maxi(high.y, y)); count += 1
    var changed := 0
    var outside := 0
    for y in a.get_height():
        for x in a.get_width():
            var pa := a.get_pixel(x, y)
            var pb := b.get_pixel(x, y)
            if absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b) > .08: changed += 1
            if solid(b, x, y) and (x < low.x - 1 or y < low.y - 1 or x > high.x + 1 or y > high.y + 1): outside += 1
    return [changed, outside, count]

func spawn(stage: Node, kind: String) -> Area2D:
    var actor := ENEMY.new()
    actor.configure({"id": "wing_" + kind, "kind": kind, "hp": 100}, "", false)
    stage.add_child(actor)
    actor.position = Vector2(VIEW.x * .5, VIEW.y * .62)
    actor.reset_physics_interpolation()
    actor.set_physics_process(false)
    return actor

func retire(stage: Node, actor: Node) -> void:
    actor.take_hit(99999, 1)
    RETIRE.retire_tree(stage)
    if is_instance_valid(actor): actor.queue_free()
    await process_frame
    await process_frame

func run() -> void:
    var real_pixels := DisplayServer.get_name() != "headless"
    root.size = VIEW
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(BACKDROP)
    var stage := Stage.new()
    root.add_child(stage)
    var pause_player := PausePlayer.new()
    stage.add_child(pause_player)
    pause_player.add_to_group("player")
    var data := ART.manifest(ENEMY.WING_FLAP_PATH)
    var creatures: Dictionary = data.get("creatures", {})
    check(creatures.size() >= 7, "winged hover creatures are listed")
    var sheet_path := OS.get_environment("WING_FLAP_SHEET")
    var tiles: Array[Image] = []
    var clips := 0
    var drawn := 0
    for kind: String in creatures:
        var entry: Dictionary = creatures[kind]
        var path := ART.character_manifest("original_creatures", kind)
        check(path.get_file() == String(data.layer), kind + " is drawn from the layer its wing was placed on")
        var actor := spawn(stage, kind)
        var sprite: AnimatedSprite2D = actor.animated_sprite
        var material := sprite.material as ShaderMaterial
        var canvas: Array = ART.manifest(path).canvas
        check(float(entry.get("hz", 0)) >= 2.0 and float(entry.hz) <= 12.0, kind + " beat can be seen at 60 frames a second")
        for animation: String in entry:
            if animation == "hz": continue
            var wing: Dictionary = entry[animation]
            clips += 1
            check(sprite.sprite_frames.has_animation(animation), "%s has %s" % [kind, animation])
            check(Rect2(0, 0, canvas[0], canvas[1]).has_point(Vector2(wing.hinge[0], wing.hinge[1])) and float(wing.sector[0]) < float(wing.sector[1]) and float(wing.radius[0]) < float(wing.radius[1]) and float(wing.radius[1]) < float(wing.radius[2]), "%s %s wing is placed on the canvas" % [kind, animation])
            sprite.play(animation); sprite.pause(); sprite.frame = 0
            check(actor.wing_flap_active and is_equal_approx(float(material.get_shader_parameter("wing_swing")), float(wing.swing)), "%s %s beats its wings" % [kind, animation])
            var texture := sprite.sprite_frames.get_frame_texture(animation, 0) as AtlasTexture
            check(material.get_shader_parameter("frame_origin") == texture.region.position - texture.margin.position, "%s %s wing follows the shown frame" % [kind, animation])
            sprite.frame = sprite.sprite_frames.get_frame_count(animation) - 1
            texture = sprite.sprite_frames.get_frame_texture(animation, sprite.frame) as AtlasTexture
            var region: Vector4 = material.get_shader_parameter("frame_region")
            check(Vector2(region.x, region.y) == texture.region.position and Vector2(region.z, region.w) == texture.region.size, "%s %s never samples a neighbouring frame" % [kind, animation])
            sprite.frame = 0
            # The beat advances with game time and wraps.
            actor.wing_flap_phase = 0.0
            actor._advance_wing_flap(.25 / float(entry.hz))
            check(is_equal_approx(float(material.get_shader_parameter("wing_phase")), PI * .5), "%s %s beat follows game time" % [kind, animation])
            actor._advance_wing_flap(1.0)
            check(actor.wing_flap_phase >= 0.0 and actor.wing_flap_phase < TAU, "%s %s beat wraps" % [kind, animation])
            # Exercise the actual UI-lock and dormant-world physics paths.
            pause_player.ui_input_locked = true
            var frozen_phase: float = actor.wing_flap_phase
            actor._physics_process(.1)
            check(actor.combat_visuals_paused and is_equal_approx(actor.wing_flap_phase, frozen_phase), "%s %s UI lock freezes wing on its first physics tick" % [kind, animation])
            actor._physics_process(.1)
            check(is_equal_approx(actor.wing_flap_phase, frozen_phase), "%s %s UI lock keeps wing frozen" % [kind, animation])
            pause_player.ui_input_locked = false
            actor._set_combat_visuals_paused(false)
            actor.set_meta("world_residency_active", false)
            actor._physics_process(.1)
            check(is_equal_approx(actor.wing_flap_phase, frozen_phase), "%s %s dormant world freezes wing" % [kind, animation])
            actor.set_meta("world_residency_active", true)
            actor._advance_wing_flap(.1 / float(entry.hz))
            check(not is_equal_approx(actor.wing_flap_phase, frozen_phase), "%s %s resumes wing after pause" % [kind, animation])
            if real_pixels:
                material.set_shader_parameter("wing_swing", 0.0)
                var plain := await capture()
                material.set_shader_parameter("wing_swing", float(wing.swing))
                var most := 0
                for step in 4:
                    material.set_shader_parameter("wing_phase", TAU * step / 4.0)
                    var shown := await capture()
                    var result := compare(plain, shown)
                    most = maxi(most, int(result[0]))
                    check(int(result[1]) == 0, "%s %s wing stays inside the drawn frame at beat %d (%d outside)" % [kind, animation, step, int(result[1])])
                    check(int(result[2]) > 400, "%s %s is on screen" % [kind, animation])
                    if not sheet_path.is_empty(): tiles.append(shown)
                check(most > 120, "%s %s wing visibly moves (%d pixels)" % [kind, animation, most])
                # Facing the other way mirrors the picture, wing included.
                material.set_shader_parameter("wing_phase", PI)
                var facing := await capture()
                sprite.flip_h = not sprite.flip_h
                var mirrored := await capture()
                sprite.flip_h = not sprite.flip_h
                mirrored.flip_x()
                check(int(compare(facing, mirrored)[0]) < 60, "%s %s mirrored wing matches" % [kind, animation])
                # A hit whitens the wing where it is now, not where it was drawn (soft
                # edges blend with the backdrop and stay darker).
                material.set_shader_parameter("flash_amount", 1.0)
                var flashed := await capture()
                material.set_shader_parameter("flash_amount", 0.0)
                var lit := 0
                var dull := 0
                for y in range(0, VIEW.y, 2):
                    for x in range(0, VIEW.x, 2):
                        if not solid(facing, x, y): continue
                        var pixel := flashed.get_pixel(x, y)
                        if minf(pixel.r, minf(pixel.g, pixel.b)) > .6: lit += 1
                        else: dull += 1
                check(lit > 100 and dull * 5 < lit, "%s %s hit flash covers the moving wing (%d lit, %d dull)" % [kind, animation, lit, dull])
                drawn += 1
        # Clips that still have drawn wing poses are left alone.
        for animation in ["windup", "attack", "recover", "hurt"]:
            if sprite.sprite_frames.has_animation(animation) and not entry.has(animation):
                sprite.play(animation); sprite.pause()
                check(not actor.wing_flap_active and float(material.get_shader_parameter("wing_swing")) == 0.0, "%s %s keeps its drawn wings" % [kind, animation])
                break
        sprite.play("idle")
        check(actor.wing_flap_active == entry.has("idle"), kind + " returns to the beat")
        await retire(stage, actor)
    # A creature without wings, and one drawn from another layer, are untouched.
    var walker := spawn(stage, "moss_larva")
    check(walker.wing_flap.is_empty() and not walker.wing_flap_active and (walker.animated_sprite.material as ShaderMaterial).get_shader_parameter("wing_swing") in [0.0, null], "ground creatures have no wing beat")
    await retire(stage, walker)
    if not sheet_path.is_empty() and not tiles.is_empty():
        var sheet := Image.create(VIEW.x * 4, VIEW.y * int(tiles.size() / 4.0), false, tiles[0].get_format())
        for index in tiles.size():
            sheet.blit_rect(tiles[index], Rect2i(Vector2i.ZERO, VIEW), Vector2i((index % 4) * VIEW.x, int(index / 4.0) * VIEW.y))
        sheet.save_png(sheet_path)
    ART.frame_cache.clear(); ART.textures.clear()
    RETIRE.retire_tree(root)
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    RETIRE.retire_tree(stage); stage.queue_free()
    await process_frame; await process_frame
    check(await RETIRE.drain(self), "audio is released before exit")
    check(not real_pixels or drawn == clips, "every listed clip was measured on screen")
    print("ENEMY_WING_FLAP checks=%d failures=%d creatures=%d clips=%d drawn=%d" % [checks, failures, creatures.size(), clips, drawn])
    call_deferred("quit", 1 if failures else 0)
