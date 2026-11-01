extends SceneTree
## Positioned reward instances exercise the real World pickup/save path. This
## fixture does not claim those rewards were reached by natural exploration.
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const SAVE := "user://test_permanent_capacity_20261024.json"
const SEED := "res://../artifacts/t04_obsidian_route/earned_camp_seed.json"
var scene: Node2D
var failures := 0
var checks := 0
var output := ""
var phase := "pickup"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("CAPACITY_WORLD: " + label)
func frames(count: int) -> void:
    for i in count:
        await physics_frame
        await process_frame
func same_json(actual: Variant, expected: Variant) -> bool:
    if (actual is int or actual is float) and (expected is int or expected is float):
        return is_finite(float(actual)) and is_finite(float(expected)) and float(actual) == float(expected)
    if typeof(actual) != typeof(expected): return false
    if actual is Dictionary:
        if actual.size() != expected.size(): return false
        for key in actual:
            if not expected.has(key) or not same_json(actual[key], expected[key]): return false
        return true
    if actual is Array:
        if actual.size() != expected.size(): return false
        for i in actual.size():
            if not same_json(actual[i], expected[i]): return false
        return true
    return actual == expected
func capture(label: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK, "native image saved")
func pickup(item_id: String) -> void:
    var point: Vector2 = scene.player.global_position + Vector2(0,-40)
    scene._collectible({"id":"test_capacity_"+item_id,"kind":"item","item_id":item_id,"position":[point.x,point.y],"amount":1,"label":"capacity regression"})
    await frames(5)
    check(scene.get_node_or_null("test_capacity_"+item_id) == null, item_id + " enters through real Area2D body contact")
func finish() -> void:
    RETIREMENT.retire_tree(scene); scene.queue_free(); await frames(5)
    AUDIO._stream_cache.clear(); AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self), "World audio retirement")
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(SAVE+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("PERMANENT_CAPACITY_WORLD phase=%s checks=%d failures=%d pid=%d" % [phase,checks,failures,OS.get_process_id()])
    quit(1 if failures else 0)
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
        if arg.begins_with("--capacity-phase="): phase = arg.trim_prefix("--capacity-phase=")
    check(phase in ["pickup","restart"] and not output.is_empty(), "explicit private fixture phase")
    if failures: quit(1); return
    var input_path := SEED if phase == "pickup" else output.path_join("earned_capacity_save.json")
    check(FileAccess.file_exists(input_path), "preceding actual save exists")
    if failures: quit(1); return
    var bytes := FileAccess.get_file_as_bytes(input_path)
    if phase == "pickup":
        var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
        check(hash.finish().hex_encode() == "91adadb812a80bece39b0b23920c306a37cc9e7f1e6c718a7bc6e1d88a5cfe0b", "unchanged published legacy camp seed")
    var file := FileAccess.open(SAVE,FileAccess.WRITE); file.store_buffer(bytes); file.close()
    scene = load("res://scenes/World.tscn").instantiate()
    check(scene.get_script() != null, "production World compiled")
    if failures: scene.free(); quit(1); return
    scene.world_resume = true; scene.world_save_path = SAVE; root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene; await frames(12)
    check(not scene.player.debug_invulnerable, "normal damage enabled")
    if phase == "restart":
        var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("expected.json")))
        check(same_json(scene.inventory_counts, expected.inventory_counts), "new PID restores full exact inventory")
        check(same_json(scene.build_system.serialize(), expected.build_state), "new PID retains exact equipment and stock")
        check(OS.get_process_id() != int(expected.origin_pid), "restart runs in an independent engine PID")
        check(scene.player.max_hp == 7 and scene.player.max_energy == 120, "new PID derives earned capacities from old inventory fields")
        check(scene.player.hp == expected.hp and scene.player.energy == expected.energy and scene.currency_count == expected.currency, "new PID restores resources without refill")
        await capture("restored_capacity")
        await finish(); return
    check(scene.inventory_counts.get("heart_knot",0) == 1 and scene.player.max_hp == 6 and scene.player.hp == 5, "legacy full knot begins working without healing old saved damage")
    check(scene.player.max_energy == 100 and scene.player.energy == 100 and scene.currency_count == 287, "other legacy resources are unchanged")
    var build_before: Dictionary = scene.build_system.serialize()
    await pickup("heart_knot")
    check(scene.inventory_counts.get("heart_knot",0) == 2 and scene.player.max_hp == 7 and scene.player.hp == 5, "contact reward increases maximum only")
    await pickup("energy_spindle")
    check(scene.inventory_counts.get("energy_spindle",0) == 1 and scene.player.max_energy == 120 and scene.player.energy == 100, "contact spindle increases thread capacity without a refill")
    check(scene.build_system.serialize() == build_before, "both original rewards preserve every equipment and stock field")
    check(scene._save_world(), "normal world save accepts earned capacities")
    var expected := {"inventory_counts":scene.inventory_counts.duplicate(true),"build_state":scene.build_system.serialize(),"hp":scene.player.hp,"energy":scene.player.energy,"currency":scene.currency_count,"origin_pid":OS.get_process_id()}
    var save_bytes := FileAccess.get_file_as_bytes(SAVE)
    file = FileAccess.open(output.path_join("earned_capacity_save.json"),FileAccess.WRITE); file.store_buffer(save_bytes); file.close()
    file = FileAccess.open(output.path_join("expected.json"),FileAccess.WRITE); file.store_string(JSON.stringify(expected,"  ")); file.close()
    await capture("earned_capacity")
    print("CAPACITY_WORLD limits=",scene.player.max_hp,"/",scene.player.max_energy," resources=",scene.player.hp,"/",scene.player.energy)
    await finish()
