extends SceneTree
## C01 hazard pogo with the production Player, real aim/attack input and
## hazards built by MainLevel._hazard. Fixture floor and positions only.
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const LEVEL_SCRIPT := preload("res://scripts/main_level.gd")
const HAZARD_POGO := preload("res://scripts/hazard_pogo.gd")
var checks := 0
var failures := 0
var level: Node2D

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(label)

func _frames(count: int) -> void:
    for _index in count:
        await physics_frame

func _hazard(kind: String, rect: Array) -> Area2D:
    var before := level.get_child_count()
    level._hazard({"id": "probe_" + kind, "kind": kind, "rect": rect, "damage": 1, "message": "probe"})
    var area: Area2D = level.get_child(before)
    level.remove_child(area)
    root.add_child(area)
    return area

func _run() -> void:
    # MainLevel is used only as the hazard factory/contact handler; it never
    # enters the tree, so no World is built.
    level = LEVEL_SCRIPT.new()
    root.add_child(_static_box(Vector2(300, 214), Vector2(1200, 24), 17))
    var player: CharacterBody2D = PLAYER_SCENE.instantiate()
    root.add_child(player)
    player.feel = null
    level.player = player
    level.world_loading = false  # off-tree factory never runs the loading handoff
    var spikes := _hazard("spikes", [110, 178, 80, 24])
    var chest := _hazard("spore_chest", [410, 178, 80, 24])
    _check(spikes.is_in_group(HAZARD_POGO.GROUP) and not chest.is_in_group(HAZARD_POGO.GROUP), "only static spikes become pogo surfaces")
    _check(HAZARD_POGO.surface_rect(spikes) == Rect2(110, 178, 80, 24), "pogo surface matches the authored hazard rect")
    await _frames(3)

    player.energy = 10
    var hp: int = player.hp
    await _downslash(player, Vector2(150, 110))
    _check(player.velocity.y < 0.0 and player.pogo_chain == 1, "downslash into spikes bounces the player")
    _check(player.energy == 10 and player.hp == hp, "a spike bounce grants no thread and costs no health")
    _check(player.hazard_pogo_guard_timer > 0.0, "the bounce opens a short spike-contact grace")
    level._on_hazard_body_entered(player, spikes)
    _check(player.hp == hp, "spike contact inside the grace does not damage")
    player.hazard_pogo_guard_timer = 0.0
    player.arrival_guard_timer = 0.0  # fresh-spawn protection, not spike logic
    level._on_hazard_body_entered(player, spikes)
    _check(player.hp == hp - 1, "spike contact after the grace damages as before")
    player.hp = hp
    player.hurt_timer = 0.0

    var ledge := _static_box(Vector2(150, 160), Vector2(140, 12), 17)
    root.add_child(ledge)
    await _frames(2)
    await _downslash(player, Vector2(150, 110))
    _check(player.velocity.y >= 0.0 and player.pogo_chain == 0, "terrain between the player and spikes blocks the bounce")
    ledge.free()
    await _frames(2)

    await _downslash(player, Vector2(450, 110))
    _check(player.velocity.y >= 0.0 and player.pogo_chain == 0, "non-standing hazards such as spore chests do not bounce")

    await _side_attack(player, Vector2(70, 196))
    _check(player.pogo_chain == 0, "a horizontal swing beside spikes does not pogo")
    _check(chest.get_meta("damage") == 1, "unmarked hazards keep their authored damage")
    level.free()
    print("SPIKE_POGO checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _reset(player: CharacterBody2D, at: Vector2) -> void:
    player.global_position = at
    player.velocity = Vector2(0, 220)
    player.facing = 1
    player.hurt_timer = 0.0
    player.death_timer = 0.0
    player.attack_timer = 0.0
    player.attack_pogo_paid = false
    player.pogo_chain = 0
    player.hazard_pogo_guard_timer = 0.0
    player.active_skill.clear()

func _downslash(player: CharacterBody2D, at: Vector2) -> void:
    _reset(player, at)
    Input.action_press("aim_down")
    await _frames(1)
    Input.action_press("attack")
    var started := false
    for _attempt in 4:
        await _frames(1)
        if player.attack_timer > 0.0:
            started = true
            break
    _check(started, "real input starts the downslash")
    Input.action_release("attack")
    Input.action_release("aim_down")
    await _frames(3)

func _side_attack(player: CharacterBody2D, at: Vector2) -> void:
    _reset(player, at)
    player.velocity = Vector2.ZERO
    await _frames(2)
    Input.action_press("attack")
    for _attempt in 4:
        await _frames(1)
        if player.attack_timer > 0.0: break
    Input.action_release("attack")
    await _frames(12)

func _static_box(position_value: Vector2, size: Vector2, layer: int) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = position_value
    body.collision_layer = layer
    body.collision_mask = 0
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    shape.shape = rectangle
    body.add_child(shape)
    return body
