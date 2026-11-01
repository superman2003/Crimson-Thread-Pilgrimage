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
const MODEL=preload("res://scripts/map_directory.gd")
const UI=preload("res://scripts/map_directory_dialog.gd")
func run() -> void:
    root.gui_embed_subwindows=true
    root.size=Vector2i(1280,720)
    var rows: Array=[]
    for i in range(80,0,-1):rows.append({"key":"room"+str(i),"kind":"room","region":"known","region_name":"已补绘区域","title":"房间"+str(i),"detail":"公开地点"})
    var sorted: Array=MODEL.arrange(rows,3)
    check(sorted[0].title=="房间1" and sorted[1].title=="房间2" and sorted[-1].title=="房间80","names use natural numeric order")
    check(rows[0].title=="房间80","sorting never mutates source")
    check(MODEL.counts(rows).room==80,"facets count public input")
    var ui:=UI.new();root.add_child(ui);ui.open(rows,func(_row):return {"ok":false})
    ui.list.select(77);ui._selection()
    var identity: String=ui.visible_rows[77].key
    ui.sort_order.select(3);ui._refresh()
    check(ui.visible_rows[ui.list.get_selected_items()[0]].key==identity,"sorting preserves selected identity")
    ui.step_selection(-1)
    check(ui.cursor.text=="2 / 80","navigation updates position")
    var event:=InputEventKey.new();event.pressed=true;event.keycode=KEY_END;ui._list_input(event)
    check(ui.next_button.disabled and ui.cursor.text=="80 / 80","End reaches bounded final row")
    event.keycode=KEY_HOME;ui._list_input(event)
    check(ui.previous_button.disabled and not ui.next_button.disabled,"Home restores first row")
    ui.search.text="不存在";ui._refresh()
    check(ui.list.item_count==0 and ui.locate_button.disabled and ui.next_button.disabled,"empty results cannot locate")
    ui.search.clear();ui._refresh()
    await process_frame
    await photograph()
    ui.free();await process_frame;finish()
