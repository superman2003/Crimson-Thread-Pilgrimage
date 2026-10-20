extends RefCounted
## Authored pixels plus production tool physics; registered by tool_practice.
const ART := preload("res://scripts/player_tool_art.gd")
const EFFECT := preload("res://scripts/player_tool_effect.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0
var manifest: Dictionary

class Target extends Node2D:
    var active := true
    var hits := 0
    var damage := 0
    var trips: Array[float] = []
    var interference: Array[float] = []
    var investigations: Array[Vector2] = []
    func world_residency_active() -> bool: return active
    func get_hurtbox_rect() -> Rect2: return Rect2(global_position - Vector2(10, 10), Vector2(20, 20))
    func take_hit(amount: int, _direction: int) -> void: hits += 1; damage += amount
    func apply_trip(seconds: float) -> void: trips.append(seconds)
    func apply_target_interference(seconds: float) -> void: interference.append(seconds)
    func investigate_lure(point: Vector2, _seconds: float) -> void: investigations.append(point)

class Reference extends Node2D:
    var source := Rect2()
    var destination := Rect2()
    var mirror := 1.0
    var opacity := 1.0
    func _draw() -> void:
        draw_set_transform(Vector2.ZERO, 0, Vector2(mirror, 1))
        draw_texture_rect_region(ART.ATLAS, destination, source, Color(1, 1, 1, opacity))
        draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("PLAYER_TOOL_ART: " + label)

func effect(stage: Node, owner_node: Node2D, id: String, point: Vector2 = Vector2.ZERO) -> Node2D:
    var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_catalog.json"))
    var node := EFFECT.new()
    node.payload = catalog.tools[id].duplicate(true)
    node.payload.id = id
    node.owner_player = owner_node
    node.position = point
    stage.add_child(node)
    node.set_physics_process(false)
    return node

func target(stage: Node, point: Vector2, active: bool = true) -> Target:
    var node := Target.new()
    node.position = point
    node.active = active
    stage.add_child(node)
    node.add_to_group("enemy")
    return node

func clear_marks(tree: SceneTree) -> void:
    for mark in tree.get_nodes_in_group(POLICY.CONTACT_GROUP): mark.queue_free()
    await tree.process_frame

func run(tree: SceneTree) -> int:
    manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/player_tools/manifest.json"))
    check(manifest.families == ART.FAMILIES and manifest.frame_count == 28, "four delivered families and twenty-eight frames")
    var image := ART.ATLAS.get_image()
    check(image.get_size() == Vector2i(2048, 1024), "bounded eight MiB RGBA atlas")
    for family in ART.FAMILIES:
        var distinct: Dictionary = {}
        for frame in range(4 if family == "lure" else 8):
            var rect: Array = manifest.sources[family].frames[frame].atlas_rect
            check(ART.atlas_rect(family, frame) == Rect2(rect[0], rect[1], rect[2], rect[3]), "%s/%d uses delivered rectangle" % [family, frame])
            var cel := image.get_region(Rect2i(ART.atlas_rect(family, frame)))
            check(not cel.is_invisible(), "%s/%d has authored pixels" % [family, frame])
            distinct[cel.get_data().hex_encode().sha256_text()] = true
        check(distinct.size() == (4 if family == "lure" else 8), family + " preserves every distinct source frame")
    check(ART.family_for({"id": "mine", "skill_effect": true}) == "" and ART.family_for({"id": "unknown"}) == "", "skill and unknown payloads cannot select tool art")
    check(ART.active_frame("shard", .1) == 1 and ART.active_frame("shard", .1, true, .3) == 2 and ART.active_frame("shard", .1, true, .1) == 3, "jar flight and original warning clock select separate stages")
    check(ART.active_frame("mine", 0) == 0 and ART.active_frame("mine", .1) == 1 and ART.active_frame("mine", .18) == 2 and ART.active_frame("mine", .26) == 1, "mine placement followed by two armed cels")
    check(ART.active_frame("fog", .01) == 0 and ART.active_frame("fog", .1) == 1 and ART.active_frame("fog", .5) == 2, "fog growth followed by four-frame loop")
    await pixels(tree)
    await physics(tree)
    await casts(tree)
    print("PLAYER_TOOL_ART_VALIDATION checks=%d failures=%d families=4 frames=28" % [checks, failures])
    return failures

func pixels(tree: SceneTree) -> void:
    check(DisplayServer.get_name() != "headless", "real GL required for tool source readback")
    if DisplayServer.get_name() == "headless": return
    var view := SubViewport.new()
    view.size = Vector2i(800, 360)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    tree.root.add_child(view)
    var stage := Node2D.new(); view.add_child(stage)
    var background := Polygon2D.new()
    background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(800, 0), Vector2(800, 360), Vector2(0, 360)])
    stage.add_child(background)
    var owner_node := CharacterBody2D.new(); stage.add_child(owner_node)
    var reference := Reference.new(); reference.position = Vector2(600, 180); stage.add_child(reference)
    for family in ART.FAMILIES:
        var node := effect(stage, owner_node, family, Vector2(200, 180))
        for light in [false, true]:
            background.color = Color(.89, .87, .8) if light else Color(.08, .12, .14)
            for direction in [-1, 1]:
                var distinct: Dictionary = {}
                for frame in range(4 if family == "lure" else 8):
                    node.hide()
                    var mark: Node2D = null
                    var terminal: bool = family == "lure" or family == "shard" and frame >= 4 or family == "mine" and frame >= 3 or family == "fog" and frame >= 6
                    var opacity := 1.0
                    if terminal:
                        var reason := "ring" if family == "lure" else "expiry" if family == "fog" else "trigger"
                        mark = ART.spawn_terminal(stage, node.position, family, direction, reason)
                        mark.set_process(false)
                        mark.age = (frame - mark.first) / 16.0 + .001
                        opacity = clampf((mark.count / 16.0 - mark.age) * 16, 0, 1)
                        mark.queue_redraw()
                        reference.modulate = Color.WHITE
                    else:
                        node.show(); node.direction = direction
                        node.elapsed = frame / 12.0 + .001
                        node.landed = family == "shard" and frame >= 2
                        node.warning_timer = .3 if frame == 2 else .1
                        node.modulate = Color(1, .45, .15) if node.landed else Color.WHITE
                        node.queue_redraw()
                        reference.modulate = node.modulate
                    var meta: Dictionary = manifest.sources[family].frames[frame]
                    var rect: Array = meta.atlas_rect
                    reference.source = Rect2(rect[0], rect[1], rect[2], rect[3])
                    var factor := float(meta.native_width) / float(meta.body_width)
                    var anchor := Vector2(meta.packed_anchor[0], meta.packed_anchor[1])
                    var offset := Vector2(0, 6 if family == "mine" else 42 if family == "lure" else 0)
                    reference.destination = Rect2(offset - anchor * factor, Vector2(256, 256) * factor)
                    reference.mirror = -1 if family == "shard" and direction < 0 else 1
                    reference.opacity = opacity * float(manifest.sources[family].opacity); reference.queue_redraw()
                    await tree.process_frame; await RenderingServer.frame_post_draw
                    var rendered := view.get_texture().get_image()
                    var actual := rendered.get_region(Rect2i(40, 30, 320, 300))
                    var expected := rendered.get_region(Rect2i(440, 30, 320, 300))
                    var a := actual.get_data(); var b := expected.get_data(); var max_error := 0
                    for index in range(a.size()): max_error = maxi(max_error, absi(int(a[index]) - int(b[index])))
                    check(max_error <= 1, "%s/%d direction=%d light=%s draws independent source pixels" % [family, frame, direction, light])
                    distinct[a.hex_encode().sha256_text()] = true
                    if frame == 1:
                        var visible := 0
                        for y in range(300):
                            for x in range(320):
                                var pixel := actual.get_pixel(x, y)
                                if Vector3(pixel.r - background.color.r, pixel.g - background.color.g, pixel.b - background.color.b).length() > .1: visible += 1
                        check(visible > 30, family + " reads at actual gameplay size")
                    if mark != null: mark.queue_free()
                    await tree.process_frame
                check(distinct.size() == (4 if family == "lure" else 8), family + " visibly changes across every phase")
        node.queue_free(); await tree.process_frame
    view.queue_free(); await tree.process_frame; await tree.process_frame

