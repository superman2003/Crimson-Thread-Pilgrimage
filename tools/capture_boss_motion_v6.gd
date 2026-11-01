extends SceneTree
## Real 60 Hz sprite playback against the archived main rig, no interpolation.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const BOSSES := ["rust_crown_guardian", "sunken_hammer_smith", "saltwhite_contract_judge", "broken_string_gardener", "silent_pilgrim_commander", "silent_crown_core"]
var destination := ""
var baseline := ""
var only_kind := ""
var view: SubViewport
class Stage extends Node2D:
    var chapter_terrain: Node = null

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-output="): destination = arg.trim_prefix("--capture-output=")
        if arg.begins_with("--baseline="): baseline = arg.trim_prefix("--baseline=")
        if arg.begins_with("--kind="): only_kind = arg.trim_prefix("--kind=")
    call_deferred("run")

func _label(stage: Node, text: String, pos: Vector2, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.position = pos
    label.add_theme_font_size_override("font_size", size)
    stage.add_child(label)
    return label

func _before_path(kind: String) -> String:
    var path := baseline.path_join("original_creatures").path_join(kind).path_join("motion_manifest.json")
    var data: Dictionary = ART.manifest(baseline.path_join(kind).path_join("motion_manifest.json")).duplicate(true)
    for animation: Dictionary in data.animations:
        for frame: Dictionary in animation.frames:
            frame.atlas = baseline.path_join(kind).path_join(String(frame.atlas).get_file())
    ART.manifest_cache[path] = data
    return path

func _enemy(stage: Node2D, kind: String, before: bool, position: Vector2):
    var path := _before_path(kind) if before else ART.character_manifest("original_creatures", kind)
    var manifest: Dictionary = ART.manifest(path)
    var enemy = ENEMY.new()
    enemy.configure({"id":"v6_preview", "kind":kind, "hp":100}, "", true)
    enemy.asset_path = path
    enemy.visual_scale = float(manifest.visual_scale)
    enemy.visual_offset = Vector2(float(manifest.visual_offset[0]), float(manifest.visual_offset[1]))
    enemy.position = position
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    enemy._set_sprite_flip(false)
    return enemy

func _capture(kind: String) -> void:
    var stage := Stage.new()
    view.add_child(stage)
    _label(stage, kind + " / authored in-betweens / equal before-after timing", Vector2(20,14), 18)
    _label(stage, "BEFORE  main", Vector2(150,54), 21)
    var record: Dictionary = ART.manifest("res://assets/sprites/original_creatures/"+kind+"/motion_generation.json")
    _label(stage, "AFTER  +%d runtime drawings" % int(record.boss_motion_v6.runtime_drawings), Vector2(575,54), 21)
    var phase_label := _label(stage, "", Vector2(20,390), 18)
    var before = _enemy(stage, kind, true, Vector2(240,355))
    var after = _enemy(stage, kind, false, Vector2(720,355))
    var actors := [before,after]
    var steps: Array = [{"pose":"idle", "duration":1.0,"command":{}},{"pose":"walk","duration":1.0,"command":{}}]
    var picked := {}
    for command: Dictionary in after.ai_commands:
        var animation := String(command.get("animation","attack"))
        if animation not in ["attack","heavy","cast","phase"] or picked.has(animation): continue
        picked[animation] = true
        for pose in ["windup","active","recover"]:
            steps.append({"pose":pose,"duration":float(command.get(pose,0.4)),"command":command})
    # Four production profiles select only heavy/cast/phase. Their generic
    # attack is a prepared fallback, not a newly added AI move. Preview that
    # fallback explicitly so its six new cels are inspected without changing AI.
    var fallback_preview := not picked.has("attack")
    if fallback_preview:
        var command := {"id":"v6_fallback_probe","animation":"attack","windup":0.48,"active":0.36,"recover":0.54}
        for pose in ["windup","active","recover"]:
            steps.append({"pose":pose,"duration":float(command[pose]),"command":command,"fallback":true})
    steps.append({"pose":"idle","duration":0.5,"command":{}})
    var output := destination.path_join("frames").path_join(kind)
    DirAccess.make_dir_recursive_absolute(output)
    var index := 0
    var observed: Dictionary = {}
    for step: Dictionary in steps:
        var pose := String(step.pose)
        var command: Dictionary = step.command
        phase_label.text = String(command.get("animation",pose)) + " / " + pose + (" [prepared fallback preview]" if bool(step.get("fallback",false)) else "")
        for actor in actors:
            actor.state = pose
            actor.state_timer = float(step.duration)
            actor._pose_sprite(pose,command)
        var ticks := maxi(1,roundi(float(step.duration)*60.0))
        for tick in ticks:
            await process_frame
            for actor in actors:
                actor.state_timer = maxf(0.0,float(step.duration)-float(tick+1)/60.0)
                actor._advance_pose_loop()
            var sprite: AnimatedSprite2D = after.animated_sprite
            observed[String(sprite.animation)+"/"+str(sprite.frame)] = true
            await RenderingServer.frame_post_draw
            var image := view.get_texture().get_image()
            if image.save_jpg(output.path_join("%05d.jpg" % index),0.97) != OK:
                push_error("Frame save failed")
                quit(1)
                return
            index += 1
    var file := FileAccess.open(destination.path_join(kind+".json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"kind":kind,"fps":60,"frames":index,"observed_poses":observed.keys(),"renderer":RenderingServer.get_video_adapter_name(),"prepared_fallback_preview":fallback_preview,"scope":"staged production sprite playback, no gameplay AI or damage; real commands retain gameplay durations; generic fallback uses the same 0.48/0.36/0.54 fixture on both sides"},"  ")+"\n")
    file.close()
    stage.queue_free()
    await process_frame
    print("BOSS_MOTION_V6_CAPTURE kind=%s frames=%d" % [kind,index])

func run() -> void:
    if destination.is_empty() or baseline.is_empty() or DisplayServer.get_name()=="headless":
        push_error("Real renderer, --capture-output and --baseline required")
        quit(1)
        return
    view = SubViewport.new()
    view.size = Vector2i(960,430)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    RenderingServer.set_default_clear_color(Color("172229"))
    for kind in BOSSES:
        if only_kind.is_empty() or only_kind==kind: await _capture(kind)
    view.queue_free()
    await process_frame
    quit(0)
