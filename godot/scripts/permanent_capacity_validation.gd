extends SceneTree
## Capacity is world progress, never equipment or a repeatable refill.
const BUILD := preload("res://scripts/build_system.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
var checks := 0
var failures := 0
var stage: Node2D
var player: CharacterBody2D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func frames(count: int) -> void:
    for i in count:
        await physics_frame
        await process_frame

func run() -> void:
    var build = BUILD.new()
    check(build.profile().max_hp == 5 and build.profile().max_energy == 100, "fresh capacity unchanged")
    var inventory := {"heart_knot": 2, "energy_spindle": 3, "heart_knot_fragment": 9, "energy_spindle_fragment": 9}
    build.sync_progress(inventory)
    check(build.profile().max_hp == 7 and build.profile().max_energy == 160, "complete items provide their promised capacity; fragments are not complete items")
    var saved: Dictionary = build.serialize()
    for i in 8: build.sync_progress(inventory)
    check(build.profile().max_hp == 7 and build.profile().max_energy == 160, "progress synchronization never compounds upgrades")
    inventory.heart_knot = 99
    check(build.profile().max_hp == 7, "derived capacity does not borrow the caller dictionary")
    check(build.serialize() == saved, "capacity does not add fields to old build saves or alter equipment")
    build.state.unlocked_crests = ["crimson", "bell", "salt"]
    for crest in ["crimson", "bell", "salt"]:
        check(build.switch_crest(crest).ok, crest + " can be equipped")
        check(build.profile().max_hp == 7 and build.profile().max_energy == 160, crest + " retains permanent progress")
        check(build.save_loadout(crest).ok, crest + " loadout saved")
        var preview: Dictionary = build.preview_loadout(crest)
        check(preview.ok and preview.profile.max_hp == 7 and preview.profile.max_energy == 160, crest + " preview includes real permanent limits")
        check(build.restore_loadout(crest).ok and build.profile().max_hp == 7, crest + " restoring equipment cannot erase or multiply progress")
    build.sync_progress({"heart_knot": 1.5, "energy_spindle": -2})
    check(build.profile().max_hp == 5 and build.profile().max_energy == 100, "invalid/fractional counts cannot grant capacity")
    build.sync_progress({"heart_knot": 1.0, "energy_spindle": 1.0})
    check(build.profile().max_hp == 6 and build.profile().max_energy == 120, "JSON whole-number counters restore exactly")
    build.reset()
    check(build.profile().max_hp == 5 and build.profile().max_energy == 100, "fresh journey clears previous inventory-derived capacity")
    var restored = BUILD.new()
    check(restored.restore(saved).ok, "original version-three build snapshot remains readable")
    restored.sync_progress({"heart_knot": 2, "energy_spindle": 3})
    check(restored.profile().max_hp == 7 and restored.profile().max_energy == 160, "old inventory reapplies without a new persisted bonus counter")
    stage = Node2D.new(); root.add_child(stage)
    var floor_body := StaticBody2D.new(); floor_body.position = Vector2(100,220)
    var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size=Vector2(1000,40); shape.shape=box; floor_body.add_child(shape); stage.add_child(floor_body)
    player = load("res://scenes/Player.tscn").instantiate(); player.position = Vector2(100,180); stage.add_child(player)
    build = BUILD.new(); player.apply_build_stats(build.profile()); await frames(5)
    player.hp = 3; player.energy = 100
    Input.action_press("heal"); await frames(2); Input.action_release("heal")
    var reservation: int = player.heal_reserved_cost
    var generation: int = player.heal_reservation_generation
    var remaining: float = player.heal_timer
    check(reservation == 60 and remaining > 0, "actual heal input reserves the original cost")
    build.sync_progress({"heart_knot": 1, "energy_spindle": 1})
    player.apply_build_stats(build.profile())
    check(player.max_hp == 6 and player.max_energy == 120, "real Player accepts both capacity upgrades")
    check(player.hp == 3 and player.energy == 40, "capacity pickup grants no health or energy refill")
    check(player.heal_timer == remaining and player.heal_reserved_cost == reservation and player.heal_reservation_generation == generation, "capacity-only progress preserves an active paid channel")
    await frames(40)
    check(player.hp == 4 and player.energy == 40 and player.heal_reserved_cost == 0, "original heal completes exactly once under its original rules")
    player.bell_guard_unlocked = true
    Input.action_press("bell_guard"); await frames(2); Input.action_release("bell_guard")
    var guard: float = player.guard_timer
    check(guard > 0, "actual guard input is active")
    build.sync_progress({"heart_knot": 2, "energy_spindle": 2}); player.apply_build_stats(build.profile())
    check(player.guard_timer == guard and player.max_hp == 7 and player.max_energy == 140, "capacity reward preserves an ongoing guard")
    var resources := [player.hp,player.energy]
    player.restore_at_save_point()
    check(player.hp == 7 and player.energy == 140, "normal bell rest refills to the earned new limits")
    player.hp = resources[0]; player.energy = resources[1]
    build.switch_crest("crimson")
    player.apply_build_stats(build.profile())
    check(player.hp == resources[0] and player.energy == resources[1], "ordinary build synchronization also cannot create resources")
    for action in ["heal","bell_guard"]: Input.action_release(action)
    RETIREMENT.retire_tree(stage); stage.queue_free(); await frames(3)
    AUDIO._stream_cache.clear(); AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self), "owned audio retires before process exit")
    print("PERMANENT_CAPACITY checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
