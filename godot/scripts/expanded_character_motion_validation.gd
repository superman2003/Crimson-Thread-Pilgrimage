extends SceneTree
## Production resources and actual event playback, including repeated one-shots.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
const LEVEL := preload("res://scripts/main_level.gd")
var checks := 0
var failures := 0
var characters := 0
var poses := 0
class Stage extends Node2D:
    var chapter_terrain: Node = null
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    var stage := Stage.new()
    root.add_child(stage)
    var designs: Dictionary = ART.manifest("res://data/original_creature_designs.json")
    for design in designs.designs:
        var kind := String(design.kind)
        var path := "res://assets/sprites/original_creatures/" + kind + "/motion_manifest.json"
        check(FileAccess.file_exists(path), kind + " expanded resource exists")
        if not FileAccess.file_exists(path): continue
        var enemy = ENEMY.new()
        enemy.configure({"id":"motion_"+kind,"kind":kind,"hp":20}, "", bool(design.boss))
        stage.add_child(enemy)
        enemy.set_physics_process(false)
        check(enemy.asset_path == path, kind + " configure selects expanded production resource")
        _check_frames(enemy.animated_sprite.sprite_frames, ART.manifest(path), kind)
        for facing in [-1,1]:
            enemy._set_sprite_flip(facing < 0)
            check(enemy.animated_sprite.flip_h == (facing < 0), kind + " mirrored facing")
        enemy.queue_free()
        await process_frame
    var world: Dictionary = ART.manifest("res://data/original_world_art_designs.json")
    var level := LEVEL.new()
    for design in world.npcs:
        var id := String(design.id)
        var path := "res://assets/sprites/original_npcs/"+id+"/motion_manifest.json"
        check(FileAccess.file_exists(path), id + " expanded resource exists")
        if not FileAccess.file_exists(path): continue
        var area: Area2D = level._make_npc({"id":id,"name":id})
        stage.add_child(area)
        var sprite := area.get_node("FriendlyFamilySprite") as AnimatedSprite2D
        check(sprite.sprite_frames == ART.frames(path), id + " production NPC factory uses expanded sequence")
        _check_frames(sprite.sprite_frames, ART.manifest(path), id)
        check(ART.portrait(id) != null, id + " original portrait retained")
        area.queue_free()
        await process_frame
    level.free()
    await _check_live_playback(stage)
    _check_attack_specific_poses(stage)
    _check_production_attack_cels(stage)
    _check_elite_profiles(stage)
    await _check_v5_playback(stage)
    _check_v6_registration()
    check(characters == 71, "all 46 creatures and 25 NPCs visited")
    print("EXPANDED_CHARACTER_MOTION checks=%d failures=%d characters=%d poses=%d" % [checks,failures,characters,poses])
    quit(0 if failures == 0 else 1)

