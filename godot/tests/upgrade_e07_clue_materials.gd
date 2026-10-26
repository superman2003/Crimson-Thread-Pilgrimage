extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func finish() -> void:
    for failure in failures:push_error(failure)
    print("UPGRADE_%s checks=%d failures=%d" % [get_script().resource_path.get_file().get_basename(),checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
func photograph() -> void:
    var target:=OS.get_environment("UPGRADE_CAPTURE")
    if target.is_empty() or DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(target)
const CLUE=preload("res://scripts/hidden_route_clue.gd")
func run() -> void:
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(600,420)
    var clues: Array=[]
    var kinds: Array=[]
    for i in 6:
        var clue:=CLUE.new();clue.clue_id="fixture"+str(i)
        clue.set_meta("hidden_route",{"region_id":"ch%02d_region" % (i+1)})
        clue.position=Vector2(90+(i%3)*180,90+(i/3)*180)
        root.add_child(clue);clues.append(clue);kinds.append(clue.material_style().kind)
        check(clue.is_processing(),"unfound visible clue animates")
        clue.found=true
        check(not clue.is_processing(),"found clue becomes static")
        clue.found=false;clue.hide()
        check(not clue.is_processing(),"hidden clue sleeps")
        clue.show();check(clue.is_processing(),"visible unfound clue resumes")
        var elapsed: float=clue.elapsed;clue._process(NAN)
        check(clue.elapsed==elapsed,"nonfinite delta cannot corrupt visual")
    check(kinds==["moss","steam","paper","root","ash","thread"],"all six regions have distinct authored materials")
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        var image:=root.get_texture().get_image()
        var hashes: Dictionary={}
        for i in 6:
            var crop:=image.get_region(Rect2i(40+(i%3)*180,35+(i/3)*180,100,115))
            hashes[crop.get_data().hex_encode().sha256_text()]=true
        check(hashes.size()==6,"actual rendered clue motifs differ")
    await photograph()
    for clue in clues:clue.free()
    await process_frame;finish()
