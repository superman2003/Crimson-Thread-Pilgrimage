extends SceneTree
## A staged real-GL capture of the production Player poses and VFX helper.
## Fixed time steps, no user's save, combat AI or game state is loaded.
const VFX := preload("res://scripts/player_basic_attack_vfx.gd")
class QuietPlayer extends "res://scripts/player_controller.gd":
    func _play_sfx(_key: String, _volume: float = -5.0, _pitch: float = 1.0, _voice_key: String = "", _priority: int = 1) -> void:
        pass
var destination := ""
var entries: Array[Dictionary] = []
var total := 24

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="):
            destination = argument.trim_prefix("--capture-output=")
    call_deferred("run")

func label_at(text: String, position: Vector2, size: int, color: Color) -> void:
    var label := Label.new()
    label.text = text
    label.position = position
    label.add_theme_font_size_override("font_size", size)
    label.modulate = color
    root.add_child(label)

func run() -> void:
    if destination.is_empty():
        push_error("Specify --capture-output=absolute-directory")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(destination)
    root.size = Vector2i(1280, 720)
    root.content_scale_size = Vector2i(1280, 720)
    root.get_viewport().transparent_bg = false
    RenderingServer.set_default_clear_color(Color("11181e"))
    label_at("绯线巡礼  /  普攻刀光", Vector2(40, 20), 29, Color("f7e7d4"))
    label_at("Pixel VFX Forge · 绯红拖尾 / 骨色刀锋 · 实际角色叠加", Vector2(42, 62), 17, Color("acb0af"))
    var specs := [
        ["右向横斩", Vector2.RIGHT, 1, false], ["左向横斩", Vector2.LEFT, -1, false],
        ["上挑 · 右", Vector2.UP, 1, false], ["上挑 · 左", Vector2.UP, -1, false],
        ["地面下劈 · 右", Vector2.DOWN, 1, false], ["地面下劈 · 左", Vector2.DOWN, -1, false],
        ["空中上挑", Vector2.UP, 1, true], ["空中下劈", Vector2.DOWN, 1, true]
    ]
    for index in specs.size():
        var spec: Array = specs[index]
        var x := float(index % 4) * 312.0 + 22.0
        var y := float(index / 4) * 287.0 + 111.0
        var card := ColorRect.new()
        card.position = Vector2(x, y)
        card.size = Vector2(300, 276)
        card.color = Color("1b252c")
        root.add_child(card)
        label_at(spec[0], Vector2(x + 16, y + 11), 20, Color("ebd7c5"))
        var arena := Node2D.new()
        arena.position = Vector2(x + 135, y + 240)
        arena.scale = Vector2.ONE * 1.45
        root.add_child(arena)
        var floor_line := Line2D.new()
        floor_line.points = PackedVector2Array([Vector2(-60, 1), Vector2(85, 1)])
        floor_line.width = 0.6
        floor_line.default_color = Color("3b4a4d")
        arena.add_child(floor_line)
        var player = load("res://scenes/Player.tscn").instantiate()
        player.set_script(QuietPlayer)
        arena.add_child(player)
        player.set_physics_process(false)
        player.set_process(false)
        player.feel = null
        player.get_node("Camera2D").enabled = false
        if spec[3]:
            player.position.y = -27
        entries.append({"player":player, "spec":spec, "effect":null})
    for frame_index in total:
        for entry in entries:
            var player = entry.player
            var spec: Array = entry.spec
            if frame_index == 0:
                player.facing = int(spec[2])
                player.sprite.flip_h = player.facing < 0
                player._start_attack(&"attack_1", false, spec[1])
                player.attack_started_grounded = not bool(spec[3])
            if frame_index > 0:
                player._update_attack(1.0 / 60.0)
            player._update_attack_pose()
            player.sprite.pause()
            var effect = player.get_node_or_null("AttackSlashVfx")
            # _update_attack_pose uses floor state for horizontal swings; the
            # stage has no physics floor, so select its grounded authored cels.
            if absf(spec[1].x) > 0.5:
                player.sprite.animation = &"attack_1"
                var elapsed: float = player.attack_duration - player.attack_timer
                var active_end: float = player.attack_windup + player.attack_active_time
                var cel := 0
                if elapsed < player.attack_windup:
                    cel = mini(1, int(elapsed / player.attack_windup * 2.0))
                elif elapsed <= active_end:
                    cel = 2 + mini(1, int((elapsed - player.attack_windup) / player.attack_active_time * 2.0))
                else:
                    cel = 4 + mini(1, int((elapsed - active_end) / (player.attack_duration - active_end) * 2.0))
                player.sprite.frame = cel
            if effect != null:
                effect.set_process(false)
                effect._process(0.0 if entry.effect == null else 1.0 / 60.0)
                entry.effect = effect
        await process_frame
        await RenderingServer.frame_post_draw
        var error := root.get_texture().get_image().save_png(destination.path_join("frame_%02d.png" % frame_index))
        if error != OK:
            push_error("Cannot save player VFX capture")
            quit(1)
            return
    for entry in entries:
        entry.player.get_parent().queue_free()
    await process_frame
    await process_frame
    print("PLAYER_BASIC_VFX_CAPTURE frames=%d staged=true" % total)
    quit(0)
