extends SceneTree
## Sample production tool nodes and their safe terminal animations at native size.
const ART := preload("res://scripts/player_tool_art.gd")
const EFFECT := preload("res://scripts/player_tool_effect.gd")
var view: SubViewport
var stage: Node2D
var phase: Label
var output := ""

func _initialize() -> void: call_deferred("run")

func point(index: int, variant: int) -> Vector2:
    return Vector2(index * 360 + (95 if variant % 2 == 0 else 265), (230 if variant < 2 else 470) - (6 if index == 1 else 42 if index == 3 else 0))

func capture(filename: String) -> void:
    await process_frame; await RenderingServer.frame_post_draw
    if view.get_texture().get_image().save_webp(output.path_join(filename + ".webp"), true, .95) != OK:
        push_error("Cannot save tool gallery"); quit(1)

func run() -> void:
    if DisplayServer.get_name() == "headless": push_error("Real GL required"); quit(1); return
    output = OS.get_environment("PLAYER_TOOL_GALLERY_DIR")
    if output.is_empty(): output = OS.get_cache_dir().path_join("player-tool-gallery")
    DirAccess.make_dir_recursive_absolute(output)
    view = SubViewport.new(); view.size = Vector2i(1440, 540); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
    stage = Node2D.new(); view.add_child(stage)
    var owner_node := CharacterBody2D.new(); stage.add_child(owner_node)
    phase = Label.new(); phase.position = Vector2(8, 515); phase.add_theme_font_size_override("font_size", 14); stage.add_child(phase)
    for index in range(4):
        for band in range(2):
            var at := Vector2(index * 360, 35 + band * 240)
            var background := Polygon2D.new(); background.polygon = PackedVector2Array([at, at + Vector2(360, 0), at + Vector2(360, 240), at + Vector2(0, 240)])
            background.color = Color(.08, .12, .14) if band == 0 else Color(.89, .87, .8); stage.add_child(background)
        var label := Label.new(); label.position = Vector2(index * 360 + 8, 6)
        label.text = ["JAR 20px / BLAST 150px", "MINE 72px", "FOG 260px", "LURE 40px"][index]
        label.add_theme_font_size_override("font_size", 15); stage.add_child(label)
    var nodes: Array[Node2D] = []
    var marks: Array[Node2D] = []
    var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_catalog.json"))
    # Fog needs its full 260px footprint, so one example per background; other
    # families show both directions. There are never more than twelve terminals.
    for index in range(4):
        for variant in range(4):
            var node := EFFECT.new(); node.payload = catalog.tools[ART.FAMILIES[index]].duplicate(true); node.payload.id = ART.FAMILIES[index]
            node.owner_player = owner_node; node.direction = -1 if variant % 2 == 0 else 1
            node.position = point(index, variant)
            if index == 2:
                node.position.x = index * 360 + 180
                node.position.y = 155 if variant < 2 else 395
            stage.add_child(node); node.set_physics_process(false)
            if index == 2 and variant % 2 == 1: node.hide()
            nodes.append(node)
    for frame in range(8):
        phase.text = "PHASE SAMPLES: jar flight / landing warning / safe blast; mine placement / armed / safe snap; fog growth / loop / safe fade; one-shot safe bell"
        for index in range(4):
            for variant in range(4):
                if index == 2 and variant % 2 == 1: continue
                var node: Node2D = nodes[index * 4 + variant]
                var terminal := index == 0 and frame >= 4 or index == 1 and frame >= 3 or index == 2 and frame >= 6 or index == 3
                if index == 3 and frame >= 4: node.hide(); continue
                if terminal:
                    node.hide()
                    var reason := "trigger" if index < 2 else "expiry" if index == 2 else "ring"
                    var mark := ART.spawn_terminal(stage, node.position, ART.FAMILIES[index], node.direction, reason)
                    if mark == null: push_error("Tool gallery exceeded decoration cap"); quit(1); return
                    mark.set_process(false); mark.age = (frame - mark.first) / 16.0 + .001; mark.queue_redraw(); marks.append(mark)
                else:
                    node.elapsed = frame / 12.0 + .001
                    node.landed = index == 0 and frame >= 2; node.warning_timer = .3 if frame == 2 else .1
                    node.modulate = Color(1, .45, .15) if node.landed else Color.WHITE
                    node.queue_redraw()
        await capture("phase_%d" % frame)
        for mark in marks: mark.queue_free()
        marks.clear(); await process_frame
    for node in nodes: node.queue_free()
    await process_frame; phase.text = "RETIRED: no remaining damage, control, trap or decoration"; await capture("empty")
    view.queue_free(); await process_frame; await process_frame
    print("PLAYER_TOOL_GALLERY families=4 frames=28 native_scale=true backgrounds=2 real_gl=true phase_samples=true")
    quit(0)
