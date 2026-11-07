extends SceneTree
## S02 ending-doors beat: the final Boss defeat raises the three ending doors
## with the generated ending-doors chord once; reloading a completed region
## restores the doors silently. Production ch06 level with a probe that records
## the level's sound requests instead of playing them.
class ProbeLevel extends "res://scripts/main_level.gd":
    var played: Array[String] = []
    func _play_sfx(audio_key: String, volume_db: float = -7.0) -> void:
        played.append(audio_key)

const CROWN := "res://data/demo_ch06_silent_crown_core.json"
const KEY := "ch06_beat_ending_doors"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _gates(level: Node) -> Array:
    return level.get_children().filter(func(child): return child is Area2D and String(child.get_meta("kind", "")) == "ending_gate")

func _level() -> Node:
    var level := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    level.set_script(ProbeLevel)
    level.set("config_path", CROWN)
    root.add_child(level)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(level)
    await process_frame
    return level

func _run() -> void:
    var level := await _level()
    _check(level.AUDIO.has(KEY) and ResourceLoader.exists(String(level.AUDIO[KEY])), "the beat is the generated ch06 ending-doors chord")
    _check(not level.played.has(KEY) and _gates(level).is_empty(), "no doors and no chord before the final defeat")
    level._on_enemy_died("validation_final_boss", true, "silent_crown_core")
    await process_frame
    _check(_gates(level).size() == 3, "the final defeat raises the three ending doors (%d)" % _gates(level).size())
    _check(level.played.count(KEY) == 1, "the doors appear with the ending-doors chord once (%d)" % level.played.count(KEY))
    level._on_enemy_died("validation_final_boss", true, "silent_crown_core")
    level._spawn_ending_gates()
    _check(level.played.count(KEY) == 1, "a repeated defeat call or spawn request does not replay it")
    preload("res://scripts/audio_retirement.gd").retire_tree(level)
    level.queue_free()
    await process_frame
    await process_frame
    # A revisit of the completed region restores the doors without the chord
    # (the region publish path), in a fresh level.
    var revisit := await _level()
    revisit.demo_complete = true
    revisit._spawn_ending_gates()
    _check(_gates(revisit).size() == 3 and not revisit.played.has(KEY), "restored doors on a revisit stay silent")
    preload("res://scripts/audio_retirement.gd").retire_tree(revisit)
    revisit.queue_free()
    await process_frame
    await process_frame
    _check(await preload("res://scripts/audio_retirement.gd").drain(self, 3000), "level audio is released before exit")
    if failures.is_empty():
        print("ENDING_DOORS_BEAT_PASS checks=%d" % checks)
    else:
        for label in failures:
            push_error(label)
        print("ENDING_DOORS_BEAT_FAIL failures=%d checks=%d" % [failures.size(), checks])
    call_deferred("quit", 0 if failures.is_empty() else 1)
