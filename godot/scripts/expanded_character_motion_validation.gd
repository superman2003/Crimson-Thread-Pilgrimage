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
class LegacyEnemy extends "res://scripts/enemy_actor.gd":
    ## Exercise the retained v6 routing separately from the richer live layer.
    func configure(data: Dictionary,sprite_path: String,boss_flag: bool=false,profile: Dictionary={}) -> void:
        super.configure(data,sprite_path,boss_flag,profile)
        var path:="res://assets/sprites/original_creatures/"+kind+"/motion_manifest.json"
        var old: Dictionary=preload("res://scripts/hand_drawn_assets.gd").manifest(path)
        asset_path=path;visual_scale=float(old.visual_scale)
        visual_offset=Vector2(float(old.visual_offset[0]),float(old.visual_offset[1]))
        authored_combat_sequences=[]
        if is_boss:
            ai_profile=preload("res://scripts/hand_drawn_assets.gd").manifest("res://data/original_creature_combat.json").get(kind,{}).duplicate(true)
            ai_commands=ai_profile.get("attacks",[]).duplicate(true)
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
        var path := ART.character_manifest("original_creatures",kind)
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
    await _check_phase_pacing(stage)
    await _check_boss_recovery_bridges(stage)
    await _check_v5_runtime_sources(stage)
    _check_recovery_hitch(stage)
    _check_v6_registration()
    _check_elite_profiles(stage)
    check(characters == 71, "all 46 creatures and 25 NPCs visited")
    print("EXPANDED_CHARACTER_MOTION checks=%d failures=%d characters=%d poses=%d" % [checks,failures,characters,poses])
    quit(0 if failures == 0 else 1)

