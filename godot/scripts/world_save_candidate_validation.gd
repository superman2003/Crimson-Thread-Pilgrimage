extends SceneTree
## Complete synchronous checkpoint candidates; no fixture touches authored files.
const WORLD := preload("res://scripts/world_state.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const REGION := "demo_ch01_moss_bell_court"
const TARGET := "demo_ch02_rain_foundry_canal"
const REGIONS := [REGION, TARGET, "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
const DISK := "user://world_save_candidate_disk.json"
const SAVE := "user://world_save_candidate_runtime.json"
var checks := 0
var failures: Array[String] = []
var scene: Node

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    _candidate_ownership()
    _regional_oracles()
    _file_protocol()
    await _runtime()
    for path in [DISK, SAVE]:
        for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
    if failures.is_empty():
        print("WORLD SAVE CANDIDATE PASS checks=%d" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)

func _base() -> RefCounted:
    var world := WORLD.new()
    world.capture_global({"current_region": REGION, "entry": Vector2(120, 500), "currency": 11})
    for id in REGIONS + ["legacy_history"]:
        world.capture_region(id, {"visited_rooms": {"old_room": true}, "checkpoint": Vector2(120, 500)})
    var rows := []
    for index in range(1200): rows.append({"index": index, "pair": [index, index + 1]})
    world.data.story_flags["history"] = rows
    world.data.death_cache = {"region_id": REGION, "position": [100, 500], "currency": 7,
        "fixture_metadata": {"values": [1, {"nested": [2, 3]}]}}
    return world

func _candidate_ownership() -> void:
    var world := _base()
    var old: Dictionary = world.data
    var old_value: Dictionary = old.duplicate(true)
    var region := {"visited_rooms": {"candidate_room": true}, "checkpoint": Vector2(200, 500), "bell_count": 2}
    var global := {"current_region": REGION, "entry": Vector2(200, 500), "currency": 31,
        "inventory_counts": {"moss_chitin": 4}, "story_flags": {"quest": {"steps": [1, 2]}},
        "build_state": {"nested": {"stock": [2, 3]}}}
    var oracle := WORLD.new()
    oracle.data = old.duplicate(true)
    _check(oracle.capture_region(REGION, region) and oracle.capture_global(global), "legacy synchronous capture oracle accepts fixture")
    var expected: Dictionary = oracle.data.duplicate(true)
    var prepared: Dictionary = world.prepare_checkpoint(REGION, region, global)
    _check(prepared.ok and prepared.candidate == expected, "combined candidate matches legacy region/global values and coordinates")
    _check(is_same(world.data, old) and world.data == old_value, "preparation never publishes or changes the old object")
    var candidate: Dictionary = prepared.candidate
    _check(not is_same(candidate, old) and not is_same(candidate.regions, old.regions) and not is_same(candidate.regions[TARGET], old.regions[TARGET]), "candidate also detaches unchanged historical regions")
    region.visited_rooms.clear()
    global.story_flags.quest.steps[0] = 99
    global.inventory_counts.moss_chitin = 100
    global.build_state.nested.stock.clear()
    old.regions[TARGET].visited_rooms["late_old_change"] = true
    old.death_cache.fixture_metadata.values[1].nested[0] = 99
    _check(candidate == expected, "nested caller and prior-state mutations cannot alter the prepared candidate")
    candidate.regions[REGION].visited_rooms.clear()
    candidate.regions[TARGET].visited_rooms.clear()
    candidate.story_flags.quest.steps.clear()
    candidate.death_cache.fixture_metadata.values[1].nested.clear()
    _check(old.death_cache.fixture_metadata.values[1].nested == [99, 3], "untouched death-cache nested history is also independently owned")
    _check(region.visited_rooms.is_empty() and global.story_flags.quest.steps == [99, 2] and old.regions[TARGET].visited_rooms.has("old_room"), "candidate mutations cannot escape into donor or old containers")
    for fault in ["unknown_region", "unknown_global", "reserved_global", "invalid_region", "invalid_global", "invalid_region_type", "invalid_location"]:
        var before: Dictionary = world.data
        var value: Dictionary = before.duplicate(true)
        var rp := {"visited_rooms": {"new_room": true}}
        var gp := {"currency": 42}
        match fault:
            "unknown_region": rp["not_a_region_field"] = true
            "unknown_global": gp["not_a_global_field"] = true
            "reserved_global": gp["regions"] = {}
            "invalid_region": rp["checkpoint"] = [1, "bad"]
            "invalid_global": gp["currency"] = -1
            "invalid_region_type": gp["current_region"] = 5
            "invalid_location": gp["world_location"] = {"region_id": REGION, "position": [1, "bad"]}
        var rp_before := rp.duplicate(true)
        var gp_before := gp.duplicate(true)
        var rejected: Dictionary = world.prepare_checkpoint("new_unpublished_region", rp, gp)
        _check(not rejected.ok and not world.last_error.is_empty() and is_same(world.data, before) and world.data == value and not world.data.regions.has("new_unpublished_region"), fault + " rejects the complete checkpoint without a partial region")
        _check(rp == rp_before and gp == gp_before, fault + " leaves invalid input donors untouched")

func _regional_oracles() -> void:
    var legacy_usec := 0
    var candidate_usec := 0
    for id in REGIONS:
        var world := _base()
        var before: Dictionary = world.data
        var region := {"visited_rooms": {"regional_oracle": true}, "checkpoint": Vector2(120, 500)}
        var global := {"current_region": id, "entry": Vector2(120, 500), "currency": 47}
        var oracle := WORLD.new()
        oracle.data = before.duplicate(true)
        var started := Time.get_ticks_usec()
        # Include the old Main rollback copy, rather than comparing against
        # only one half of the production legacy capture sequence.
        var legacy_previous: Dictionary = oracle.data.duplicate(true)
        var accepted: bool = oracle.capture_region(id, region) and oracle.capture_global(global)
        legacy_usec += Time.get_ticks_usec() - started
        started = Time.get_ticks_usec()
        var prepared: Dictionary = world.prepare_checkpoint(id, region, global)
        candidate_usec += Time.get_ticks_usec() - started
        _check(accepted and prepared.ok and prepared.candidate == oracle.data and prepared.candidate.world_location.region_id == id, id + " matches the original combined capture and world coordinates")
        _check(is_same(world.data, before) and world.data == legacy_previous and not is_same(prepared.candidate.story_flags.history, before.story_flags.history), id + " preserves the old history and owns the large candidate tree")
    print("SAVE CANDIDATE OBSERVATION regions=%d legacy_capture_usec=%d candidate_prepare_usec=%d; timing only, no threshold" % [REGIONS.size(), legacy_usec, candidate_usec])

func _file_protocol() -> void:
    var world := _base()
    _check(world.write(DISK), "legacy write API still persists published data")
    var original := FileAccess.get_file_as_bytes(DISK)
    var before: Dictionary = world.data
    var prepared: Dictionary = world.prepare_checkpoint(REGION, {"visited_rooms": {"new": true}}, {"currency": 22})
    _check(prepared.ok and world.write_candidate(prepared.candidate, DISK), "candidate uses atomic persistence without publication")
    _check(is_same(world.data, before) and world.data.currency == 11, "successful candidate disk write leaves publication to its owner")
    var reboot := WORLD.new()
    var backup := WORLD.new()
    _check(reboot.read(DISK) and reboot.data.currency == 22 and backup.read(DISK + ".bak") and backup.data.currency == 11, "candidate restart and backup retain new and previous transactions")
    var good := FileAccess.get_file_as_bytes(DISK)
    var good_backup := FileAccess.get_file_as_bytes(DISK + ".bak")
    prepared.candidate.currency = -1
    _check(not world.write_candidate(prepared.candidate, DISK) and FileAccess.get_file_as_bytes(DISK) == good, "invalid candidate never reaches the temporary write")
    prepared.candidate.currency = 22
    _put(DISK, "{damaged")
    _check(not world.write_candidate(prepared.candidate, DISK) and FileAccess.get_file_as_string(DISK) == "{damaged" and FileAccess.get_file_as_bytes(DISK + ".bak") == good_backup and is_same(world.data, before), "damaged primary and valid backup remain untouched")
    _put(DISK, good.get_string_from_utf8())
    DirAccess.make_dir_absolute(ProjectSettings.globalize_path(DISK + ".tmp"))
    _check(not world.write_candidate(prepared.candidate, DISK) and FileAccess.get_file_as_bytes(DISK) == good and FileAccess.get_file_as_bytes(DISK + ".bak") == good_backup and is_same(world.data, before), "temporary-open failure changes neither file nor published object")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(DISK + ".tmp"))
    var v1: Dictionary = JSON.parse_string(original.get_string_from_utf8())
    v1.version = 1
    for field in ["build_state", "death_cache", "world_location"]: v1.erase(field)
    _put(DISK, JSON.stringify(v1))
    var v1_bytes := FileAccess.get_file_as_bytes(DISK)
    _check(world.write_candidate(prepared.candidate, DISK) and FileAccess.get_file_as_bytes(DISK + ".bak") == v1_bytes, "candidate write accepts a valid migrated primary and preserves exact original backup")
    _check(reboot.read(DISK + ".bak") and reboot.data.version == WORLD.VERSION and reboot.data.currency == 11 and reboot.resume_local_position() == Vector2(120, 500), "legacy candidate backup remains migratable and restartable")

func _spawn(resume: bool) -> void:
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = resume
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)

