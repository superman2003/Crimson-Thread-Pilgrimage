extends SceneTree
## Production spawn paths, bounded cosmetic churn and real GL overlap pixels.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const MELEE := preload("res://scripts/player_melee_feedback.gd")

# Audio has its own retirement suite; keep this rapid visual churn independent
# of the engine's Ogg playback teardown (the ordinary combat suites retain it).
class VisualEnemy extends "res://scripts/enemy_actor.gd":
    func _should_play_sfx() -> bool:
        return false

class ClockFeel extends "res://scripts/feel_kit.gd":
    var clock := 1000000
    func _now_usec() -> int:
        return clock

var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func _run() -> void:
    var real_gl := DisplayServer.get_name() != "headless"
    _check(real_gl, "Real GL is required for overlap verification")
    if not real_gl:
        quit(1)
        return
    _screen_budget()
    await _contact_budget()
    await _overlap_pixels()
    await process_frame
    print("COMBAT_VISUAL_BUDGET checks=%d failures=%d real_gl=%s" % [checks, failures, real_gl])
    quit(0 if failures == 0 else 1)

func _screen_budget() -> void:
    var feel := ClockFeel.new()
    root.add_child(feel)
    feel.set_process(false)
    feel.flash_screen(Color.WHITE * 10.0, 1.0, 600)
    var first := feel._screen_effect
    var deadline := feel._screen_effect_deadline_usec
    _check(first != null and first.color == Color(1, 1, 1, 0.12), "Flash clamps both opacity and HDR color")
    _check(deadline - feel.clock <= 50000, "Oversized frame request is capped at 50ms")
    for index in range(40):
        feel.flash_screen(Color.RED, 1.0, 600)
    _check(feel._overlay_layer.get_child_count() == 1 and feel._screen_effect == first, "Forty same-frame kill flashes neither stack nor replace")
    feel.clock += 10000
    feel.black_frame(Vector2(110, 80), 600)
    _check(feel._overlay_layer.get_child_count() == 1 and feel._screen_effect.name == "FeelKitBlackFrame", "Damage takes priority over a live kill accent without stacking")
    _check(feel._screen_effect_deadline_usec == deadline, "Priority replacement cannot extend the original envelope")
    _check(feel._screen_effect.material.get_shader_parameter("tint").a <= 0.24, "Damage shade remains translucent")
    var damage_rect := feel._screen_effect
    for index in range(40):
        feel.black_frame(Vector2.ZERO, 600)
        feel.flash_screen(Color.WHITE, 1.0, 600)
    _check(feel._screen_effect == damage_rect and feel._screen_effect_deadline_usec == deadline, "Repeated damage/kill feedback cannot restart the envelope")
    Engine.time_scale = 0.05
    feel.clock = deadline
    feel._process(0.0001)
    Engine.time_scale = 1.0
    _check(feel._overlay_layer.get_child_count() == 0, "Wall-clock deadline clears the overlay during hitstop")
    feel.black_frame(Vector2.ZERO, 3)
    _check(feel._overlay_layer.get_child_count() == 0, "Cooldown blocks even damage after the envelope expires")
    feel.clock = 1200000
    feel.flash_screen(Color.WHITE, 0.08, 1)
    _check(feel._screen_effect != null and is_equal_approx(feel._screen_effect.color.a, 0.08), "Fresh accents resume at 200ms without increasing a weaker authored alpha")
    feel.set_accessibility({"flash_enabled": false})
    feel.black_frame(Vector2.ZERO)
    _check(feel._overlay_layer.get_child_count() == 0, "Flash setting immediately clears and suppresses both forms")
    feel.set_accessibility({"flash_enabled": true})
    feel.flash_screen(Color.WHITE, NAN, 3)
    feel.black_frame(Vector2(INF, 0))
    feel.flash_screen(Color.WHITE, 1.0, 0)
    _check(feel._overlay_layer.get_child_count() == 0, "Malformed/zero-duration requests consume no budget")
    feel.black_frame(Vector2.ZERO, 2)
    var reverse := feel._screen_effect
    feel.flash_screen(Color.WHITE, 1.0, 3)
    _check(feel._screen_effect == reverse, "Kill accent cannot replace damage when call order is reversed")
    var camera := Camera2D.new()
    root.add_child(camera)
    feel.register_camera(camera)
    _check(feel._overlay_layer.get_child_count() == 0, "Camera handover clears feedback from the retired view")
    camera.free()
    feel.free()

