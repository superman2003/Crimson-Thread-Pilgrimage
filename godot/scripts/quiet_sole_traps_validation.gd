extends SceneTree
## Real World legacy-save unlock followed by production factory/Player physics.
const BUILD = preload("res://scripts/build_system.gd")
const LEVEL = preload("res://scripts/main_level.gd")
const PLAYER = preload("res://scenes/Player.tscn")
const POGO = preload("res://scripts/hazard_pogo.gd")
var failures := 0
var checks := 0
var level: Node2D
var player: CharacterBody2D
var build: RefCounted

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    print("CHECK %s %s" % ["PASS" if ok else "FAIL", label])
    if not ok: failures += 1

func _frames(count: int) -> void:
    for i in count:
        await physics_frame
        await process_frame

func _run() -> void:
    # Exact earned W03 return save; no inventory grants are synthesized here.
    var seed := FileAccess.get_file_as_string("res://tests/fixtures/quiet_sole_earned_return.json")
    var save_path := "user://quiet_sole_legacy_%d.json" % OS.get_process_id()
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(seed)
    file.close()
    var world = preload("res://scenes/World.tscn").instantiate()
    world.world_save_path = save_path
    world.world_resume = true
    root.add_child(world)
    current_scene = world
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    _check(world.initial_region_ready, "World legacy save ready")
    _check(int(world.inventory_counts.get("quiet_sole", 0)) == 1, "earned legacy relic restored")
    _check(world.build_system.state.unlocked_passives.has("quiet_sole"), "legacy inventory unlocks actual accessory")
    _check(is_equal_approx(float(world.player.build_profile.get("hazard_trigger_mult", 1)), 1), "holding relic alone has no effect")
    world.queue_free()
    await _frames(4)
    # Add script after entering tree: use production factory and sync methods,
    # while deliberately omitting chapter generation for this component fixture.
    level = Node2D.new()
    root.add_child(level)
    level.set_script(LEVEL)
    level.set_process(false)
    level.set_physics_process(false)
    level.world_mode = true
    level.world_loading = false
    build = BUILD.new()
    level.build_system = build
    level.inventory_counts = JSON.parse_string(seed).inventory_counts
    player = PLAYER.instantiate()
    root.add_child(player)
    player.feel = null
    level.player = player
    level._sync_player_build()
    var floor_body := StaticBody2D.new()
    floor_body.position = Vector2(400, 312)
    floor_body.collision_layer = 17
    var floor_shape := CollisionShape2D.new()
    floor_shape.shape = RectangleShape2D.new()
    floor_shape.shape.size = Vector2(1200, 24)
    floor_body.add_child(floor_shape)
    root.add_child(floor_body)
    var a := _hazard("first", [200, 100, 200, 200])
    var b := _hazard("second", [700, 100, 100, 100])
    _check(a.get_node("TriggerShape").shape != b.get_node("TriggerShape").shape, "each trap owns a distinct shape")
    var body_size: Vector2 = player.get_node("CollisionShape2D").shape.size
    var hp_max: int = player.max_hp
    var speed: float = player.speed
    _check(build.equip_family_slot("quiet_sole", "travel_accessory", 0).ok, "equip actual unlocked travel accessory")
    level._sync_player_build()
    await _frames(3)
    _check(_size(a) == Vector2(160, 160) and _size(b) == Vector2(80, 80), "all authored trap sizes shrink independently")
    _check(POGO.surface_rect(a) == Rect2(200, 100, 200, 200), "authored spike pogo surface unchanged")
    _check(body_size == Vector2(34, 84) and player.max_hp == hp_max and player.speed == speed, "player body HP and movement unchanged")
    build.save_loadout("quiet")
    build.equip_family_slot("", "travel_accessory", 0)
    var before: Dictionary = build.serialize()
    var preview: Dictionary = build.preview_loadout("quiet")
    _check(preview.ok and is_equal_approx(float(preview.profile.hazard_trigger_mult), 0.8) and build.serialize() == before, "loadout preview derives 80 percent without mutation")
    build.restore_loadout("quiet")
    level._sync_player_build()
    await _reset(Vector2(170, 300))
    var hp: int = player.hp
    Input.action_press("move_right")
    for i in 30:
        if player.position.x >= 190 or player.hp != hp: break
        await _frames(1)
    Input.action_release("move_right")
    player.velocity.x = 0
    await _frames(3)
    _check(player.position.x >= 190 and player.position.x < 201 and player.hp == hp and not a.overlaps_body(player), "real move input reaches original outer edge safely")
    Input.action_press("move_right")
    for i in 20:
        await _frames(1)
        if player.hp < hp: break
    Input.action_release("move_right")
    _check(player.hp == hp - 1 and a.overlaps_body(player), "continuing input enters inner shape and real Area contact deals authored damage")
    await _reset(Vector2(190, 300))
    _check(not a.overlaps_body(player), "equipped outer boundary remains outside")
    build.equip_family_slot("", "travel_accessory", 0)
    level._sync_player_build()
    await _frames(4)
    _check(_size(a) == Vector2(200, 200) and player.hp == hp_max - 1, "unequip while stationary at outer boundary reenters expanded Area and hurts")
    build.equip_family_slot("quiet_sole", "travel_accessory", 0)
    level._sync_player_build()
    await _frames(4)
    _check(not a.overlaps_body(player), "equip while already inside original Area updates overlap without movement")
    # Slot 1 requires crimson mechanism; bell slot 1 remains dormant.
    build.sync_progress({}, "", {"quest_bring_names_complete": true})
    build.state.unlocked_crests.append("bell") # Component fixture: known crest, unrepaired mechanism.
    build.equip_family_slot("", "travel_accessory", 0)
    _check(build.equip_family_slot("quiet_sole", "travel_accessory", 1).ok, "quiet sole accepts unlocked expansion")
    _check(build.switch_crest("bell").ok, "switch crest for dormant slot")
    level._sync_player_build()
    await _frames(3)
    _check(_size(a) == Vector2(200, 200) and not build.state.passives.has("quiet_sole"), "dormant incompatible slot leaves no trap modifier")
    a.free()
    var rebuilt := _hazard("rebuilt", [200, 100, 200, 200])
    _check(_size(rebuilt) == Vector2(200, 200), "rebuilt trap uses current inactive profile")
    _check(build.switch_crest("crimson").ok, "return to active crest")
    level._sync_player_build()
    await _frames(3)
    _check(_size(rebuilt) == Vector2(160, 160), "reactivated slot updates rebuilt trap")
    var restored = BUILD.new()
    _check(restored.restore(build.serialize()).ok and is_equal_approx(float(restored.profile().get("hazard_trigger_mult", 1)), 0.8), "serialized actual equipment restores modifier")
    Input.action_release("move_right")
    level.queue_free()
    player.queue_free()
    floor_body.queue_free()
    await _frames(3)
    print("QUIET_SOLE_TRAPS checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _hazard(id: String, rect: Array) -> Area2D:
    level._hazard({"id": id, "kind": "spikes", "rect": rect, "damage": 1})
    return level.get_node(id)

func _size(area: Area2D) -> Vector2:
    return area.get_node("TriggerShape").shape.size

func _reset(at: Vector2) -> void:
    player.position = at
    player.velocity = Vector2.ZERO
    player.hp = player.max_hp
    player.arrival_guard_timer = 0.0
    player.hurt_timer = 0.0
    await _frames(4)
