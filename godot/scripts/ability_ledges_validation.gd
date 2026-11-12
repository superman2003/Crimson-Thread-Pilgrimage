extends SceneTree
## A01: each authored double-jump ledge, rebuilt from world_routes.json at its real
## coordinates, is reached with real jump input only when the double jump is owned.
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const PLATFORM_BODY := preload("res://scripts/world_platform_body.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_routes.json"))
    var ledges: Array = routes.get("ability_ledges", [])
    _check(not ledges.is_empty(), "world routes list at least one ability ledge")
    for entry in ledges:
        var region := String(entry.region_id)
        var base_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
        var overlay: Dictionary = routes.chapters[region]
        var base := _platform(base_config.platforms, String(entry.base_platform_id))
        var ledge := _platform(overlay.platforms, String(entry.platform_id))
        var reward := _platform(overlay.get("collectibles", []), String(entry.reward_id))
        _check(not base.is_empty() and not ledge.is_empty() and not reward.is_empty(), String(entry.id) + " base, ledge and reward exist")
        if base.is_empty() or ledge.is_empty() or reward.is_empty():
            continue
        var base_rect := _rect(base.rect)
        var ledge_rect := _rect(ledge.rect)
        var bodies := [
            PLATFORM_BODY.create("base", base_rect, String(base.get("collision_role", "floor"))),
            PLATFORM_BODY.create("ledge", ledge_rect, String(ledge.get("collision_role", "one_way"))),
        ]
        for body in bodies:
            root.add_child(body)
        var start := Vector2(ledge_rect.get_center().x, base_rect.position.y)
        var pickup_position := Vector2(float(reward.position[0]), float(reward.position[1]))
        var locked: Dictionary = await _attempt(start, false, pickup_position)
        _check(absf(float(locked.rest) - base_rect.position.y) < 4.0, String(entry.id) + " without double jump the player lands back on the base floor (y=%.1f)" % float(locked.rest))
        _check(not bool(locked.collected), String(entry.id) + " single-jump head overlap cannot collect the reward")
        var unlocked: Dictionary = await _attempt(start, true, pickup_position)
        _check(absf(float(unlocked.rest) - ledge_rect.position.y) < 4.0, String(entry.id) + " jump then air jump lands on the ledge (y=%.1f)" % float(unlocked.rest))
        _check(bool(unlocked.collected), String(entry.id) + " double jump reaches and collects the reward")
        for body in bodies:
            body.queue_free()
        await _frames(2)
    print("ABILITY_LEDGES checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _attempt(start: Vector2, unlocked: bool, pickup_position: Vector2) -> Dictionary:
    var player = PLAYER_SCENE.instantiate()
    root.add_child(player)
    # Match the production collectible's radius18 Area2D, using the real Player body.
    var pickup := Area2D.new()
    pickup.position = pickup_position
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 18
    shape.shape = circle
    pickup.add_child(shape)
    var collected := {"value": false}
    pickup.body_entered.connect(func(body: Node):
        if body == player: collected.value = true)
    root.add_child(pickup)
    player.feel = null
    player.double_jump_unlocked = unlocked
    player.respawn_at(start)
    await _frames(6)
    Input.action_press("jump")
    await _frames(14)
    Input.action_release("jump")
    await _frames(2)
    Input.action_press("jump")
    await _frames(20)
    Input.action_release("jump")
    await _frames(70)
    var rest: float = player.global_position.y if player.is_on_floor() else INF
    var result := {"rest": rest, "collected": bool(collected.value)}
    pickup.queue_free()
    player.queue_free()
    await _frames(2)
    return result

func _platform(list: Array, id: String) -> Dictionary:
    for item in list:
        if String(item.get("id", "")) == id:
            return item
    return {}

func _rect(values: Array) -> Rect2:
    return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

func _frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("PASS: " + label)
    else:
        failures += 1
        push_error("FAIL: " + label)