func _check_phase_pacing(stage: Node2D) -> void:
    var designs: Dictionary = ART.manifest("res://data/original_creature_designs.json")
    var combat: Dictionary = ART.manifest("res://data/original_creature_combat.json")
    var commands := 0
    var held_charges := 0
    var authored_phases := 0
    for design: Dictionary in designs.designs:
        var enemy = ENEMY.new()
        var kind := String(design.kind)
        enemy.configure({"id":"pacing_" + kind, "kind":kind, "hp":20, "elite":combat.get(kind, {}).get("elite") is Dictionary}, "", bool(design.boss))
        stage.add_child(enemy)
        enemy.set_physics_process(false)
        check(enemy.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON, kind + " interpolates between physics ticks")
        for command: Dictionary in enemy.ai_commands:
            commands += 1
            for phase: String in ["windup", "active", "recover"]:
                enemy.state = phase
                enemy.state_timer = float(command[phase])
                var point: Vector2 = enemy.global_position
                enemy._pose_sprite(phase, command)
                var sprite: AnimatedSprite2D = enemy.animated_sprite
                var frames: SpriteFrames = sprite.sprite_frames
                var count := frames.get_frame_count(sprite.animation)
                var rate := frames.get_animation_speed(sprite.animation) * sprite.speed_scale
                var segment: float = float(command[phase]) - enemy.pose_loop_at if not enemy.pose_loop_animation.is_empty() else float(command[phase])
                var seconds := 0.0
                # #570's authored combat sequences keep their drawn, evenly
                # spaced timing; the pose holds apply to the other phase art.
                var authored: bool = String(sprite.animation).trim_suffix("_left").trim_suffix("_right") in enemy.authored_combat_sequences
                if authored and phase != "active":
                    authored_phases += 1
                for index in count:
                    var cel_seconds := frames.get_frame_duration(sprite.animation, index) / rate
                    seconds += cel_seconds
                    if not authored and ((phase == "windup" and index < count - 1) or (phase == "recover" and index > 0)):
                        check(cel_seconds <= 1.0 / 12.0 + .00001, kind + "/" + String(command.id) + " moving cel is at least 12fps")
                check(absf(seconds - segment) < .0001, kind + "/" + String(command.id) + "/" + phase + " retains the exact phase duration")
                check(enemy.global_position == point and is_equal_approx(enemy.state_timer, float(command[phase])), kind + " presentation leaves position and combat deadline unchanged")
                if phase == "windup" and not enemy.pose_loop_animation.is_empty():
                    var loop := enemy._resolve_directional_animation(enemy.pose_loop_animation)
                    if frames.get_frame_count(loop) <= 2:
                        var final_cel := frames.get_frame_texture(sprite.animation, count - 1)
                        enemy.state_timer = enemy.pose_loop_at
                        enemy._advance_pose_loop()
                        check(enemy.pose_holding_charge and not sprite.is_playing() and frames.get_frame_texture(sprite.animation, sprite.frame) == final_cel, kind + " holds the same final windup cel")
                        held_charges += 1
        enemy.queue_free()
        await process_frame
    var a = ENEMY.new()
    var b = ENEMY.new()
    for enemy in [a, b]:
        enemy.configure({"id":"pacing_isolation", "kind":"moss_larva", "hp":20}, "")
        stage.add_child(enemy)
        enemy.set_physics_process(false)
    var shared: SpriteFrames = b.animated_sprite.sprite_frames
    # Every shipped phase is authored now; exercise the hold timing on art
    # that is not, as a manifest without authored sequences would be.
    a.authored_combat_sequences = []
    a._pose_sprite("recover", {"id":"generic", "recover":1.4})
    check(a.animated_sprite.sprite_frames != shared and b.animated_sprite.sprite_frames == shared, "phase timing is owned by each actor")
    check(a.animated_sprite.sprite_frames.get_frame_duration("recover", 0) > 1.0, "slow recovery holds its first cel")
    for index in shared.get_frame_count("recover"):
        check(is_equal_approx(shared.get_frame_duration("recover", index), 1.0), "actor A never changes actor B or the shared art cache")
    # Ground walking cadence is owned by _sync_walk_cadence (main, #570).
    a.state = "patrol"
    a._pose_sprite("walk")
    var point: Vector2 = a.global_position
    a._sync_walk_cadence(.1, point - Vector2(a.speed * .01, 0))
    check(is_equal_approx(a.animated_sprite.speed_scale, .28), "slow walking clamps cadence to .28")
    a._sync_walk_cadence(.1, point - Vector2(a.speed * .2, 0))
    check(is_equal_approx(a.animated_sprite.speed_scale, 1.5), "fast walking clamps cadence to 1.5")
    a._sync_walk_cadence(.1, point - Vector2(a.speed * .1, 0))
    check(a.animated_sprite.is_playing() and is_equal_approx(a.animated_sprite.speed_scale, 1.0), "walking follows its actual travel cadence")
    a._sync_walk_cadence(.1, point)
    check(String(a.animated_sprite.animation).begins_with("idle"), "blocked walking settles to idle")
    a.state = "recover"
    a.active_attack = {"type":"lunge"}
    a._update_animation_motion(.025, point, "active")
    a._update_animation_motion(.025, point, "recover")
    check(a.sprite.scale.x > a.sprite_base_scale.x and a.global_position == point, "impact feedback changes only the sprite")
    var foot := Vector2(0, 40)
    var local_foot: Vector2 = (foot - a.sprite_base_position) / a.sprite_base_scale
    check((a.sprite.position + local_foot * a.sprite.scale).distance_to(foot) < .001, "impact pulse preserves the grounded foot pivot")
    a._pose_sprite("hurt")
    check(a.pose_feedback_time == 0 and a.sprite.scale == a.sprite_base_scale, "interrupt clears impact feedback")
    a.queue_free()
    b.queue_free()
    check(commands == 114 and authored_phases == 228, "all 114 creature commands have actual runtime timing coverage (authored windup/recover %d, held charges %d)" % [authored_phases, held_charges])
    print("ENEMY_PHASE_PACING commands=%d held_charges=%d" % [commands, held_charges])
func _check_v6_registration() -> void:
    var bosses := ["rust_crown_guardian", "sunken_hammer_smith", "saltwhite_contract_judge", "broken_string_gardener", "silent_pilgrim_commander", "silent_crown_core"]
    var total := 0
    var playable := 0
    var source_only := 0
    for kind: String in bosses:
        var record: Dictionary = ART.manifest("res://assets/sprites/original_creatures/" + kind + "/motion_generation.json")
        check(record.has("boss_motion_v6"), kind + " new in-between batch exists")
        if not record.has("boss_motion_v6"): continue
        var batch: Dictionary = record.boss_motion_v6
        check(batch.runtime_model == "main-bridge-settle", kind + " preserves upstream bridge/settle model")
        check(batch.sources.size() == 8 and int(batch.new_drawings) == 48, kind + " eight sheets / 48 authored drawings")
        total += int(batch.new_drawings)
        playable += int(batch.runtime_drawings)
        source_only += batch.source_only.size()
        var runtime: Dictionary = record.runtime_frames
        check(runtime.idle.size() == 8 and runtime.walk.size() == 16, kind + " idle and gait include loop seam drawings")
        for animation in ["windup","attack","heavy_windup","heavy","cast_windup","cast","phase_windup","phase"]:
            check(runtime[animation].size() == 7, kind + "/" + animation + " three new anatomical in-betweens")
        check(runtime.recover.size() == batch.baseline_frames.recover.size()+6, kind + " generic return to guard gains six drawings")
        for move in ["heavy","cast","phase"]:
            var settles: bool = kind == "broken_string_gardener" and move in ["heavy","phase"]
            var name: String = move + ("_settle" if settles else "_bridge")
            check(runtime[name].size() == (3 if settles else 4), kind + "/" + name + " preserves standing settle or shared recovery")
            check(not runtime.has(move+"_recover"), kind + " does not override main bridge routing")
        var new_entries := 0
        for animation: String in batch.baseline_frames:
            var cursor := 0
            for original: Dictionary in batch.baseline_frames[animation]:
                while cursor < runtime[animation].size() and runtime[animation][cursor] != original: cursor += 1
                check(cursor < runtime[animation].size(), kind + "/" + animation + " keeps upstream pose order and grade")
                cursor += 1
            for entry: Dictionary in runtime[animation]:
                if String(entry.get("source", "")).begins_with("art_requests/boss_motion_v6/"):
                    new_entries += 1
                    check(entry.has("grade"), kind + " new cel matches main palette")
        check(new_entries == int(batch.runtime_drawings), kind + " all registered new drawings are accounted for")
    check(total == 288 and playable == 286 and source_only == 2, "288 authored poses: 286 compatible runtime cels, two source-only upright-to-crouch cels")

