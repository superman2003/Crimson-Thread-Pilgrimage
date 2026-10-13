extends SceneTree
## Explicit landing/state fixtures, not seamless crossing or natural combat.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const GAMEPLAY := preload("res://scripts/world_gameplay_prefetch.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://neighbor_gameplay_validation.json"
const MASK := 1 << 22
var scene: Node
var checks := 0
var failures: Array[String] = []
var metrics: Array = []
var observed: Dictionary = {}
var churn: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func frames(count: int) -> void:
    for unused in count:
        await physics_frame
        await process_frame
func _seed_cache(id: String, entry: Vector2) -> RefCounted:
    var pref: RefCounted = scene.world_prefetch
    pref.shutdown()
    pref.generation = scene.world_loader.generation
    pref.selection_elapsed = -1000
    var path := ROUTES.config_path(id)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var prepared: Dictionary = scene.world_loader.validate_config(raw, path, entry)
    check(not prepared.is_empty(), "canonical target validates")
    pref.desired = {id: {"path": path, "entry": entry, "distance": 0}}
    pref.configs = {id: {"raw": raw, "prepared": prepared, "stamp": FileAccess.get_modified_time(path)}}
    return pref
func warm(pref: RefCounted) -> void:
    var deadline := Time.get_ticks_msec() + 15000
    while Time.get_ticks_msec() < deadline:
        var built: int = pref.entity_builds + pref.gameplay.builds
        var retired: int = pref.entity_releases + pref.gameplay.releases
        pref.step(scene,0)
        check(pref.entity_builds + pref.gameplay.builds - built <= 2, "shared geometry/gameplay creation admission <=2")
        check(pref.entity_releases + pref.gameplay.releases - retired <= 2, "shared retirement admission <=2")
        check(pref.snapshot().owned_bodies <= 48 and pref.gameplay.owned() <= 24, "owned + pending retirement capacity bounded")
        var ready: bool = pref.entities.values().all(func(x): return x.pending.is_empty()) and pref.gameplay.regions.values().all(func(x): return x.pending.is_empty())
        if not pref.gameplay.regions.is_empty() and pref.gameplay.regions.size() == pref.desired.size() and ready: return
        await process_frame
    check(false, "warming finishes before fixture deadline")
func live(kind: String, data: Dictionary) -> Area2D:
    if kind != "enemy": return scene.get_node_or_null(NodePath(String(data.id)))
    for child in scene.get_children():
        if child.get_script() == scene.ENEMY_ACTOR_SCRIPT and child.spawn_id == String(data.id): return child
    return null
func signature(actor: Area2D) -> Array:
    var result: Array = [actor.position,actor.collision_layer,actor.collision_mask,actor.monitoring,actor.monitorable]
    if actor.get_script() == scene.ENEMY_ACTOR_SCRIPT:
        result.append([actor.spawn_id,actor.kind,actor.hp,actor.max_hp,actor.ai_profile,actor.spawn_position,actor.platform_min_x,actor.platform_max_x,actor.death_sfx_key])
    else:
        result.append([actor.get_meta("kind",""),actor.get_meta("label",""),actor.get_meta("dialogue",[]),actor.get_meta("world_location_state",""),actor.get_meta("activated",false),actor.get_meta("requires_keys",0),actor.get_meta("world_portal_data",{})])
    for child in actor.get_children():
        if child is CollisionShape2D:
            result.append([child.position,str(child.shape.get_class()),child.shape.size if child.shape is RectangleShape2D else child.shape.radius])
        elif child is AnimatedSprite2D:
            result.append([str(child.name) if not str(child.name).begins_with("@") else child.get_class(),child.position,child.scale,child.sprite_frames.get_animation_names(),child.animation,child.frame])
        elif child is Sprite2D:
            result.append([str(child.name) if not str(child.name).begins_with("@") else child.get_class(),child.position,child.scale,child.texture.get_size(),child.modulate])
    return result
