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
    check(characters == 71, "all 46 creatures and 25 NPCs visited")
    print("EXPANDED_CHARACTER_MOTION checks=%d failures=%d characters=%d poses=%d" % [checks,failures,characters,poses])
    quit(0 if failures == 0 else 1)
func _check_frames(frames: SpriteFrames, manifest: Dictionary, id: String) -> void:
    characters += 1
    check(frames != null, id + " frames loaded")
    if frames == null:return
    var canvas := Vector2(float(manifest.canvas[0]),float(manifest.canvas[1]))
    for animation in manifest.animations:
        var name := String(animation.name)
        check(frames.get_frame_count(name) == animation.frames.size(), id+"/"+name+" every reviewed pose loads")
        check(frames.get_animation_loop(name) == (name in ["idle","walk","talk"]), id+"/"+name+" loop mode")
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