func _check_v5_playback(stage: Node2D) -> void:
    var bosses := ["broken_string_gardener", "rust_crown_guardian", "saltwhite_contract_judge", "sunken_hammer_smith", "silent_crown_core", "silent_pilgrim_commander"]
    var sheets := 0
    var new_cels := 0
    var kinds: Array = bosses + ["ash_banner_imp", "echo_contract_scribe", "wax_lancer", "delayed_shadow", "pipe_thrower", "npc_blind_bell_knight", "npc_deserter_flagbearer"]
    for kind: String in kinds:
        var family := "original_npcs" if kind.begins_with("npc_") else "original_creatures"
        var path := "res://assets/sprites/" + family + "/" + kind + "/"
        var record: Dictionary = ART.manifest(path + "motion_generation.json")
        check(record.has("character_motion_v5"), kind + " v5 registration exists")
        if not record.has("character_motion_v5"): continue
        var batch: Dictionary = record.character_motion_v5
        var registered: Dictionary = record.get("boss_motion_v6", {}).get("baseline_frames", record.runtime_frames)
        for sheet: Dictionary in batch.sheets:
            sheets += 1
            new_cels += int(sheet.frames)
            var entries: Array = registered[sheet.animation]
            var start := int(sheet.index) if sheet.mode == "frame" else 0
            for cel in int(sheet.frames):
                check(String(entries[start + cel].source).ends_with("/" + String(sheet.image)), kind + " consumes delivered cel " + str(cel))
            if sheet.mode == "prepend":
                check(entries.size() == int(sheet.frames) + batch.baseline_frames.recover.size(), kind + "/" + String(sheet.animation) + " preserves generic recovery after transition")
                for index in batch.baseline_frames.recover.size():
                    check(entries[index + int(sheet.frames)] == batch.baseline_frames.recover[index], kind + " original recovery registration preserved")
        if family == "original_npcs": continue
        var enemy = ENEMY.new()
        enemy.configure({"id":"v5_" + kind, "kind":kind, "hp":40}, "", kind in bosses)
        stage.add_child(enemy)
        enemy.set_physics_process(false)
        var sprite: AnimatedSprite2D = enemy.animated_sprite
        var recovered := {}
        for command: Dictionary in enemy.ai_commands:
            var animation := String(command.get("animation", "attack"))
            if kind not in bosses or animation not in ["heavy", "cast", "phase"]: continue
            recovered[animation] = true
            for facing in [-1, 1]:
                enemy._set_sprite_flip(facing < 0)
                enemy._pose_sprite("active", command)
                check(sprite.animation == StringName(animation), kind + "/" + animation + " actual command selects strike")
                var duration := float(command.get("recover", 0.42))
                var original_command := command.duplicate(true)
                enemy.active_attack = command.duplicate(true)
                enemy.state = "recover"
                enemy.state_timer = duration
                enemy._pose_sprite("recover", command)
                var expected := animation + "_recover"
                check(sprite.animation == StringName(expected) and sprite.frame == 0, kind + "/" + expected + " starts from transition")
                var count := sprite.sprite_frames.get_frame_count(expected)
                check(is_equal_approx(count / (sprite.sprite_frames.get_animation_speed(expected) * sprite.speed_scale), duration), kind + " recovery fits original combat window")
                check(sprite.flip_h == (facing < 0), kind + " recovery retains facing")
                # Let real AnimatedSprite2D playback present each authored cel,
                # then advance the real state timer at its original boundary.
                var seen := {}
                var elapsed := 0.0
                while elapsed < duration + 0.025:
                    seen[sprite.frame] = true
                    await process_frame
                    elapsed += root.get_process_delta_time()
                check(seen.size() == count, kind + "/" + expected + " presents transition and generic cels")
                enemy._pose_sprite("recover", command)
                check(sprite.frame == 0 and sprite.is_playing(), kind + " repeated recovery restarts")
                enemy._update_recover(duration - 0.001)
                check(enemy.state == "recover", kind + " keeps original punish window")
                enemy._update_recover(0.002)
                check(enemy.state == "patrol" and sprite.animation == &"idle", kind + " returns to idle at original boundary")
                check(command == original_command, kind + " playback never changes attack costs/timing")
        if kind in bosses:
            check(recovered.size() == 3, kind + " all three real special commands exercised")
        enemy.queue_free()
        await process_frame
    check(sheets == 32 and new_cels == 67, "all 32 delivered v5 sheets / 67 cels registered exactly once")

func _check_v6_registration() -> void:
    var bosses := ["rust_crown_guardian", "sunken_hammer_smith", "saltwhite_contract_judge", "broken_string_gardener", "silent_pilgrim_commander", "silent_crown_core"]
    var total := 0
    for kind: String in bosses:
        var record: Dictionary = ART.manifest("res://assets/sprites/original_creatures/" + kind + "/motion_generation.json")
        check(record.has("boss_motion_v6"), kind + " new in-between batch exists")
        if not record.has("boss_motion_v6"): continue
        var batch: Dictionary = record.boss_motion_v6
        check(batch.sources.size() == 8 and int(batch.new_drawings) == 48, kind + " eight sheets / 48 authored drawings")
        total += int(batch.new_drawings)
        var runtime: Dictionary = record.runtime_frames
        check(runtime.idle.size() == 8 and runtime.walk.size() == 16, kind + " idle and gait include loop seam drawings")
        for animation in ["windup","attack","heavy_windup","heavy","cast_windup","cast","phase_windup","phase"]:
            check(runtime[animation].size() == 7, kind + "/" + animation + " three new anatomical in-betweens")
        check(runtime.recover.size() == batch.baseline_frames.recover.size()+6, kind + " generic return to guard gains six drawings")
        for animation in ["heavy_recover","cast_recover","phase_recover"]:
            check(runtime[animation].size() == batch.baseline_frames[animation].size()+8, kind + "/" + animation + " bridges and shared generic in-betweens")
        for animation: String in batch.baseline_frames:
            var cursor := 0
            for original: Dictionary in batch.baseline_frames[animation]:
                while cursor < runtime[animation].size() and runtime[animation][cursor] != original: cursor += 1
                check(cursor < runtime[animation].size(), kind + "/" + animation + " keeps original pose order")
                cursor += 1
    check(total == 288, "six production Bosses gain 288 authored poses")