func landing(id: String, entry: Vector2) -> void:
    var pref := _seed_cache(id,entry)
    var state: Dictionary = scene.story_flags.duplicate(true)
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var wallet: int = scene.currency_count
    var enemy_count := get_nodes_in_group("enemy").size()
    var node_count: int = scene.get_child_count()
    await warm(pref)
    check(scene.story_flags == state and scene.inventory_counts == inventory and scene.currency_count == wallet and get_nodes_in_group("enemy").size() == enemy_count and scene.get_child_count() == node_count, "prebuild leaves active progression/inventory/groups/tree unchanged")
    var records: Dictionary = pref.gameplay.regions[id].actors.duplicate()
    check(records.size() <= GAMEPLAY.MAX_PER_REGION, "per-region actor limit")
    var before_hits: int = pref.gameplay.hits
    for key in records:
        var record: Dictionary = records[key]
        var actor: Area2D = record.actor
        var kind := String(key).get_slice(":",0)
        observed[kind] = true
        check(not actor.is_inside_tree() and actor.get_parent() == null and actor.get_child_count() >= 2, "detached actor includes collider + original visual")
        check(not actor.body_entered.is_connected(scene._on_interactable_entered.bind(actor)), "detached interaction has no live callback")
        actor.collision_layer = MASK
        var query := PhysicsPointQueryParameters2D.new()
        query.position = actor.position
        query.collision_mask = MASK
        query.collide_with_areas = true
        check(root.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "detached Area absent from source physics")
        actor.collision_layer = 1
        var wrong: Dictionary = record.data.duplicate(true)
        wrong.position[0] += 1
        check(pref.gameplay.take(id,kind,wrong,record.profile) == null, "descriptor mismatch does not consume actor")
        if kind == "enemy":
            var wrong_profile: Dictionary = record.profile.duplicate(true)
            wrong_profile.fixture_mismatch = true
            check(pref.gameplay.take(id,kind,record.data,wrong_profile) == null, "AI profile lease cannot be substituted")
    scene._travel_world(ROUTES.config_path(id),entry)
    await frames(2)
    var warm_signatures: Dictionary = {}
    for key in records:
        var record: Dictionary = records[key]
        var actor := live(String(key).get_slice(":",0),record.data)
        check(actor != null and actor == record.actor and actor.get_parent() == scene, "arrival adopts exact gameplay instance")
        if actor == null: continue
        warm_signatures[key] = signature(actor)
        if String(key).begins_with("enemy:"):
            check(actor.presentation_prepared and actor.is_in_group("enemy"), "enemy ready activates once with prepared artwork")
            check(actor.get_children().filter(func(x): return x is CollisionShape2D).size() == 1, "adoption does not duplicate enemy collision")
        else:
            check(actor.body_entered.is_connected(scene._on_interactable_entered.bind(actor)), "arrival binds current persistent host once")
            check(actor.has_node("Wayfinding"), "original sign added only on arrival")
    check(pref.gameplay.hits - before_hits == records.size(), "all planned actors reused")
    metrics.append({"region":id,"entry":[entry.x,entry.y],"adopted":records.size(),"kinds":records.keys()})
    pref.shutdown()
    scene._travel_world(ROUTES.config_path(id),entry)
    await frames(2)
    for key in warm_signatures:
        var actor := live(String(key).get_slice(":",0),records[key].data)
        var actual: Array = signature(actor) if actor != null else []
        if actual != warm_signatures[key]:
            print("GAMEPLAY_PARITY_DIFF ",JSON.stringify({"region":id,"entry":[entry.x,entry.y],"key":key,"warm":warm_signatures[key],"cold":actual}))
        check(actor != null and actual == warm_signatures[key], "warm arrival equals cold authored gameplay/artwork/state " + id + ":" + key)
func invalid_descriptors() -> void:
    var path := ROUTES.config_path(String(scene.config.id))
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var entry := Vector2(raw.player_start[0],raw.player_start[1])
    for field in ["enemy_spawns","npcs","save_points","interactives"]:
        var malformed: Dictionary = raw.duplicate(true)
        malformed[field].append(malformed[field][0].duplicate(true))
        check(scene.world_loader.validate_config(malformed,path,entry).is_empty(), "duplicate gameplay identity rejected before prebuild")
        malformed = raw.duplicate(true)
        malformed[field][0].erase("position")
        check(scene.world_loader.validate_config(malformed,path,entry).is_empty(), "missing gameplay position rejected before allocation")
    for value in [[],[0,40],[-1,40],[INF,40],["bad",40]]:
        var malformed: Dictionary = raw.duplicate(true)
        malformed.interactives[0].interaction_size = value
        check(scene.world_loader.validate_config(malformed,path,entry).is_empty(), "bad interaction dimensions rejected")
    for value in [[], "invalid", {String(raw.enemy_spawns[0].kind): []}]:
        var malformed: Dictionary = raw.duplicate(true)
        malformed.ai_profiles = value
        check(scene.world_loader.validate_config(malformed,path,entry).is_empty(), "malformed enemy profile rejected before prebuild")
    var defaults: Dictionary = raw.duplicate(true)
    defaults.enemy_spawns[0].body_size = []
    defaults.enemy_spawns[0].hurtbox_size = []
    check(not scene.world_loader.validate_config(defaults,path,entry).is_empty(), "empty enemy sizes retain authored defaults")