func _check_frames(frames: SpriteFrames, manifest: Dictionary, id: String) -> void:
    characters += 1
    check(frames != null, id + " frames loaded")
    if frames == null:return
    var canvas := Vector2(float(manifest.canvas[0]),float(manifest.canvas[1]))
    for animation in manifest.animations:
        var name := String(animation.name)
        check(frames.get_frame_count(name) == animation.frames.size(), id+"/"+name+" every reviewed pose loads")
        var looping := name in ["idle","walk","talk","charge","travel","backstep"] or name.ends_with("_charge") or name.ends_with("_travel")
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
    check(sprite.animation == &"probe_curl_windup" and not sprite.is_playing() and sprite.frame == 1 and enemy.pose_holding_charge and enemy.pose_loop_animation.is_empty(), "held two-cel charge keeps the final wind-up drawing")
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
    check(sprite.animation == &"windup" and enemy.pose_loop_animation == ("" if "windup" in enemy.authored_combat_sequences else "charge"), "kept attack uses the complete authored wind-up or retained charge fallback")
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
## Every boss heavy/cast/phase recovery first plays its drawn bridge, then hands
## over to the shared recovery fitted to the remaining time (the root bishop's
## heavy and phase bridges end upright and settle straight into idle).
func _check_boss_recovery_bridges(stage: Node2D) -> void:
    var settle := {"broken_string_gardener": ["heavy", "phase"]}
    var bridged := 0
    for kind in ["broken_string_gardener","rust_crown_guardian","saltwhite_contract_judge","sunken_hammer_smith","silent_crown_core","silent_pilgrim_commander"]:
        var enemy = LegacyEnemy.new()
        enemy.configure({"id":"bridge_"+kind,"kind":kind,"hp":20}, "", true)
        stage.add_child(enemy)
        enemy.set_physics_process(false)
        var sprite: AnimatedSprite2D = enemy.animated_sprite
        for command: Dictionary in enemy.ai_commands:
            var move := String(command.get("animation", "attack"))
            if not move in ["heavy", "cast", "phase"]: continue
            var settles: bool = move in settle.get(kind, [])
            var bridge := move + ("_settle" if settles else "_bridge")
            var after := "idle" if settles else "recover"
            var label: String = kind+"/"+String(command.id)
            check(sprite.sprite_frames.get_frame_count(bridge) == (3 if settles else 4), label+" includes compatible bridge in-betweens")
            enemy.state = "recover"
            enemy.state_timer = float(command.get("recover", 0.5))
            enemy._pose_sprite("recover", command)
            check(sprite.animation == StringName(bridge) and sprite.frame == 0, label+" recovery opens on its bridge")
            check(enemy.pose_loop_animation == after, label+" bridge hands over to "+after)
            var handover: float=float(command.get("recover",0.5))-float(enemy.pose_loop_at)
            check(handover>0.0 and handover<float(command.get("recover",0.5)),label+" bridge gets a bounded share of the original window")
            enemy._update_recover(handover*.6)
            check(sprite.animation == StringName(bridge), label+" bridge is shown before the hand-over")
            enemy._update_recover(handover*.4+.001)
            check(sprite.animation == StringName(after) and enemy.pose_loop_animation.is_empty(), label+" continues as "+after)
            if after == "recover":
                var remaining := float(command.get("recover", 0.5)) - handover
                var expected := sprite.sprite_frames.get_frame_count("recover") / (sprite.sprite_frames.get_animation_speed("recover") * remaining)
                check(absf(sprite.speed_scale - expected) < 0.001, label+" shared recovery fills the remaining time")
            enemy._pose_sprite("idle")
            bridged += 1
        enemy.queue_free()
        await process_frame
    check(bridged == 22, "22 boss heavy/cast/phase attacks recover through a drawn bridge")
