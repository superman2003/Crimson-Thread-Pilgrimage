extends SceneTree
const ART := preload("res://scripts/hand_drawn_assets.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0
var characters := 0
var old_poses := 0
var new_poses := 0
var only: Array[String] = []

class Stage extends Node2D:
    var chapter_terrain: Node = null

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("CHARACTER_MOTION_V8: "+label)

func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--only="):only.append(String(argument).trim_prefix("--only="))
    var stage := Stage.new()
    root.add_child(stage)
    var roster := ART.manifest("res://data/original_creature_designs.json")
    for design: Dictionary in roster.designs:
        var kind := String(design.kind)
        if not only.is_empty() and not kind in only:continue
        var path := ART.character_manifest("original_creatures",kind)
        check(path.ends_with("motion_v8_manifest.json"),kind+" production/prewarm chooses v8")
        if not path.ends_with("motion_v8_manifest.json"):continue
        var manifest := ART.manifest(path)
        var record := ART.manifest(path.get_base_dir()+"/motion_v8_generation.json")
        var baseline := ART.manifest("res://"+String(record.baseline_manifest).trim_prefix("godot/"))
        var originals := {}
        for animation: Dictionary in baseline.animations:originals[String(animation.name)]=animation
        var actor := ENEMY.new()
        actor.configure({"kind":kind,"id":"v8_"+kind,"hp":999},"",bool(design.boss))
        stage.add_child(actor)
        actor.set_physics_process(false)
        check(actor.asset_path==path,kind+" binds the exact prewarmed layer")
        var frames: SpriteFrames = actor.animated_sprite.sprite_frames
        for animation: Dictionary in manifest.animations:
            var name := String(animation.name)
            var previous: Dictionary=originals[name]
            check(animation.frames.size()==previous.frames.size()*2,kind+"/"+name+" exactly doubles cels")
            check(is_equal_approx(float(animation.fps),float(previous.fps)*2),kind+"/"+name+" preserves cycle time")
            check(bool(animation.loop)==bool(previous.loop),kind+"/"+name+" preserves loop policy")
            for i in previous.frames.size():
                check(animation.frames[i*2]==previous.frames[i],kind+"/"+name+" retains old pixels and placement")
                var texture := frames.get_frame_texture(name,i*2+1)
                check(texture!=null and texture.get_size()==Vector2(manifest.canvas[0],manifest.canvas[1]),kind+"/"+name+" new pose uses original rig canvas")
            old_poses+=previous.frames.size()
            new_poses+=animation.frames.size()
        for command: Dictionary in actor.ai_commands:
            for phase in ["windup","active","recover"]:
                actor._pose_sprite(phase,command)
                var clip := String(actor.animated_sprite.animation)
                check(actor.pose_loop_animation.is_empty(),kind+"/"+command.id+" keeps authored phase cels")
                check(absf(actor._animation_seconds(clip)/actor.animated_sprite.speed_scale-float(command[phase]))<.001,kind+"/"+command.id+" preserves "+phase+" deadline")
        characters+=1
        RETIRE.retire_tree(actor)
        actor.queue_free()
        await process_frame
        await process_frame
        ART.frame_cache.clear()
        ART.textures.clear()
    RETIRE.retire_tree(root)
    stage.queue_free()
    await process_frame
    await process_frame
    check(await RETIRE.drain(self),"audio retired")
    if only.is_empty():check(characters==46 and old_poses==5439 and new_poses==10878,"complete frozen roster and doubled frame totals")
    else:check(characters==only.size() and new_poses==old_poses*2,"requested native subset is complete")
    print("CHARACTER_MOTION_V8 checks=%d failures=%d characters=%d old_poses=%d new_poses=%d" % [checks,failures,characters,old_poses,new_poses])
    quit(0 if failures==0 else 1)
