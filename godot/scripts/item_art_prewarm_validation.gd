extends SceneTree
## Cold atlas loading with actual collectible consumers; not a natural playthrough.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const WARM := preload("res://scripts/character_art_warm_job.gd")
const LEVEL := preload("res://scripts/main_level.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ITEMS := "res://assets/sprites/original_items/manifest.json"
var checks := 0
var failures := 0
var regions := 0
var max_requests := 0
var descriptors := 0

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func finish_job(job: RefCounted) -> void:
    var deadline := Time.get_ticks_msec() + 15000
    while not job.done and Time.get_ticks_msec() < deadline:
        job.step(2, 2000)
        max_requests = maxi(max_requests, ART.texture_requests.size())
        await process_frame
    check(job.done, "art plan finishes inside its existing polling deadline")
    check(job.max_step_operations <= 2 and max_requests <= 2,
        "item descriptors retain the shared two-operation/two-worker admission")

func original_spec(manifest: Dictionary, item_id: String) -> Dictionary:
    # The original item consumer's choice, captured independently of the new resolver.
    return manifest.get(item_id, manifest["thread_burst" if item_id.contains("_ability_") else "map_fragment"])

func check_texture(texture: Texture2D, spec: Dictionary, label: String) -> void:
    var atlas := texture as AtlasTexture
    check(atlas != null and atlas.atlas != null and atlas.atlas.resource_path == String(spec.atlas)
        and atlas.region == Rect2(float(spec.region[0]), float(spec.region[1]), float(spec.region[2]), float(spec.region[3])),
        label + " keeps its original atlas and crop")

func run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ITEMS))
    var owned: Array = ["currency", "testimony_06", "_ability_warm_fixture", "unknown_warm_fixture"]
    var baseline := ART.synchronous_texture_loads
    var all_atlases: Dictionary = {}
    var ids: Array = COORDINATES.manifest().regions.keys()
    ids.sort()
    for region in ids:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(String(region))))
        var job := WARM.new()
        job.begin(config, [], false, owned)
        await finish_job(job)
        check(job.done and job.error.is_empty(), String(region) + " region artwork warms successfully: " + job.error)
        var expected: Array = []
        for data in config.get("collectibles", []):
            var path := String(original_spec(original, String(data.get("item_id", data.get("kind", "bell_key")))).atlas)
            if not expected.has(path): expected.append(path)
        for item_id in owned:
            var path := String(original_spec(original, String(item_id)).atlas)
            if not expected.has(path): expected.append(path)
        expected.sort()
        var actual: Array = job.item_paths.duplicate()
        actual.sort()
        check(actual == expected, String(region) + " warms exactly destination collectibles and held inventory, including remote testimony")
        check(job.item_scanned == config.get("collectibles", []).size() + owned.size(),
            String(region) + " visits each item descriptor incrementally")
        descriptors += job.item_scanned
        for path in expected:
            all_atlases[path] = true
            check(ART.textures.has(path), String(region) + " required item atlas is resident before consumers")
        var level := LEVEL.new()
        level.config = config
        level.world_mode = false
        for data in config.get("collectibles", []):
            level._collectible(data)
            var area := level.get_child(level.get_child_count() - 1) as Area2D
            var sprite: Sprite2D
            var sprite_count := 0
            if area != null:
                for child in area.get_children():
                    if child is Sprite2D:
                        sprite = child
                        sprite_count += 1
            var item_id := String(data.get("item_id", data.get("kind", "bell_key")))
            check(sprite_count == 1 and sprite != null and sprite.texture != null, item_id + " actual collectible factory binds a visible texture")
            if sprite != null and sprite.texture != null:
                check_texture(sprite.texture, original_spec(original, item_id), item_id)
                check(is_equal_approx(maxf(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.scale.x, 32.0),
                    item_id + " retains the original displayed collectible size")
        for item_id in owned:
            check_texture(ART.item(String(item_id)), original_spec(original, String(item_id)), String(item_id))
        level.free()
        check(ART.synchronous_texture_loads == baseline, String(region) + " prewarm and actual consumers never decode an item atlas synchronously")
        regions += 1
    for item_id in original:
        check_texture(ART.item(String(item_id)), original[item_id], String(item_id))
    check(all_atlases.size() == 6 and ART.threaded_texture_loads > 0,
        "all six original item atlases actually pass through shared resource owners")
    check(ART.synchronous_texture_loads == baseline, "all original and fallback item choices remain resident")
    var selected := WARM.new()
    selected.begin({}, [], true)
    await finish_job(selected)
    check(selected.item_scanned == 0 and selected.paths.is_empty(), "actor-only speculative selection acquires no unrelated item atlases")
    var cancelled := WARM.new()
    cancelled.begin({}, [], false, ["testimony_05"])
    cancelled.cancel()
    cancelled.step()
    check(cancelled.cancelled and cancelled.item_scanned == 0 and cancelled.paths.is_empty(),
        "cancelled inventory plan performs no descriptor or texture work")
    var saved_manifest: Dictionary = ART.manifest_cache[ITEMS]
    ART.manifest_cache[ITEMS] = {"missing_item_fixture": {"atlas":"res://missing_item_atlas_warm.png", "region":[0,0,1,1]}}
    var missing := WARM.new()
    missing.begin({}, [], false, ["missing_item_fixture"])
    await finish_job(missing)
    check(missing.done and not missing.error.is_empty(), "missing item atlas fails explicitly without synchronous fallback")
    ART.manifest_cache[ITEMS] = saved_manifest
    check(ART.synchronous_texture_loads == baseline, "missing item atlas never falls back to synchronous loading")
    var item_sync_loads := ART.synchronous_texture_loads - baseline
    var world_binding: bool = await world_inventory_binding(original)
    print("ITEM ART METRICS ", JSON.stringify({"regions":regions, "item_descriptors":descriptors,
        "item_atlases":all_atlases.size(), "max_requests":max_requests,
        "sync_loads":item_sync_loads, "world_inventory_binding":world_binding, "natural_playthrough":false}))
    print("ITEM_ART_PREWARM checks=%d failures=%d regions=%d sync_loads=%d" % [checks, failures, regions, item_sync_loads])
    quit(0 if failures == 0 else 1)

func world_inventory_binding(original: Dictionary) -> bool:
    const SAVE := "user://item_art_prewarm_validation.json"
    var before := failures
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = SAVE
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    current_scene = world
    # A held item from chapter six must be planned even on arrival in chapter one.
    world.inventory_counts = {"crown_echo_shard":1, "pollen_wax":0}
    var arrived: bool = await world.world_loader.replace_region_async(world,
        ROUTES.config_path("demo_ch01_moss_bell_court"), Vector2(1610,3712))
    check(arrived and world.ui_shell.construction_complete, "actual World completes arrival and inventory construction")
    var metric: Dictionary = world.world_loader.last_transition
    var paths: Array = metric.get("item_art_paths", [])
    var foreign_atlas := String(original.crown_echo_shard.atlas)
    check(paths.has(foreign_atlas), "actual region loader includes the held remote item in its prewarm plan")
    check(not paths.has(String(original.pollen_wax.atlas)), "zero-count inventory does not acquire an unrelated atlas")
    check(not paths.is_empty() and paths.all(func(path): return ART.textures.has(path)),
        "actual arrival retains every planned item atlas")
    var found := false
    for button in world.ui_shell.bag_grid.get_children():
        if String(button.get_meta("item_id", "")) != "crown_echo_shard": continue
        for child in button.get_children():
            if child is TextureRect and child.texture != null:
                found = true
                check_texture(child.texture, original.crown_echo_shard, "actual World foreign inventory icon")
    check(found and world.inventory_counts.get("crown_echo_shard", 0) == 1,
        "actual inventory binds the held item icon without consuming the item")
    world.free()
    current_scene = null
    await process_frame
    await process_frame
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    return failures == before
