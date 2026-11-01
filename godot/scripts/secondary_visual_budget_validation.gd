extends RefCounted
## Deliberate saturation fixtures, not natural combat or comfort acceptance.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const EFFECT := preload("res://scripts/player_tool_effect.gd")
var checks := 0
var failures := 0

class QuietPlayer extends "res://scripts/player_controller.gd":
    func _should_play_sfx() -> bool: return false

class VisualWorld extends "res://scripts/main_level.gd":
    func _ready() -> void:
        set_process(false)
        set_physics_process(false)

class Target extends Node2D:
    var damage := 0
    func get_hurtbox_rect() -> Rect2: return Rect2(global_position-Vector2(10,10),Vector2(20,20))
    func take_hit(amount: int, _direction: int) -> void: damage += amount

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("SECONDARY_VISUAL_BUDGET: " + label)

func live(tree: SceneTree, category: StringName = &"") -> Array:
    return tree.get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(item): return not item.is_queued_for_deletion() and (category == &"" or item.get_meta("secondary_category") == category))

func count_units(tree: SceneTree, category: StringName = &"") -> int:
    var count := 0
    for item in live(tree, category): count += int(item.get_meta("secondary_units", 1))
    return count

func run(tree: SceneTree) -> int:
    var arena := Node2D.new()
    tree.root.add_child(arena)
    var player = load("res://scenes/Player.tscn").instantiate()
    player.set_script(QuietPlayer)
    arena.add_child(player)
    player.set_physics_process(false)
    player.set_process(false)
    var base_children := arena.get_child_count()
    for attempt in 80: player._spawn_dash_ghost()
    check(arena.get_child_count()-base_children <= 12, "eighty real dash ghosts share twelve motion units")
    check(count_units(tree, &"motion") == 12, "real player ghosts register the shared motion budget")
    var ghosts := arena.get_children().filter(func(item): return item != player)
    var marked := live(tree, &"motion")
    if not marked.is_empty(): marked[0].queue_free()
    # The dash ribbon is now one authored node; keep the multi-piece batch rule.
    var pair: Array[Node2D] = [Node2D.new(), Node2D.new()]
    check(not POLICY.attach_secondary_batch(arena, pair, &"motion", player), "two-piece motion accent is rejected as a whole")
    check(count_units(tree, &"motion") == 11, "two-piece motion accent does not partially claim one remaining slot")
    var second = load("res://scenes/Player.tscn").instantiate()
    second.set_script(QuietPlayer)
    arena.add_child(second)
    second.set_physics_process(false)
    second.set_process(false)
    for attempt in 30: second._spawn_land_vfx()
    check(count_units(tree, &"motion") == 12, "another player shares the same scene budget and reuses a queued slot")
    player.dash_start_position = Vector2(-100, 0)
    player._spawn_dash_trail()
    check(count_units(tree, &"motion") == 12 and arena.get_node_or_null("PlayerDashRibbon") == null, "one-piece dash ribbon respects a full motion pool")
    for attempt in 40:
        player._spawn_double_jump_vfx()
        player._spawn_heal_effect()
        player._ability_ring(64, Color.WHITE)
        player._spawn_hook_trail_vfx()
        player._spawn_skill_slash_vfx()
        player._spawn_thread_snap_vfx(Vector2(-10,0))
    check(count_units(tree, &"state") == 12, "heal, ability and skill accents share twelve state units")
    check(count_units(tree) == 24, "mixed motion and state accents remain within twenty-four canvas units")
    check(player.get_child_count() < 45, "repeated production factories cannot retain hundreds of player children")
    for accent in live(tree):
        check(not accent.z_as_relative and accent.z_index < POLICY.CONTACT_Z, "cosmetic layers remain below contacts and dangers regardless of parent Z")
    # Full decoration pools cannot affect a real paid heal or dash state.
    var sfx := AudioServer.get_bus_index("SFX")
    var previous_db := AudioServer.get_bus_volume_db(sfx) if sfx >= 0 else 0.0
    if sfx >= 0: AudioServer.set_bus_volume_db(sfx, -80)
    player.build_profile = {"crest_id":"crimson", "heal_airborne":true}
    player.energy = player.max_energy
    player.hp = player.max_hp-2
    var old_hp: int = player.hp
    var old_energy: int = player.energy
    check(player._try_heal(), "full cosmetic budget permits the production heal reservation")
    player._update_heal(player.heal_duration+0.1)
    check(player.hp == mini(player.max_hp,old_hp+player.heal_amount) and player.energy == old_energy-player.heal_energy_cost, "real heal HP and exact paid thread settle while accents are rejected")
    player._start_dash()
    check(player.dash_timer == player.dash_time and player.velocity.x == player.dash_speed*player.facing, "full motion budget leaves actual dash duration and velocity intact")
    if sfx >= 0: AudioServer.set_bus_volume_db(sfx, previous_db)
    # Real skill damage remains outside the decoration admission path.
    var target := Target.new()
    target.position = Vector2(60,80)
    target.add_to_group("enemy")
    arena.add_child(target)
    for shot in 20:
        var effect := EFFECT.new()
        effect.payload = {"id":"needle", "kind":"projectile", "skill_effect":true, "damage":2, "range":200, "duration":1.0}
        effect.owner_player = player
        effect.position = Vector2(45,80)
        arena.add_child(effect)
        effect.set_physics_process(false)
        effect._physics_process(0.02)
    check(target.damage == 40, "all twenty real skill projectiles still deal damage with both cosmetic pools full")
    var world := VisualWorld.new()
    arena.add_child(world)
    # Release player categories without touching another owner's accent.
    player._reset_traversal_state()
    check(ghosts.all(func(item): return not is_instance_valid(item) or item.is_queued_for_deletion()), "traversal reset retires player-owned sibling ghosts")
    check(count_units(tree, &"motion") == 1, "reset leaves the other player's live accent intact")
    var initial_world_children := world.get_child_count()
    for attempt in 30:
        world._spawn_pickup_effect(Vector2(20,20))
        world._spawn_route_open_effect(Vector2(40,20))
    check(world.get_child_count()-initial_world_children <= 8 and count_units(tree,&"environment") == 8, "real pickup and route effects share eight environment units")
    var shrine := Area2D.new()
    var marker := Sprite2D.new();marker.name="SavePointSprite";shrine.add_child(marker)
    var ring := Line2D.new();ring.name="SavePointHalo";shrine.add_child(ring)
    world.add_child(shrine)
    world._play_save_point_activation(shrine)
    check(shrine.get_meta("activated",false) and marker.modulate == Color(1.0,0.94,0.78,1.0), "saturated environment still activates the actual shrine marker")
    var wall := StaticBody2D.new();wall.name="fixture_post_boss_wall";world.add_child(wall)
    world.config = {"platforms":[{"id":"fixture_post_boss_wall"}]}
    world._open_post_boss_route()
    check(world.post_boss_route_open and wall.is_queued_for_deletion(), "saturated opening accents never retain the real route blocker")
    check(count_units(tree) <= 24, "environment cannot overrun the global unit budget")
    await tree.create_timer(0.9).timeout
    check(live(tree).is_empty(), "all admitted production tweens retire their own accents")
    var feedback := preload("res://scripts/player_melee_feedback.gd")
    var admitted := 0
    for swing in 30:
        if feedback.spawn_swing(player,player.sprite,0.1) != null: admitted += 1
    check(admitted == POLICY.MAX_ACTION_TRACES, "real weapon smears share the existing eight action trace units")
    player._start_attack(&"attack_1")
    check(player.attack_timer > 0.0 and player.current_attack == &"attack_1", "full weapon smear budget leaves the actual attack state and body animation intact")
    second._spawn_dash_ghost()
    var departed_owner: int = second.get_instance_id()
    second.free()
    check(live(tree).all(func(item): return int(item.get_meta("secondary_owner",0)) != departed_owner), "removing a player retires its sibling accents even without a traversal reset")
    arena.free()
    await tree.process_frame
    check(tree.get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty(), "scene teardown leaves no cosmetic budget owners")
    await _compound_units(tree)
    print("SECONDARY_VISUAL_BUDGET checks=%d failures=%d" % [checks,failures])
    return failures

func _compound_units(tree: SceneTree) -> void:
    var host := Node2D.new();host.z_index=3000;tree.root.add_child(host)
    var bundle := Node2D.new()
    for index in 11:
        var line := Line2D.new();line.z_index=2000;bundle.add_child(line)
    check(POLICY.attach_secondary(host,bundle,&"state") and count_units(tree,&"state") == 12, "compound effects count every child canvas item")
    check(bundle.get_children().all(func(item): return not item.z_as_relative and item.z_index<=POLICY.SECONDARY_MAX_Z), "nested cosmetics cannot inherit a dangerous foreground layer")
    var rejected := Node2D.new()
    check(not POLICY.attach_secondary(host,rejected,&"state") and not is_instance_valid(rejected), "rejected cosmetic is freed before a tween can own it")
    host.free()
    await tree.process_frame
    var detached := Node2D.new();var invalid := Node2D.new()
    check(not POLICY.attach_secondary(detached,invalid,&"motion") and not is_instance_valid(invalid), "detached hosts do not leak rejected nodes")
    detached.free()
