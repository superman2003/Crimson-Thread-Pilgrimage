extends SceneTree
## Freeze production effects at each phase; inspect real scale and both directions.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/terrain_attack_art.gd")
const RADII := [11,23,16,26,22]
var view: SubViewport
var stage: Node2D
var enemy: Node2D
var phase: Label
var output := ""
func _initialize() -> void: call_deferred("run")
func point(index: int,variant: int) -> Vector2:
    return Vector2(index*192+(52 if variant%2==0 else 140),(162 if variant < 2 else 312)-(18 if index < 3 else 5))
func capture(filename: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    if view.get_texture().get_image().save_webp(output.path_join(filename+".webp"),true,.95) != OK:
        push_error("Cannot save terrain gallery")
        quit(1)
func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real GL required")
        quit(1)
        return
    output=OS.get_environment("TERRAIN_ATTACK_GALLERY_DIR")
    if output.is_empty():output="/tmp/terrain-gallery"
    DirAccess.make_dir_recursive_absolute(output)
    view=SubViewport.new();view.size=Vector2i(960,350);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    stage=Node2D.new();view.add_child(stage)
    enemy=ENEMY.new();enemy.position=Vector2(-10000,-10000);stage.add_child(enemy);enemy.set_physics_process(false)
    phase=Label.new();phase.position=Vector2(8,331);phase.add_theme_font_size_override("font_size",13);stage.add_child(phase)
    for index in range(5):
        for band in range(2):
            var at := Vector2(index*192,30+band*150)
            var background := Polygon2D.new()
            background.polygon=PackedVector2Array([at,at+Vector2(192,0),at+Vector2(192,150),at+Vector2(0,150)])
            background.color=Color(.08,.12,.14) if band==0 else Color(.89,.87,.8);stage.add_child(background)
        var label:=Label.new();label.text=ART.FAMILIES[index]+"  %dpx" % (RADII[index]*2);label.position=Vector2(index*192+6,7);label.add_theme_font_size_override("font_size",14);stage.add_child(label)
    var nodes:Array[Node2D]=[]
    for index in range(5):
        for variant in range(4):
            var kind := "wave" if index < 3 else "eruption"
            var node:Node2D=enemy._effect(kind,point(index,variant),Vector2((-1 if variant%2==0 else 1)*200,0),{"skin":ART.FAMILIES[index],"radius":RADII[index]},0 if index < 3 else 1,3)
            node.set_physics_process(false);nodes.append(node)
    for slot in range(6):
        phase.text="WAVE: active rise / ERUPTION: warning, no damage" if slot < 2 else "ACTIVE: original circle / rectangle collision remains in force"
        for i in range(nodes.size()):
            var wave := i/4 < 3
            nodes[i].age=slot/ART.FPS+.001 if wave else (.801+slot*.1 if slot < 2 else 1+(slot-2)%2/ART.FPS+.001)
            nodes[i].queue_redraw()
        await capture("phase_%d" % slot)
    for node in nodes:node.cancel()
    await process_frame
    phase.text="EXPIRED: no damage, decorative fade / retract only"
    await capture("empty")
    for page in range(2):
        var marks:Array[Node2D]=[]
        for index in range(page*3,mini(5,page*3+3)):
            for variant in range(4):
                var mark:=ART.spawn_fade(stage,point(index,variant),ART.FAMILIES[index],RADII[index],-1 if variant%2==0 else 1,Color.html("#c99558"))
                if mark==null:
                    push_error("Gallery exceeded real decoration cap")
                    quit(1)
                    return
                mark.set_process(false);marks.append(mark)
        for frame in range(2):
            for mark in marks:mark.age=frame/ART.FPS+.001;mark.queue_redraw()
            await capture("fade_%d_%d" % [page,frame])
        for mark in marks:mark.queue_free()
        await process_frame
    view.queue_free();await process_frame;await process_frame
    print("TERRAIN_ATTACK_GALLERY families=5 frames=36 gameplay_scale=true directions=2 backgrounds=2 real_gl=true")
    quit(0)
