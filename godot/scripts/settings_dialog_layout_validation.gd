extends SceneTree
const ADAPTER:=preload("res://scripts/settings_dialog_layout.gd")
const POLICY:=preload("res://scripts/journey_window_layout.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames() -> void:
    for index in 5:await process_frame
func run() -> void:
    root.content_scale_size=Vector2i(960,540);root.size=Vector2i(960,540)
    var shell:=FakeShell.new();root.add_child(shell)
    var original_listeners:=root.size_changed.get_connections().size()
    var dialog:=preload("res://scripts/controller_comfort_dialog.gd").new();shell.add_child(dialog)
    var adapter: Node=dialog.get_node("SettingsDialogLayout")
    var body: ScrollContainer=adapter.body;var column: Control=adapter.content()
    var intro:=column.get_child(0) as Label;var original_font:=intro.get_theme_font_size("font_size")
    var applied:={"count":0}
    dialog.open({},func(_values: Dictionary):applied.count+=1;return {"ok":true,"persisted":true});await frames()
    check(adapter==ADAPTER.install(dialog,column,Vector2i(720,620)),"idempotent installation keeps one body and owner")
    check(dialog.size.y<=root.get_visible_rect().size.y and dialog.size.x<=root.get_visible_rect().size.x,"actual native form fits explicit 960x540 logical viewport")
    check(dialog.position.x>=0 and dialog.position.y>=0,"window chrome positioned inside logical viewport")
    check(intro.get_theme_font_size("font_size")==POLICY.scaled_font(original_font,26),"body font follows live installation reading preference")
    check(body.follow_focus and body.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO,"long and wide controls remain scrollable")
    check(not body.is_ancestor_of(dialog.get_cancel_button()) and not body.is_ancestor_of(dialog.get_ok_button()),"native confirm/cancel remain outside scrolling body")
    var initial:=dialog.candidate.duplicate(true)
    var spacer:=Control.new();spacer.custom_minimum_size=Vector2(700,900);column.add_child(spacer)
    var tail:=Button.new();tail.text="Dynamic reachable action";column.add_child(tail);await frames()
    var tail_base: int=tail.get_meta("journey_layout_original_font_size")
    check(tail.get_theme_font_size("font_size")==POLICY.scaled_font(tail_base,26),"dynamic form controls receive non-compounding typography")
    tail.grab_focus();await frames()
    check(body.scroll_vertical>0,"native keyboard focus scrolls to deep form action")
    check(body.get_global_rect().intersects(tail.get_global_rect()),"focused deep control intersects actual scroll viewport")
    shell.font_size=17;adapter.request();await frames()
    check(intro.get_theme_font_size("font_size")==POLICY.scaled_font(original_font,17),"decreasing reading size returns from authored base")
    shell.font_size=26;adapter.request();await frames()
    check(intro.get_theme_font_size("font_size")==POLICY.scaled_font(original_font,26),"roundtrip reading size does not compound")
    var stable_applications: int=adapter.applications
    adapter._process(1.0);await frames()
    check(adapter.applications==stable_applications,"unchanged visible context does not rebuild fonts or layout")
    root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await frames()
    check(dialog.size.y>468 and dialog.size.y<=720,"viewport growth restores preferred form height")
    check(body.get_global_rect().intersects(tail.get_global_rect()),"resize keeps currently focused deep action reachable")
    root.content_scale_size=Vector2i(960,540);root.size=Vector2i(960,540);await frames()
    check(dialog.size.y<=540 and dialog.position.y+dialog.size.y<=540,"viewport shrink keeps full native chrome inside view")
    check(dialog.candidate==initial and applied.count==0,"all layout changes leave staged preference and callback untouched")
    dialog.hide();await frames();var hidden_applications: int=adapter.applications
    shell.font_size=17;adapter._process(1.0);await frames()
    check(adapter.applications==hidden_applications,"hidden forms do not rebuild for reading changes")
    dialog.open({},func(_values: Dictionary):applied.count+=1;return {"ok":true});await frames()
    check(intro.get_theme_font_size("font_size")==POLICY.scaled_font(original_font,17),"reopening resolves latest reading preference")
    dialog.queue_free();await frames()
    check(root.size_changed.get_connections().size()==original_listeners,"retiring owner disconnects external viewport listener")
    for index in 12:
        var cycle:=preload("res://scripts/controller_comfort_dialog.gd").new();shell.add_child(cycle)
        cycle.open({},func(_values: Dictionary):return {"ok":true});await process_frame
        cycle.queue_free();await process_frame
    check(root.size_changed.get_connections().size()==original_listeners,"repeated actual forms do not accumulate external callbacks")
    shell.queue_free();await frames()
    print("SETTINGS_DIALOG_LAYOUT checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
class FakeShell extends Control:
    var font_size:=26
    func get_accessibility(key: String,fallback: Variant=null) -> Variant:return font_size if key=="subtitle_size" else fallback
