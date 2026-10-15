extends RefCounted

const MARKER := preload("res://scripts/world_wayfinding.gd")
var checker: Callable
var checks := 0
var failures := 0

func run(world: Node, callback: Callable) -> void:
    checker = callback
    var player: CharacterBody2D = world.player
    var previous := {
        "position": player.global_position, "hp": player.hp, "death_timer": player.death_timer,
        "overlay": world.active_overlay, "loading": world.world_loading,
        "transition": world.chapter_transitioning, "complete": world.demo_complete,
        "nearby": world.nearby_interactable, "flags": world.story_flags.duplicate(true),
        "physics": world.is_physics_processing()}
    world.set_physics_process(false)
    world.active_overlay = ""
    world.world_loading = false
    world.chapter_transitioning = false
    player.hp = player.max_hp
    player.death_timer = 0.0
    # Isolate target selection from authored geometry/combat. These inert areas
    # deliberately have no pickup side effect; _try_interact still selects them.
    var origin := Vector2(20000, -1000)
    player.global_position = origin
    world.story_flags["tutorial_interaction_seen_death_cache"] = true
    var z := _area(world, "Selection_Z", origin + Vector2(40, 0))
    var a := _area(world, "Selection_A", origin - Vector2(40, 0))
    _check(world.interaction_target() == a, "equal-distance selection follows authored ID, not insertion order")
    world.move_child(z, world.get_child_count() - 1)
    _check(world.interaction_target() == a, "reordering adopted area children keeps the same target")
    var a_marker: Node = a.get_node("Wayfinding")
    var z_marker: Node = z.get_node("Wayfinding")
    a_marker._process(0.0)
    z_marker._process(0.0)
    _check(a_marker.nearby and not z_marker.nearby, "only the chosen overlapping area displays a prompt")
    world.nearby_interactable = z
    world._try_interact()
    _check(world.nearby_interactable == a, "interaction dispatch replaces stale body-enter target with displayed target")
    var closer := _area(world, "Selection_ZZ_Closer", origin + Vector2(5, 0))
    _check(world.interaction_target() == closer, "distance still outranks the ID tie break")
    closer.queue_free()
    _check(world.interaction_target() == a, "queued target is excluded before the frame ends")
    await world.get_tree().process_frame
    a.hide()
    _check(world.interaction_target() == z, "hidden area cannot intercept a visible object's interaction")
    a_marker._process(0.0)
    _check(not a_marker.nearby and a_marker.key_hint.is_empty(), "hidden area loses its nearby prompt")
    a.show()
    a.global_position = origin + Vector2(600, 0)
    for distance in [140.0, 145.0, 150.0]:
        z.global_position = origin + Vector2(distance, 0)
        z_marker._process(0.0)
        _check(world.interaction_target() == z and z_marker.nearby and not z_marker.key_hint.is_empty(), "prompt and interaction agree at distance %.0f" % distance)
        world.nearby_interactable = null
        world._try_interact()
        _check(world.nearby_interactable == z, "actual dispatch includes reachable boundary %.0f" % distance)
    z.global_position = origin + Vector2(150.25, 0)
    z_marker._process(0.0)
    _check(world.interaction_target() == null and not z_marker.nearby and z_marker.key_hint.is_empty(), "outside the shared range neither target nor prompt remains")
    z.global_position = origin
    _check(world._nearest_interactable(0.0) == z, "zero-radius query includes an exactly coincident object")
    for radius in [-1.0, NAN, INF]:
        _check(world._nearest_interactable(radius) == null, "invalid query radius is rejected")

    z.global_position = origin + Vector2(50, 0)
    var exit_area := _area(world, "Selection_Exit", origin + Vector2(140, 0))
    exit_area.set_meta("kind", "chapter_exit")
    exit_area.set_meta("requires_demo_complete", false)
    _check(world.interaction_target() == exit_area, "ready chapter exit retains its existing selection priority")
    world.demo_complete = false
    exit_area.set_meta("requires_demo_complete", true)
    _check(world.interaction_target() == z, "locked exit does not gain ready-exit priority")
    exit_area.queue_free()
    var auto_pickup := _area(world, "Selection_AutoPickup", origin)
    auto_pickup.set_meta("kind", "item")
    _check(world.interaction_target() == z, "automatic pickup does not steal an interaction prompt")
    auto_pickup.set_meta("manual_pickup", true)
    _check(world.interaction_target() == auto_pickup, "manual pickup remains a valid nearest target")
    auto_pickup.queue_free()
    for overlay in ["map", "settings", "dialogue", "build", "backpack"]:
        world.active_overlay = overlay
        z_marker._process(0.0)
        _check(world.interaction_target() == null and not z_marker.nearby, "overlay suppresses target and prompt: " + overlay)
    world.active_overlay = ""
    player.hp = 0
    player.death_timer = 0.5
    z_marker._process(0.0)
    _check(world.interaction_target() == null and not z_marker.nearby, "dead player has no actionable proximity prompt")
    player.hp = player.max_hp
    player.death_timer = 0.0
    world.world_loading = true
    world.nearby_interactable = a
    world._try_interact()
    z_marker._process(0.0)
    _check(world.interaction_target() == null and not z_marker.nearby and world.nearby_interactable == a, "loading suppresses dispatch as well as proximity prompt")
    world.world_loading = false
    world.chapter_transitioning = true
    z_marker._process(0.0)
    _check(world.interaction_target() == null and not z_marker.nearby, "pending chapter transition has no actionable prompt")
    world.chapter_transitioning = false
    _check(world.interaction_target() == z, "target is available again after temporary locks clear")

    a.queue_free()
    z.queue_free()
    await world.get_tree().process_frame
    player.global_position = previous.position
    player.hp = previous.hp
    player.death_timer = previous.death_timer
    world.active_overlay = previous.overlay
    world.world_loading = previous.loading
    world.chapter_transitioning = previous.transition
    world.demo_complete = previous.complete
    world.nearby_interactable = previous.nearby if is_instance_valid(previous.nearby) else null
    world.story_flags = previous.flags
    world.set_physics_process(previous.physics)
    print("INTERACTION_TARGETING checks=%d failures=%d" % [checks, failures])

func _area(world: Node, id: String, position: Vector2) -> Area2D:
    var area := Area2D.new()
    area.name = id
    area.set_meta("kind", "death_cache")
    world.add_child(area)
    area.global_position = position
    var marker := MARKER.new()
    marker.name = "Wayfinding"
    marker.host = world
    marker.area = area
    area.add_child(marker)
    marker.set_process(false)
    return area

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
    checker.call(ok, label)