func physics(tree: SceneTree) -> void:
    var stage := Node2D.new(); tree.root.add_child(stage)
    var owner_node := CharacterBody2D.new(); stage.add_child(owner_node)
    var shard := effect(stage, owner_node, "shard", Vector2(100, -200))
    shard._physics_process(.1)
    check(shard.global_position.distance_to(Vector2(129, -220)) < .001 and shard.ballistic_velocity == Vector2(290, -200), "jar preserves original velocity and 700px/s2 gravity")
    check(shard.targets.is_empty() and not shard.landed, "airborne jar cannot damage")
    shard.queue_free(); await tree.process_frame
    var wall := StaticBody2D.new(); wall.position = Vector2(300, 0)
    var shape := RectangleShape2D.new(); shape.size = Vector2(10, 300)
    var collider := CollisionShape2D.new(); collider.shape = shape; wall.add_child(collider); stage.add_child(wall)
    await tree.physics_frame; await tree.process_frame
    var near := target(stage, Vector2(270, 0))
    # Keep the occluding wall separated from the emission surface: a native
    # ray starting exactly on a collider boundary need not hit that collider.
    var blocker := StaticBody2D.new(); blocker.position = Vector2(325, 0)
    var blocker_shape := CollisionShape2D.new(); blocker_shape.shape = shape; blocker.add_child(blocker_shape); stage.add_child(blocker)
    await tree.physics_frame; await tree.process_frame
    var behind := target(stage, Vector2(350, 0))
    var inactive := target(stage, Vector2(270, 0), false)
    shard = effect(stage, owner_node, "shard", Vector2(294, 0))
    shard.ballistic_velocity = Vector2(290, 0)
    shard._physics_process(.01)
    check(shard.landed and is_equal_approx(shard.global_position.x, 295) and near.hits == 0, "terrain ray stops jar and begins warning without damage")
    check(is_equal_approx(shard.warning_timer, .34) and shard.modulate == Color(1, .45, .15), "original .35s orange warning clock is preserved including landing tick")
    shard._physics_process(.16); check(near.hits == 0 and ART.active_frame("shard", shard.elapsed, true, shard.warning_timer) == 2, "early warning retains landed cel and no damage")
    shard._physics_process(.16); check(near.hits == 0 and ART.active_frame("shard", shard.elapsed, true, shard.warning_timer) == 3, "late warning changes cel without moving impact time")
    shard._physics_process(.03)
    check(near.hits == 1 and near.damage == 2 and behind.hits == 0 and inactive.hits == 0, "blast keeps damage, residency and terrain occlusion: near=%d damage=%d behind=%d inactive=%d" % [near.hits, near.damage, behind.hits, inactive.hits])
    check(shard.is_queued_for_deletion() and not shard.is_physics_processing() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 1, "damage retires before four safe blast frames")
    shard._physics_process(.01); check(near.hits == 1, "safe blast cannot repeat damage")
    near.queue_free(); behind.queue_free(); inactive.queue_free(); wall.queue_free(); blocker.queue_free()
    await clear_marks(tree); await tree.physics_frame
    near = target(stage, Vector2(84.9, 0)); var outside := target(stage, Vector2(85.1, 0))
    shard = effect(stage, owner_node, "shard")
    shard.landed = true; shard.warning_timer = 0
    shard._physics_process(.01)
    check(near.hits == 1 and outside.hits == 0, "blast preserves hurtbox growth by 75px")
    near.queue_free(); outside.queue_free(); await clear_marks(tree)
    var airborne := effect(stage, owner_node, "shard", Vector2(100, -200))
    airborne._physics_process(1.01)
    check(airborne.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(), "airborne jar expiry creates no false explosion")
    near = target(stage, Vector2(45.9, 0)); outside = target(stage, Vector2(46.1, 0))
    var mine := effect(stage, owner_node, "mine")
    check(mine.is_in_group("player_trap") and mine.z_index == POLICY.BLADE_Z and not mine.z_as_relative, "mine keeps trap membership below enemy danger")
    mine._physics_process(.001)
    check(near.damage == 3 and near.trips == [.7] and outside.hits == 0, "mine is armed immediately with original radius, damage and trip")
    check(mine.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 1, "trigger retires mine before five safe terminal cels")
    mine._physics_process(.1); check(near.hits == 1, "retired mine cannot trip twice")
    near.queue_free(); outside.queue_free(); await clear_marks(tree)
    var idle := effect(stage, owner_node, "mine")
    idle._physics_process(5.99); check(not idle.is_queued_for_deletion(), "idle mine preserves six-second duration")
    idle._physics_process(.02)
    check(idle.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP)[0].first == 6, "untriggered mine expires with fade, without a false wire snap")
    await clear_marks(tree)
    near = target(stage, Vector2(139.9, 0)); outside = target(stage, Vector2(140.1, 0)); inactive = target(stage, Vector2(0, 0), false)
    var fog := effect(stage, owner_node, "fog")
    fog._physics_process(.01); fog._physics_process(.1)
    check(near.interference == [2.0, 2.0] and near.hits == 0 and outside.interference.is_empty() and inactive.interference.is_empty(), "fog refreshes interference within original 130px hurtbox growth, with no damage")
    check(fog.global_position == Vector2.ZERO, "fog remains at original placement")
    fog._physics_process(3.9)
    check(fog.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 1, "four-second fog retires control before safe wisps")
    var prior := near.interference.size(); fog._physics_process(.1); check(near.interference.size() == prior, "cosmetic fade cannot refresh interference")
    near.queue_free(); outside.queue_free(); inactive.queue_free(); await clear_marks(tree)
    near = target(stage, Vector2(179.9, 0)); outside = target(stage, Vector2(180.1, 0)); inactive = target(stage, Vector2(0, 0), false)
    var lure := effect(stage, owner_node, "lure")
    lure._physics_process(.01)
    check(near.investigations == [Vector2.ZERO] and outside.investigations.is_empty() and inactive.investigations.is_empty() and near.hits == 0, "lure uses catalog range 180, one investigation, no damage")
    check(lure.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 1, "one-tick lure becomes four safe bell cels")
    lure._physics_process(.1); check(near.investigations.size() == 1, "ringing cannot repeat the AI command")
    near.queue_free(); outside.queue_free(); inactive.queue_free(); await clear_marks(tree)
    for family in ART.FAMILIES:
        var cancelled := effect(stage, owner_node, family); cancelled.queue_free()
    check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(), "external cancellation produces no trigger or expiry decoration")
    await tree.process_frame
    var orphan := effect(stage, owner_node, "lure")
    owner_node.queue_free(); await tree.process_frame; orphan._physics_process(.01)
    check(orphan.is_queued_for_deletion() and tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(), "freed owner retires tool without ringing")
    for family in ART.FAMILIES:
        var mark := ART.spawn_terminal(stage, Vector2(10, 20), family, -1, "ring" if family == "lure" else "expiry" if family == "fog" else "trigger")
        mark.set_process(false)
        var selected: Array[int] = []
        mark.paint = func(_host, _family, frame, _direction, _alpha): selected.append(frame)
        for frame in range(mark.count): mark.age = frame / 16.0 + .001; mark._draw()
        var wanted: Array[int] = []
        for frame in range(mark.count): wanted.append(mark.first + frame)
        check(selected == wanted, family + " terminal plays every delivered stage in order")
        check(not mark.is_in_group("player_trap") and not mark.is_in_group("player_snare_field"), "terminal holds no gameplay membership")
        mark.age = 0; mark._process(1); check(not mark.is_queued_for_deletion(), "slow first draw preserves terminal opening cel")
        mark._process(1); check(mark.is_queued_for_deletion(), "terminal has bounded lifetime")
    await clear_marks(tree)
    for i in range(20): ART.spawn_terminal(stage, Vector2.ZERO, "lure", 1, "ring")
    check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).size() == 12, "tool decoration obeys shared twelve-mark cap")
    var new_owner := CharacterBody2D.new(); stage.add_child(new_owner)
    near = target(stage, Vector2.ZERO)
    mine = effect(stage, new_owner, "mine"); mine._physics_process(.01)
    check(near.damage == 3 and near.trips == [.7], "saturated decoration budget cannot suppress real mine damage or control")
    stage.queue_free(); await tree.process_frame; await tree.process_frame
    check(tree.get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty(), "scene retirement releases every tool decoration")

