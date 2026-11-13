extends SceneTree
const ASSIST:=preload("res://scripts/colour_assist.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func shot() -> Image:
    for index in 4:await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func gap(image: Image) -> float:
    var a:=image.get_pixel(80,90);var b:=image.get_pixel(240,90)
    return Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
func blue_gap(image: Image) -> float:
    return absf(image.get_pixel(80,90).b-image.get_pixel(240,90).b)
func run() -> void:
    root.size=Vector2i(480,180)
    # A red and a green of equal brightness: the pair red/green-weak eyes confuse.
    var swatches:=[[Color(0.80,0.25,0.20),0],[Color(0.35,0.55,0.20),160],[Color(0.20,0.30,0.85),320]]
    for entry in swatches:
        var rect:=ColorRect.new();rect.color=entry[0];rect.position=Vector2(entry[1],0);rect.size=Vector2(160,180);root.add_child(rect)
    var plain: Image=await shot()
    check(plain.get_pixel(80,90).is_equal_approx(Color(0.80,0.25,0.20)) or absf(plain.get_pixel(80,90).r-0.80)<0.02,"fixture renders its swatches")
    check(root.get_node_or_null("ColourAssist")==null,"nothing in the tree while off")
    ASSIST.apply(root,"off")
    check(root.get_node_or_null("ColourAssist")==null,"off creates nothing")
    var before:=blue_gap(plain)
    for mode in ["protan","deutan"]:
        ASSIST.apply(root,mode)
        var filtered: Image=await shot()
        check(root.get_node_or_null("ColourAssist")!=null,mode+" adds the filter")
        check(blue_gap(filtered)>before+0.10,"%s separates red from green in the blue channel (%.3f -> %.3f)" % [mode,before,blue_gap(filtered)])
        check(gap(filtered)>=gap(plain)*0.9,mode+" does not flatten the pair")
    check(root.get_node("ColourAssist").get_child_count()==1,"switching modes reuses one filter")
    ASSIST.apply(root,"sepia")
    await process_frame
    check(root.get_node_or_null("ColourAssist")==null,"an unknown mode turns the filter off")
    ASSIST.apply(root,"deutan")
    ASSIST.apply(root,"off")
    var restored: Image=await shot()
    check(root.get_node_or_null("ColourAssist")==null,"off removes the filter")
    var same:=true
    for x in [80,240,400]:
        if not restored.get_pixel(x,90).is_equal_approx(plain.get_pixel(x,90)):same=false
    check(same,"off restores the original picture exactly")
    print("COLOUR_ASSIST checks=%d failures=%d" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
