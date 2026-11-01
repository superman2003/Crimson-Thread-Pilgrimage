extends SceneTree
## Rendered positioned component fixture; actual Input invokes Q and ward.
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const ART := preload("res://scripts/player_guard_art.gd")
var player: Node2D
var output := ""
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int = 2) -> void:
    for i in count: await physics_frame; await process_frame
func check(ok: bool, label: String) -> void:
    if not ok: failures += 1; push_error(label)
func guards() -> Array:
    return player.get_children().filter(func(n): return n.has_meta("player_guard_art") and not n.is_queued_for_deletion())
func reset(direction: int, reduced: bool = false) -> void:
    player._reset_traversal_state()
    player.position = Vector2(480, 360)
    player.velocity = Vector2.ZERO
    player.hp = player.max_hp
    player.energy = 100
    player.hurt_timer = 0
    player.arrival_guard_timer = 0
    player.ui_input_locked = false
    player.facing = direction
    player.set_meta("accessibility", {"flash_enabled":not reduced})
func capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    check(image.get_width() == 960 and image.get_height() == 540, "native fixture viewport dimensions")
    check(image.save_png(output.path_join(label + ".png")) == OK, "write " + label)
    print("GUARD_CAPTURE " + label + " facing=" + str(player.facing) + " guard=" + str(player.guard_timer))
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    check(not output.is_empty(), "explicit output")
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(960, 540)
    root.content_scale_size = Vector2i(960, 540)
    root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
    var stage := Node2D.new(); root.add_child(stage)
    var backdrop := Polygon2D.new(); backdrop.polygon = PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,540),Vector2(0,540)]); backdrop.color = Color("18242b"); stage.add_child(backdrop)
    var floor_body := StaticBody2D.new(); floor_body.position = Vector2(480,380)
    var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size = Vector2(960,40); shape.shape = box; floor_body.add_child(shape); stage.add_child(floor_body)
    var floor_paint := Polygon2D.new(); floor_paint.polygon = PackedVector2Array([Vector2(0,360),Vector2(960,360),Vector2(960,540),Vector2(0,540)]); floor_paint.color = Color("344048"); stage.add_child(floor_paint)
    player = load("res://scenes/Player.tscn").instantiate(); stage.add_child(player)
    for child in player.get_children():
        if child is Camera2D: child.enabled = false
    player.build_system = null; player.feel = null; player.bell_guard_unlocked = true
    await frames(3)
    for direction in [-1,1]:
        var side := "left" if direction < 0 else "right"
        reset(direction); await frames(3)
        await capture("baseline_" + side)
        Input.action_press("bell_guard"); await frames(3); Input.action_release("bell_guard")
        check(player.guard_timer > 0 and guards().size() == 1, "actual Q rendered")
        await frames(5); await capture("raise_" + side)
        while player.guard_timer >= player.guard_initial_duration - .14: await frames(1)
        player.take_damage(1,player.global_position + Vector2(direction * 60,0))
        check(guards().size() == 1 and guards()[0].family == "block", "ordinary contact selected")
        await frames(4); await capture("block_" + side)
        await frames(18)
        reset(direction); await frames(3)
        Input.action_press("bell_guard"); await frames(3); Input.action_release("bell_guard")
        player.take_damage(1,player.global_position + Vector2(direction * 60,0))
        check(guards().size() == 1 and guards()[0].family == "perfect", "perfect contact selected")
        await frames(4); await capture("perfect_" + side)
        await frames(18)
    reset(1,true); await frames(3)
    # Creation and capture occur before any process await: test first draw, not steady state.
    player._try_guard()
    check(guards().size() == 1 and guards()[0].frame == 2 and guards()[0].opacity <= .65, "low-flash first raise state")
    await capture("reduced_raise_first")
    player.take_damage(1,player.global_position + Vector2(60,0))
    check(guards().size() == 1 and guards()[0].frame == 3 and guards()[0].opacity <= .55, "low-flash first contact state")
    await capture("reduced_perfect_first")
    reset(1); await frames(3)
    player.configure_selected_skill({"id":"ward","kind":"defense","energy_cost":8,"windup":.05,"duration":.5,"recovery":.1})
    Input.action_press("skill_1"); await frames(7); Input.action_release("skill_1")
    check(player.guard_timer > .35 and guards().size() == 1,"actual ward rendered")
    await capture("ward_hold")
    player._reset_traversal_state(); await frames(2)
    check(guards().is_empty(),"cancel retires visual")
    await capture("cancelled")
    RETIREMENT.retire_tree(stage); stage.queue_free(); await frames(4)
    # Match the existing audio-retirement fixture: end intentional static cache ownership.
    AUDIO._stream_cache.clear(); AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self), "observed audio playback retirement completes")
    print("PLAYER_GUARD_CAPTURE failures=" + str(failures))
    quit(0 if failures == 0 else 1)
