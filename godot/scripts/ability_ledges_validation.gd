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
        _check(not base.is_empty() and not ledge.is_empty(), String(entry.id) + " base and ledge exist")
        if base.is_empty() or ledge.is_empty():
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
        var locked: float = await _attempt(start, false)
        _check(absf(locked - base_rect.position.y) < 4.0, String(entry.id) + " without double jump the player lands back on the base floor (y=%.1f)" % locked)
        var unlocked: float = await _attempt(start, true)
        _check(absf(unlocked - ledge_rect.position.y) < 4.0, String(entry.id) + " jump then air jump lands on the ledge (y=%.1f)" % unlocked)
        for body in bodies:
            body.queue_free()
        await _frames(2)
    print("ABILITY_LEDGES checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _attempt(start: Vector2, unlocked: bool) -> float:
    var player = PLAYER_SCENE.instantiate()
    root.add_child(player)
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
    player.queue_free()
    await _frames(2)
    return rest

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
