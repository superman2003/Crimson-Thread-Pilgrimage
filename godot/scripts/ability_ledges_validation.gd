extends SceneTree
## A01: every optional ability place in world_routes.json `ability_ledges`, rebuilt
## at its real coordinates (base floor, shelf, niche shell, bell plate, hook ring),
## is reached with real input only when its ability is used.
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const PLATFORM_BODY := preload("res://scripts/world_platform_body.gd")
const ENEMY_ACTOR := preload("res://scripts/enemy_actor.gd")
const ACTION_STAGE := preload("res://tests/ability_action_stage.gd")
var failures := 0
var checks := 0
var active_player: Node = null
var collected := false
var last_collected := false

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_routes.json"))
    var places: Array = routes.get("ability_ledges", [])
    var kinds := {}
    for entry in places:
        kinds[String(entry.required_ability)] = true
    _check(kinds.has("double_thread_jump") and kinds.has("echo_hook") and kinds.has("crown_resonance"), "places cover double jump, echo hook and crown resonance")
    for entry in places:
        await _place(routes, entry)
    await _wall_surface_policy()
    print("ABILITY_LEDGES checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _place(routes: Dictionary, entry: Dictionary) -> void:
    var id := String(entry.id)
    var region := String(entry.region_id)
    var base_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
    var overlay: Dictionary = routes.chapters[region]
    for override in overlay.get("platform_overrides", []):
        _find(base_config.platforms, String(override.id)).merge(override, true)
    var base := _find(base_config.platforms, String(entry.base_platform_id))
    var shelf := _find(overlay.platforms, String(entry.platform_id))
    var reward := _find(overlay.collectibles, String(entry.reward_id))
    _check(not base.is_empty() and not shelf.is_empty(), id + " base and shelf exist")
    if base.is_empty() or shelf.is_empty():
        return
    var base_rect := _rect(base.rect)
    var shelf_rect := _rect(shelf.rect)
    var bodies: Array = [
        PLATFORM_BODY.create("base", base_rect, String(base.get("collision_role", "floor"))),
        PLATFORM_BODY.create("shelf", shelf_rect, String(shelf.get("collision_role", "one_way"))),
    ]
    for part in ["roof", "wall_l", "wall_r"]:
        var piece := _find(overlay.platforms, id + "_" + part)
        if not piece.is_empty():
            bodies.append(PLATFORM_BODY.create(part, _rect(piece.rect), String(piece.collision_role)))
    var gate_body: StaticBody2D = null
    var action_stage = null
    var controlled_gate := String(entry.get("gate_id", entry.get("reward_gate_id", "")))
    if not controlled_gate.is_empty():
        var gate := _find(overlay.locked_gates, controlled_gate)
        _check(String(gate.get("requires_action", "")) == String(entry.required_ability), id + " seal opens only by its actual ability action")
        gate_body = PLATFORM_BODY.create("bell", _rect(gate.rect), "")
        bodies.append(gate_body)
        action_stage = ACTION_STAGE.new()
        action_stage.world_mode = true
        action_stage.config = {"locked_gates": [gate]}
        action_stage.locked_gate_bodies[String(gate.id)] = gate_body
        root.add_child(action_stage)
    var anchor: Node2D = null
    var ring := {}
    if entry.has("ring_id"):
        ring = _find(overlay.grapple_anchors, String(entry.ring_id))
        anchor = Node2D.new()
        anchor.position = _vec(ring.position)
        anchor.add_to_group("grapple_anchor")
        bodies.append(anchor)
    for body in bodies:
        root.add_child(body)
    var pickup := Area2D.new()
    pickup.position = _vec(reward.position)
    var pickup_shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 18
    pickup_shape.shape = circle
    pickup.add_child(pickup_shape)
    pickup.body_entered.connect(func(body: Node):
        if body == active_player: collected = true)
    root.add_child(pickup)
    await _frames(2)
    var floor_y := base_rect.position.y
    var shelf_y := shelf_rect.position.y
    var start := Vector2(shelf_rect.get_center().x, floor_y)
    match String(entry.required_ability):
        "double_thread_jump":
            _near(await _jump(start, false), floor_y, id + " a single jump falls back to the floor")
            _check(not last_collected, id + " a single-jump head overlap cannot collect the reward")
            _near(await _jump(start, true), shelf_y, id + " jump then air jump lands on the shelf")
            _check(last_collected, id + " double jump collects the reward")
            if String(entry.get("kind", "ledge")) == "ledge":
                var adjacent := _find(base_config.platforms, "mezz_gallery_floor")
                _check(not adjacent.is_empty(), "adjacent gallery exists for the pickup bypass regression")
                var adjacent_rect := _rect(adjacent.rect)
                var support := PLATFORM_BODY.create("adjacent", adjacent_rect, String(adjacent.get("collision_role", "floor")))
                root.add_child(support)
                var adjacent_start := Vector2(adjacent_rect.end.x - 17, adjacent_rect.position.y)
                await _adjacent_dash(adjacent_start)
                _check(not last_collected, id + " adjacent single jump plus airborne dash cannot collect the reward")
                var scribe := _find(base_config.get("enemy_spawns", []), "E06")
                _check(not scribe.is_empty(), "authored enemy exists for the pogo bypass regression")
                if not scribe.is_empty():
                    var profile: Dictionary = base_config.get("ai_profiles", {}).get(String(scribe.kind), {})
                    var enemy_floor := _find(base_config.platforms, String(scribe.platform_id))
                    _check(not enemy_floor.is_empty(), "pogo fixture retains the authored enemy support")
                    if not enemy_floor.is_empty():
                        var enemy_rect := _rect(enemy_floor.rect)
                        var enemy_support := PLATFORM_BODY.create("enemy_support", enemy_rect, String(enemy_floor.get("collision_role", "floor")))
                        root.add_child(enemy_support)
                        var pogo: Dictionary = await _pogo_attempt(scribe, profile, enemy_rect, _vec(reward.position))
                        _check(bool(pogo.hit), "real downward attack produces the strongest-crest enemy bounce")
                        _check(bool(pogo.dashed), "enemy pogo fixture performs a real airborne dash")
                        _check(not bool(pogo.collected), "enemy pogo and dash cannot collect the high-shelf reward")
                        enemy_support.queue_free()
                support.queue_free()
        "echo_hook":
            _near(await _jump(start, true), floor_y, id + " even the double jump falls back to the floor")
            _check(not last_collected, id + " double jump cannot collect the hook reward")
            var hook_start := Vector2(float(ring.test_from[0]), floor_y)
            _near(await _hook(hook_start, false, action_stage), floor_y, id + " without the hook the ring does nothing")
            _check(action_stage.locked_gate_bodies.has(controlled_gate), "owning no hook cannot open the reward box")
            var mote := _find(base_config.get("enemy_spawns", []), "E12")
            _check(not mote.is_empty(), "authored flying enemy exists for the hook-reward pogo regression")
            if not mote.is_empty():
                var profile: Dictionary = base_config.get("ai_profiles", {}).get(String(mote.kind), {})
                var enemy_floor := _find(base_config.platforms, String(mote.platform_id))
                var pogo: Dictionary = await _pogo_attempt(mote, profile, _rect(enemy_floor.rect), _vec(reward.position))
                _check(bool(pogo.hit), "real downward attack creates the flying-enemy crest bounce")
                _check(bool(pogo.dashed), "hook reward bypass fixture really dashes")
                _check(not bool(pogo.collected), "enemy pogo plus dash cannot collect the sealed hook reward")
            _near(await _hook(hook_start, true, action_stage), shelf_y, id + " aiming up at the ring pulls the body onto the shelf")
            _check(not action_stage.locked_gate_bodies.has(controlled_gate), "real hook action permanently opens the reward box")
            _check(last_collected, id + " the hook route collects its reward")
        "crown_resonance":
            _near(await _jump(start, true), floor_y, id + " the sealed bell plate stops every jump")
            _check(not last_collected, id + " the sealed bell plate also stops early collection")
            var player = _spawn(start)
            player.crown_resonance_unlocked = true
            player.energy = player.max_energy
            action_stage.player = player
            player.ability_action.connect(action_stage._on_ability_action)
            await _frames(6)
            Input.action_press("crown_resonance")
            await _frames(2)
            Input.action_release("crown_resonance")
            _check(action_stage.locked_gate_bodies.has(String(entry.gate_id)), id + " ownership without the permanent item cannot open the plate")
            await _frames(40)
            action_stage.inventory_counts["crown_resonance"] = 1
            player.resonance_cooldown = 0
            player.energy = player.max_energy
            Input.action_press("crown_resonance")
            await _frames(2)
            Input.action_release("crown_resonance")
            _check(not action_stage.locked_gate_bodies.has(String(entry.gate_id)), id + " real resonance input opens the production action gate")
            _check(action_stage.story_flags.get("action_gate_" + String(entry.gate_id), false), id + " the plate remains permanently open")
            player.queue_free()
            await _frames(2)
            _near(await _jump(start, false), shelf_y, id + " once the plate opens a single jump lands on the shelf")
            _check(last_collected, id + " the open bell niche grants its reward")
    pickup.queue_free()
    if action_stage != null:
        action_stage.queue_free()
    for body in bodies:
        if is_instance_valid(body):
            body.queue_free()
    await _frames(2)

func _pogo_attempt(data: Dictionary, profile: Dictionary, floor_rect: Rect2, pickup_position: Vector2) -> Dictionary:
    var stage := Node2D.new()
    root.add_child(stage)
    var enemy = ENEMY_ACTOR.new()
    enemy.configure(data, String(data.get("sprite", "")), false, profile)
    # Exercise the allowed recoil position closest to the reward on either side.
    var minimum_x := maxf(float(data.position[0])-float(data.leash_radius), floor_rect.position.x+float(data.spawn_half_width))
    var maximum_x := minf(float(data.position[0])+float(data.leash_radius), floor_rect.end.x-float(data.spawn_half_width))
    enemy.position = Vector2(clampf(pickup_position.x, minimum_x, maximum_x), float(data.position[1]))
    stage.add_child(enemy)
    enemy.set_process(false)
    enemy.set_physics_process(false)
    var player = PLAYER_SCENE.instantiate()
    stage.add_child(player)
    player.feel = null
    player.double_jump_unlocked = false
    player.dash_unlocked = true
    var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_catalog.json"))
    var maximum_bounce := 1.0
    for crest in catalog.crests.values():
        maximum_bounce = maxf(maximum_bounce, float(crest.get("pogo_bounce_mult", 1.0)))
    player.build_profile["downstrike_bounce_mult"] = maximum_bounce
    player.respawn_at(enemy.position-Vector2(0, float(data.get("spawn_visual_height", 56))))
    var direction := -1 if pickup_position.x < enemy.position.x else 1
    player.facing = direction
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
    stage.add_child(pickup)
    await _frames(2)
    var previous_hp: int = enemy.hp
    player._start_attack(&"attack_1", true, Vector2.DOWN)
    player._apply_attack_hits()
    var hit: bool = enemy.hp < previous_hp and player.pogo_chain > 0 and player.velocity.y < -600.0*maximum_bounce
    var movement := "move_left" if direction < 0 else "move_right"
    Input.action_press(movement)
    var dashed := false
    var attempts: Array = []
    for frame in 90:
        # Fresh presses span the real swing recovery; an early buffered press
        # can expire during hit pause before the action gate opens.
        if frame in [16, 24, 32]:
            attempts.append({"frame": frame, "ready": player._can_start_action(false, true), "attack": player.attack_timer, "hurt": player.hurt_timer, "cooldown": player.dash_cooldown, "airborne": not player.is_on_floor()})
            Input.action_press("dash")
        if frame in [18, 26, 34]: Input.action_release("dash")
        await _frames(1)
        dashed = dashed or player.dash_timer > 0.0
    for action in ["move_left", "move_right", "dash"]: Input.action_release(action)
    var result := {"hit": hit, "dashed": dashed, "collected": bool(collected.value)}
    print("ABILITY_POGO ", JSON.stringify({"enemy": data.id, "position": [enemy.position.x, enemy.position.y], "result": result, "attempts": attempts}))
    stage.queue_free()
    await _frames(2)
    return result


func _spawn(start: Vector2):
    var player = PLAYER_SCENE.instantiate()
    root.add_child(player)
    player.feel = null
    player.respawn_at(start)
    active_player = player
    collected = false
    return player

## Jump; with `air` also press jump again near the apex. Returns resting feet y.
func _jump(start: Vector2, air: bool) -> float:
    var player = _spawn(start)
    player.double_jump_unlocked = air
    await _frames(6)
    await _jump_to_apex(player)
    if air:
        await _frames(1)
        await _jump_to_apex(player)
    return await _settle(player)

func _jump_to_apex(player) -> void:
    # Physics can advance several ticks between process frames on a cold/loaded
    # runner. Observe the real jump instead of assuming 14 yields is its apex.
    Input.action_press("jump")
    var airborne := false
    for tick in range(90):
        await _frames(1)
        airborne = airborne or not player.is_on_floor()
        if airborne and player.velocity.y >= -35.0:
            break
    Input.action_release("jump")

func _hook(start: Vector2, unlocked: bool, action_stage = null) -> float:
    var player = _spawn(start)
    player.thread_grapple_unlocked = unlocked
    if action_stage != null:
        action_stage.player = player
        action_stage.inventory_counts["echo_hook"] = 1 if unlocked else 0
        player.ability_action.connect(action_stage._on_ability_action)
    await _frames(6)
    Input.action_press("aim_up")
    Input.action_press("hook")
    await _frames(2)
    Input.action_release("hook")
    for frame in range(60):
        if player.grapple_timer <= 0.0:
            break
        await _frames(1)
    Input.action_release("aim_up")
    # The ring hangs in the open shaft beside the shelf; step onto the shelf.
    Input.action_press("move_right")
    await _frames(24)
    Input.action_release("move_right")
    return await _settle(player)

func _adjacent_dash(start: Vector2) -> void:
    var player = _spawn(start)
    player.dash_unlocked = true
    var observed := {"value": false}
    player.ability_action.connect(func(key: String, _origin: Vector2, _direction: Vector2):
        if key == "thread_dash": observed.value = true)
    await _frames(6)
    Input.action_press("move_right")
    await _jump_to_apex(player)
    Input.action_press("dash")
    await _frames(2)
    Input.action_release("dash")
    await _frames(24)
    Input.action_release("move_right")
    _check(observed.value, "adjacent-surface fixture really performs an airborne dash")
    await _settle(player)

func _wall_surface_policy() -> void:
    for smooth in [false, true]:
        var wall := PLATFORM_BODY.create("wall_policy", Rect2(0, 0, 24, 400), "ungrippable_wall" if smooth else "wall")
        root.add_child(wall)
        var player = _spawn(Vector2(-18, 200))
        player.wall_grip_unlocked = true
        Input.action_press("move_right")
        await _frames(8)
        _check(player.is_on_wall(), "wall policy fixture touches its real collider")
        Input.action_press("jump")
        await _frames(2)
        Input.action_release("jump")
        Input.action_release("move_right")
        _check((player.velocity.y < 0) == not smooth, "ordinary walls retain wall jumps; sealed niche walls cannot supply one")
        player.queue_free()
        wall.queue_free()
        await _frames(2)

func _settle(player) -> float:
    for index in range(90):
        await _frames(1)
        if index > 20 and player.is_on_floor() and absf(player.velocity.y) < 1.0:
            break
    var rest: float = player.global_position.y if player.is_on_floor() else INF
    last_collected = collected
    player.queue_free()
    await _frames(2)
    return rest

func _near(value: float, target: float, label: String) -> void:
    _check(absf(value - target) < 4.0, label + " (y=%.1f, expected %.1f)" % [value, target])

func _find(list: Array, id: String) -> Dictionary:
    for item in list:
        if String(item.get("id", "")) == id:
            return item
    return {}

func _rect(values: Array) -> Rect2:
    return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

func _vec(values: Array) -> Vector2:
    return Vector2(float(values[0]), float(values[1]))

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
