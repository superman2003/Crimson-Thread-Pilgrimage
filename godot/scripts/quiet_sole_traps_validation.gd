extends SceneTree
## Real World legacy-save unlock followed by production factory/Player physics.
const BUILD = preload("res://scripts/build_system.gd")
const LEVEL = preload("res://scripts/main_level.gd")
const PLAYER = preload("res://scenes/Player.tscn")
const RETIREMENT = preload("res://scripts/audio_retirement.gd")
const AUDIO = preload("res://scripts/audio_director.gd")
var failures := 0
var checks := 0
var level: Node2D
var player: CharacterBody2D
var build: RefCounted
var capture_audio := true

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
    capture_audio = not OS.get_cmdline_user_args().has("--skip-fixture-audio-retirement")
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
    _check(is_equal_approx(float(world.player.build_profile.get("move_mult", 1)), 1), "holding relic alone has no movement effect")
    await _release_owned([world], "legacy World")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(save_path + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
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
    build.equip_family_slot("", "travel_accessory", 0)
    level._sync_player_build()
    var baseline: float = player.speed
    var body_size: Vector2 = player.get_node("CollisionShape2D").shape.size
    _check(build.equip_family_slot("quiet_sole","travel_accessory",0).ok,"legacy quiet sole remains equippable")
    level._sync_player_build()
    _check(is_equal_approx(player.speed,baseline*1.05),"quiet sole now grants its actual five percent ground speed")
    _check(player.get_node("CollisionShape2D").shape.size==body_size,"the relic never resizes the Player")
    for result in preload("res://scripts/trap_free_validation_helper.gd").probe(level,player):
        _check(bool(result[0]),String(result[1]))
    _check(build.save_loadout("quiet").ok,"trap-free reward loadout saves")
    var restored:=BUILD.new()
    _check(restored.restore(build.serialize()).ok and is_equal_approx(float(restored.profile().get("move_mult",1)),1.05),"legacy reward identity and useful movement effect restore")
    build.equip_family_slot("","travel_accessory",0);level._sync_player_build()
    _check(is_equal_approx(player.speed,baseline),"unequipping restores the original speed")
    await _release_owned([level,player,floor_body],"component")
    print("QUIET_SOLE_TRAPS checks=%d failures=%d"%[checks,failures])
    quit(0 if failures==0 else 1)

func _release_owned(nodes: Array, label: String) -> void:
    var observed_before: int = RETIREMENT.observed
    var captured := 0
    for node in nodes:
        if is_instance_valid(node) and capture_audio:
            captured += RETIREMENT.retire_tree(node)
    for node in nodes:
        if is_instance_valid(node):node.queue_free()
    await _frames(1)
    # The fixture ends the sole scene owner's intentional stream cache lifetime.
    # Weak pending retirement records remain intact until their objects expire.
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    _check(await RETIREMENT.drain(self), label + " observable audio retirement")
    if label == "legacy World" and DisplayServer.get_name() != "headless":
        _check(captured > 0 and RETIREMENT.observed > observed_before, "native fixture captured owned World playback inside tree")
