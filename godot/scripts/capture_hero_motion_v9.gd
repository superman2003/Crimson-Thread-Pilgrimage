extends SceneTree
## Staged body comparison with real SpriteFrames clocks and heavy phase selection.
class QuietPlayer extends "res://scripts/player_controller.gd":
    func _should_play_sfx() -> bool: return false

var destination := ""
var actors: Array[Dictionary] = []
func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="): destination=argument.trim_prefix("--capture-output=")
    call_deferred("run")
func label_at(value: String, position: Vector2, size: int, color: Color) -> void:
    var label := Label.new(); label.text=value; label.position=position
    label.add_theme_font_size_override("font_size",size); label.modulate=color; root.add_child(label)
func run() -> void:
    if destination.is_empty(): push_error("Specify --capture-output=absolute-directory"); quit(1); return
    DirAccess.make_dir_recursive_absolute(destination)
    root.size=Vector2i(1520,800); root.content_scale_size=root.size
    RenderingServer.set_default_clear_color(Color("11181e"))
    label_at("绯线巡礼 / 整身呼吸与重击衔接",Vector2(24,14),27,Color("ecddc6"))
    label_at("暂停位移 · 原控制器与动画时钟 · 身体取样，不代表自然战斗或性能验收",Vector2(25,49),16,Color("a6b4b6"))
    for col in 4:
        label_at(["原画 / 朝右","新画 / 朝右","原画 / 朝左","新画 / 朝左"][col],Vector2(col*380+20,80),18,Color("d6c6ae"))
    var previous_path := ProjectSettings.globalize_path("res://").path_join("../art_requests/hero_motion_v9/previous_animations.json")
    var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(previous_path))
    for row in 2:
        for col in 4:
            var base := Vector2(col*380+8,row*330+110)
            var background := ColorRect.new(); background.position=base; background.size=Vector2(364,310)
            background.color=Color("212d34") if col<2 else Color("aaa393"); root.add_child(background)
            label_at("整身呼吸" if row==0 else "待机 → 重击 → 收势 → 待机",base+Vector2(10,7),15,Color("e4d3ba") if col<2 else Color("342e2a"))
            var stage := Node2D.new(); stage.position=base+Vector2(182,290); stage.scale=Vector2.ONE*1.8; root.add_child(stage)
            var floor_body := StaticBody2D.new(); floor_body.position=Vector2(0,10)
            var collision := CollisionShape2D.new(); var rectangle := RectangleShape2D.new()
            rectangle.size=Vector2(180,20); collision.shape=rectangle; floor_body.add_child(collision); stage.add_child(floor_body)
            var player=load("res://scenes/Player.tscn").instantiate(); player.set_script(QuietPlayer)
            player.get_node("Camera2D").enabled=false; stage.add_child(player); player.feel=null
            player.facing=1 if col<2 else -1; player.sprite.flip_h=player.facing<0
            if col%2==0:
                for name in previous:
                    player.sprite.sprite_frames.clear(name)
                    var spec: Dictionary=previous[name]
                    player.sprite.sprite_frames.set_animation_speed(name,spec.fps)
                    player.sprite.sprite_frames.set_animation_loop(name,spec.loop)
                    for path in spec.frames: player.sprite.sprite_frames.add_frame(name,load(path))
                player.idle_foot_centers=player.IDLE_FOOT_CENTER_X.duplicate()
                player.grounded_pose_foot_centers={}
                player.use_layered_idle=true
                player.layered_idle=player.LAYERED_IDLE.new()
                player.layered_idle.attach(player.sprite)
            actors.append({"player":player,"heavy":row==1})
    for index in 6: await physics_frame; await process_frame
    for actor in actors:
        actor.player.set_physics_process(false)
        actor.player._reset_traversal_state()
        actor.player._play(&"idle",true)
    for index in 192:
        var phase := index%96
        for actor in actors:
            var player=actor.player
            if actor.heavy:
                if phase==18: player._start_attack(&"attack_2",false,Vector2(player.facing,0))
                elif phase>18 and phase<=47: player._update_attack(1.0/60)
                player._update_animation(0)
        await process_frame; await RenderingServer.frame_post_draw
        if root.get_texture().get_image().save_png(destination.path_join("frame_%03d.png"%index))!=OK:
            push_error("Cannot save complete-body comparison"); quit(1); return
    for actor in actors: actor.player.get_parent().queue_free()
    actors.clear(); await process_frame; await process_frame
    print("HERO_MOTION_V9_CAPTURE frames=192 fps=60 staged=true")
    quit(0)
