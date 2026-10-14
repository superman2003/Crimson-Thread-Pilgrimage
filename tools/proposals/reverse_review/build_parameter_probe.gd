extends SceneTree
# Run only in a disposable imported project, with an isolated XDG_DATA_HOME.
# This checks scene initialization and explicitly marked loadout fixtures, not playthrough.
func _initialize() -> void:
    call_deferred("run")

func snapshot(scene: Node, label: String) -> void:
    var p = scene.player
    print("REVIEW_BUILD_JSON " + JSON.stringify({"label":label,
        "world_mode":scene.world_mode,"config":scene.config.id,
        "heal_duration":p.heal_duration,"heal_cost":p.heal_energy_cost,
        "heal_amount":p.heal_amount,"energy_per_hit":p.energy_per_hit,
        "energy_on_damage":p.energy_on_damage,"max_hp":p.max_hp,
        "crest":p.build_profile.get("crest_id", "not_applied")}))

func run() -> void:
    var demo = load("res://scenes/Main.tscn").instantiate()
    root.add_child(demo)
    current_scene = demo
    await physics_frame
    snapshot(demo, "Main_original_initialization")
    demo.queue_free()
    await process_frame
    var world = load("res://scenes/World.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await physics_frame
    snapshot(world, "World_original_initialization")
    for crest in ["crimson", "bell", "salt"]:
        # Explicit fixture: bypass unlocking ONLY to inspect the computed profile.
        world.build_system.state.crest = crest
        world.build_system.state.passives = []
        world._sync_player_build()
        snapshot(world, "World_fixture_no_passives_" + crest)
    world.queue_free()
    await process_frame
    quit()
