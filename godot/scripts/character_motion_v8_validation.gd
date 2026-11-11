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
        var production := ART.manifest(path)
        var extension: Dictionary = production.get("transition_record",{})
        var redraw: Dictionary = production.get("redraw_record",{}).get("clips",{})
        var uses_v8 := path.ends_with("motion_v8_manifest.json") or (path.ends_with("motion_transition_manifest.json") and String(extension.get("baseline",""))=="motion_v8_manifest.json")
        uses_v8 = uses_v8 or (path.ends_with("motion_redraw_manifest.json") and String(production.get("generation_record",""))=="motion_v8_generation.json")
        check(uses_v8,kind+" production/prewarm retains the complete v8 core")
        if not uses_v8:continue
        # New gestures are supplemental. Keep every frozen v8 assertion and
        # its totals, and separately require the production core to be exact.
        var manifest := ART.manifest(path.get_base_dir()+"/motion_v8_manifest.json")
        var production_clips := {}
        for clip: Dictionary in production.animations:production_clips[String(clip.name)]=clip
        check(production.canvas==manifest.canvas and production.visual_scale==manifest.visual_scale and production.visual_offset==manifest.visual_offset,kind+" extension retains the complete fixed rig")
        var record := ART.manifest(path.get_base_dir()+"/motion_v8_generation.json")
        var baseline := ART.manifest("res://"+String(record.baseline_manifest).trim_prefix("godot/"))
        var padding: Array=record.symmetric_padding
        var pad := Vector2(float(padding[0]),float(padding[1]))
        var old_canvas := Vector2(float(baseline.canvas[0]),float(baseline.canvas[1]))
        var canvas := Vector2(float(manifest.canvas[0]),float(manifest.canvas[1]))
        check(canvas==old_canvas+pad*2,kind+" uses symmetric padding only")
        check(manifest.visual_scale==baseline.visual_scale and manifest.visual_offset==baseline.visual_offset,kind+" retains original sprite scale and offset")
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
            var shown: Dictionary = production_clips.get(name,{})
            if redraw.has(name):
                check(shown.get("fps")==animation.fps and shown.get("loop")==animation.loop and shown.get("frames",[]).size()==animation.frames.size(),kind+" reviewed redraw preserves the core clock and frame count")
            else:
                check(shown==animation,kind+" extension never replaces an unreviewed core pose or clock")
            var previous: Dictionary=originals[name]
            check(animation.frames.size()==previous.frames.size()*2,kind+"/"+name+" exactly doubles cels")
            check(is_equal_approx(float(animation.fps),float(previous.fps)*2),kind+"/"+name+" preserves cycle time")
            check(bool(animation.loop)==bool(previous.loop),kind+"/"+name+" preserves loop policy")
            for i in previous.frames.size():
                var old: Dictionary=previous.frames[i]
                var retained: Dictionary=animation.frames[i*2]
                check(retained.atlas==old.atlas and retained.region==old.region,kind+"/"+name+" retains original source pixels")
                check(frames.get_frame_texture(name,i*2).get_size()==canvas,kind+"/"+name+" retained pose has the common padded canvas")
                for facing in [-1,1]:
                    var old_origin:=Vector2(float(old.margin[0]),float(old.margin[1]))-old_canvas*.5
                    var new_origin:=Vector2(float(retained.margin[0]),float(retained.margin[1]))-canvas*.5
                    check((new_origin*Vector2(facing,1)).is_equal_approx(old_origin*Vector2(facing,1)),kind+"/"+name+" retains old world placement in both facings")
                var texture := frames.get_frame_texture(name,i*2+1)
                check(texture!=null and texture.get_size()==canvas,kind+"/"+name+" new pose uses common padded rig canvas")
            for frame: Dictionary in animation.frames:
                var visible:=Rect2(Vector2(float(frame.margin[0]),float(frame.margin[1])),Vector2(float(frame.region[2]),float(frame.region[3])))
                check(Rect2(Vector2.ZERO,canvas).encloses(visible),kind+"/"+name+" full pose fits the runtime canvas")
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
