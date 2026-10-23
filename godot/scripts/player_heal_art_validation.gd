extends SceneTree
## Positioned production-Player fixture. Artificial injury/loadouts are component setup only.
const ART := preload("res://scripts/player_heal_art.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const BUILD := preload("res://scripts/build_system.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
var player: CharacterBody2D
var stage: Node2D
var build: RefCounted
var checks := 0
var failures := 0
var output := ""
var events: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error("HEAL_ART: " + label)
func frames(count: int = 2) -> void:
    for i in count: await physics_frame; await process_frame
func artwork() -> Array:
    return player.get_children().filter(func(n): return n.has_meta("player_heal_art") and not n.is_queued_for_deletion())
func family(name: String) -> bool:
    return artwork().size() == 1 and artwork()[0].family == name
func record_event(state: String) -> void: events.append(state)
func cancel_payment(_energy: int, _maximum: int) -> void:
    player.energy_changed.disconnect(cancel_payment)
    player._interrupt_heal()
func capture(label: String) -> void:
    if output.is_empty(): return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native save " + label)
func setup(crest: String = "crimson", injured: bool = true) -> void:
    for action in ["heal","jump","dash","move_left","move_right"]: Input.action_release(action)
    player.ui_input_locked = false
    build.state.crest = crest
    player.apply_build_stats(build.profile())
    player.restore_at_save_point()
    player.position = Vector2(480,360)
    player.velocity = Vector2.ZERO
    player.set_meta("accessibility",{"flash_enabled":true})
    if injured: player.hp = player.max_hp - 2
    events.clear()
    await frames(4)
func begin() -> void:
    Input.action_press("heal"); await frames(3); Input.action_release("heal")
func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
    root.size = Vector2i(960,540); root.content_scale_size = Vector2i(960,540)
    stage = Node2D.new(); root.add_child(stage)
    var backdrop := Polygon2D.new(); backdrop.polygon = PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,540),Vector2(0,540)]); backdrop.color = Color("18242b"); stage.add_child(backdrop)
    var floor_body := StaticBody2D.new(); floor_body.position = Vector2(480,380)
    var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size = Vector2(2000,40); shape.shape = box; floor_body.add_child(shape); stage.add_child(floor_body)
    var floor_paint := Polygon2D.new(); floor_paint.polygon = PackedVector2Array([Vector2(0,360),Vector2(960,360),Vector2(960,540),Vector2(0,540)]); floor_paint.color = Color("344048"); stage.add_child(floor_paint)
    player = load("res://scenes/Player.tscn").instantiate()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--heal-player-script="): player.set_script(load(argument.trim_prefix("--heal-player-script=")))
    stage.add_child(player)
    for child in player.get_children():
        if child is Camera2D: child.enabled = false
    player.feel = null
    build = BUILD.new(); build.state.unlocked_crests = build.catalog.crests.keys(); build.state.mechanisms = ["crimson","bell","salt"]
    player.build_system = build
    player.heal_state_changed.connect(record_event)
    await frames(4)
    check(ART.ATLAS.get_size() == Vector2(1536,576),"bounded shared atlas")
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/player_heal/manifest.json"))
    for family_name in ART.FAMILIES:
        var distinct := {}
        for i in manifest.sources[family_name].frames.size():
            var image := ART.ATLAS.get_image().get_region(Rect2i(ART.frame_rect(family_name,i)))
            check(not image.is_invisible(),family_name+" actual delivered cel " + str(i))
            distinct[image.get_data().hex_encode().sha256_text()] = true
        check(distinct.size() == manifest.sources[family_name].frames.size(),family_name+" distinct real frames")
    for crest in ["crimson","bell","salt"]:
        await setup(crest)
        var row: Dictionary = build.catalog.crests[crest]
        check(player.heal_energy_cost == row.heal_cost and player.heal_amount == row.heal_amount and is_equal_approx(player.heal_duration,row.heal_duration),crest+" authored treatment unchanged")
        var hp_before: int = player.hp
        await begin()
        check(player.heal_timer > 0 and player.heal_reserved_cost == row.heal_cost and player.energy == 100-int(row.heal_cost) and player.hp == hp_before,crest+" actual H reserves once without early HP")
        check(family("channel"),crest+" paid lifecycle has authored channel")
        if family("channel"): check(artwork()[0].z_index == 45 and not artwork()[0].z_as_relative,crest+" world-visible absolute45 below danger")
        await frames(7); await capture(crest+"_channel")
        check(player.sprite.animation == &"heal",crest+" existing heal action pose unchanged")
        await frames(int(ceil(player.heal_duration*60))+2)
        check(player.hp == mini(player.max_hp,hp_before+int(row.heal_amount)) and player.heal_reserved_cost == 0 and player.energy == 100-int(row.heal_cost),crest+" true completion settles exactly once")
        check(events == ["started","completed"] and family("complete"),crest+" only successful HP settlement produces completion")
        await capture(crest+"_complete")
        await frames(22); check(artwork().is_empty(),crest+" completion expires")
        await setup(crest); hp_before = player.hp; await begin()
        Input.action_press("move_right"); await frames(2); Input.action_release("move_right")
        var loss := int(ceil(float(row.heal_cost)*float(row.heal_interrupt_loss_ratio)))
        check(player.heal_timer <= 0 and player.hp == hp_before and player.energy == 100-loss,crest+" actual movement cancels using original reservation loss")
        check(events == ["started","interrupted"] and family("interrupt"),crest+" real cancellation produces distinct torn stitch")
        await frames(3); await capture(crest+"_interrupt")
        await frames(18); check(artwork().is_empty(),crest+" interruption expires without late heal")
        await setup(crest)
        player.position = Vector2(480,-1000); await frames(2)
        var allowed: bool = row.get("heal_airborne",false)
        Input.action_press("heal"); await frames(3); Input.action_release("heal")
        check((player.heal_timer > 0) == allowed,crest+" airborne actual input follows existing seal restriction")
        check(family("channel") if allowed else artwork().is_empty(),crest+" rejected airborne input has no interrupt flash")
    await setup()
    for reason in ["full","energy","busy"]:
        player._reset_traversal_state(); player.heal_cooldown = 0; events.clear()
        player.hp = player.max_hp if reason == "full" else player.max_hp-2
        player.energy = 0 if reason == "energy" else 100
        player.attack_timer = .5 if reason == "busy" else 0
        check(not player._try_heal() and artwork().is_empty() and events.is_empty(),reason+" rejected attempt creates no interruption or success")
    for action in ["jump","dash"]:
        await setup(); await begin(); Input.action_press(action); await frames(2); Input.action_release(action)
        check(player.heal_timer <= 0 and family("interrupt") and not events.has("completed"),action+" actual input interrupts and never completes")
    await setup(); await begin()
    var hp_before: int = player.hp
    player.arrival_guard_timer = 0
    player.take_damage(1,player.global_position+Vector2(80,0),false)
    check(player.hp == hp_before-1 and player.heal_timer <= 0 and family("interrupt"),"real damage path cancels paid channel")
    await setup("bell"); await begin()
    build.state.crest = "salt"; player.apply_build_stats(build.profile())
    check(player.heal_timer <= 0 and player.energy == 60 and family("interrupt"),"build replacement settles bell's half loss before applying salt")
    await setup(); await begin()
    var timer: float = player.heal_timer
    var frame_before: int = artwork()[0].frame if family("channel") else -1
    paused = true; await frames(6)
    check(is_equal_approx(timer,player.heal_timer) and family("channel") and artwork()[0].frame == frame_before,"pause freezes actual channel and its cel")
    paused = false
    player._reset_traversal_state(); check(artwork().is_empty(),"traversal cancel leaves no new presentation")
    await setup(); player.set_meta("accessibility",{"flash_enabled":false}); player._try_heal()
    check(family("channel") and artwork()[0].frame == 2 and artwork()[0].opacity <= .34,"low-flash channel bounded before first process/draw")
    await capture("reduced_channel_first")
    player._interrupt_heal()
    check(family("interrupt") and artwork()[0].frame == 3 and artwork()[0].opacity <= .4,"low-flash interrupt bounded before first process/draw")
    await capture("reduced_interrupt_first")
    await setup(); player.set_meta("accessibility",{"flash_enabled":false}); player.set_physics_process(false); player._try_heal(); player._update_heal(player.heal_duration)
    check(family("complete") and artwork()[0].frame == 3 and artwork()[0].opacity <= .4,"low-flash completion bounded before first process/draw")
    await capture("reduced_complete_first"); player.set_physics_process(true)
    await setup()
    player.energy_changed.connect(cancel_payment)
    check(not player._try_heal() and player.heal_timer <= 0 and not family("channel") and not family("complete"),"reentrant payment cancellation cannot attach stale channel or success")
    await setup(); await begin()
    var old_generation: int = player.heal_reservation_generation
    player._interrupt_heal(); player.heal_cooldown=0; player.energy=100
    check(player._try_heal() and player.heal_reservation_generation > old_generation and family("channel"),"replacement reservation owns exactly the new channel")
    if family("channel"): check(artwork()[0].reservation == player.heal_reservation_generation,"channel belongs to current reservation generation")
    await setup(); var fillers: Array[Node2D] = []
    for i in 12:
        var node := Node2D.new(); check(POLICY.attach_secondary(stage,node,&"state",stage),"shared state budget fill"); fillers.append(node)
    hp_before = player.hp; await begin()
    check(artwork().is_empty() and player.heal_timer > 0,"full cosmetic budget still permits paid H")
    await frames(40)
    check(player.hp == hp_before+1 and player.energy == 40 and artwork().is_empty(),"budget exhaustion cannot change successful healing")
    for node in fillers: node.queue_free()
    await setup(); await begin(); player.death_timer = .5; await frames(2)
    check(artwork().is_empty(),"death suppresses channel before draw")
    await setup(); await begin()
    RETIREMENT.retire_tree(stage); stage.queue_free(); await frames(5)
    AUDIO._stream_cache.clear(); AUDIO._npc_voice_cache.clear()
    check(get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty(),"scene teardown releases presentation budget")
    check(await RETIREMENT.drain(self),"observed fixture audio retirement")
    print("PLAYER_HEAL_ART checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