func _check_frames(frames: SpriteFrames, manifest: Dictionary, id: String) -> void:
    characters += 1
    check(frames != null, id + " frames loaded")
    if frames == null:return
    var canvas := Vector2(float(manifest.canvas[0]),float(manifest.canvas[1]))
    for animation in manifest.animations:
        var name := String(animation.name)
        check(frames.get_frame_count(name) == animation.frames.size(), id+"/"+name+" every reviewed pose loads")
        var looping := name in ["idle","walk","talk","charge","travel"] or name.ends_with("_charge") or name.ends_with("_travel")
        check(frames.get_animation_loop(name) == looping, id+"/"+name+" loop mode")
        for index in animation.frames.size():
            var texture := frames.get_frame_texture(name,index)
            check(texture != null and texture.get_size() == canvas, id+"/"+name+" consistent rig canvas")
            poses += 1
func _check_live_playback(stage: Node2D) -> void:
    var enemy = ENEMY.new()
    enemy.configure({"id":"motion_live","kind":"moss_larva","hp":20}, "")
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    var command := {"id":"motion_probe","animation":"attack","windup":0.48,"active":0.36,"recover":0.54}
    for pair in [["windup","windup"],["active","attack"],["recover","recover"]]:
        enemy._pose_sprite(pair[0],command)
        var sprite: AnimatedSprite2D = enemy.animated_sprite
        check(sprite.animation == StringName(pair[1]), "live phase selects "+pair[1])
        check(sprite.frame == 0, "live phase begins at first pose")
        var seen := {}
        var elapsed := 0.0
        var duration := float(command[pair[0]])
        while elapsed < duration + 0.025:
            seen[sprite.frame] = true
            await process_frame
            elapsed += root.get_process_delta_time()
        check(seen.size() == sprite.sprite_frames.get_frame_count(sprite.animation), "live phase presents every "+pair[1]+" pose")
        enemy._pose_sprite(pair[0],command)
        check(sprite.frame == 0 and sprite.is_playing(), "repeated phase restarts "+pair[1])
    enemy.take_hit(1,1)
    check(enemy.animated_sprite.animation == &"hurt" and enemy.animated_sprite.frame == 0, "hit restarts recoil")
    await create_timer(0.10).timeout
    enemy.take_hit(1,-1)
    check(enemy.animated_sprite.frame == 0, "second hit restarts same recoil")
    enemy._begin_death_dissolve()
    check(enemy.animated_sprite.animation == &"death", "death sequence starts")
    var death_seen := {}
    while is_instance_valid(enemy):
        death_seen[enemy.animated_sprite.frame] = true
        await process_frame
    check(death_seen.size() >= 3, "death presents collapse poses before removal")
func _check_attack_specific_poses(stage: Node2D) -> void:
    # Fixture cels under a probe id exercise the loop timing; production frames are untouched.
    var enemy = ENEMY.new()
    enemy.configure({"id":"motion_attack_specific","kind":"moss_larva","hp":20}, "")
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    var sprite: AnimatedSprite2D = enemy.animated_sprite
    var frames: SpriteFrames = sprite.sprite_frames.duplicate()
    var cel := frames.get_frame_texture("attack", 0)
    for data in [["probe_curl_windup",false],["probe_curl",false],["probe_curl_recover",false],["probe_curl_charge",true],["probe_curl_travel",true]]:
        frames.add_animation(data[0])
        frames.set_animation_loop(data[0], data[1])
        frames.set_animation_speed(data[0], 8.0)
        for index in 2: frames.add_frame(data[0], cel)
    sprite.sprite_frames = frames
    var command := {"id":"probe_curl","animation":"attack","windup":0.9,"active":0.5,"recover":0.5}
    enemy.state = "windup"
    enemy.state_timer = 0.9
    enemy._pose_sprite("windup", command)
    check(sprite.animation == &"probe_curl_windup", "attack id selects its own wind-up")
    check(enemy.pose_loop_animation == "probe_curl_charge", "long wind-up schedules its charge loop")
    enemy._update_windup(0.3)
    check(sprite.animation == &"probe_curl_windup", "charge loop waits until the one-shot wind-up was shown")
    enemy._update_windup(0.2)
    check(sprite.animation == &"probe_curl_charge" and sprite.is_playing() and enemy.pose_loop_animation.is_empty(), "held wind-up continues as its charge loop")
    enemy._pose_sprite("active", command)
    check(sprite.animation == &"probe_curl" and enemy.pose_loop_animation == "probe_curl_travel", "travelling strike schedules its travel loop")
    enemy._pose_sprite("recover", command)
    check(sprite.animation == &"probe_curl_recover" and enemy.pose_loop_animation.is_empty(), "recover uses the attack's own cels and clears loops")
    var short := {"id":"probe_curl","animation":"attack","windup":0.4,"active":0.24,"recover":0.5}
    enemy._pose_sprite("windup", short)
    check(enemy.pose_loop_animation.is_empty(), "short wind-up plays its one-shot cels only")
    enemy._pose_sprite("windup", command)
    enemy.take_hit(1, 1)
    check(enemy.pose_loop_animation.is_empty(), "recoil cancels a pending charge loop")
    var other := {"id":"larva_curl","animation":"attack","windup":0.9,"active":0.24,"recover":0.5}
    enemy._pose_sprite("windup", other)
    check(sprite.animation == &"windup" and enemy.pose_loop_animation == "charge", "kept attack holds the species wind-up with its own charge loop")
    enemy._pose_sprite("active", other)
    check(sprite.animation == &"attack" and enemy.pose_loop_animation.is_empty(), "kept attack keeps the species strike")
    enemy.queue_free()