func _contact_budget() -> void:
    var arena := Node2D.new()
    root.add_child(arena)
    var enemy := VisualEnemy.new()
    arena.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.hp = 100
    enemy.max_hp = 100
    for index in range(24):
        enemy.take_hit(1, 1)
        MELEE.spawn_hit(arena, Vector2(150, 150), Vector2.RIGHT, &"attack_1")
    _check(enemy.hp == 76, "All 24 accepted hits deal damage while cosmetic budget is saturated")
    _check(get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 12, "Enemy sparks and player contact marks share twelve slots")
    _check(MELEE.spawn_hit(arena, Vector2.ZERO, Vector2.RIGHT, &"attack_1") == null, "Overflow rejects only the new cosmetic mark")
    var hazards: Array[Node2D] = []
    for index in range(20):
        var hazard: Node2D = enemy._effect("projectile", Vector2(100 + index * 10, 200), Vector2.ZERO, {"damage": 2, "radius": 10}, 0.0, 2.0)
        hazard.set_physics_process(false)
        hazards.append(hazard)
    _check(hazards.size() == 20 and get_nodes_in_group("hostile_attack").size() == 20, "All twenty gameplay hazards spawn despite the decorative limit")
    _check(hazards[0]._hits_player(hazards[0].global_position), "Hazard hit geometry remains active")
    for mark in get_nodes_in_group(POLICY.CONTACT_GROUP):
        mark.queue_free()
    var replacement := MELEE.spawn_hit(arena, Vector2.ZERO, Vector2.RIGHT, &"attack_1")
    _check(replacement != null, "Queued cosmetic deletion releases capacity immediately")
    arena.queue_free()
    await process_frame
    await process_frame
    _check(get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty() and get_nodes_in_group("hostile_attack").is_empty(), "Scene retirement clears both groups without a static reference cache")
    var fresh := Node2D.new()
    root.add_child(fresh)
    var mark := MELEE.spawn_hit(fresh, Vector2.ZERO, Vector2.RIGHT, &"attack_1")
    _check(mark != null, "Next scene starts with its full cosmetic budget")
    if mark != null:
        mark._process(0.1)
        _check(not mark.is_queued_for_deletion(), "Slow first process still preserves the contact's first draw opportunity")
        mark._process(0.1)
        _check(mark.is_queued_for_deletion(), "Contact mark then expires at the authored lifetime")
    fresh.queue_free()
    await process_frame

func _overlap_pixels() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(480, 300)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var arena := Node2D.new()
    arena.z_index = -30
    viewport.add_child(arena)
    var enemy := VisualEnemy.new()
    enemy.position = Vector2(100, 160)
    enemy.z_index = -200
    arena.add_child(enemy)
    enemy.set_physics_process(false)
    var command := {"id":"budget_probe", "type":"melee", "hit_width":100.0, "hit_height":60.0, "offset":50.0, "windup":2.0}
    for original in [false, true]:
        enemy.original_visual = original
        enemy._begin_attack(command)
        _check(enemy.windup_vfx != null and not enemy.windup_vfx.z_as_relative and enemy.windup_vfx.z_index == POLICY.WARNING_Z, "Warning ignores parent Z in visual mode %s" % original)
        if not original:
            _check(not enemy.telegraph.z_as_relative and enemy.telegraph.z_index == POLICY.WARNING_Z, "Filled telegraph shares protected warning layer")
    enemy._clear_telegraph()
    var beam: Node2D = enemy._effect("beam", Vector2(50, 90), Vector2.RIGHT, {"beam_length":300, "radius":10, "damage":2}, 0.5, 2.0)
    beam.set_physics_process(false)
    var orb: Node2D = enemy._effect("projectile", Vector2(200, 200), Vector2.ZERO, {"radius":16, "skin":"spore"}, 0.0, 2.0)
    orb.set_physics_process(false)
    orb.skin = "spore"
    await process_frame
    await RenderingServer.frame_post_draw
    var baseline := viewport.get_texture().get_image()
    var cover := Polygon2D.new()
    cover.polygon = PackedVector2Array([Vector2.ZERO, Vector2(480, 0), Vector2(480, 300), Vector2(0, 300)])
    cover.color = Color(0.12, 0.22, 0.32)
    cover.z_as_relative = false
    cover.z_index = POLICY.CONTACT_Z
    arena.add_child(cover)
    var contact := MELEE.spawn_hit(arena, Vector2(200, 200), Vector2.RIGHT, &"attack_2")
    if contact != null:
        contact.set_process(false)
    await process_frame
    await RenderingServer.frame_post_draw
    var warning_image := viewport.get_texture().get_image()
    _check(warning_image.get_pixel(180, 90).r > 0.6, "Beam warning draws over an opaque decorative layer (real GL pixel)")
    var projectile_equal := true
    var opaque_samples := 0
    var projectile_art := preload("res://scripts/projectile_art.gd")
    var pixels := projectile_art.ATLAS.get_image()
    var source_rect: Rect2 = projectile_art.atlas_rect("spore", 0)
    for y in range(191, 210):
        for x in range(191, 210):
            # The 128px cel is rendered at 64px here; require all bilinear
            # neighbours to be opaque before asserting exact pixel equality.
            var u := int(source_rect.position.x) + 64 + (x - 200) * 2
            var v := int(source_rect.position.y) + 64 + (y - 200) * 2
            var opaque := true
            for dy in range(-1, 3):
                for dx in range(-1, 3):
                    if pixels.get_pixel(u + dx, v + dy).a < 1.0:
                        opaque = false
            if opaque:
                opaque_samples += 1
                if baseline.get_pixel(x, y) != warning_image.get_pixel(x, y):
                    projectile_equal = false
    _check(projectile_equal and opaque_samples >= 20, "Opaque authored projectile pixels remain identical under late contact/decoration (real GL)")
    beam.age = beam.arm_delay + 0.01
    beam.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    var active_image := viewport.get_texture().get_image()
    _check(active_image.get_pixel(180, 90).r > 0.6, "Armed beam remains visible above decoration (real GL pixel)")
    _check(beam.damage == 2 and is_equal_approx(beam.arm_delay, 0.5) and is_equal_approx(beam.length, 300.0), "Visual priority preserves damage, warning timing and beam reach")
    viewport.queue_free()
    await process_frame
    await process_frame