func _runtime() -> void:
    await _spawn(false)
    _check(scene.initial_region_ready, "real World startup commits its initial candidate")
    scene.currency_count = 211
    scene.inventory_counts["moss_chitin"] = 7
    scene.story_flags["candidate_nested"] = {"value": [1, 2]}
    scene.visited_rooms["candidate_room"] = true
    var before: Dictionary = scene.world_state.data
    var value := before.duplicate(true)
    var disk := FileAccess.get_file_as_bytes(SAVE)
    scene.world_save_failure_injected_for_validation = true
    _check(not scene._save_world() and scene.world_save_capture_ok, "injected write failure follows successful complete candidate capture")
    _check(is_same(scene.world_state.data, before) and scene.world_state.data == value and FileAccess.get_file_as_bytes(SAVE) == disk, "failed runtime persistence retains the original object, contents and disk")
    _check(scene.currency_count == 211 and scene.inventory_counts.moss_chitin == 7 and scene.story_flags.candidate_nested.value == [1, 2], "failed checkpoint preserves current live progress")
    scene._set_story_flag("candidate_earned_reward")
    _check(bool(scene.story_flags.candidate_earned_reward) and not scene.world_state.data.story_flags.has("candidate_earned_reward"), "earned live reward survives failure without mutating the prior committed checkpoint")
    for fault in ["region", "global"]:
        var bells: int = scene.bell_count
        var currency: int = scene.currency_count
        scene.world_save_capture_ok = true
        if fault == "region": scene.bell_count = -1
        else: scene.currency_count = -1
        _check(not scene._save_world() and not scene.world_save_capture_ok and is_same(scene.world_state.data, before) and scene.world_state.data == value, fault + " failure cannot publish a partial region or reuse stale capture status")
        scene.bell_count = bells
        scene.currency_count = currency
    scene.world_save_failure_injected_for_validation = false
    scene.world_save_blocked = true
    _check(not scene._save_world() and scene.world_save_capture_ok and not is_same(scene.world_state.data, before), "valid blocked checkpoint atomically publishes only to memory")
    _check(scene.world_state.data.currency == 211 and scene.world_state.data.regions[REGION].visited_rooms.candidate_room and FileAccess.get_file_as_bytes(SAVE) == disk, "blocked checkpoint includes both region/global state and withholds disk writes")
    scene.story_flags.candidate_nested.value[0] = 99
    scene.visited_rooms.erase("candidate_room")
    _check(scene.world_state.data.story_flags.candidate_nested.value == [1, 2] and scene.world_state.data.regions[REGION].visited_rooms.candidate_room, "published blocked checkpoint owns its nested region and global inputs")
    var blocked_before: Dictionary = scene.world_state.data
    scene.currency_count = -1
    scene.world_save_capture_ok = true
    _check(not scene._save_world() and not scene.world_save_capture_ok and is_same(scene.world_state.data, blocked_before) and FileAccess.get_file_as_bytes(SAVE) == disk, "blocked flag cannot publish an invalid candidate or reuse stale capture success")
    scene.currency_count = 211
    scene.world_save_blocked = false
    _check(scene._save_world(), "repaired runtime commits current donors after blocked capture")
    await _paid_transaction()
    scene.currency_count = 100
    scene.death_recorded = false
    scene.world_save_failure_injected_for_validation = true
    scene._record_death_cache()
    _check(scene.currency_count == 50 and scene.world_state.data.death_cache.currency == 50, "pre-existing death-cache capture remains visible when its subsequent checkpoint write fails")
    scene.world_save_failure_injected_for_validation = false
    _check(scene._save_world(), "death-cache checkpoint repairs after storage resumes")
    scene._recover_death_cache(scene.death_cache_area)
    _check(scene.currency_count == 100 and scene.world_state.data.death_cache.is_empty(), "death-cache recovery preserves reward and cache-clear transaction order")
    var path := ROUTES.cached_config_path(TARGET)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var entry := Vector2(raw.player_start[0], raw.player_start[1])
    var injected := {"done": false}
    var cancel := func():
        if scene.world_loader.phase == "loading" and not injected.done:
            injected.done = true
            scene.world_loader.cancel_transition()
    process_frame.connect(cancel)
    var ok: bool = await scene.world_loader.replace_region_async(scene, path, entry, Vector2.INF, {"candidate_target_reward": true})
    process_frame.disconnect(cancel)
    _check(injected.done and not ok and scene.world_loader.last_transition.rolled_back and scene.config.id == REGION and scene.world_state.data.current_region == REGION and not scene.story_flags.has("candidate_target_reward"), "departure cancellation rolls back a complete checkpoint without target rewards")
    _check(await scene.world_loader.replace_region_async(scene, path, entry, Vector2.INF, {"candidate_target_reward": true}), "repaired departure commits target candidate")
    _check(scene.world_state.data.current_region == TARGET and scene.currency_count == 100 and bool(scene.story_flags.candidate_earned_reward), "target candidate carries source rewards and checkpoint resources")
    scene.free()
    await process_frame
    await _spawn(true)
    _check(scene.config.id == TARGET and scene.currency_count == 100 and bool(scene.story_flags.candidate_target_reward) and bool(scene.story_flags.candidate_earned_reward) and scene.world_state.data.death_cache.is_empty(), "fresh World resumes the complete persisted target and rewards")
    scene.free()
    await process_frame

