extends SceneTree
## Staged production-controller state sampling, not natural gameplay or a FPS test.
class QuietPlayer extends "res://scripts/player_controller.gd":
    func _should_play_sfx() -> bool: return false

const ACTIONS := ["guard","heal","hook_throw","wall_slide","phase","resonance","skill_projectile","skill_control","skill_defense"]
const LABELS := ["格挡","疗伤","钩索","贴墙","相位","共鸣","投射","控制","防御起手 → 格挡"]
var destination := ""
var samples: Array[Dictionary] = []

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="):
            destination = argument.trim_prefix("--capture-output=")
    call_deferred("run")

func label_at(text: String, point: Vector2, size: int, color: Color) -> void:
    var label := Label.new()
    label.text = text
    label.position = point
    label.add_theme_font_size_override("font_size",size)
    label.modulate = color
    root.add_child(label)

func sample_state(player, action: String, elapsed: float) -> void:
    player.heal_timer = 0
    player.guard_timer = 0
    player.attack_timer = 0
    player.grapple_timer = 0
    player.grapple_recovery_timer = 0
    player.wall_sliding = false
    player.phase_active = false
    player.active_skill.clear()
    if action == "guard":
        player.guard_initial_duration = 0.42
        player.guard_timer = maxf(0.001,0.42-elapsed)
    elif action == "heal":
        player.heal_timer = maxf(0.001,player.heal_duration-elapsed)
    elif action == "hook_throw":
        if elapsed < 0.1:
            player.current_attack = &"hook_throw"
            player.attack_duration = 0.4
            player.attack_windup = 0.1
            player.attack_active_time = 0.1
            player.attack_timer = 0.4-elapsed
        elif elapsed < 0.5:
            player.grapple_timer = player.grapple_timeout-(elapsed-0.1)
        else:
            player.grapple_recovery_timer = 0.1
    elif action == "wall_slide":
        player.wall_sliding = true
    elif action == "phase":
        player.phase_active = true
    else:
        var kind: String = {"resonance":"resonance","skill_projectile":"ranged","skill_control":"control","skill_defense":"defense"}[action]
        player.active_skill = {"kind":kind}
        player.attack_duration = 0.5
        player.attack_windup = 0.1
        player.attack_active_time = 0.2
        player.attack_timer = maxf(0.001,0.5-elapsed)
        if action == "skill_defense" and elapsed >= 0.1:
            player.guard_initial_duration = 0.5
            player.guard_timer = maxf(0.001,0.6-elapsed)
    player._update_animation(0)

func run() -> void:
    if destination.is_empty():
        push_error("Specify --capture-output=absolute-directory")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(destination)
    root.size = Vector2i(1440,1630)
    root.content_scale_size = root.size
    RenderingServer.set_default_clear_color(Color("11181e"))
    label_at("绯线巡礼 / 九类能力动作新绘",Vector2(25,12),26,Color("ecddc6"))
    label_at("原控制器取样 · 暂停物理 · 画面仅比较身体姿势",Vector2(26,46),16,Color("a6b4b6"))
    for col in 4:
        label_at(["原画 / 朝右","新画 / 朝右","原画 / 朝左","新画 / 朝左"][col],Vector2(col*360+22,76),18,Color("d6c6ae"))
    var path := ProjectSettings.globalize_path("res://").path_join("../art_requests/hero_motion_v8/previous_animations.json")
    var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    for row in ACTIONS.size():
        for col in 4:
            var base := Vector2(col*360+8,row*168+108)
            var background := ColorRect.new()
            background.position = base
            background.size = Vector2(344,162)
            background.color = Color("212d34") if col<2 else Color("aaa393")
            root.add_child(background)
            label_at(LABELS[row],base+Vector2(10,5),14,Color("e4d3ba") if col<2 else Color("342e2a"))
            var arena := Node2D.new()
            arena.position = base+Vector2(172,149)
            arena.scale = Vector2.ONE*1.35
            root.add_child(arena)
            var player = load("res://scenes/Player.tscn").instantiate()
            player.set_script(QuietPlayer)
            arena.add_child(player)
            player.set_physics_process(false)
            player.feel = null
            player.get_node("Camera2D").enabled = false
            if col%2==0:
                for name in previous:
                    player.sprite.sprite_frames.clear(name)
                    var spec: Dictionary = previous[name]
                    player.sprite.sprite_frames.set_animation_speed(name,spec.fps)
                    player.sprite.sprite_frames.set_animation_loop(name,spec.loop)
                    for frame_path in spec.frames:
                        player.sprite.sprite_frames.add_frame(name,load(frame_path))
            player.facing = 1 if col<2 else -1
            samples.append({"player":player,"action":ACTIONS[row]})
    for index in 144:
        var elapsed := fmod(float(index)/60.0,1.2)
        for sample in samples:
            sample_state(sample.player,sample.action,elapsed)
        await process_frame
        await RenderingServer.frame_post_draw
        var result := root.get_texture().get_image().save_png(destination.path_join("frame_%03d.png"%index))
        if result!=OK:
            push_error("Cannot save hero ability comparison")
            quit(1)
            return
    for sample in samples:
        sample.player.get_parent().queue_free()
    samples.clear()
    await process_frame
    await process_frame
    print("HERO_MOTION_V8_CAPTURE frames=144 fps=60 staged=true")
    quit(0)
