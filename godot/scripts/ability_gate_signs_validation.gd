extends SceneTree
## A01: every closed ability gate in the six regions carries the pictogram of
## the ability that opens it; its written name shows only near the gate, and
## opening the gate removes the sign with the wall.
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const SIGN := preload("res://scripts/ability_gate_sign.gd")
const CHAPTERS := [
    "res://data/demo_ch01_moss_bell_court.json",
    "res://data/demo_ch02_rain_foundry_canal.json",
    "res://data/demo_ch03_saltwhite_archive.json",
    "res://data/demo_ch04_broken_string_greenhouse.json",
    "res://data/demo_ch05_obsidian_pilgrim_road.json",
    "res://data/demo_ch06_silent_crown_core.json",
]

var failures := 0
var checks := 0
var gates := 0
var abilities := {}


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    for path: String in CHAPTERS:
        var scene: Node = MAIN_SCENE.instantiate()
        scene.set("config_path", path)
        root.add_child(scene)
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
        await _frames(4)
        for data: Dictionary in scene.config.get("locked_gates", []):
            await _check_gate(scene, data, path.get_file())
        scene.queue_free()
        await _frames(4)
    _check(abilities.size() == SIGN.GLYPHS.size(), "every gated ability has a drawn pictogram %s" % str(abilities.keys()))
    if failures > 0:
        print("ABILITY_GATE_SIGNS_FAIL failures=%d checks=%d" % [failures, checks])
        quit(1)
        return
    print("ABILITY_GATE_SIGNS_PASS gates=%d abilities=%d checks=%d" % [gates, abilities.size(), checks])
    quit(0)


func _check_gate(scene: Node, data: Dictionary, chapter: String) -> void:
    var id := String(data.get("id", ""))
    var ability := String(data.get("required_ability", ""))
    var body: Node2D = scene.locked_gate_bodies.get(id)
    if not is_instance_valid(body):
        # Already opened for this host (owned ability): no wall, no sign.
        return
    gates += 1
    abilities[ability] = true
    var sign: Node2D = body.get_node_or_null("AbilityGateSign")
    _check(sign != null and sign.ability == ability, "%s %s shows the %s pictogram" % [chapter, id, ability])
    if sign == null:
        return
    _check(SIGN.GLYPHS.has(ability), "%s %s ability has its own glyph" % [chapter, id])
    _check(not String(sign.ability_name).is_empty() and sign.caption() == "需要 · " + String(data.get("required_ability_name", "")), "%s %s names the ability" % [chapter, id])
    var player: Node2D = scene.player
    player.global_position = sign.global_position + Vector2(600, 0)
    await _frames(2)
    _check(not sign.nearby, "%s %s keeps its caption hidden from afar" % [chapter, id])
    player.global_position = sign.global_position + Vector2(-90, 40)
    await _frames(2)
    _check(sign.nearby, "%s %s shows its caption up close" % [chapter, id])
    scene._unlock_ability_gate(id)
    await _frames(2)
    _check(not is_instance_valid(sign), "%s %s sign leaves with the opened gate" % [chapter, id])


func _frames(count: int) -> void:
    for index in count:
        await process_frame


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("ABILITY_GATE_SIGNS " + label)