func casts(tree: SceneTree) -> void:
    var stage := Node2D.new(); tree.root.add_child(stage)
    var player = load("res://scenes/Player.tscn").instantiate(); stage.add_child(player)
    player.set_physics_process(false)
    player.build_system = null
    var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_catalog.json"))
    var build := preload("res://scripts/build_system.gd").new()
    build.unlock_event("repair_crimson")
    for id in ART.FAMILIES:
        build.unlock_event("tool_%s_found" % id)
        var slot := 0 if id == "shard" else 1
        check(build.select_tool(id, slot).get("ok", false), id + " equips through actual build system")
        build.state.tool_counts[id] = 2
        var paid: Dictionary = build.use_tool(slot)
        check(paid.get("ok", false) and int(build.state.tool_counts[id]) == 1 and int(paid.damage) == int(catalog.tools[id].damage), id + " retains one-charge payment and catalog damage")
        build.state.tool_counts[id] = 0
        check(not build.use_tool(slot).get("ok", false) and int(build.state.tool_counts[id]) == 0, id + " cannot spend empty stock")
    for direction in [-1, 1]:
        for id in ART.FAMILIES:
            player._reset_traversal_state(); player.facing = direction; player.energy = 40
            var row: Dictionary = catalog.tools[id].duplicate(true); row.id = id
            check(player.cast_tool(row), id + " casts through actual public player action")
            var nodes: Array[Node2D] = []
            for node in stage.get_children():
                if node.get_script() == EFFECT and not node.is_queued_for_deletion(): nodes.append(node); node.set_physics_process(false)
            check(nodes.size() == 1, id + " emits exactly one effect")
            if nodes.size() == 1:
                var node: Node2D = nodes[0]
                check(node.tool_art_family == id and node.art_family.is_empty() and node.direction == direction, id + " reaches correct tool family and facing")
                check(node.payload == row and player.energy == 40, id + " keeps gameplay payload and never generates thread")
                var offset := Vector2(direction * 24, -6 if id == "mine" else -42)
                check(node.global_position.distance_to(player.global_position + offset) < .001, id + " retains public spawn anchor")
                node.queue_free()
            await tree.process_frame
    player._reset_traversal_state()
    var mine: Dictionary = catalog.tools.mine.duplicate(true); mine.id = "mine"
    check(player.cast_tool(mine), "first real mine is accepted")
    player._reset_traversal_state(); check(player.cast_tool(mine), "second real mine is accepted")
    player._reset_traversal_state(); check(not player.cast_tool(mine), "third real mine remains rejected")
    AUDIO.retire_tree(stage)
    stage.queue_free(); await tree.process_frame; await tree.process_frame
    check(await AUDIO.drain(tree), "actual cast fixture releases all audio playback before shutdown")
