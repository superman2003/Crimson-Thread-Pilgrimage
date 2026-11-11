extends SceneTree
const ART:=preload("res://scripts/hand_drawn_assets.gd")
const ENEMY:=preload("res://scripts/enemy_actor.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
var checks:=0
var failures:=0
var characters:=0
var clips:=0
var new_drawings:=0

class Stage extends Node2D:
    var chapter_terrain: Node=null

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error("COMBAT_MOTION_V7: "+label)

func run() -> void:
    var stage:=Stage.new();root.add_child(stage)
    var roster: Dictionary=ART.manifest("res://data/original_creature_designs.json")
    for design in roster.designs:
        var kind:=String(design.kind)
        var path:=ART.character_manifest("original_creatures",kind)
        check(not ART.manifest(path).get("authored_combat_sequences",[]).is_empty(),kind+" uses the reviewed v7 production layer")
        if ART.manifest(path).get("authored_combat_sequences",[]).is_empty():continue
        var manifest: Dictionary=ART.manifest(path)
        # Composite movement layers inherit the v8 combat poses and provenance.
        # The selected filename no longer identifies the authored combat layer.
        var expansion := 2 if String(manifest.generation_record) == "motion_v8_generation.json" else 1
        var record: Dictionary=ART.manifest(path.get_base_dir()+"/combat_motion_v7.json")
        var actor:=ENEMY.new();actor.configure({"kind":kind,"id":"v7_"+kind,"hp":99},"",bool(design.boss))
        stage.add_child(actor);actor.set_physics_process(false)
        check(actor.asset_path==path,kind+" production configure selects the same layer as prewarming")
        check(String(manifest.generation_record)==("motion_v8_generation.json" if expansion==2 else "combat_motion_v7.json"),kind+" binds its versioned provenance")
        var frames: SpriteFrames=actor.animated_sprite.sprite_frames
        var canvas:=Vector2(float(manifest.canvas[0]),float(manifest.canvas[1]))
        var animation_data:={}
        for animation in manifest.animations:animation_data[String(animation.name)]=animation
        if manifest.has("transition_record"):
            var inherited: Dictionary=ART.manifest(path.get_base_dir()+"/"+String(manifest.transition_record.baseline))
            for animation in inherited.animations:
                var replacement: Dictionary=animation_data.get(String(animation.name),{})
                if manifest.get("redraw_record",{}).get("clips",{}).has(String(animation.name)):
                    check(replacement.get("fps")==animation.fps and replacement.get("loop")==animation.loop and replacement.get("frames",[]).size()==animation.frames.size(),kind+" reviewed redraw preserves inherited clocks")
                else:
                    check(replacement==animation,kind+" movement layer preserves inherited "+String(animation.name)+" exactly")
        for name: String in manifest.authored_combat_sequences:
            clips+=1
            check(frames.get_frame_count(name)==12*expansion,kind+"/"+name+" presents the authored source poses")
            check(not frames.get_animation_loop(name),kind+"/"+name+" finishes rather than looping a strike")
            var hashes:={}
            var atlas_images:={}
            for frame in animation_data[name].frames:
                var atlas_path:=String(frame.atlas)
                if not atlas_images.has(atlas_path):atlas_images[atlas_path]=ART.texture(atlas_path).get_image()
                var region: Array=frame.region
                var image: Image=atlas_images[atlas_path].get_region(Rect2i(region[0],region[1],region[2],region[3]))
                check(not image.is_invisible(),kind+"/"+name+" contains visible authored ink")
                hashes[image.get_data().hex_encode().sha256_text()]=true
            check(hashes.size()==12*expansion,kind+"/"+name+" contains distinct pose images")
            atlas_images.clear()
            for index in frames.get_frame_count(name):
                check(frames.get_frame_texture(name,index).get_size()==canvas,kind+"/"+name+" preserves a fixed rig canvas")
        for source in record.combat_motion_v7.sources:
            new_drawings+=int(source.new_drawings)
            var names: Array=source.animations
            var requested:=String(names[1])
            var command:={"id":"v7_clock","animation":requested,"windup":1.2,"active":.36,"recover":.9}
            for pair in [["windup",names[0]],["active",names[1]],["recover",names[2]]]:
                actor._pose_sprite(String(pair[0]),command)
                check(String(actor.animated_sprite.animation)==String(pair[1]),kind+" owns its exact action phase")
                check(actor.pose_loop_animation.is_empty(),kind+" rich clip does not jump into a legacy charge/travel/recover loop")
                var duration:=float(command[String(pair[0])])
                check(absf(actor._animation_seconds(String(pair[1]))/actor.animated_sprite.speed_scale-duration)<.001,kind+" preserves the full authored combat deadline")
        characters+=1
        RETIRE.retire_tree(actor);actor.queue_free();actor=null
        await process_frame;await process_frame
        ART.frame_cache.clear();ART.textures.clear()
    check(characters==46,"all 40 regular species and six Boss rigs are upgraded")
    check(clips>=300,"both shared and attack-specific phase clips are covered")
    check(new_drawings>=2000,"source generation records account for the full authored batch")
    RETIRE.retire_tree(root);stage.queue_free()
    await process_frame;await process_frame
    check(await RETIRE.drain(self),"motion validation retires audio")
    print("COMBAT_MOTION_V7 checks=%d failures=%d characters=%d clips=%d new_drawings=%d" % [checks,failures,characters,clips,new_drawings])
    quit(0 if failures==0 else 1)
