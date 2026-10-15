extends "res://scripts/world_neighbor_gameplay_validation.gd"
## Separate lifecycle stress from landing parity so each keeps a strict timeout.
func run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for suffix in ["",".bak",".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await frames(2)
    await cache_churn()
    scene.free()
    current_scene = null
    await frames(2)
    for suffix in ["",".bak",".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("NEIGHBOR GAMEPLAY STRESS METRICS ",JSON.stringify(churn))
    for message in failures:
        push_error(message)
    print("WORLD_NEIGHBOR_GAMEPLAY_STRESS checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
