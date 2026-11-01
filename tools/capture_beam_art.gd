extends SceneTree
## Real-GL production beam objects, native widths/ranges and both directions.
const ENEMY:=preload("res://scripts/enemy_actor.gd")
const ART:=preload("res://scripts/beam_art.gd")
const LENGTHS:=[455,720,300,650]
const RADII:=[18,18,13,15]
const WARNINGS:=[1.1,1.15,.9,1.0]
const LIFETIMES:=[.36,.42,.4,.42]
var view:SubViewport
var stage:Node2D
var enemy:Node2D
var phase:Label
var output:=""
func _initialize()->void:call_deferred("run")
func capture(filename:String)->void:
    await process_frame;await RenderingServer.frame_post_draw
    if view.get_texture().get_image().save_webp(output.path_join(filename+".webp"),true,.95)!=OK:
        push_error("Cannot save beam gallery");quit(1)
func run()->void:
    if DisplayServer.get_name()=="headless":push_error("Real GL required");quit(1);return
    output=OS.get_environment("BEAM_GALLERY_DIR")
    if output.is_empty():output="/tmp/beam-gallery"
    DirAccess.make_dir_recursive_absolute(output)
    view=SubViewport.new();view.size=Vector2i(1000,984);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    stage=Node2D.new();view.add_child(stage)
    enemy=ENEMY.new();enemy.position=Vector2(-10000,-10000);stage.add_child(enemy);enemy.set_physics_process(false)
    phase=Label.new();phase.position=Vector2(8,962);phase.add_theme_font_size_override("font_size",14);stage.add_child(phase)
    var beams:Array[Node2D]=[]
    for index in range(4):
        var base:=index*240
        for light in range(2):
            var at:=Vector2(0,base+28+light*106)
            var background:=Polygon2D.new();background.polygon=PackedVector2Array([at,at+Vector2(1000,0),at+Vector2(1000,106),at+Vector2(0,106)]);background.color=Color(.08,.12,.14) if light==0 else Color(.89,.87,.8);stage.add_child(background)
            var direction:=1 if light==0 else -1
            var radius:int=RADII[index];var length:int=LENGTHS[index]
            var warning:float=WARNINGS[index];var lifetime:float=LIFETIMES[index]
            if index==2 and light==1:radius=17;length=160;warning=.65;lifetime=.38
            var node:Node2D=enemy._effect("beam",Vector2(90 if light==0 else 910,base+81+light*106),Vector2(direction,0),{"skin":ART.FAMILIES[index],"radius":radius,"beam_length":length},warning,lifetime)
            node.set_physics_process(false);beams.append(node)
        var title:=Label.new();title.text=ART.FAMILIES[index]+"  %dpx thick / %dpx long" % [RADII[index]*2,LENGTHS[index]]
        if index==2:title.text+="   reverse: 34px / 160px"
        title.position=Vector2(8,base+3);title.add_theme_font_size_override("font_size",14);stage.add_child(title)
    for slot in range(5):
        phase.text="WARNING: no damage" if slot<2 else ("ACTIVE: full channel remains dangerous" if slot<4 else "ACTIVE: last millisecond, full range still shown")
        for node in beams:
            node.age=node.arm_delay*.3+slot*.15 if slot<2 else (node.arm_delay+(slot-2)/ART.FPS+.001 if slot<4 else node.duration-.001)
            node.queue_redraw()
        await capture("phase_%d" % slot)
    for node in beams:node.cancel()
    await process_frame;phase.text="EXPIRED: no beam, no damage";await capture("empty")
    # Tiny wall clips must stay inside their assigned geometry.
    for index in range(4):
        for variant in range(3):
            var length:float=[95,7,0][variant]
            var node:Node2D=enemy._effect("beam",Vector2(120+variant*280,index*240+81),Vector2.RIGHT,{"skin":ART.FAMILIES[index],"radius":RADII[index],"beam_length":length},0,1)
            node.set_physics_process(false);node.age=.01
            var label:=Label.new();label.position=Vector2(110+variant*280,index*240+110);label.text="clip %dpx" % length;label.add_theme_font_size_override("font_size",14);stage.add_child(label)
    phase.text="WALL CLIPS: 95px / 7px / zero-length (empty)"
    await capture("clips")
    view.queue_free();await process_frame;await process_frame
    print("BEAM_GALLERY families=4 parts=16 commands=5 native_scale=true directions=2 real_gl=true")
    quit(0)