func _paid_transaction() -> void:
    var shrine: Area2D
    for child in scene.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "save_point":
            shrine = child
            break
    _check(is_instance_valid(shrine), "real shrine exists for paid transaction")
    if not is_instance_valid(shrine): return
    scene.player.global_position = shrine.global_position
    for tool in scene.build_system.state.tool_counts: scene.build_system.state.tool_counts[tool] = 0
    scene.currency_count = 5
    scene.inventory_counts["moss_chitin"] = 1
    _check(scene._save_world(), "paid transaction starts from a durable source checkpoint")
    var build: Dictionary = scene.build_system.serialize()
    var wallet: Dictionary = scene._build_wallet_snapshot()
    var before: Dictionary = scene.world_state.data
    var value := before.duplicate(true)
    var disk := FileAccess.get_file_as_bytes(SAVE)
    scene.world_save_blocked = true
    var blocked: Dictionary = scene.perform_build_action("resupply_tools")
    _check(not blocked.ok and String(blocked.reason) == "构筑存档不兼容，当前不能保存交易", "blocked real paid action is rejected before any capture or wallet change")
    _check(scene.build_system.serialize() == build and scene.currency_count == wallet.currency and scene.inventory_counts == wallet.inventory_counts and is_same(scene.world_state.data, before) and scene.world_state.data == value and FileAccess.get_file_as_bytes(SAVE) == disk, "blocked paid guard preserves live state, original checkpoint object and disk")
    scene.world_save_blocked = false
    _check(scene._save_world(), "unblocking permits the next complete checkpoint")
    before = scene.world_state.data
    value = before.duplicate(true)
    disk = FileAccess.get_file_as_bytes(SAVE)
    scene.world_save_failure_injected_for_validation = true
    var failed: Dictionary = scene.perform_build_action("resupply_tools")
    _check(not failed.ok and String(failed.reason).begins_with("归途记录未能写入") and scene.build_system.serialize() == build and scene.currency_count == wallet.currency and scene.inventory_counts == wallet.inventory_counts, "failed paid resupply rolls back build and wallet")
    _check(is_same(scene.world_state.data, before) and scene.world_state.data == value and FileAccess.get_file_as_bytes(SAVE) == disk, "paid rollback also preserves the original committed state object and bytes")
    scene.world_save_failure_injected_for_validation = false
    var paid: Dictionary = scene.perform_build_action("resupply_tools")
    _check(paid.ok and scene.currency_count == 1 and int(scene.inventory_counts.get("moss_chitin", 0)) == 0, "successful real resupply commits its exact wallet charge")
    var reboot := WORLD.new()
    var read_ok: bool = reboot.read(SAVE)
    var live_build: Dictionary = scene.build_system.serialize()
    var json_equal: bool = reboot.data.build_state == JSON.parse_string(JSON.stringify(live_build))
    if read_ok and reboot.data.build_state != live_build:
        var differences: Array[String] = []
        _type_differences(reboot.data.build_state, live_build, "$", differences)
        print("SAVE BUILD REPRESENTATION json_equal=", json_equal, " type_differences=", differences)
        print("SAVE BUILD PERSISTED ", JSON.stringify(reboot.data.build_state))
        print("SAVE BUILD LIVE ", JSON.stringify(live_build))
    _check(read_ok and reboot.data.currency == scene.currency_count and json_equal, "paid stock and wallet restart from the same candidate")

func _type_differences(persisted: Variant, live: Variant, path: String, differences: Array[String]) -> void:
    if typeof(persisted) != typeof(live):
        differences.append(path + ":" + type_string(typeof(persisted)) + "->" + type_string(typeof(live)))
    elif persisted is Dictionary and live is Dictionary:
        for key in persisted:
            if live.has(key): _type_differences(persisted[key], live[key], path + "." + String(key), differences)
    elif persisted is Array and live is Array:
        for index in mini(persisted.size(), live.size()):
            _type_differences(persisted[index], live[index], path + "[%d]" % index, differences)

func _put(path: String, contents: String) -> void:
    var handle := FileAccess.open(path, FileAccess.WRITE)
    handle.store_string(contents)
    handle.close()

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