func _check_v5_runtime_sources(stage: Node2D) -> void:
    var delivered := {}
    var source_frames := 0
    var level := LEVEL.new()
    var bosses := ["broken_string_gardener", "rust_crown_guardian", "saltwhite_contract_judge", "sunken_hammer_smith", "silent_crown_core", "silent_pilgrim_commander"]
    var ids := bosses + ["ash_banner_imp", "echo_contract_scribe", "wax_lancer", "delayed_shadow", "pipe_thrower", "npc_blind_bell_knight", "npc_deserter_flagbearer"]
    for id: String in ids:
        var npc := id.begins_with("npc_")
        var path := ART.character_manifest("original_npcs",id) if npc else "res://assets/sprites/original_creatures/"+id+"/motion_manifest.json"
        var record: Dictionary = ART.manifest(path.get_base_dir() + "/motion_generation.json")
        var actor: Node2D
        var sprite: AnimatedSprite2D
        if npc:
            actor = level._make_npc({"id": id, "name": id})
            stage.add_child(actor)
            sprite = actor.get_node("FriendlyFamilySprite") as AnimatedSprite2D
        else:
            actor = LegacyEnemy.new()
            actor.configure({"id": "v5_" + id, "kind": id, "hp": 20}, "", id in bosses)
            stage.add_child(actor)
            actor.set_physics_process(false)
            sprite = actor.animated_sprite
            check(actor.asset_path == path, id + " retained v5 manifest selected")
        check(sprite.sprite_frames == ART.frames(path), id + " retained v5 factory uses reviewed motion frames")
        for animation: String in record.get("runtime_frames", {}):
            var entries: Array = record.runtime_frames[animation]
            for index in entries.size():
                var source := String(entries[index].get("source", ""))
                if not source.begins_with("art_requests/character_motion_v5/incoming/"): continue
                delivered[source] = int(delivered.get(source, 0)) + 1
                source_frames += 1
                sprite.play(animation)
                sprite.pause()
                sprite.frame = index
                var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
                check(texture != null and texture.atlas != null and texture.atlas.resource_path.ends_with("/motion_runtime.png"), id + "/" + animation + "[%d] uses packed v5 pixels" % index)
        actor.queue_free()
        await process_frame
    level.free()
    check(delivered.size() == 32 and source_frames == 67, "all 32 PR138 sheets / 67 cels remain available in the retained fallback")
    print("CHARACTER_MOTION_V5 sources=%d frames=%d" % [delivered.size(), source_frames])

func _check_recovery_hitch(stage: Node2D) -> void:
    var enemy = LegacyEnemy.new()
    enemy.configure({"id": "v5_hitch", "kind": "sunken_hammer_smith", "hp": 20}, "", true)
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    var sprite: AnimatedSprite2D = enemy.animated_sprite
    var command := {"id": "boss_shears_close", "animation": "heavy", "recover": 0.8}
    for fraction: float in [0.0,0.16,0.56,0.94]:
        enemy.state = "recover"
        enemy.state_timer = 0.8
        enemy._pose_sprite("recover", command)
        var handover: float=0.8-float(enemy.pose_loop_at)
        var remaining:=0.8-handover
        var overshoot:=fraction*remaining
        enemy._update_recover(handover+overshoot)
        var count := sprite.sprite_frames.get_frame_count("recover")
        var expected := overshoot * count / remaining
        check(sprite.animation == &"recover", "hitch still selects shared recovery")
        check(absf(sprite.frame + sprite.frame_progress - expected) < 0.001, "hitch preserves elapsed recovery animation at %.2fs" % overshoot)
        check(absf(enemy.state_timer - (remaining - overshoot)) < 0.001, "hitch keeps the original punishment window")
        enemy._update_recover(enemy.state_timer + 0.001)
        check(enemy.state == "patrol" and sprite.animation in [&"idle",&"walk"], "hitch recovery hands back to locomotion on schedule")
    enemy._pose_sprite("recover", command)
    enemy._pose_sprite("hurt")
    check(enemy.pose_loop_animation.is_empty(), "recoil cancels pending v5 bridge follow-up")
    enemy.queue_free()

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

