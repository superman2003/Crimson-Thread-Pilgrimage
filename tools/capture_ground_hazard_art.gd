extends SceneTree
## Controlled production attack objects, gameplay radii, real GL readback.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/ground_hazard_art.gd")
const RADII := [28,48,45,36,37,36,32,34]
var view: SubViewport
var stage: Node2D
var enemy: Node2D
var output := ""
var phase: Label

func _initialize() -> void: call_deferred("run")

func point(index: int, variant: int) -> Vector2:
    return Vector2(index%4*160+80,index/4*260+100+variant*110)

func capture(filename: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var error := view.get_texture().get_image().save_webp(output.path_join(filename+".webp"),true,.95)
    if error != OK:
        push_error("Cannot save gallery: " + filename)
        quit(1)

func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real GL required")
        quit(1)
        return
    output = OS.get_environment("GROUND_HAZARD_GALLERY_DIR")
    if output.is_empty(): output = "/tmp/ground-gallery"
    DirAccess.make_dir_recursive_absolute(output)
    view = SubViewport.new()
    view.size = Vector2i(640,550)
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    stage = Node2D.new()
    view.add_child(stage)
    enemy = ENEMY.new()
    enemy.position = Vector2(-10000,-10000)
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    phase = Label.new()
    phase.position = Vector2(10,528)
    phase.add_theme_font_size_override("font_size",14)
    stage.add_child(phase)
    for index in range(8):
        var corner := Vector2(index%4*160,index/4*260)
        for variant in range(2):
            var at := corner+Vector2(0,40+variant*110)
            var background := Polygon2D.new()
            background.polygon = PackedVector2Array([at,at+Vector2(160,0),at+Vector2(160,110),at+Vector2(0,110)])
            background.color = Color(.08,.12,.14) if variant == 0 else Color(.89,.87,.8)
            stage.add_child(background)
        var label := Label.new()
        label.text = ART.FAMILIES[index]+"  %dpx" % (RADII[index]*2)
        label.position = corner+Vector2(6,8)
        label.add_theme_font_size_override("font_size",14)
        stage.add_child(label)
    var pools: Array[Node2D] = []
    for index in range(8):
        for variant in range(2):
            var node: Node2D = enemy._effect("pool",point(index,variant),Vector2.ZERO,{"skin":ART.FAMILIES[index],"radius":RADII[index]},1,2)
            node.set_physics_process(false)
            pools.append(node)
    for frame in range(7):
        phase.text = "WARNING: no damage" if frame < 3 else "ACTIVE: original circular collision and lifetime"
        for node in pools:
            node.age = .2 if frame == 0 else (.801+(frame-1)*.1 if frame < 3 else 1+(frame-3)/ART.ACTIVE_FPS+.001)
            node.queue_redraw()
        await capture("phase_%d" % frame)
    for node in pools: node.cancel()
    await process_frame
    phase.text = "EXPIRED: no damage"
    await capture("empty")
    # Four families x two backgrounds leaves room under the real 12-mark cap.
    for page in range(2):
        var marks: Array[Node2D] = []
        for index in range(page*4,page*4+4):
            for variant in range(2):
                var node := ART.spawn_fade(stage,point(index,variant),ART.FAMILIES[index],RADII[index],Color.html("#c99558"))
                if node == null:
                    push_error("Gallery exceeded decoration budget")
                    quit(1)
                    return
                node.set_process(false)
                marks.append(node)
        for frame in range(2):
            for node in marks:
                node.age = frame/ART.FADE_FPS+.001
                node.queue_redraw()
            await capture("fade_%d_%d" % [page,frame])
        for node in marks: node.queue_free()
        await process_frame
    view.queue_free()
    await process_frame
    await process_frame
    print("GROUND_HAZARD_GALLERY families=8 frames=64 gameplay_scale=true real_gl=true")
    quit(0)
