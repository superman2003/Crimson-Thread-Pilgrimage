extends SceneTree
## Real Player routing, finite lifetime and packaged texture acceptance.
const VFX := preload("res://scripts/player_basic_attack_vfx.gd")
const MELEE := preload("res://scripts/player_melee_feedback.gd")
class QuietPlayer extends "res://scripts/player_controller.gd":
    func _play_sfx(_key: String, _volume: float = -5.0, _pitch: float = 1.0, _voice_key: String = "", _priority: int = 1) -> void:
        pass

var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func new_player(parent: Node2D):
    var player = load("res://scenes/Player.tscn").instantiate()
    player.set_script(QuietPlayer)
    parent.add_child(player)
    player.set_physics_process(false)
    player.set_process(false)
    player.feel = null
    player.get_node("Camera2D").enabled = false
    return player

func run() -> void:
    var arena := Node2D.new()
    root.add_child(arena)
    var player = new_player(arena)
    for key in [&"right", &"left", &"up", &"down", &"air_up", &"air_down"]:
        check(VFX.FRAMES.has_animation(key), "Packaged effect exists: " + key)
        check(not VFX.FRAMES.get_animation_loop(key), "Basic slash is finite: " + key)
        var count := VFX.FRAMES.get_frame_count(key)
        check(count >= 3, "Effect contains several drawable frames: " + key)
        for index in count:
            var texture := VFX.FRAMES.get_frame_texture(key, index)
            var image := texture.get_image()
            check(image != null and not image.is_empty() and image.get_used_rect().size != Vector2i.ZERO, "Imported cel has visible pixels: %s/%d" % [key, index])
    for airborne in [false, true]:
        for facing in [1, -1]:
            for direction in [Vector2(facing, 0), Vector2.UP, Vector2.DOWN]:
                player.facing = facing
                player.sprite.flip_h = facing < 0
                player._start_attack(&"attack_1", false, direction)
                player.attack_started_grounded = not airborne
                var before: Array = [player.attack_duration, player.attack_damage, player.attack_range, player.attack_height, player.attack_windup, player.attack_active_time, player.energy, player.hp]
                player._update_attack(player.attack_windup + 0.001)
                player._update_attack_pose()
                var effect = player.get_node_or_null("AttackSlashVfx")
                check(effect is Node2D and effect.has_method("_build_ribbon"), "Production active boundary uses a blade-driven textured ribbon")
                effect.set_process(false)
                effect._process(0.001)
                check(effect.effect == VFX.effect_key(direction, airborne), "Direction and ground/air select the correct Forge texture")
                var blade := MELEE.blade_points(player.sprite, player.sprite.frame, player)
                check(not effect.is_queued_for_deletion() and blade.size() == 2 and effect.blade[0].is_equal_approx(blade[0]), "Generated effect samples the displayed weapon grip")
                check(not effect.quads.is_empty() and effect.quads.back()[2].is_equal_approx(blade[1]), "Bright leading edge ends at the actual steel tip in every facing")
                check(before == [player.attack_duration, player.attack_damage, player.attack_range, player.attack_height, player.attack_windup, player.attack_active_time, player.energy, player.hp], "Visual routing preserves combat values")
                var old_quads: Array = effect.quads.duplicate(true)
                effect._process(VFX.TRAIL_SECONDS + 0.001)
                check(not effect.visible and effect.quads == old_quads, "Held character pose cannot independently sweep or keep emitting")
                player.sprite.frame = 3
                effect._process(0.001)
                blade = MELEE.blade_points(player.sprite, 3, player)
                check(effect.visible and effect.quads.back()[2].is_equal_approx(blade[1]), "Next cutting pose renews only its measured blade sweep")
                player.sprite.scale *= Vector2(0.86, 1.14)
                effect._process(0.001)
                blade = MELEE.blade_points(player.sprite, 3, player)
                check(effect.quads.back()[2].is_equal_approx(blade[1]), "Pogo scale keeps the trail on the transformed sword tip")
                player.sprite.scale = player.sprite_base_scale
                player.attack_timer = player.attack_duration - player.attack_windup - player.attack_active_time - 0.001
                effect._process(0.001)
                check(effect.is_queued_for_deletion(), "Slash cannot outlive the active window")
                await process_frame
    # Exercise every authored basic-cut family, including standing and running
    # horizontal poses rather than only the airborne no-floor fixture above.
    for pose in [&"attack_1", &"run_attack", &"air_attack", &"up_attack", &"air_up_attack", &"ground_down_attack", &"down_attack"]:
        for facing in [1, -1]:
            player._reset_traversal_state()
            player._start_attack(&"attack_1", false, Vector2.RIGHT)
            player.attack_timer = player.attack_duration - player.attack_windup - 0.001
            player.sprite.animation = pose
            player.sprite.frame = 1
            player.sprite.flip_h = facing < 0
            var effect = VFX.spawn(player, player.sprite, Vector2(facing, 0), false, player.attack_active_time)
            effect.set_process(false)
            effect._process(0.001)
            check(not effect.visible and effect.quads.is_empty(), "Wind-up cannot draw a free-floating slash: " + pose)
            for cel in [2, 3]:
                player.sprite.frame = cel
                effect._process(0.001)
                var endpoints := MELEE.blade_points(player.sprite, cel, player)
                check(effect.visible and effect.quads.back()[2].is_equal_approx(endpoints[1]), "Authored cel anchors the trail to the steel: %s/%d/%d" % [pose, cel, facing])
            player.sprite.frame = 4
            effect._process(0.001)
            check(not effect.visible and effect.is_queued_for_deletion(), "Recovery cannot emit or retain a slash: " + pose)
            await process_frame
    for cause in ["hurt", "death", "handoff", "overlay", "skill", "unsupported_pose"]:
        player._reset_traversal_state()
        player.facing = 1
        player._start_attack(&"attack_1", false, Vector2.RIGHT)
        player._update_attack(player.attack_windup + 0.001)
        player._update_attack_pose()
        var effect = player.get_node("AttackSlashVfx")
        effect.set_process(false)
        match cause:
            "hurt": player.hurt_timer = 0.1
            "death": player.death_timer = 0.1
            "handoff": player.prepare_region_handoff()
            "overlay": player.ui_input_locked = true
            "skill": player.active_skill = {"id":"cleave", "kind":"melee"}
            "unsupported_pose": player.sprite.animation = &"idle"
        effect._process(0.001)
        check(effect.is_queued_for_deletion(), "Interrupted slash cancels immediately: " + cause)
        player.hurt_timer = 0.0
        player.death_timer = 0.0
        player.ui_input_locked = false
        await process_frame
    player._reset_traversal_state()
    player._start_attack(&"attack_1", false, Vector2.RIGHT)
    player._update_attack_pose()
    var reduced := VFX.spawn(player, player.sprite, Vector2.RIGHT, false, 0.18, {"flash_enabled":false})
    check(reduced.reduced_flash, "Reduced-flash setting dims the generated pixels")
    check(VFX.spawn(player, player.sprite, Vector2.RIGHT, false, 0.0) == null, "Inactive attacks cannot create a slash")
    reduced.queue_free()
    await process_frame
    var fillers: Array[Node2D] = []
    for index in VFX.POLICY.MAX_ACTION_TRACES:
        var filler := Node2D.new()
        if VFX.POLICY.attach_action_trace(arena, filler): fillers.append(filler)
    check(fillers.size() == VFX.POLICY.MAX_ACTION_TRACES, "Cosmetic trace fixtures fill the existing global budget")
    check(VFX.spawn(player, player.sprite, Vector2.RIGHT, false, 0.18) == null, "Full global trace budget rejects only the new cosmetic ribbon")
    fillers[0].queue_free()
    var admitted := VFX.spawn(player, player.sprite, Vector2.RIGHT, false, 0.18)
    check(admitted != null and admitted.z_index == VFX.POLICY.BLADE_Z and not admitted.z_as_relative, "Retired trace releases a slot and preserves the protected absolute blade Z")
    player._reset_traversal_state()
    check(admitted.is_queued_for_deletion() and not admitted.visible, "Existing player reset clears the new ribbon through its owner metadata")
    arena.queue_free()
    await process_frame
    await process_frame
    print("PLAYER_BASIC_ATTACK_VFX checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
