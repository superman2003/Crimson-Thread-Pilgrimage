extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    _assert(scene.config.has("world_story"), "world story data still exists")
    _assert(int(scene.config.get("npcs", []).size()) >= 5, "five story npcs configured")
    _assert(int(scene.config.get("guides", []).size()) == 0, "guide arrows are removed from config")
    _assert(scene.get_node_or_null("npc_lift_cartographer") != null, "cartographer npc spawned")
    _assert(scene.get_node_or_null("guide_map") == null, "guide arrow nodes are not spawned")
    _assert(scene.dialogue_panel != null, "dialogue overlay exists")

    scene._refresh_hud()
    _assert(String(scene.hud_label.text).contains("HP"), "HUD remains readable during Chinese content pass")

    scene._toggle_backpack()
    _assert(_contains_han(scene.backpack_text.text), "backpack text uses Chinese item copy")
    _assert(String(scene.backpack_text.text).contains("绯线爆裂"), "Chinese skill item name is visible")
    _assert(String(scene.backpack_text.text).contains("苔光镜"), "Chinese relic item name is visible")

    scene._toggle_map()
    _assert(_contains_han(scene.map_text.text), "map detail text uses Chinese route copy")
    _assert(String(scene.map_text.text).contains("Objective"), "map objective is shown")
    _assert(String(scene.map_text.text).contains("Next"), "map next route is shown")

    scene._close_overlays()
    var npc: Area2D = scene.get_node_or_null("npc_gate_pilgrim")
    _assert(npc != null, "gate pilgrim npc spawned")
    scene._on_interactable_entered(scene.player, npc)
    _assert(String(scene.toast_label.text) == "按F交谈", "NPC prompt is Chinese")
    scene.nearby_interactable = npc
    scene._try_interact()
    _assert(scene.dialogue_panel.visible, "NPC dialogue opens panel")
    _assert(_contains_han(scene.dialogue_text_label.text), "NPC dialogue panel text is Chinese")
    _assert(String(scene.dialogue_name_label.text).contains("守门朝圣者"), "Chinese NPC name is visible")
    _assert(String(npc.get_meta("identity", "")).contains("老巡礼者"), "NPC identity is data-driven")
    var npc_help := String(npc.get_meta("help", ""))
    _assert(npc_help.contains("敌") or npc_help.contains("战斗"), "NPC help text is data-driven combat guidance")

    scene._toggle_map()
    await process_frame
    _assert(not _visible_han_labels(scene).is_empty(), "visible map labels include Chinese")

    print("CHINESE_STORY_VALIDATION_PASS chinese_story_visible=true npc_prompt_chinese=true")
    quit(0)


func _visible_han_labels(node: Node) -> Array[String]:
    var hits: Array[String] = []
    var label := node as Label
    if label != null and label.is_visible_in_tree():
        var text := String(label.text)
        if _contains_han(text):
            hits.append("%s=%s" % [label.get_path(), text])
    for child in node.get_children():
        hits.append_array(_visible_han_labels(child))
    return hits


func _contains_han(text: String) -> bool:
    for index in range(text.length()):
        var code := text.unicode_at(index)
        if code >= 0x4E00 and code <= 0x9FFF:
            return true
    return false


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    quit(1)
