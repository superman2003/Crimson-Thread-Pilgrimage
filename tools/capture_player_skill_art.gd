extends SceneTree
## Native-sized production skill fixtures; phase times are sampled independently.
const ART:=preload("res://scripts/player_skill_art.gd")
const EFFECT:=preload("res://scripts/player_tool_effect.gd")
var view:SubViewport
var stage:Node2D
var phase:Label
var output:=""
func _initialize()->void:call_deferred("run")
func point(index:int,variant:int)->Vector2:return Vector2(index*256+(64 if variant%2==0 else 192),(200 if variant<2 else 410)-(6 if index==2 else 42))
func capture(filename:String)->void:
    await process_frame;await RenderingServer.frame_post_draw
    if view.get_texture().get_image().save_webp(output.path_join(filename+".webp"),true,.95)!=OK:push_error("Cannot save player skill gallery");quit(1)
func run()->void:
    if DisplayServer.get_name()=="headless":push_error("Real GL required");quit(1);return
    output=OS.get_environment("PLAYER_SKILL_GALLERY_DIR")
    if output.is_empty():output="/tmp/player-skill-gallery"
    DirAccess.make_dir_recursive_absolute(output)
    view=SubViewport.new();view.size=Vector2i(768,490);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    stage=Node2D.new();view.add_child(stage);var owner_node:=CharacterBody2D.new();stage.add_child(owner_node)
    phase=Label.new();phase.position=Vector2(8,466);phase.add_theme_font_size_override("font_size",13);stage.add_child(phase)
    for index in range(3):
        for band in range(2):
            var at:=Vector2(index*256,40+band*210);var background:=Polygon2D.new();background.polygon=PackedVector2Array([at,at+Vector2(256,0),at+Vector2(256,210),at+Vector2(0,210)]);background.color=Color(.08,.12,.14) if band==0 else Color(.89,.87,.8);stage.add_child(background)
        var label:=Label.new();label.position=Vector2(index*256+8,9);label.text=ART.FAMILIES[index]+"  %dpx" % ART.WIDTHS[ART.FAMILIES[index]];label.add_theme_font_size_override("font_size",16);stage.add_child(label)
    var nodes:Array[Node2D]=[];var marks:Array[Node2D]=[]
    for index in range(3):
        for variant in range(4):
            var node:=EFFECT.new();node.payload={"kind":["projectile","wave","snare_field"][index],"skill_effect":true,"duration":5,"range":10000};node.owner_player=owner_node;node.direction=-1 if variant%2==0 else 1;node.position=point(index,variant);stage.add_child(node);node.set_physics_process(false);nodes.append(node)
    for frame in range(8):
        phase.text="NEEDLE: flight / WAVE + SNARE: active" if frame<4 else ("NEEDLE: safe impact / WAVE + SNARE: active" if frame<6 else "ALL TERMINAL SPRITES: no damage or control")
        for index in range(3):
            for variant in range(4):
                var node:Node2D=nodes[index*4+variant]
                var first:=4 if index==0 else 6
                if frame<first:
                    node.elapsed=frame/(14.0 if index==0 else 24.0 if index==1 else 12.0)+.001;node.queue_redraw()
                elif frame==first:
                    node.hide()
                    var mark:=ART.spawn_terminal(stage,point(index,variant),ART.FAMILIES[index],node.direction,"hit" if index==0 else "expiry")
                    if mark==null:push_error("Gallery exceeded production budget");quit(1);return
                    mark.set_process(false);marks.append(mark)
        for mark in marks:
            mark.age=(frame-(4 if mark.family=="needle" else 6))/(20.0 if mark.family=="needle" else 12.0)+.001;mark.queue_redraw()
        await capture("phase_%d" % frame)
    for node in nodes:node.queue_free()
    for mark in marks:mark.queue_free()
    await process_frame;phase.text="RETIRED: no active effect";await capture("empty")
    view.queue_free();await process_frame;await process_frame
    print("PLAYER_SKILL_GALLERY families=3 frames=24 native_scale=true directions=2 backgrounds=2 real_gl=true")
    quit(0)
