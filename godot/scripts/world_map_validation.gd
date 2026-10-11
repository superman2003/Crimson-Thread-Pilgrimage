extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _run() -> void:
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://world_map_validation.json"
    root.add_child(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)
    scene._toggle_map()
    _check(scene.active_overlay == "map" and scene.player.ui_input_locked, "map locks player movement")
    _check(scene.map_draw_root.get_node_or_null("WorldRegion_demo_ch01_moss_bell_court") == null, "local map remains initial view")
    scene.world_map_view = true
    scene._refresh_map_overlay()
    _check(scene.map_text.text.contains("互联世界"), "world atlas shows topology copy")
    var panels := 0
    var edges := 0
    for child in scene.map_draw_root.get_children():
        if String(child.name).begins_with("WorldRegion_") and not String(child.name).ends_with("Border"):
            panels += 1
            _check(child.position.y + child.size.y <= scene.map_draw_root.size.y, "world panels fit above map text")
        if child is Line2D:
            edges += 1
            _check(child.points.size() == 2, "atlas edges represent actual paired regions")
    _check(panels == 6, "atlas contains six canonical regions")
    _check(edges > 0 and edges < 6, "atlas reveals only known region adjacency")
    _check(scene.wish_panel == null or not scene.wish_panel.visible, "atlas does not overlap wish board")
    var anchor: Node2D = scene.get_node("moss_viaduct_ring")
    _check(not bool(anchor.get_meta("grapple_enabled")), "real world anchor remains locked without hook")
    scene._add_inventory_item("echo_hook", 1, false)
    scene._sync_player_abilities()
    _check(bool(anchor.get_meta("grapple_enabled")) and scene.player.thread_grapple_unlocked, "real world anchor and action unlock together")
    scene.world_map_view = false
    scene._refresh_map_overlay()
    _check(scene.map_draw_root.get_node_or_null("WorldRegion_demo_ch01_moss_bell_court") == null, "returning to local map clears atlas")
    _check(scene.wish_panel == null or scene.wish_panel.visible, "local map restores wish board")
    scene._close_overlays()
    _check(not scene.player.ui_input_locked, "map close returns player control")
    scene.queue_free()
    await process_frame
    for suffix in ["", ".tmp", ".bak"]:
        var path: String = "user://world_map_validation.json" + String(suffix)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("WORLD_MAP checks=%d failures=%d" % [checks, failures])
    quit(1 if failures > 0 else 0)