## Every regular creature: one attack keeps the species cels, every other attack
## (the elite signature included) plays its own wind-up, strike and recovery.
func _check_production_attack_cels(stage: Node2D) -> void:
    var combat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var designs: Dictionary = ART.manifest("res://data/original_creature_designs.json")
    var kinds := 0
    var own_total := 0
    for design in designs.designs:
        if bool(design.boss): continue
        var kind := String(design.kind)
        var enemy = ENEMY.new()
        enemy.configure({"id":"attack_cels_"+kind,"kind":kind,"hp":20,"elite":combat.get(kind, {}).get("elite") is Dictionary}, "")
        stage.add_child(enemy)
        enemy.set_physics_process(false)
        var sprite: AnimatedSprite2D = enemy.animated_sprite
        var own := 0
        for command: Dictionary in enemy.ai_commands:
            var id := String(command.id)
            enemy._pose_sprite("windup", command)
            var mine := sprite.animation == StringName(id + "_windup")
            check(mine or sprite.animation == &"windup", kind+"/"+id+" wind-up resolves")
            enemy._pose_sprite("active", command)
            check(sprite.animation == (StringName(id) if mine else &"attack"), kind+"/"+id+" strike matches its wind-up")
            enemy._pose_sprite("recover", command)
            check(sprite.animation == (StringName(id + "_recover") if mine else &"recover"), kind+"/"+id+" recovery matches its wind-up")
            if mine: own += 1
        check(own == enemy.ai_commands.size() - 1, kind+" draws every attack but the kept one")
        own_total += own
        kinds += 1
        enemy.queue_free()
    check(kinds == 40 and own_total == 50, "40 regular creatures with 40 new and 10 elite attacks")
func _check_elite_profiles(stage: Node2D) -> void:
    var combat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var normal = ENEMY.new()
    normal.configure({"id":"elite_probe_normal","kind":"gear_sentinel","hp":3,"damage":1}, "")
    stage.add_child(normal)
    var elite = ENEMY.new()
    elite.configure({"id":"elite_probe","kind":"gear_sentinel","hp":3,"damage":1,"elite":true}, "")
    stage.add_child(elite)
    check(elite.is_elite and not normal.is_elite, "elite flag selects the species elite profile")
    check(elite.max_hp == 6 and normal.max_hp == 3, "elite health is 1.75x rounded up")
    check(elite.ai_commands.size() == normal.ai_commands.size() + 1 and String(elite.ai_commands.back().id) == "gear_elite_spin", "elite gains its signature attack")
    var boosted := true
    for index in normal.ai_commands.size():
        boosted = boosted and int(elite.ai_commands[index].get("damage", 1)) == int(normal.ai_commands[index].get("damage", 1)) + 1
    check(boosted and int(normal.ai_commands[0].get("damage", 1)) == 1, "elite adds damage without changing the shared profile")
    check(elite.visual_scale > normal.visual_scale, "elite silhouette is larger")
    check(elite.cooldowns.has("gear_elite_spin"), "signature attack has its own cooldown")
    normal.queue_free()
    elite.queue_free()
    var elite_spawns := 0
    for path in ["demo_ch01_moss_bell_court","demo_ch02_rain_foundry_canal","demo_ch03_saltwhite_archive","demo_ch04_broken_string_greenhouse","demo_ch05_obsidian_pilgrim_road","demo_ch06_silent_crown_core"]:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + path + ".json"))
        for spawn: Dictionary in config.get("enemy_spawns", []):
            if bool(spawn.get("elite", false)):
                elite_spawns += 1
                check(combat.get(String(spawn.kind), {}).get("elite") is Dictionary, path + " elite " + String(spawn.kind) + " has an elite profile")
    check(elite_spawns == 10, "ten elite spawns across the six regions")

