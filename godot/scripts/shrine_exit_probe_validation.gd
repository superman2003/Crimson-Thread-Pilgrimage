extends SceneTree
const PROBE := preload("res://scripts/shrine_exit_probe.gd")
var checks := 0
var failures := 0
class FixtureWorld extends Node2D:
    var player: CharacterBody2D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func body(parent: Node, at: Vector2, size: Vector2) -> void:
    var solid := StaticBody2D.new()
    solid.position = at
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    collider.shape = shape
    solid.add_child(collider)
    parent.add_child(solid)
func fixture(blocked: bool, gap: bool = false) -> FixtureWorld:
    var world := FixtureWorld.new()
    root.add_child(world)
    if gap:
        body(world, Vector2(-175, 10), Vector2(250, 20))
        body(world, Vector2(175, 10), Vector2(250, 20))
    else:
        body(world, Vector2(0, 10), Vector2(2000, 20))
    if blocked:
        body(world, Vector2(-120, -400), Vector2(20, 800))
        body(world, Vector2(120, -400), Vector2(20, 800))
    world.player = load("res://scenes/Player.tscn").instantiate()
    world.add_child(world.player)
    return world
func release_fixture(world: Node) -> void:
    world.queue_free()
    for frame in 3: await process_frame
func run() -> void:
    var room := {"id": "sealed", "kind": "secret", "layout_rect": [-120, -800, 240, 820]}
    var config := {"map_rooms": [room, {"id": "outside_left", "kind": "corridor", "layout_rect": [-1000, -800, 880, 820]}, {"id": "outside_right", "kind": "corridor", "layout_rect": [120, -800, 880, 820]}]}
    var sealed := fixture(true)
    PROBE.disable_ability_pickups(sealed)
    var ability := Area2D.new()
    ability.set_meta("item_id", "lantern_phase")
    sealed.add_child(ability)
    check(ability.is_queued_for_deletion(), "ability pickups are suppressed before they can open possession gates")
    var material := Area2D.new()
    material.set_meta("item_id", "wet_chitin")
    sealed.add_child(material)
    check(not material.is_queued_for_deletion(), "ordinary rewards are retained in the production fixture")
    var result: Dictionary = await PROBE.new().search(sealed, config, Vector2.ZERO, room, 4)
    check(not result.escaped and not result.replay_verified, "800px walls cannot be escaped by a jump or a teleported approach")
    await release_fixture(sealed)
    var open := fixture(false)
    result = await PROBE.new().search(open, config, Vector2.ZERO, room, 8)
    check(result.escaped and result.replay_verified, "an open exit is found and replayed from the original start")
    check(not result.get("inputs", []).is_empty() and result.get("trajectory", []).size() == result.get("inputs", []).size() + 1, "successful exits include every input and replay landing")
    check(result.get("from", []) == [0.0, 0.0], "the certificate starts at the shrine, never at an offset sample")
    await release_fixture(open)
    var gap_room := {"id": "ledge", "kind": "secret", "layout_rect": [-300, -800, 250, 820]}
    var gap_config := {"map_rooms": [gap_room, {"id": "far_ledge", "kind": "corridor", "layout_rect": [50, -800, 250, 820]}]}
    var gap := fixture(false, true)
    result = await PROBE.new().search(gap, gap_config, Vector2(-150, 0), gap_room, 8)
    check(result.escaped and result.replay_verified and result.get("via", "") == "far_ledge", "a real jump across a 100px gap can be found and replayed")
    var jumped := false
    for action in result.get("inputs", []): jumped = jumped or bool(action.jump)
    check(jumped, "the gap certificate contains an actual jump")
    await release_fixture(gap)
    print("SHRINE_EXIT_PROBE checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
