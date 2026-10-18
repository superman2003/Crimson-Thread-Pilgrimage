extends SceneTree
## Real-GL capture of every regular creature playing its newly drawn attack
## through the production actor (_pose_sprite), plus the elite signatures.
## Run: godot --display-driver x11 --rendering-method gl_compatibility --fixed-fps 60
##      --path godot --script res://../tools/capture_creature_attack_motion.gd
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const COLS := 8
const CELL := Vector2(220, 230)
const PHASES := [["windup", 0.5], ["active", 0.4], ["recover", 0.5]]
const SHOTS_PER_PHASE := 4
var output := ""
var view: SubViewport
var records: Array = []

class Stage extends Node2D:
    var chapter_terrain: Node = null

func _initialize() -> void: call_deferred("run")

func _own_command(enemy, elite: bool) -> Dictionary:
    var picked: Dictionary = {}
    for command: Dictionary in enemy.ai_commands:
        if enemy._has_enemy_animation(String(command.id) + "_windup"):
            picked = command
            if not elite: break
    return picked

func _pose_all(enemies: Array, phase: String, duration: float) -> void:
    for entry: Dictionary in enemies:
        var probe: Dictionary = entry.command.duplicate()
        probe[phase] = duration
        entry.enemy._pose_sprite(phase, probe)

func _capture_set(label: String, elite: bool) -> void:
    var stage := Stage.new()
    view.add_child(stage)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.11, 0.12, 0.15)
    backdrop.size = Vector2(view.size)
    stage.add_child(backdrop)
    var combat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    var designs: Dictionary = ART.manifest("res://data/original_creature_designs.json")
    var enemies: Array = []
    for design in designs.designs:
        var kind := String(design.kind)
        if bool(design.boss) or (elite and not combat.get(kind, {}).get("elite") is Dictionary): continue
        var index := enemies.size()
        var cell := Vector2(index % COLS, index / COLS) * CELL
        var enemy = ENEMY.new()
        enemy.configure({"id": "capture_" + kind, "kind": kind, "hp": 20, "elite": elite}, "")
        enemy.position = cell + Vector2(CELL.x * 0.5, CELL.y - 34)
        stage.add_child(enemy)
        enemy.set_physics_process(false)
        enemy.direction = 1
        enemy.attack_direction = 1
        enemy._set_sprite_flip(false)
        var caption := Label.new()
        caption.position = cell + Vector2(6, CELL.y - 26)
        caption.add_theme_font_size_override("font_size", 12)
        var command := _own_command(enemy, elite)
        caption.text = kind + "  " + String(command.get("id", "?"))
        stage.add_child(caption)
        enemies.append({"kind": kind, "enemy": enemy, "command": command})
    await process_frame
    var shot := 0
    for phase_data in PHASES:
        var phase := String(phase_data[0])
        var duration := float(phase_data[1])
        _pose_all(enemies, phase, duration)
        for index in SHOTS_PER_PHASE:
            var wait := duration / SHOTS_PER_PHASE
            var elapsed := 0.0
            while elapsed < wait - 0.001:
                await process_frame
                elapsed += 1.0 / 60.0
            await RenderingServer.frame_post_draw
            var image: Image = view.get_texture().get_image()
            if image.is_empty():
                push_error("Real renderer required")
                quit(1)
                return
            var name := "%s_%02d_%s.jpg" % [label, shot, phase]
            image.save_jpg(output.path_join(name), 0.9)
            var animations := {}
            for entry: Dictionary in enemies:
                var sprite: AnimatedSprite2D = entry.enemy.animated_sprite
                animations[entry.kind] = [String(sprite.animation), sprite.frame]
            records.append({"image": name, "phase": phase, "animations": animations})
            shot += 1
    stage.queue_free()
    await process_frame

func run() -> void:
    # An offscreen viewport keeps the capture size independent of the desktop window.
    view = SubViewport.new()
    view.size = Vector2i(int(CELL.x) * COLS, int(CELL.y) * 5)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    output = ProjectSettings.globalize_path("res://../artifacts/creature_attack_motion")
    DirAccess.make_dir_recursive_absolute(output)
    if RenderingServer.get_current_rendering_method() != "gl_compatibility" or DisplayServer.get_name() == "headless":
        push_error("Real compatibility renderer required")
        quit(1)
        return
    await _capture_set("regular", false)
    await _capture_set("elite", true)
    var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "viewport": [view.size.x, view.size.y], "shots": records}, "  ") + "\n")
    file.close()
    print("CREATURE_ATTACK_CAPTURE shots=%d" % records.size())
    quit(0)
