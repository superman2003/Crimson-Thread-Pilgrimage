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
const ECHO_KEY := "ch06_beat_echo_room"
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

## Echo-room beat (manifest ch06_beat_01): the first visit to each of the five
## echo rooms answers with the low bell phrase; other rooms and revisits do not.
func _echo_rooms(level: Node) -> void:
    _check(level.AUDIO.has(ECHO_KEY) and ResourceLoader.exists(String(level.AUDIO[ECHO_KEY])), "the echo-room beat is the generated ch06 bell phrase")
    level.set_process(false)
    level.set_physics_process(false)
    level.player.set_physics_process(false)
    level.visited_rooms.clear()
    level.current_room_id = ""
    var echo_rooms := 0
    var other_rooms := 0
    for room in level.config.get("map_rooms", []):
        var rect: Array = room.get("layout_rect", [])
        if rect.size() != 4:
            continue
        var id := String(room.get("id", ""))
        var before: int = level.played.count(ECHO_KEY)
        level.player.global_position = Vector2(float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + float(rect[3]) * 0.5)
        level._update_room_visit()
        if String(level.current_room_id) != id:
            continue
        var rang: bool = level.played.count(ECHO_KEY) == before + 1
        if id.begins_with("echo_"):
            echo_rooms += 1
            _check(rang, "first visit to %s rings the bell phrase once" % id)
        else:
            other_rooms += 1
            _check(level.played.count(ECHO_KEY) == before, "%s is not an echo room and stays quiet" % id)
    _check(echo_rooms == 5 and other_rooms >= 5, "all five echo rooms and the other rooms were walked (%d, %d)" % [echo_rooms, other_rooms])
    var total: int = level.played.count(ECHO_KEY)
    for room in level.config.get("map_rooms", []):
        var rect: Array = room.get("layout_rect", [])
        if rect.size() != 4 or not String(room.get("id", "")).begins_with("echo_"):
            continue
        level.player.global_position = Vector2(float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + float(rect[3]) * 0.5)
        level._update_room_visit()
    _check(level.played.count(ECHO_KEY) == total, "revisiting the echo rooms does not ring again")
    level.config["id"] = "demo_ch01_moss_bell_court"
    _check(not level._play_echo_room_beat({"id": "echo_moss"}), "a room named echo_* in another region stays quiet")
    level.config["id"] = "demo_ch06_silent_crown_core"

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
    await _echo_rooms(revisit)
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
