extends SceneTree
## Positioned production-Player presentation and unchanged guard-mechanics checks.
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const ART := preload("res://scripts/player_guard_art.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
var checks := 0
var failures := 0
var stage: Node2D
var player: Node2D

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error("GUARD_ART: " + label)
func frames(count: int = 2) -> void:
    for i in count: await physics_frame; await process_frame
func guards() -> Array:
    return player.get_children().filter(func(n): return n.has_meta("player_guard_art") and not n.is_queued_for_deletion())
func reset() -> void:
    player._reset_traversal_state()
    player.velocity = Vector2.ZERO
    player.ui_input_locked = false
    player.hurt_timer = 0
    player.death_timer = 0
    player.arrival_guard_timer = 0
    player.energy = 100
    player.hp = player.max_hp
    player.bell_guard_unlocked = true
    player.active_skill.clear()

func _run() -> void:
    stage = Node2D.new(); root.add_child(stage)
    player = load("res://scenes/Player.tscn").instantiate()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--guard-player-script="):
            player.set_script(load(argument.trim_prefix("--guard-player-script=")))
    stage.add_child(player)
    await frames(3)
    player.set_physics_process(false)
    player.build_system = null
    player.feel = null
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/player_guard/manifest.json"))
    check(ART.ATLAS.get_size() == Vector2(1152, 576), "one bounded atlas for eighteen real delivered cels")
    for family in ART.FAMILIES:
        var distinct: Dictionary = {}
        for frame in 6:
            var image := ART.ATLAS.get_image().get_region(Rect2i(ART.frame_rect(family, frame)))
            check(not image.is_invisible(), family + " actual source pixels " + str(frame))
            distinct[image.get_data().hex_encode().sha256_text()] = true
            var rect: Array = manifest.sources[family].frames[frame].atlas_rect
            check(ART.frame_rect(family, frame) == Rect2(rect[0], rect[1], rect[2], rect[3]), "sidecar-derived frame registration")
        check(distinct.size() == 6, family + " six distinct authored frames")
    for direction in [-1, 1]:
        reset(); player.facing = direction
        check(player._try_guard(), "actual Q guard starts")
        check(player.energy == 92 and is_equal_approx(player.guard_timer, .42), "Q cost and duration unchanged")
        await frames()
        check(guards().size() == 1 and guards()[0].family == "raise", "Q creates authored half-shield rather than full ring")
        if guards().size() == 1:
            check(guards()[0].direction == direction and guards()[0].z_index == 60 and not guards()[0].z_as_relative, "facing and secondary layer policy")
        var hp: int = player.hp
        player.take_damage(1, player.global_position + Vector2(direction * 60, 0))
        check(player.hp == hp and player.energy == 96 and player.guard_refunded, "real front perfect guard retains refund and protection")
        check(guards().size() == 1 and guards()[0].family == "perfect", "actual perfect hit selects distinct delivered feedback")
        reset(); player.facing = direction; player._try_guard()
        player.guard_timer = .27
        player.take_damage(1, player.global_position + Vector2(direction * 60, 0))
        check(player.hp == hp and player.energy == 92 and not player.guard_refunded, "ordinary window has no perfect refund")
        check(guards().size() == 1 and guards()[0].family == "block", "ordinary hit selects its own authored feedback")
        reset(); player.facing = direction; player._try_guard()
        player.take_damage(1, player.global_position - Vector2(direction * 60, 0))
        check(player.hp == hp - 1 and guards().is_empty(), "rear hit remains unprotected and retires all guard presentation")
        reset(); player.facing = direction; player._try_guard()
        player.take_damage(1, player.global_position + Vector2(direction * 60, 0), false)
        check(player.hp == hp - 1 and guards().is_empty(), "unblockable hit remains damaging and clears presentation")
    for duration in [.3, .5, .9]:
        reset(); player.active_skill = {"kind": "defense", "duration": duration}; player._apply_special_skill()
        check(is_equal_approx(player.guard_timer, minf(.65, duration)), "ward keeps its actual configured duration")
        await frames()
        check(guards().size() == 1 and guards()[0].family == "raise", "ward uses the same front shield for its real window")
        player.guard_timer = 0
        await frames()
        check(guards().is_empty(), "ward visual stops at actual expiry")
    reset()
    player.position = Vector2(410, 180)
    player.wall_grip_unlocked = true
    var wall := StaticBody2D.new()
    wall.position = Vector2(440, 250)
    var shape := CollisionShape2D.new()
    var box := RectangleShape2D.new()
    box.size = Vector2(20, 500)
    shape.shape = box
    wall.add_child(shape)
    stage.add_child(wall)
    player.set_physics_process(true)
    Input.action_press("move_right")
    await frames(6)
    check(player.is_on_wall(), "actual wall contact for guard-turn input")
    player._try_guard()
    Input.action_press("jump")
    await frames(2)
    Input.action_release("jump")
    Input.action_release("move_right")
    check(player.guard_timer > 0 and player.facing == -1, "real wall-jump input changes facing during the live guard window")
    check(guards().size() == 1 and guards()[0].direction == player.facing, "held shield follows current protected side after actual turn")
    player.arrival_guard_timer = 0
    var turn_hp: int = player.hp
    player.take_damage(1, player.global_position + Vector2(-60, 0))
    check(player.hp == turn_hp and guards().size() == 1 and guards()[0].family == "perfect", "front protection follows actual turned facing")
    player.set_physics_process(false)
    wall.queue_free()
    reset()
    player.position = Vector2(600, 200)
    player.set_physics_process(true)
    Input.action_press("move_right"); await frames(3); Input.action_release("move_right")
    Input.action_press("bell_guard"); await frames(3); Input.action_release("bell_guard")
    Input.action_press("move_left"); await frames(5)
    check(player.guard_timer > 0 and player.facing == 1, "actual Q plus reverse movement preserves locked guard facing")
    await frames(30)
    check(player.guard_timer <= 0 and player.facing == -1, "actual reverse movement turns after guard expiry")
    Input.action_release("move_left")
    reset()
    player.configure_selected_skill({"id":"ward", "kind":"defense", "energy_cost":8, "windup":.05, "duration":.5, "recovery":.1})
    Input.action_press("skill_1"); await frames(7); Input.action_release("skill_1")
    check(player.guard_timer > .35 and guards().size() == 1, "actual ward input raises shield after skill windup")
    await frames(35)
    check(player.guard_timer <= 0 and guards().is_empty(), "actual ward input expires with gameplay timer")
    player.set_physics_process(false)
    reset(); player.set_meta("accessibility", {"flash_enabled": false}); player._try_guard()
    check(guards().size() == 1 and guards()[0].frame == 2 and guards()[0].opacity <= .65, "reduced shield initialized before first draw without awaiting process")
    await frames()
    if guards().size() == 1:
        check(guards()[0].frame == 2 and guards()[0].opacity <= .65, "reduced-flash shield has stable held cel and bounded opacity")
    else: check(false, "reduced-flash shield is present")
    player.take_damage(1, player.global_position + Vector2(player.facing * 60, 0))
    check(guards().size() == 1 and guards()[0].frame == 3 and guards()[0].opacity <= .55, "reduced contact initialized before first draw without awaiting process")
    var impact_direction: int = player.facing
    player.facing = -player.facing
    await frames()
    check(guards().size() == 1 and guards()[0].direction == impact_direction, "resolved contact retains impact-side snapshot after turning")
    if guards().size() == 1: check(guards()[0].frame == 3 and guards()[0].opacity <= .55, "reduced perfect feedback avoids bright animated star sequence")
    else: check(false, "reduced perfect mark is present")
    reset(); await frames(); check(guards().is_empty(), "traversal reset clears raise and contact artwork")
    var fillers: Array[Node2D] = []
    for i in 12:
        var n := Node2D.new(); check(POLICY.attach_secondary(stage, n, &"state", stage), "state budget setup"); fillers.append(n)
    player._try_guard(); check(guards().is_empty() and is_equal_approx(player.guard_timer, .42), "full cosmetic budget cannot change gameplay guard")
    for n in fillers: n.queue_free()
    reset(); await frames()
    for i in 12:
        var n := Node2D.new(); check(POLICY.attach_contact(stage, n), "contact budget setup"); fillers.append(n)
    player._try_guard()
    var full_hp: int = player.hp
    player.take_damage(1, player.global_position + Vector2(player.facing * 60, 0))
    check(guards().is_empty() and player.hp == full_hp and player.guard_refunded, "full contact budget cannot alter perfect guard or refund")
    for n in fillers:
        if is_instance_valid(n): n.queue_free()
    reset(); await frames(); player._try_guard(); player.death_timer = 1; await frames(); check(guards().is_empty(), "death clears persistent shield")
    reset(); await frames(); player._try_guard(); var ref: WeakRef = weakref(player); RETIREMENT.retire_tree(stage); stage.queue_free(); await frames(5)
    check(ref.get_ref() == null, "owner and visual leave together on room teardown")
    check(get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty() and get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(), "no stale budget units after scene change")
    # Match the existing audio-retirement fixture: end intentional static cache ownership.
    AUDIO._stream_cache.clear(); AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self), "observed audio playback retirement completes")
    print("PLAYER_GUARD_ART checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
