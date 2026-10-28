extends SceneTree
const SURFACE=preload("res://scripts/danger_caption_surface.gd")
const GROUPS=preload("res://scripts/danger_caption_groups.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var host:=Control.new();root.add_child(host)
    var view:=SURFACE.new();var first:=view.install(host)
    view.apply({"subtitle_size":21,"danger_caption_contrast":true})
    var style:=view.style
    for unused in 100:view.apply({"subtitle_size":21,"danger_caption_contrast":true})
    check(style==view.style,"steady frames retain one style")
    check(view.install(host).panel==first.panel and host.get_child_count()==1,"same host install idempotent")
    view.apply({"subtitle_size":26,"danger_caption_contrast":false})
    check(view.style==style and is_equal_approx(style.bg_color.a,.72),"contrast mutates cached style")
    check(view.labels[0].get_theme_font_size("font_size")==26,"font updates actual label")
    GROUPS.render(view.labels,[{"text":"danger","count":1,"unblockable":true}],26)
    view.panel.show();view.hide()
    check(not view.panel.visible and view.labels[0].text.is_empty(),"disabled display clears stale tell")
    var other:=Control.new();root.add_child(other);view.install(other)
    check(host.get_child_count()==0 and other.get_child_count()==1,"new host retires previous panel")
    other.free();view.clear();check(view.panel==null and view.labels.is_empty(),"freed UI safe cleanup")
    host.free();await process_frame
    print("RELIABILITY_R08 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
