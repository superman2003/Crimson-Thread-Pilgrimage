extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var state: Dictionary = scene.get_demo_state()
    _assert(bool(state.get("backpack_overlay_ready", false)), "backpack overlay exists")
    _assert(bool(state.get("map_overlay_ready", false)), "map overlay exists")
    _assert(int(scene.inventory_counts.get("thread_burst", 0)) == 1, "starting skill tool is in backpack")
    _assert(int(scene.inventory_counts.get("menders_right", 0)) == 1, "healing tool is in backpack")
    _assert(int(scene.inventory_counts.get("moss_lens", 0)) == 1, "map relic is in backpack")
    _assert(String(state.get("progression_mode", "")) == "combat_clear", "combat-clear progression is active")
    _assert(String(state.get("current_room_id", "")) == "entry_bell", "player starts in entry map room")

    scene._toggle_backpack()
    _assert(scene.backpack_panel.visible, "Tab/I backpack opens overlay")
    _assert(String(scene.backpack_text.text).contains("绯线爆裂"), "backpack lists skill tool")
    _assert(String(scene.backpack_text.text).contains("苔光镜"), "backpack lists map relic")

    scene._toggle_map()
    _assert(not scene.backpack_panel.visible, "map hides backpack overlay")
    _assert(scene.map_panel.visible, "M map opens overlay")
    _assert(scene.map_draw_root.get_child_count() > 0, "map draws room geometry")

    scene.player.global_position = Vector2(2030, 478)
    await process_frame
    scene._toggle_map()
    scene._toggle_map()
    state = scene.get_demo_state()
    _assert(String(state.get("current_room_id", "")) == "gear_lift", "map tracks current room after travel")
    _assert(int(state.get("visited_room_total", 0)) >= 2, "map records visited rooms")
    _assert(String(scene.map_text.text).contains(_room_name(scene.config, "gear_lift")), "map text names current room")
    _assert(String(scene.map_text.text).contains("Objective"), "map text shows route objective")

    var currency_before := int(scene.currency_count)
    scene._on_enemy_died("T", false, "moss_larva")
    _assert(scene.currency_count > currency_before, "normal melee enemy drops currency")
    _assert(int(scene.inventory_materials.get("moss_chitin", 0)) >= 1, "normal melee enemy drops material")
    scene._debug_clear_combat_route()
    state = scene.get_demo_state()
    _assert(bool(state.get("boss_unlocked", false)), "combat clear unlocks boss route")

    scene._on_enemy_died("B", true, "rust_crown_guardian")
    _assert(int(scene.inventory_materials.get("crown_splinter", 0)) >= 1, "boss drops unique material")

    scene._close_overlays()
    _assert(not scene.backpack_panel.visible and not scene.map_panel.visible, "Esc closes overlays")

    print("INVENTORY_MAP_VALIDATION_PASS backpack=true map=true visited=%d currency=%d" % [scene.visited_rooms.size(), scene.currency_count])
    quit(0)


func _room_name(config: Dictionary, room_id: String) -> String:
    for room in config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if String(room_data.get("id", "")) == room_id:
            return String(room_data.get("name", room_id))
    return room_id


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    quit(1)
