extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    var scroll:=ScrollContainer.new();scroll.size=Vector2(300,100);root.add_child(scroll)
    var column:=VBoxContainer.new();scroll.add_child(column)
    var buttons: Array[Button]=[]
    for index in 12:
        var button:=preload("res://scripts/pilgrimage_button.gd").new();button.text="选择 %d"%index;button.custom_minimum_size=Vector2(260,40);column.add_child(button);buttons.append(button)
    await process_frame;await process_frame
    buttons[-1].grab_focus();await process_frame;await process_frame
    check(scroll.scroll_vertical>0,"keyboard focus scrolls last menu option into view")
    buttons[0].grab_focus();await process_frame;await process_frame
    check(scroll.scroll_vertical==0,"returning to first option reveals top")
    var compact:=preload("res://scripts/pilgrimage_button.gd").new();compact.clip_text=true;compact.size=Vector2(60,40);compact.text="完整保留的长按钮文字";root.add_child(compact)
    compact._refresh_overflow_hint()
    check(compact.tooltip_text==compact.text,"clipped label has full tooltip")
    compact.tooltip_text="专门的操作说明";compact._refresh_overflow_hint()
    check(compact.tooltip_text=="专门的操作说明","custom tooltips preserved")
    compact.grab_focus();compact.hide();compact._reveal_focus()
    check(not compact._reveal_pending,"hidden deferred focus ends safely")
    compact.queue_free();scroll.queue_free();await process_frame
    print("UPGRADE_G08 checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
