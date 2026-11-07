extends SceneTree
## S02 region beat layers: the delayed shadow's echo strike layers the archive's
## glass and page sound (its blink does not), and breaking a floor with the
## thorn downstrike in the broken string greenhouse layers the snapped-string
## sound on the break (other regions keep only the break); the pilgrim
## commander's charge windup carries parade footfalls that stop the moment the
## windup ends, is interrupted or the commander retires. Real actors and
## production levels with probes that record sound requests instead of playing.
class ProbeEnemy extends "res://scripts/enemy_actor.gd":
    var played: Array[String] = []
    func _play_sfx(audio_key: String, volume_db: float = -6.0, pitch_scale: float = 1.0, voice_priority: int = 1) -> void:
        played.append(audio_key)

class AudibleEnemy extends "res://scripts/enemy_actor.gd":
    func _should_play_sfx() -> bool:
        return true

class ProbeLevel extends "res://scripts/main_level.gd":
    var played: Array[String] = []
    func _play_sfx(audio_key: String, volume_db: float = -7.0) -> void:
        played.append(audio_key)

const SHADOW_KEY := "ch03_beat_delayed_shadow"
const STRING_KEY := "ch04_beat_string_break"
const PARADE_KEY := "ch05_beat_parade"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    await _shadow()
    await _parade()
    for row in [["res://data/demo_ch04_broken_string_greenhouse.json", true], ["res://data/demo_ch01_moss_bell_court.json", false]]:
        await _floor_break(String(row[0]), bool(row[1]))
    _check(await preload("res://scripts/audio_retirement.gd").drain(self, 3000), "fixture audio is released before exit")
    if failures.is_empty():
        print("REGION_BEAT_LAYERS_PASS checks=%d" % checks)
    else:
        for label in failures:
            push_error(label)
        print("REGION_BEAT_LAYERS_FAIL failures=%d checks=%d" % [failures.size(), checks])
    call_deferred("quit", 0 if failures.is_empty() else 1)

## Each delayed shadow command through the actor's own attack path.
func _shadow() -> void:
    var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var arena := Node2D.new()
    root.add_child(arena)
    var actor := ProbeEnemy.new()
    actor.configure({"kind": "delayed_shadow", "hp": 40}, "res://assets/sprites/original_creatures/delayed_shadow/manifest.json", false, catalogue["delayed_shadow"])
    actor.position = Vector2(400, 300)
    arena.add_child(actor)
    actor.set_physics_process(false)
    _check(actor.SFX.has(SHADOW_KEY) and ResourceLoader.exists(String(actor.SFX[SHADOW_KEY])), "the shadow layer is the generated archive glass and page sound")
    var ids := {}
    for command: Dictionary in catalogue["delayed_shadow"].get("attacks", []):
        actor.played.clear()
        actor.attack_target = actor.position + Vector2(160, 0)
        actor._begin_attack(command)
        actor._play_attack_sfx("active")
        ids[String(command.id)] = actor.played.count(SHADOW_KEY)
        actor._cancel_attack_effects()
        actor._clear_telegraph()
    _check(ids.get("shadow_echo", 0) == 1, "the echo strike layers the shadow sound once (%s)" % ids)
    _check(ids.get("shadow_blink", -1) == 0, "the blink keeps only the ordinary attack sound (%s)" % ids)
    preload("res://scripts/audio_retirement.gd").retire_tree(arena)
    arena.queue_free()
    await process_frame

func _parade_nodes(actor: Node) -> Array:
    return actor.get_children().filter(func(child): return child is AudioStreamPlayer2D and String(child.name).begins_with("Sfx_" + PARADE_KEY) and not child.is_queued_for_deletion())

## The commander's real charge (vault) and an ordinary strike, with real voices.
func _parade() -> void:
    var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var profile: Dictionary = catalogue["silent_pilgrim_commander"]
    var arena := Node2D.new()
    root.add_child(arena)
    var actor := AudibleEnemy.new()
    actor.configure({"kind": "silent_pilgrim_commander", "hp": 40}, "res://assets/sprites/original_creatures/silent_pilgrim_commander/manifest.json", false, profile)
    actor.position = Vector2(400, 300)
    arena.add_child(actor)
    actor.set_physics_process(false)
    _check(actor.SFX.has(PARADE_KEY) and ResourceLoader.exists(String(actor.SFX[PARADE_KEY])), "the parade layer is the generated footfall loop")
    var charge: Dictionary = {}
    var strike: Dictionary = {}
    for command: Dictionary in profile.get("attacks", []):
        if String(command.get("type", "")) == "vault": charge = command
        elif String(command.get("type", "")) == "melee": strike = command
    _check(not charge.is_empty() and not strike.is_empty(), "the commander has a charge and an ordinary strike")
    actor.attack_target = actor.position + Vector2(200, 0)
    actor._begin_attack(strike)
    _check(_parade_nodes(actor).is_empty(), "an ordinary strike has no parade footfalls")
    actor._cancel_attack_effects()
    actor._begin_attack(charge)
    var running: Array = _parade_nodes(actor)
    _check(running.size() == 1 and running[0].playing, "the charge windup plays the parade footfalls")
    actor._update_windup(99.0)
    _check(actor.state == "active" and _parade_nodes(actor).is_empty(), "the footfalls stop when the charge is released")
    actor._cancel_attack_effects()
    # Voice admission spaces repeats of one key; wait it out like a real fight.
    for frame in 60:
        await process_frame
    actor._begin_attack(charge)
    _check(_parade_nodes(actor).size() == 1, "a later charge plays the footfalls again")
    actor.state = "recover"
    actor._physics_process(1.0 / 60.0)
    _check(_parade_nodes(actor).is_empty(), "an interrupted charge does not leave the footfalls running")
    actor._cancel_attack_effects()
    preload("res://scripts/audio_retirement.gd").retire_tree(arena)
    arena.queue_free()
    await process_frame

## A planted downstrike floor broken through the level's own unlock path.
func _floor_break(config: String, greenhouse: bool) -> void:
    var level := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    level.set_script(ProbeLevel)
    level.set("config_path", config)
    root.add_child(level)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(level)
    await process_frame
    var region := config.get_file().get_basename()
    if greenhouse:
        _check(level.AUDIO.has(STRING_KEY) and ResourceLoader.exists(String(level.AUDIO[STRING_KEY])), "the greenhouse layer is the generated snapped-string sound")
    for gate in [["validation_downstrike_floor", "gate_downstrike"], ["validation_dash_gate", "gate_dash"]]:
        var body := StaticBody2D.new()
        level.add_child(body)
        level.locked_gate_bodies[String(gate[0])] = body
        level.played.clear()
        level._unlock_ability_gate(String(gate[0]), String(gate[1]))
        var layered: int = level.played.count(STRING_KEY)
        var expected := 1 if greenhouse and gate[1] == "gate_downstrike" else 0
        _check(level.played.has(String(gate[1])) and layered == expected, "%s %s plays its break sound with %d string layer(s) (got %d)" % [region, gate[1], expected, layered])
    preload("res://scripts/audio_retirement.gd").retire_tree(level)
    level.queue_free()
    await process_frame
    await process_frame
