extends SceneTree
## A fixed-clock visual probe of production take_hit; not a natural playthrough.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
var destination := ""
class Stage extends Node2D:
    var chapter_terrain: Node = null
func _initialize() -> void:call_deferred("run")
func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--capture-dir="):destination=String(argument).trim_prefix("--capture-dir=")
    if destination.is_empty() or DisplayServer.get_name()=="headless":quit(1);return
    DirAccess.make_dir_recursive_absolute(destination)
    root.size=Vector2i(960,540)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color(.045,.065,.075))
    var hud:=CanvasLayer.new();root.add_child(hud)
    var title:=Label.new();title.position=Vector2(24,16)
    title.add_theme_font_override("font",load("res://assets/fonts/GlobalTypeface.otf"))
    title.add_theme_font_size_override("font_size",22);hud.add_child(title)
    var index:=0
    var records: Array=[]
    for kind in ["moss_larva","wax_bee","rust_crown_guardian"]:
        var stage:=Stage.new();root.add_child(stage)
        var camera:=Camera2D.new();camera.position=Vector2(390,300)
        camera.zoom=Vector2.ONE*(1.8 if kind=="rust_crown_guardian" else 2.5);stage.add_child(camera)
        var actor:=ENEMY.new();actor.configure({"id":"feedback_capture","kind":kind,"hp":1000},"",kind=="rust_crown_guardian")
        actor.position=Vector2(360,340);stage.add_child(actor);actor.set_physics_process(false)
        actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
        actor.position=Vector2(360,340);actor.spawn_position=actor.position;actor.reset_physics_interpolation()
        var origin:=actor.position.x
        for frame in 72:
            if frame==18:actor.take_hit(1,1)
            if frame>=18:actor._tick_timers(1.0/60.0)
            if frame==42:actor._set_enemy_animation("idle")
            title.text=kind+" · "+("命中前" if frame<18 else "全身白闪 / 受击击退" if actor.flash_timer>0 else "颜色恢复")
            await process_frame
            await RenderingServer.frame_post_draw
            var image:=root.get_texture().get_image()
            image.save_png(destination.path_join("frame_%05d.png" % index))
            var flash: Variant=actor.flash_materials[0].get_shader_parameter("flash_amount")
            records.append({"kind":kind,"frame":frame,"hp":actor.hp,"flash":float(flash) if flash!=null else 0.0,"recoil_px":actor.position.x-origin,"body_animation":String(actor.animated_sprite.animation),"body_frame":actor.animated_sprite.frame,"body_scale":[actor.sprite.scale.x,actor.sprite.scale.y]})
            index+=1
        RETIRE.retire_tree(stage);stage.queue_free();actor=null
        await process_frame;await process_frame
        ART.frame_cache.clear();ART.textures.clear()
    RETIRE.retire_tree(root)
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    await RETIRE.drain(self)
    var report:=FileAccess.open(destination.path_join("events.json"),FileAccess.WRITE)
    report.store_string(JSON.stringify(records));report.close()
    print("ENEMY_HIT_FEEDBACK_CAPTURE frames=%d" % index)
    quit()
