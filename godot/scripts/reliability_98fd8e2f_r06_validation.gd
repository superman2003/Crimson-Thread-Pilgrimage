extends SceneTree
const READER=preload("res://scripts/dialogue_reader.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var panel:=READER.new();root.add_child(panel)
    var scroll:=ScrollContainer.new();scroll.size=Vector2(400,200);root.add_child(scroll)
    var body:=Label.new();body.text="Reading test";body.visible_characters=3;scroll.add_child(body)
    var calls: Array=[0]
    panel.configure(body,scroll,func():calls[0]+=1;body.visible_characters=-1)
    check(panel.get_child_count()==4,"reader creates one control set")
    var button:=panel.reveal_button
    panel.configure(body,scroll,func():calls[0]+=1;body.visible_characters=-1)
    check(panel.get_child_count()==4 and panel.reveal_button==button,"reconfigure reuses controls")
    panel.reveal_button.pressed.emit()
    check(calls[0]==1 and body.visible_characters==-1,"one reveal callback after reconfigure")
    check(panel.reveal_button.disabled,"reveal disabled for complete text")
    var second:=Label.new();second.text="Second reading";second.visible_characters=0;scroll.add_child(second)
    panel.configure(second,scroll,Callable())
    check(panel.reveal_button.disabled,"invalid reveal callable disabled")
    var bar:=scroll.get_v_scroll_bar();bar.max_value=1000;bar.page=100
    panel.turn(1)
    check(scroll.scroll_vertical==80,"page step uses visible page")
    panel.turn(-1);check(scroll.scroll_vertical==0,"back clamps at start")
    for unused in 20:panel.turn(1)
    check(scroll.scroll_vertical<=900,"forward clamps at end")
    second.queue_free();panel.refresh()
    check(panel.reveal_button.disabled and panel.next_button.disabled,"queued body retires controls immediately")
    scroll.free();panel.refresh()
    check(panel.progress.text.contains("关闭"),"freed viewport safe")
    panel.free()
    await process_frame
    print("RELIABILITY_R06 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
