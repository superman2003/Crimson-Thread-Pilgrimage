extends SceneTree
## All registered connectors: real player physics, fixture placement only at mouths.
const PASSAGE := preload("res://scripts/world_passage.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://passage_network_validation.json"
var scene: Node
var checks := 0
var failures: Array[String] = []
var roundtrips := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)
func frames(count: int = 1) -> void:
    for tick in count:
        await physics_frame
        await process_frame
func release() -> void:
    for action in ["move_left","move_right","close_overlay"]:
        if InputMap.has_action(action): Input.action_release(action)
func clean() -> void:
    for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
func spawn_region(region: String, point: Vector2) -> void:
    release()
    if is_instance_valid(scene):
        scene.free()
        await frames(3)
    clean()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path=SAVE
    scene.config_path=ROUTES.config_path(region)
    scene.entry_spawn_override_enabled=true
    scene.entry_spawn_override=point
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    scene.process_mode=Node.PROCESS_MODE_DISABLED

func walk(direction: int) -> bool:
    release()
    Input.action_press("move_right" if direction>0 else "move_left")
    scene.player.process_mode=Node.PROCESS_MODE_ALWAYS
    var previous: Vector2=scene.player_world_position()
    var max_step := 0.0
    for tick in 4200:
        await frames()
        if not scene.world_passage.settling: scene.world_passage.step()
        if scene.world_passage.settling: scene.player.process_mode=Node.PROCESS_MODE_INHERIT
        var point: Vector2=scene.player_world_position()
        max_step=maxf(max_step,point.distance_to(previous))
        previous=point
        if not scene.world_passage.active: break
    release()
    scene.player.process_mode=Node.PROCESS_MODE_INHERIT
    check(max_step<35,"World position stays continuous during physical walk/terminal rebase")
    if scene.world_passage.active:
        print("PASSAGE_STUCK route=",scene.world_passage.route.id," player=",scene.player.global_position," target=",scene.world_passage.destination_point," floor=",scene.player.is_on_floor()," settling=",scene.world_passage.settling," loader=",scene.world_loader.phase)
    return not scene.world_passage.active

func _run() -> void:
    var definitions := PASSAGE.routes()
    check(definitions.size()==5,"Five physical links connect the six-region network")
    for route in definitions:
        var portal: Dictionary=ROUTES.portal(String(route.a.region),String(route.a.portal))
        await spawn_region(String(route.a.region),Vector2(portal.position[0],portal.position[1]))
        var passage: Node=scene.world_passage
        var host_id: int=scene.get_instance_id()
        var player_id: int=scene.player.get_instance_id()
        var build_id: int=scene.build_system.get_instance_id()
        var required := String(portal.get("required_ability",""))
        if not required.is_empty():
            check(not passage.begin(String(portal.id)),String(route.id)+": missing ability blocks physical entry")
        for ability in ["silk_wall_grip","double_thread_jump","lantern_phase"]:
            scene._add_inventory_item(ability,1,false)
        scene._sync_player_abilities()
        scene.player.hp=3
        scene.player.energy=41
        scene.currency_count=97
        for side in ["a","b"]:
            var mouth: Dictionary=route[side]
            var other: Dictionary=route["b" if side=="a" else "a"]
            var area: Node=scene.get_node(String(mouth.portal))
            scene.player.global_position=area.global_position
            scene.player.velocity=Vector2.ZERO
            scene.world_platforms.warm(scene,area.global_position)
            scene.cave_world.warm_collision_focus(area.global_position)
            scene.chapter_terrain.warm_focus(area.global_position)
            scene.player.process_mode=Node.PROCESS_MODE_ALWAYS
            await frames(12)
            var glyph: String=PASSAGE.glyph(String(mouth.region),String(mouth.portal))
            var direction := 1 if glyph=="→" else -1
            Input.action_press("move_right" if direction>0 else "move_left")
            for tick in 30:
                passage.try_walk_entry()
                if passage.active: break
                await frames()
            check(passage.active,String(route.id)+" "+side+": deliberate walking enters the correct mouth")
            if not passage.active:
                quit(1)
                return
            check(passage.route.id==route.id,"Selected connector descriptor matches mouth")
            if side=="a":
                Input.action_press("close_overlay")
                passage.step()
                release()
                check(not passage.active and not scene.world_loading and scene.player.collision_layer==1,"Esc restores source region and ordinary collision")
                var cancelled := STATE.new()
                check(cancelled.read(SAVE) and cancelled.data.current_region==mouth.region,"Cancellation retains the source saved region")
                scene.player.process_mode=Node.PROCESS_MODE_INHERIT
                await frames(2)
                check(passage.begin(String(mouth.portal)),"Cancelled connector can be entered again")

            var world_span: float=passage.source_point.distance_to(passage.destination_point)
            var save_before := FileAccess.get_file_as_string(SAVE)
            scene._save_world()
            check(FileAccess.get_file_as_string(SAVE)==save_before,"Transit cannot overwrite the source checkpoint")
            check(await walk(direction),String(route.id)+" "+side+": physical traversal reaches terminal")
            check(String(scene.config.id)==String(other.region),String(route.id)+" "+side+": terminal commits expected region")
            if String(scene.config.id)!=String(other.region):
                quit(1)
                return
            check(passage.last_result.get("arrived",false) and float(passage.last_result.distance)>=world_span-65,"Authored world span is traversed by physics")
            check(scene.get_instance_id()==host_id and scene.player.get_instance_id()==player_id and scene.build_system.get_instance_id()==build_id,"Host/player/build identities survive arrival")
            check(scene.player.hp==3 and scene.player.energy==41 and scene.currency_count==97,"Walking preserves HP, energy and wallet")
            check(scene.player.collision_layer==1 and scene.player.collision_mask!=64 and passage.get_child_count()==0,"Arrival retires passage physics and restores collision")
            var state := STATE.new()
            check(state.read(SAVE) and state.data.current_region==other.region,"Completed destination is persisted")
            check(scene.player_world_position().distance_to(passage.last_result.world_position)<0.1,"Terminal coordinate rebase stays continuous")
            print("PASSAGE_NETWORK route=",route.id," side=",side," distance=",passage.last_result.distance)
        roundtrips+=1
    scene.free()
    scene=null
    current_scene=null
    await frames(4)
    clean()
    print("WORLD_PASSAGE_NETWORK checks=%d failures=%d physical_roundtrips=%d" % [checks,failures.size(),roundtrips])
    quit(0 if failures.is_empty() else 1)
