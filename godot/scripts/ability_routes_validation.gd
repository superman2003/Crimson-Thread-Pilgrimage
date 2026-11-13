extends SceneTree
## Production ability-action handler + real input, paired route permissions and
## disk round trips. Local floor fixtures do not claim a campaign playthrough.
const STAGE := preload("res://tests/ability_action_stage.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const BODY := preload("res://scripts/world_platform_body.gd")
const PLAYER := preload("res://scenes/Player.tscn")
const STATE := preload("res://scripts/world_state.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_routes.json"))
    _check(data.get("ability_routes", []).size() == 5, "two hook lines and three sleeping bells are authored")
    for entry in data.get("ability_routes", []):
        await _route(data, entry)
    _check(await preload("res://scripts/audio_retirement.gd").drain(self), "player audio retires")
    print("ABILITY_ROUTES checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)

func _route(data: Dictionary, entry: Dictionary) -> void:
    var id := String(entry.id)
    var region := String(entry.region_id)
    var ability := String(entry.required_ability)
    var overlay: Dictionary = data.chapters[region]
    var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
    var gate := _find(overlay.locked_gates, String(entry.gate_id))
    var forward := _find(overlay.portals, String(entry.entry_portal_id))
    var reverse := _find(overlay.portals, String(entry.return_portal_id))
    var floor := _find(base.platforms, String(entry.base_platform_id))
    var stage = STAGE.new()
    stage.world_mode = true
    stage.config = ROUTES.apply_to(base)
    stage.config["locked_gates"] = [gate]
    root.add_child(stage)
    var floor_body := BODY.create("route_floor", _rect(floor.rect), String(floor.get("collision_role", "floor")))
    var gate_body := BODY.create("route_seal", _rect(gate.rect), "")
    root.add_child(floor_body)
    root.add_child(gate_body)
    stage.locked_gate_bodies[String(gate.id)] = gate_body
    var anchor: Node2D = null
    if ability == "echo_hook":
        var ring := _find(overlay.grapple_anchors, id + "_ring")
        anchor = Node2D.new()
        anchor.position = _vec(ring.position)
        root.add_child(anchor)
        anchor.add_to_group("grapple_anchor")
    var player = PLAYER.instantiate()
    root.add_child(player)
    player.feel = null
    stage.player = player
    player.ability_action.connect(stage._on_ability_action)
    var start := Vector2(float(forward.position[0]), float(floor.rect[1]))
    player.respawn_at(start)
    await _frames(6)
    _check(not ROUTES.access(forward, {}, {}).open and not ROUTES.access(reverse, {}, {}).open, id + " both ends start closed")
    stage._on_ability_action(ability, start, Vector2.UP)
    _check(stage.locked_gate_bodies.has(String(gate.id)), id + " no permanent ability means no unlock")
    stage.inventory_counts[ability] = 1
    stage._on_ability_action(ability, start + Vector2(500, 0), Vector2.UP)
    _check(stage.locked_gate_bodies.has(String(gate.id)), id + " a distant ability action cannot unlock the route")
    stage._on_ability_action("thread_dash", start, Vector2.RIGHT)
    _check(stage.locked_gate_bodies.has(String(gate.id)), id + " the wrong action leaves the seal closed")
    _check(not ROUTES.access(forward, stage.inventory_counts, stage.story_flags).open, id + " possession alone leaves the route closed")
    player.thread_grapple_unlocked = ability == "echo_hook"
    player.crown_resonance_unlocked = ability == "crown_resonance"
    player.energy = player.max_energy
    if ability == "echo_hook": Input.action_press("aim_up")
    Input.action_press("hook" if ability == "echo_hook" else "crown_resonance")
    await _frames(3)
    Input.action_release("hook")
    Input.action_release("crown_resonance")
    Input.action_release("aim_up")
    _check(not stage.locked_gate_bodies.has(String(gate.id)), id + " real ability input opens the production action seal")
    _check(stage.save_requests == 1, id + " unlocking requests a checkpoint")
    _check(ROUTES.access(forward, stage.inventory_counts, stage.story_flags).open and ROUTES.access(reverse, stage.inventory_counts, stage.story_flags).open, id + " the same latch opens both directions")
    if not String(entry.record_id).is_empty():
        _check(stage.inventory_counts.get(String(entry.record_id), 0) == 1 and stage.inventory_relics.has(String(entry.record_id)), id + " the old bell grants a journal relic once")
    stage._on_ability_action(ability, start, Vector2.UP)
    _check(stage.save_requests == 1, id + " replaying the action cannot duplicate rewards or checkpoints")
    var saved := STATE.new()
    var snapshot := {"inventory_counts": stage.inventory_counts, "story_flags": stage.story_flags,
        "current_region": region, "entry": forward.position}
    _check(saved.capture_global(snapshot), id + " checkpoint accepts inventory and latch together")
    var path := "user://a01_route_validation.json"
    _check(saved.write(path), id + " checkpoint writes to disk")
    var restored := STATE.new()
    _check(restored.read(path), id + " fresh state reads the disk checkpoint")
    _check(ROUTES.access(reverse, restored.data.inventory_counts, restored.data.story_flags).open, id + " return passage stays open after reload")
    stage.story_flags = restored.data.story_flags.duplicate(true)
    stage.inventory_counts = restored.data.inventory_counts.duplicate(true)
    var rebuilt_gate := BODY.create("reloaded_seal", _rect(gate.rect), "")
    root.add_child(rebuilt_gate)
    stage.locked_gate_bodies[String(gate.id)] = rebuilt_gate
    stage._refresh_ability_gates()
    _check(not stage.locked_gate_bodies.has(String(gate.id)), id + " reloading removes the already-open seal")
    if not String(entry.record_id).is_empty():
        _check(stage.inventory_counts.get(String(entry.record_id), 0) == 1, id + " reload never grants a second record")
    for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
    player.queue_free()
    stage.queue_free()
    floor_body.queue_free()
    if is_instance_valid(gate_body): gate_body.queue_free()
    if is_instance_valid(anchor): anchor.queue_free()
    await _frames(3)

func _find(items: Array, id: String) -> Dictionary:
    for item in items:
        if String(item.get("id", "")) == id: return item
    return {}
func _vec(v: Array) -> Vector2: return Vector2(float(v[0]), float(v[1]))
func _rect(r: Array) -> Rect2: return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
func _frames(count: int) -> void:
    for i in range(count):
        await physics_frame
        await process_frame
func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