func invalidation() -> void:
    var id := "demo_ch02_rain_foundry_canal"
    var entry := Vector2(330,720)
    var pref := _seed_cache(id,entry)
    await warm(pref)
    var old: Array = pref.gameplay.regions[id].actors.values().map(func(x): return x.actor)
    var key: String = pref.gameplay.regions[id].actors.keys()[0]
    var record: Dictionary = pref.gameplay.regions[id].actors[key]
    pref.gameplay.regions[id].stamp = -1
    check(pref.gameplay.take(id,key.get_slice(":",0),record.data,record.profile) == null, "timestamp mismatch prevents adoption")
    await warm(pref)
    check(old.all(func(x): return not is_instance_valid(x)), "stale actors retire before new lease warms")
    old = pref.gameplay.regions[id].actors.values().map(func(x): return x.actor)
    pref.desired = {}
    for unused in 100:
        pref.step(scene,0)
        if pref.gameplay.owned() == 0: break
        await process_frame
    check(pref.gameplay.owned() == 0 and old.all(func(x): return not is_instance_valid(x)), "leaving range drains detached actors")
    pref = _seed_cache(id,entry)
    await warm(pref)
    old = pref.gameplay.regions[id].actors.values().map(func(x): return x.actor)
    pref.generation = -1
    pref.step(scene,0)
    pref.shutdown()
    check(old.all(func(x): return not is_instance_valid(x)) and pref.gameplay.owned() == 0, "generation change and teardown drain actor ownership")
func two_neighbors() -> void:
    scene.world_prefetch.shutdown()
    scene._travel_world(ROUTES.config_path("demo_ch01_moss_bell_court"),Vector2(200,3360))
    var pref: RefCounted = scene.world_prefetch
    pref.selection_elapsed = 1
    pref.generation = -1
    scene.player.position = (scene.get_node("moss_rain_pipe").position + scene.get_node("moss_archive_return").position) * 0.5
    await warm(pref)
    check(pref.desired.size() == 2 and pref.gameplay.regions.size() == 2, "two natural neighboring entrance caches prepared")
    check(pref.gameplay.owned() <= 24 and pref.snapshot().owned_bodies + pref.gameplay.owned() <= 72, "combined detached ownership bounded")
    var blocked := GAMEPLAY.new()
    blocked.synchronize(pref.desired,pref.configs,pref.generation)
    for unused in GAMEPLAY.MAX_TOTAL: blocked.retiring.append(Area2D.new())
    check(blocked.warm(scene,Time.get_ticks_usec(),2) == 0 and blocked.owned() == 24, "pending retirement consumes capacity before creation")
    blocked.shutdown()
    check(blocked.owned() == 0, "saturated cache teardown drains all actors")
    pref.shutdown()

func cancellation() -> void:
    var id := "demo_ch02_rain_foundry_canal"
    var pref := _seed_cache(id,Vector2(330,720))
    await warm(pref)
    var before_hits: int = pref.gameplay.hits
    var source := String(scene.config.id)
    var state: Dictionary = scene.story_flags.duplicate(true)
    var wallet: int = scene.currency_count
    scene._travel_world_async(ROUTES.config_path(id),Vector2(330,720))
    for unused in 2000:
        if pref.gameplay.hits > before_hits or scene.world_loader.phase == "idle": break
        await process_frame
    check(pref.gameplay.hits > before_hits and scene.world_loader.phase == "loading", "cancel fixture reaches partially adopted target")
    scene.world_loader.cancel_transition()
    for unused in 2000:
        if scene.world_loader.phase == "idle": break
        await process_frame
    check(scene.world_loader.last_transition.get("rolled_back",false) and String(scene.config.id) == source, "cancelled target rolls back source")
    check(scene.story_flags == state and scene.currency_count == wallet, "cancelled gameplay preserves source progress")
    var saved := STATE.new()
    check(saved.read(SAVE) and saved.data.current_region == source, "partial destination never committed to disk")
    pref.shutdown()

