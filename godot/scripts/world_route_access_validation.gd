extends SceneTree
## Condition matrix plus live entry feedback; does not claim physical traversal.
const ROUTES := preload("res://scripts/world_routes.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    for region in ROUTES._data().chapters.values():
        for portal in region.portals:
            var ability := String(portal.get("required_ability", ""))
            var latch := String(portal.get("requires_shortcut", ""))
            var unlock := String(portal.get("unlock_shortcut_id", ""))
            for owned in [false,true]:
                for opened in [false,true]:
                    var inventory := {}
                    var flags := {}
                    if not ability.is_empty(): inventory[ability] = 1 if owned else 0
                    if not latch.is_empty(): flags["world_shortcut_"+latch] = opened
                    if not unlock.is_empty(): flags["world_shortcut_"+unlock] = opened
                    var result := ROUTES.access(portal,inventory,flags)
                    var allowed: bool = (ability.is_empty() or owned) and (latch.is_empty() or opened)
                    check(result.open==allowed,String(portal.id)+": ability and directional latch remain independent")
                    check(result.hint.is_empty()==allowed,String(portal.id)+": blocking reason agrees with traversal")
    # Historical shortcut bypass: archive return has both a latch and an ability.
    var entry := ROUTES.portal("demo_ch01_moss_bell_court","moss_archive_return")
    check(not ROUTES.access(entry,{}, {"world_shortcut_archive_return":true}).open,"opened archive latch does not grant double jump")
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path="user://route_access_validation.json"
    root.add_child(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    var area: Node = scene.get_node("moss_archive_return")
    scene._refresh_world_portals()
    check(area.get_node("Wayfinding").gate_state=="far_side","closed near-side entry visibly identifies distant latch")
    scene.story_flags["world_shortcut_archive_return"]=true
    scene._refresh_world_portals()
    check(area.get_node("Wayfinding").gate_state=="ability","opening latch updates feedback to remaining ability")
    check(area.get_meta("interaction_label").contains("双线跃"),"interaction explains remaining ability without hover")
    scene._activate_world_portal(area)
    check(not scene.chapter_transitioning,"live activation cannot bypass missing ability after latch unlock")
    scene._add_inventory_item("double_thread_jump",1,false)
    scene._refresh_ability_gates()
    check(area.get_node("Wayfinding").gate_state=="open","ability pickup refreshes entry without scene reload")
    check(area.get_meta("route_status").open,"live feedback uses same condition as traversal")
    scene.story_flags.erase("world_shortcut_archive_return")
    var journal = preload("res://scripts/pilgrimage_cartography.gd")
    journal.region(scene.story_flags,String(scene.config.id)).owned=true
    journal.visit(scene.story_flags,String(scene.config.id),String(entry.room_id))
    journal.rest(scene.story_flags)
    scene._toggle_map()
    scene.world_map_view=true
    scene._refresh_map_overlay()
    var asymmetric := false
    for child in scene.map_draw_root.get_children():
        if child is Line2D and child.has_meta("target_region"):
            if String(child.get_meta("target_region"))=="demo_ch03_saltwhite_archive":
                asymmetric=true
                check(not child.get_meta("forward_status").open and child.get_meta("reverse_status").open,"atlas retains both directions of far-side return")
    check(asymmetric,"atlas displays actual archive return pair")
    scene.queue_free()
    await process_frame
    for suffix in ["", ".tmp", ".bak"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://route_access_validation.json"+suffix))
    print("WORLD_ROUTE_ACCESS checks=%d failures=%d fixture_positioning=true" % [checks,failures])
    quit(1 if failures else 0)
