extends SceneTree
## The initial source checkpoint is a fixture. Both pipe crossings, approach,
## combat and shrine/NPC interactions use live input and normal damage.
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://neighbor_gameplay_live.json"
const MOSS := "demo_ch01_moss_bell_court"
const RAIN := "demo_ch02_rain_foundry_canal"
var scene: Node
var checks := 0
var frames := 0
var failures: Array[String] = []
var crossings: Array = []
var combat: Dictionary = {}

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        print("LIVE GAMEPLAY FAIL ",message)

func tick(count: int = 1) -> void:
    for unused in count:
        await physics_frame
        await process_frame
        frames += 1

func release_input() -> void:
    for action in ["move_left","move_right","jump","attack","interact"]:
        Input.action_release(action)

func axis(direction: float) -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    if absf(direction) > 0:
        Input.action_press("move_right" if direction > 0 else "move_left")

func press(action: String) -> void:
    Input.action_press(action)
    await tick(2)
    Input.action_release(action)
    await tick(2)

func capture_review(filename: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    var directory := ProjectSettings.globalize_path("res://../artifacts/neighbor_gameplay")
    DirAccess.make_dir_recursive_absolute(directory)
    root.get_texture().get_image().save_jpg(directory.path_join(filename),0.92)

func walk(target: Vector2, label: String, limit: int = 700) -> bool:
    release_input()
    var held := 0
    var rearm := 0
    for unused in limit:
        var dx: float = target.x - scene.player.position.x
        var rise: float = scene.player.position.y - target.y
        if absf(dx) < 16 and absf(rise) < 55 and scene.player.is_on_floor():
            release_input()
            return true
        if scene.player.hp <= 0:
            break
        axis(signf(dx) if absf(dx) > 8 else 0)
        if held > 0:
            held -= 1
            if held == 0:
                Input.action_release("jump")
                rearm = 4
        elif rearm > 0:
            rearm -= 1
        elif scene.player.is_on_floor():
            var ahead: Vector2 = scene.player.position + Vector2(signf(dx)*52,-3)
            var query := PhysicsRayQueryParameters2D.create(ahead,ahead+Vector2(0,90),1,[scene.player.get_rid()])
            var gap: bool = scene.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
            if (rise > 25 and absf(dx) < 165) or (gap and absf(dx) > 50) or (scene.player.is_on_wall() and absf(dx) > 30):
                Input.action_press("jump")
                held = 45
        await tick()
    release_input()
    check(false,"live walk reaches " + label + " actual=" + str(scene.player.position))
    return false

func actor(kind: String, data: Dictionary) -> Area2D:
    if kind != "enemy":
        return scene.get_node_or_null(NodePath(String(data.id)))
    for child in scene.get_children():
        if child.get_script() == scene.ENEMY_ACTOR_SCRIPT and child.spawn_id == String(data.id):
            return child
    return null

func crossing(target: String, direction: int) -> Dictionary:
    var pref: RefCounted = scene.world_prefetch
    # Let ordinary host _process choose/read/warm the neighbor. No cache seed.
    for unused in 240:
        await tick()
        if pref.gameplay.regions.has(target) and pref.gameplay.regions[target].plan_complete and pref.gameplay.regions[target].pending.is_empty():
            break
    check(pref.gameplay.regions.has(target),"approach naturally selects neighbor " + target)
    if not pref.gameplay.regions.has(target): return {}
    check(pref.gameplay.regions[target].plan_complete and pref.gameplay.regions[target].pending.is_empty(),"natural neighbor planning and actor warming finish before crossing")
    var records: Dictionary = pref.gameplay.regions[target].actors.duplicate()
    check(not records.is_empty(),"natural neighbor cache includes gameplay")
    var before_hits: int = pref.gameplay.hits
    var player_id: int = scene.player.get_instance_id()
    var hp: int = scene.player.hp
    var energy: int = scene.player.energy
    var wallet: int = scene.currency_count
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    axis(direction)
    var entered := false
    for unused in 3600:
        await tick()
        entered = entered or scene.world_passage.active
        if entered and not scene.world_passage.active and not scene.chapter_transitioning:
            break
    release_input()
    # Inspect adoption before active destination AI has time to despawn actors.
    check(entered and String(scene.config.id) == target and scene.world_loader.phase == "idle","directional input completes authored pipe crossing")
    check(float(scene.world_passage.last_result.get("distance",0)) >= 8500,"natural mouth approach traverses full pipe")
    check(not String(scene.world_passage.last_result.get("landing_support", "")).is_empty(),"crossing walks through the prefetched landing floor seam")
    check(scene.player.get_instance_id() == player_id and scene.player.hp == hp and scene.player.energy == energy and scene.currency_count == wallet,"crossing preserves player resources and identity")
    var expected_inventory: Dictionary = inventory.duplicate(true)
    var starting: Dictionary = scene.config.get("inventory",{})
    for item in starting.get("starting_tools",[]):
        if not scene.WORLD_ABILITIES.has(String(item)):
            expected_inventory[item] = maxi(1,int(expected_inventory.get(item,0)))
    for item in starting.get("starting_relics",[]):
        expected_inventory[item] = maxi(1,int(expected_inventory.get(item,0)))
    check(scene.inventory_counts == expected_inventory,"arrival retains inventory and canonical regional starter items without granting an exploration ability")
    check(not scene.player.debug_invulnerable,"crossing retains ordinary damage rules")
    for key in records:
        var record: Dictionary = records[key]
        var adopted := actor(String(key).get_slice(":",0),record.data)
        check(adopted != null and adopted == record.actor,"physical arrival reuses cached actor " + key)
    check(pref.gameplay.hits-before_hits == records.size(),"physical arrival consumes each gameplay lease once")
    var saved := STATE.new()
    check(saved.read(SAVE) and String(saved.data.current_region) == target,"physical arrival commits destination to save")
    crossings.append({"target":target,"reused":records.size(),"distance":scene.world_passage.last_result.get("distance",0),"damage_suppression":false})
    await capture_review("live_01_rain_arrival.jpg" if target == RAIN else "live_02_moss_return.jpg")
    return records

func fight(records: Dictionary) -> void:
    var enemy: Area2D
    for key in records:
        if String(key).begins_with("enemy:"):
            enemy = actor("enemy",records[key].data)
            break
    check(enemy != null,"arrival has a reused combat actor")
    if enemy == null: return
    var instance_id := enemy.get_instance_id()
    var hp_before: int = scene.player.hp
    var reads_before: int = enemy.command_read_count
    if not await walk(Vector2(620,812),"rain approach"): return
    # Continue beyond the tower roof before engaging on the aqueduct deck.
    if not await walk(Vector2(960,880),"aqueduct combat deck"): return
    # Wait for an actual AI/contact hit; no direct take_damage/take_hit calls.
    for unused in 240:
        if scene.player.hp < hp_before: break
        if absf(scene.player.position.x-enemy.position.x) > 60:
            axis(signf(enemy.position.x-scene.player.position.x))
        else:
            axis(0)
        await tick()
    release_input()
    check(scene.player.hp > 0 and scene.player.hp < hp_before,"reused enemy deals real damage")
    check(enemy.command_read_count > reads_before,"reused enemy resumes live AI")
    var wallet: int = scene.currency_count
    var defeated: int = scene.enemy_defeated
    var hp_after_hit: int = scene.player.hp
    var killed := false
    for frame in 480:
        if not is_instance_valid(enemy) or enemy.dying:
            killed = true
            break
        if scene.player.hp <= 0: break
        var dx: float = enemy.position.x-scene.player.position.x
        axis(signf(dx) if absf(dx) > 45 or scene.player.facing != int(signf(dx)) else 0)
        if frame % 24 == 0 and absf(dx) < 90 and scene.player._can_start_action():
            await press("attack")
        await tick()
    killed = killed or (is_instance_valid(enemy) and enemy.dying)
    check(killed and scene.player.hp > 0,"normal attack input defeats reused enemy")
    check(scene.enemy_defeated == defeated+1 and scene.currency_count == wallet+8,"adopted enemy death rewards once")
    var saved := STATE.new()
    check(saved.read(SAVE) and int(saved.data.currency) == scene.currency_count,"reused enemy reward persists")
    combat = {"actor_id":instance_id,"hp_before":hp_before,"hp_after_hit":hp_after_hit,"killed":killed,"reward_delta":scene.currency_count-wallet,"direct_damage_calls":false}

func interactions(records: Dictionary) -> void:
    var shrine: Area2D = scene.get_node_or_null("save_first_bell")
    var npc: Area2D = scene.get_node_or_null("npc_threadsmith_apprentice")
    check(records.has("save_point:save_first_bell") and records.has("npc:npc_threadsmith_apprentice"),"return naturally prebuilds authored shrine and NPC")
    if shrine == null or npc == null: return
    var prior_hp: int = scene.player.hp
    if not await walk(shrine.position,"reused shrine"): return
    await press("interact")
    check(bool(shrine.get_meta("activated",false)) and scene.player.hp == scene.player.max_hp and scene.player.hp >= prior_hp,"reused shrine restores life through input")
    await capture_review("live_03_shrine_rest.jpg")
    var saved := STATE.new()
    check(saved.read(SAVE) and String(saved.get_region(MOSS).get("checkpoint_id","")) == String(shrine.name),"reused shrine records checkpoint")
    if not await walk(npc.position,"reused NPC"): return
    await press("interact")
    check(scene.active_overlay == "dialogue" and npc.get_meta("dialogue_index",0) > 0,"reused NPC opens live dialogue through input")
    await press("interact")
    check(npc.body_entered.get_connections().size() == 1 and shrine.body_entered.get_connections().size() == 1,"arrival callbacks bound exactly once")
    scene._close_overlays()

func run() -> void:
    for suffix in ["",".bak",".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await tick(4)
    scene._travel_world(ROUTES.config_path(MOSS),Vector2(1610,3712)) # initial checkpoint fixture only
    scene.player.hp = 4
    scene.player.energy = 41
    scene.currency_count = 97
    await tick(8)
    if await walk(Vector2(1735,3712),"source pipe approach"):
        var outward := await crossing(RAIN,1)
        if String(scene.config.id) == RAIN:
            await fight(outward)
            if scene.player.hp > 0 and await walk(Vector2(390,720),"return pipe approach"):
                var returning := await crossing(MOSS,-1)
                if String(scene.config.id) == MOSS:
                    await interactions(returning)
    release_input()
    var saved := STATE.new()
    check(saved.read(SAVE),"live journey leaves readable save")
    var persisted: Dictionary = saved.data.duplicate(true)
    var final_inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var final_wallet: int = scene.currency_count
    scene.free()
    current_scene = null
    await tick(4)
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = true
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await tick(4)
    check(String(scene.config.id) == String(persisted.current_region) and scene.inventory_counts == final_inventory and scene.currency_count == final_wallet,"restart restores live arrival rewards and checkpoint")
    scene.free()
    current_scene = null
    await tick(4)
    for suffix in ["",".bak",".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    var result := {"crossings":crossings,"combat":combat,"physics_frames":frames,"initial_checkpoint_fixture":true,"damage_suppression":false,"six_region_playthrough":false,"failures":failures.size()}
    if DisplayServer.get_name() != "headless":
        result.renderer = "real OpenGL"
        var output := FileAccess.open("res://../artifacts/neighbor_gameplay/gpu_live.json",FileAccess.WRITE)
        output.store_string(JSON.stringify(result,"  ")+"\n")
        output.close()
    print("NEIGHBOR GAMEPLAY LIVE METRICS ",JSON.stringify(result))
    for message in failures:
        push_error(message)
    print("WORLD_NEIGHBOR_GAMEPLAY_LIVE checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