func cache_churn() -> void:
    scene._travel_world(ROUTES.config_path("demo_ch01_moss_bell_court"),Vector2(200,3360))
    var pref: RefCounted = scene.world_prefetch
    pref.shutdown()
    pref.generation = scene.world_loader.generation
    pref.selection_elapsed = -1000
    var baseline_nodes := scene.get_child_count()
    var baseline_enemies := get_nodes_in_group("enemy").size()
    var baseline_state: Dictionary = scene.story_flags.duplicate(true)
    var source_position: Vector2 = scene.player.position
    var source_portals: Array = scene.config.interactives.duplicate(true)
    var focus: Vector2 = (scene.get_node("moss_rain_pipe").position + scene.get_node("moss_archive_return").position) * 0.5
    var old_actors: Array = []
    var before_builds: int = pref.gameplay.builds
    var before_releases: int = pref.gameplay.releases
    # Repeated two-neighbor, changed-entry and leave-range leases in one host.
    # Retirements deliberately overlap new plans; no per-cycle shutdown.
    for cycle in 80:
        scene.config.interactives = source_portals.duplicate(true)
        for portal in scene.config.interactives:
            if String(portal.get("target_config_id","")) in ["demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive"]:
                portal.target_spawn[0] += (cycle % 2) * 120
        scene.player.position = focus
        pref.selection_elapsed = 1
        await warm(pref)
        check(old_actors.all(func(x): return not is_instance_valid(x)), "changed entry releases previous gameplay lease")
        old_actors = []
        for cache in pref.gameplay.regions.values():
            old_actors.append_array(cache.actors.values().map(func(x): return x.actor))
        if cycle % 5 == 4:
            scene.player.position = Vector2(8000,6000)
            pref.selection_elapsed = 1
            for unused in 80:
                var built: int = pref.entity_builds + pref.gameplay.builds
                var released: int = pref.entity_releases + pref.gameplay.releases
                pref.step(scene,0)
                check(pref.entity_builds + pref.gameplay.builds - built <= 2 and pref.entity_releases + pref.gameplay.releases - released <= 2, "leave-range shared frame admission bounded")
                if pref.gameplay.owned() == 0 and pref.snapshot().owned_bodies == 0: break
                await process_frame
            check(old_actors.all(func(x): return not is_instance_valid(x)), "leave-range lease drains during churn")
    pref.shutdown()
    scene.config.interactives = source_portals
    scene.player.position = source_position
    check(old_actors.all(func(x): return not is_instance_valid(x)) and pref.gameplay.owned() == 0 and pref.snapshot().owned_bodies == 0, "churn teardown releases all detached objects")
    check(pref.gameplay.builds - before_builds == pref.gameplay.releases - before_releases, "every churn-built gameplay actor retired exactly once")
    check(scene.get_child_count() == baseline_nodes and get_nodes_in_group("enemy").size() == baseline_enemies and scene.story_flags == baseline_state, "80 cache cycles leave source tree groups and progress untouched")
    churn = {"cycles":80,"builds":pref.gameplay.builds-before_builds,"releases":pref.gameplay.releases-before_releases,"final":pref.snapshot(),"memory_soak":false}
func run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    current_scene = scene
    await frames(2)
    invalid_descriptors()
    for id in COORD.manifest().regions:
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
        await landing(id,Vector2(raw.player_start[0],raw.player_start[1]))
    for id in COORD.manifest().regions:
        var raw := ROUTES.apply_to(JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id))))
        for portal in raw.interactives:
            if String(portal.get("kind","")) == "world_portal":
                await landing(String(portal.target_config_id),Vector2(portal.target_spawn[0],portal.target_spawn[1]))
    # All regions/portal landings are covered above. Add the two categories
    # outside those landing windows without repeating entire-region rebuilds.
    var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path("demo_ch01_moss_bell_court")))
    for data in authored.interactives:
        if String(data.get("kind","")) in ["lever","boss_gate"]:
            await landing("demo_ch01_moss_bell_court",Vector2(data.position[0],data.position[1]))
    for kind in ["enemy","npc","save_point","lever","boss_gate","world_portal"]: check(observed.has(kind), "canonical fixtures cover " + kind)
    await invalidation()
    await two_neighbors()
    await cancellation()
    var stats: Dictionary = scene.world_prefetch.snapshot()
    scene.free()
    current_scene = null
    await frames(2)
    for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("NEIGHBOR GAMEPLAY METRICS ",JSON.stringify({"landings":metrics,"final":stats,"churn":churn,"fixture_positioning":true,"combat_acceptance":false}))
    for message in failures: push_error(message)
    print("WORLD_NEIGHBOR_GAMEPLAY checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
