extends SceneTree
## Real renderer gallery at gameplay scale and 2x, with both directions/backgrounds.
## Fixture only: physics is disabled so each authored cel can be inspected.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/projectile_art.gd")
var view: SubViewport
var stage: Node2D
var enemy: Node2D
var output := ""
const CELL := Vector2i(160, 240)

func _initialize() -> void:
    call_deferred("run")

func shot(name: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    view.get_texture().get_image().save_webp(output.path_join(name + ".webp"), true, 0.95)

func position_for(index: int, variant: int) -> Vector2:
    return Vector2(index % 5 * CELL.x, index / 5 * CELL.y) + Vector2(44 if variant % 2 == 0 else 116, 82 if variant < 2 else 186)

func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real GL required")
        quit(1)
        return
    output = OS.get_environment("PROJECTILE_GALLERY_DIR")
    if output.is_empty(): output = "/tmp/projectile-gallery"
    DirAccess.make_dir_recursive_absolute(output)
    view = SubViewport.new()
    view.size = Vector2i(800, 720)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    stage = Node2D.new()
    view.add_child(stage)
    enemy = ENEMY.new()
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    for index in range(15):
        var corner := Vector2(index % 5 * CELL.x, index / 5 * CELL.y)
        for band in range(2):
            var background := Polygon2D.new()
            var at := corner + Vector2(0, 30 if band == 0 else 134)
            background.polygon = PackedVector2Array([at,at+Vector2(160,0),at+Vector2(160,106),at+Vector2(0,106)])
            background.color = Color(0.08,0.12,0.14) if band == 0 else Color(0.89,0.87,0.8)
            stage.add_child(background)
        var title := Label.new()
        title.text = ART.FAMILIES[index] + "   22px / 44px"
        title.position = corner + Vector2(4,5)
        title.add_theme_font_size_override("font_size",12)
        stage.add_child(title)
    var shots: Array[Node2D] = []
    for index in range(15):
        for variant in range(4):
            var axis := Vector2.RIGHT if variant % 2 == 0 else Vector2.LEFT
            var node: Node2D = enemy._effect("projectile",position_for(index,variant),axis*90,{"skin":ART.FAMILIES[index],"radius":11 if variant % 2 == 0 else 22},0,2)
            node.set_physics_process(false)
            shots.append(node)
    for frame in range(4):
        for node in shots:
            node.age = frame / ART.FLIGHT_FPS + 0.001
            node.queue_redraw()
        await shot("flight_%d" % frame)
    for node in shots: node.cancel()
    await process_frame
    await shot("empty")
    # Three families * four variants == the production twelve-contact cap.
    for page in range(5):
        var marks: Array[Node2D] = []
        for index in range(page*3,page*3+3):
            for variant in range(4):
                var axis := Vector2.RIGHT if variant % 2 == 0 else Vector2.LEFT
                var node: Node2D = ART.spawn_impact(stage,position_for(index,variant),ART.FAMILIES[index],11 if variant%2==0 else 22,axis,false)
                if node == null:
                    push_error("Gallery exceeded production budget")
                    quit(1)
                    return
                node.set_process(false)
                marks.append(node)
        for frame in range(4):
            for node in marks:
                node.age = frame / ART.IMPACT_FPS + 0.001
                node.queue_redraw()
            await shot("impact_%d_%d" % [page,frame])
        for node in marks: node.queue_free()
        await process_frame
    view.queue_free()
    await process_frame
    await process_frame
    print("PROJECTILE_GALLERY families=15 flight_cels=60 impact_cels=60 native_and_2x=true real_gl=true")
    quit(0)
