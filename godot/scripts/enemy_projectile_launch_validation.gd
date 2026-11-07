extends SceneTree
## V04 launch at collision boundaries: every ordinary and elite shot of the
## forty creatures, fired by the real actor standing flush against a wall it
## faces, impacts on that wall and never appears beyond it; a beam reaches no
## further than the wall. The muzzle sits 18px (20px after a blink) ahead of the
## actor origin while bodies are 35px wide and often offset towards their art,
## so shots used to start inside the wall, where rays ignore it. Open-air shots
## and beams still reach past where the wall would be.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const SHOTS := ["projectile", "fan", "nova", "mortar", "blink", "beam"]
const WALL_THICKNESS := 24.0
var checks := 0
var failures := 0
var report := {"commands": 0, "launches": 0, "muzzle_in_wall": 0, "open_air_flew": 0}

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("ENEMY_PROJECTILE_LAUNCH: " + label)

func _frames(count: int) -> void:
    for index in count:
        await physics_frame

func _wall(arena: Node2D, near_x: float, facing: int) -> StaticBody2D:
    var body := StaticBody2D.new()
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(WALL_THICKNESS, 900)
    shape.shape = rect
    body.position = Vector2(near_x + facing * WALL_THICKNESS * 0.5, 300)
    body.add_child(shape)
    arena.add_child(body)
    return body

func _live_shots(actor: Node) -> Array:
    return actor.owned_attack_effects.filter(func(effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.effect_kind in ["projectile", "beam"])

## Fires one command and follows every shot; returns the farthest point any
## shot reached along `facing` (beams: their drawn end), and whether a muzzle
## started inside the wall span.
func _fire(arena: Node2D, kind: String, profile: Dictionary, command: Dictionary, facing: int, walled: bool) -> Dictionary:
    var actor = ENEMY.new()
    actor.configure({"kind": kind, "hp": 40, "elite": true}, "res://assets/sprites/original_creatures/" + kind + "/manifest.json", false, profile)
    actor.position = Vector2(600, 300)
    arena.add_child(actor)
    actor.set_physics_process(false)
    var body: CollisionShape2D = null
    for child in actor.get_children():
        if child is CollisionShape2D: body = child
    var center: Vector2 = body.global_position
    var near_x: float = center.x + facing * (body.shape as RectangleShape2D).size.x * 0.5
    var wall: StaticBody2D = _wall(arena, near_x, facing) if walled else null
    actor.direction = facing
    actor.attack_direction = facing
    actor.spawn_position = actor.position
    # A blink clamps to the platform: keep it flush against the wall.
    actor.platform_min_x = actor.position.x if facing < 0 else 0.0
    actor.platform_max_x = actor.position.x if facing > 0 else 4000.0
    actor.attack_target = Vector2(actor.position.x + facing * 420, center.y)
    await _frames(2)
    actor._spawn_command_effects(command, false)
    var result := {"reach": -INF, "in_wall": false, "shots": 0}
    for effect in _live_shots(actor):
        result.shots += 1
        if effect.muzzle_blocked:
            result.in_wall = true
    for frame in 150:
        var live := _live_shots(actor)
        if live.is_empty():
            break
        for effect in live:
            var tip: Vector2 = effect.global_position
            if effect.effect_kind == "beam":
                tip += effect.heading * effect.length
            result.reach = maxf(result.reach, (tip.x - near_x) * facing)
        await _frames(1)
    RETIREMENT.retire_tree(actor)
    for effect in actor.owned_attack_effects:
        if is_instance_valid(effect): effect.queue_free()
    actor.queue_free()
    if wall != null: wall.queue_free()
    await _frames(2)
    return result

func _run() -> void:
    var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var arena := Node2D.new()
    root.add_child(arena)
    for kind in catalogue:
        var profile: Dictionary = catalogue[kind]
        var commands: Array = profile.get("attacks", []).duplicate(true)
        commands.append_array(profile.get("elite", {}).get("attacks", []).duplicate(true))
        for command: Dictionary in commands:
            if not String(command.get("type", "")) in SHOTS:
                continue
            report.commands += 1
            var cid := String(command.get("id", kind))
            for facing in [-1, 1]:
                var walled: Dictionary = await _fire(arena, kind, profile, command, facing, true)
                report.launches += 1
                if walled.in_wall:
                    report.muzzle_in_wall += 1
                check(walled.shots > 0, "%s (%d) fires at least one shot" % [cid, facing])
                check(walled.reach <= WALL_THICKNESS * 0.5, "%s (%d) never passes the wall it is pressed against (reached %.0fpx past its face)" % [cid, facing, walled.reach])
                if facing == 1:
                    var open: Dictionary = await _fire(arena, kind, profile, command, facing, false)
                    if open.reach > WALL_THICKNESS * 2.0:
                        report.open_air_flew += 1
    check(report.commands >= 30, "the catalogue still holds the ranged commands (%d)" % report.commands)
    check(report.muzzle_in_wall > 0, "the fixture puts muzzles inside the wall (%d)" % report.muzzle_in_wall)
    check(report.open_air_flew * 10 >= report.commands * 9, "open-air shots still fly past where the wall would be (%d/%d)" % [report.open_air_flew, report.commands])
    arena.queue_free()
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    await _frames(2)
    check(await RETIREMENT.drain(self), "fixture releases mixer references before exit")
    print("ENEMY_PROJECTILE_LAUNCH_REPORT ", JSON.stringify(report))
    if failures == 0:
        print("ENEMY_PROJECTILE_LAUNCH_PASS checks=%d" % checks)
    else:
        print("ENEMY_PROJECTILE_LAUNCH_FAIL failures=%d checks=%d" % [failures, checks])
    call_deferred("quit", 0 if failures == 0 else 1)
