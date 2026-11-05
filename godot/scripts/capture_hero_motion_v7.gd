extends SceneTree
## Real imported Player rendering at original clocks, with scripted pose sampling.
## Old and new use the same controller, transforms and frame times. No gameplay AI.
class QuietPlayer extends "res://scripts/player_controller.gd":
    func _should_play_sfx() -> bool: return false

var destination := ""
var samples: Array[Dictionary] = []
const ACTIONS := ["jump_start", "land", "dash", "hurt", "death"]
const LABELS := ["起跳 → 空中", "落地 → 站稳", "冲刺 → 跑步", "受击 → 恢复", "死亡 → 末帧保持／淡出"]

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="):
            destination = argument.trim_prefix("--capture-output=")
    call_deferred("run")

func label_at(text: String, point: Vector2, size: int, color: Color) -> void:
    var label := Label.new()
    label.text = text
    label.position = point
    label.add_theme_font_size_override("font_size", size)
    label.modulate = color
    root.add_child(label)

func run() -> void:
    if destination.is_empty():
        push_error("Specify --capture-output=absolute-directory")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(destination)
    root.size = Vector2i(1600, 1120)
    root.content_scale_size = root.size
    RenderingServer.set_default_clear_color(Color("11181e"))
    label_at("绯线巡礼 / 主角五类动作新绘", Vector2(30, 12), 28, Color("ecddc6"))
    label_at("同一 Player · 原时钟取样 · 脚本定位，不代表自然战斗或性能验收", Vector2(32, 49), 17, Color("a6b4b6"))
    for col in 4:
        label_at(["原画 / 朝右", "新画 / 朝右", "原画 / 朝左", "新画 / 朝左"][col], Vector2(col*400+22, 81), 19, Color("d6c6ae"))
    var path := ProjectSettings.globalize_path("res://").path_join("../art_requests/hero_motion_v7/previous_animations.json")
    var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    for row in ACTIONS.size():
        for col in 4:
            var base := Vector2(col*400+10, row*200+114)
            var background := ColorRect.new()
            background.position = base
            background.size = Vector2(380, 190)
            background.color = Color("212d34") if col < 2 else Color("aaa393")
            root.add_child(background)
            label_at(LABELS[row], base+Vector2(12, 6), 15, Color("e4d3ba") if col < 2 else Color("342e2a"))
            var arena := Node2D.new()
            arena.position = base + Vector2(190, 175)
            arena.scale = Vector2.ONE * 1.55
            root.add_child(arena)
            var player = load("res://scenes/Player.tscn").instantiate()
            player.set_script(QuietPlayer)
            arena.add_child(player)
            player.set_physics_process(false)
            player.feel = null
            player.get_node("Camera2D").enabled = false
            if col % 2 == 0:
                # This Player owns its SpriteFrames; textures stay immutable.
                for name in previous:
                    player.sprite.sprite_frames.clear(name)
                    var spec: Dictionary = previous[name]
                    player.sprite.sprite_frames.set_animation_speed(name, spec.fps)
                    player.sprite.sprite_frames.set_animation_loop(name, spec.loop)
                    for frame_path in spec.frames:
                        player.sprite.sprite_frames.add_frame(name, load(frame_path))
            player.facing = 1 if col < 2 else -1
            player.sprite.flip_h = player.facing < 0
            samples.append({"player":player, "action":ACTIONS[row]})
    var frame_count := 216
    for frame_index in frame_count:
        var elapsed := fmod(float(frame_index)/60.0, 1.2)-0.15
        for sample in samples:
            var player = sample.player
            var action: String = sample.action
            var clock: float = float(player.sprite.sprite_frames.get_frame_count(action))/player.sprite.sprite_frames.get_animation_speed(action)
            if action == "dash": clock = player.dash_time
            if action == "land": clock = 0.14
            player._set_death_visibility(1.0)
            if elapsed < 0.0:
                player._pose_progress(&"idle", 0.0)
            elif action == "death":
                player._pose_progress(&"death", clampf(elapsed/clock, 0.0, 1.0))
                player._set_death_visibility((0.9-elapsed)/player.DEATH_FADE_SECONDS)
            elif elapsed < clock:
                player._pose_progress(StringName(action), elapsed/clock)
            else:
                var next := &"jump_loop" if action == "jump_start" else (&"run" if action == "dash" else &"idle")
                player._pose_progress(next, fmod((elapsed-clock)*8.0, 1.0))
        await process_frame
        await RenderingServer.frame_post_draw
        var result := root.get_texture().get_image().save_png(destination.path_join("frame_%03d.png" % frame_index))
        if result != OK:
            push_error("Cannot save hero comparison frame")
            quit(1)
            return
    for sample in samples:
        sample.player.get_parent().queue_free()
    samples.clear()
    await process_frame
    await process_frame
    print("HERO_MOTION_V7_CAPTURE frames=%d fps=60 staged=true" % frame_count)
    quit(0)
