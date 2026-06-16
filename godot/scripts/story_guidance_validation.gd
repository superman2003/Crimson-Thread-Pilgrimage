extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"
const CONFIG_PATHS := [
    "res://data/demo_ch01_moss_bell_court.json",
    "res://data/demo_ch02_rain_foundry_canal.json",
    "res://data/demo_ch03_saltwhite_archive.json",
    "res://data/demo_ch04_broken_string_greenhouse.json",
    "res://data/demo_ch05_obsidian_pilgrim_road.json",
    "res://data/demo_ch06_silent_crown_core.json"
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    for config_path in CONFIG_PATHS:
        await _validate_config(config_path)

    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    _assert(scene.get_demo_state().get("dialogue_overlay_ready") == true, "dialogue overlay is built")
    _assert(int(scene.get_demo_state().get("guide_marker_total", -1)) == 0, "guide arrow config is empty at runtime")
    _assert(_count_nodes_with_prefix(scene, "guide") == 0, "guide arrow nodes are not spawned")

    var npc: Area2D = scene.get_node_or_null("npc_gate_pilgrim")
    _assert(npc != null, "story NPC exists")
    scene.nearby_interactable = npc
    scene._try_interact()
    _assert(scene.dialogue_panel.visible, "NPC opens dialogue panel")
    _assert(String(scene.dialogue_name_label.text).contains("守门朝圣者"), "dialogue panel shows NPC name")
    _assert(String(scene.dialogue_meta_label.text).contains("老巡礼者"), "dialogue panel shows NPC identity")
    var help_text := String(scene.dialogue_hint_label.text)
    _assert(help_text.contains("敌") or help_text.contains("战斗"), "dialogue panel shows combat-clear NPC help")
    _assert(String(scene.dialogue_text_label.text).contains("正门"), "dialogue panel shows story line")

    print("STORY_GUIDANCE_VALIDATION_PASS chapters=6 arrows=0 npc_story=true dialogue_panel=true")
    quit(0)


func _validate_config(config_path: String) -> void:
    var config := _load_json(config_path)
    _assert(config.has("world_story"), config_path + " has world story")
    _assert(int(config.get("guides", []).size()) == 0, config_path + " has no guide arrows")
    for item in config.get("npcs", []):
        var npc: Dictionary = item
        _assert(not String(npc.get("identity", "")).is_empty(), config_path + " NPC identity exists: " + String(npc.get("id", "")))
        _assert(not String(npc.get("motive", "")).is_empty(), config_path + " NPC motive exists: " + String(npc.get("id", "")))
        _assert(not String(npc.get("help", "")).is_empty(), config_path + " NPC help exists: " + String(npc.get("id", "")))
        _assert(npc.get("dialogue", []).size() >= 3, config_path + " NPC has story dialogue: " + String(npc.get("id", "")))
    await process_frame


func _count_nodes_with_prefix(node: Node, prefix: String) -> int:
    var count := 0
    if String(node.name).begins_with(prefix):
        count += 1
    for child in node.get_children():
        count += _count_nodes_with_prefix(child, prefix)
    return count


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var data = JSON.parse_string(file.get_as_text())
    return data if typeof(data) == TYPE_DICTIONARY else {}


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    quit(1)
