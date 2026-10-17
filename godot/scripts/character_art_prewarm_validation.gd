extends SceneTree
## A cold process warms actual production atlases, then uses normal consumers.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const WARM := preload("res://scripts/character_art_warm_job.gd")
const LEVEL := preload("res://scripts/main_level.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_ch01_moss_bell_court.json"))
    # Include a remote NPC whose art is not in the three landing winners.
    config.npcs.append({"id":"npc_gear_cartographer", "name":"warm fixture", "position":[90000,90000]})
    var baseline := ART.synchronous_texture_loads
    var job := WARM.new()
    job.begin(config)
    var deadline := Time.get_ticks_msec() + 15000
    while not job.done and Time.get_ticks_msec() < deadline:
        job.step(2, 2000)
        check(ART.texture_requests.size() <= 2, "bounded background texture ownership")
        await process_frame
    check(job.done and job.error.is_empty(), "complete production region artwork warms successfully: " + job.error)
    check(job.max_step_operations <= 2, "descriptor work respects operation admission")
    check(ART.synchronous_texture_loads == baseline, "prewarm performs no synchronous texture loading")
    check(ART.threaded_texture_loads > 0, "cold process actually used background requests")
    var level := LEVEL.new()
    for npc in config.npcs:
        var area: Area2D = level._make_npc(npc)
        check(area.get_node_or_null("FriendlyFamilySprite") != null, "normal NPC factory consumes warmed frames")
        check(ART.portrait(String(npc.id)) != null, "original portrait already warmed")
        area.free()
    for data in config.enemy_spawns + [config.boss]:
        var enemy := ENEMY.new()
        enemy.configure(data, "", data == config.boss)
        enemy.prepare_presentation()
        check(enemy.animated_sprite != null and enemy.animated_sprite.sprite_frames != null, "normal enemy factory consumes warmed frames")
        enemy.free()
    check(ART.synchronous_texture_loads == baseline, "formal frames and portraits perform zero first synchronous texture loads")
    check(ART.textures.has(ART.atlas_paths(ART.character_manifest("original_npcs", "npc_gear_cartographer"))[0]), "far NPC outside landing window is warmed")
    level.free()
    # A cancelled speculative plan cannot create requests or publish readiness.
    var cancelled := WARM.new()
    cancelled.begin(config)
    cancelled.cancel()
    cancelled.step()
    check(cancelled.cancelled and cancelled.scanned == 0, "cancelled plan does no further descriptor or texture work")
    var failed := WARM.new()
    failed.begin({}, [{"kind":"enemy", "data":{"kind":"no_such_creature", "sprite":"res://missing_character_warm.png"}}], true)
    for index in range(10):
        failed.step()
        if failed.done: break
    check(failed.done and not failed.error.is_empty(), "missing resource fails explicitly without a synchronous fallback")
    check(ART.synchronous_texture_loads == baseline, "failed prewarm also never decodes synchronously")
    print("CHARACTER_ART_PREWARM checks=%d failures=%d sync_loads=%d" % [checks, failures, ART.synchronous_texture_loads - baseline])
    quit(0 if failures == 0 else 1)
