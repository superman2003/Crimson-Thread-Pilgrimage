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
const BUILD=preload("res://scripts/build_system.gd")
const UI=preload("res://scripts/resupply_planner.gd")
var purchases:=0
func run() -> void:
    root.gui_embed_subwindows=true;root.size=Vector2i(1280,720)
    var build:=BUILD.new()
    for event in ["tool_mine_found","tool_fog_found","tool_lure_found"]:build.unlock_event(event)
    for id in build.state.tool_counts:build.state.tool_counts[id]=0
    var money:={"currency":5,"inventory_counts":{"moss_chitin":10,"wet_chitin":10,"salt_crystal_shard":10,"pollen_wax":10}}
    var before: Dictionary=build.serialize()
    var ui:=UI.new();root.add_child(ui)
    ui.open(build.get_snapshot().tools,func(plan):return build.quote_resupply(money,plan),func(_plan):purchases+=1;return {"ok":false},func(id):return id)
    ui.apply_preset("one")
    for value in ui.quantities.values():check(value==1,"one preset requests exactly one per owned tool")
    check(ui.selection_summary.text.contains("申请 4") and ui.detail.text.contains("部分补给"),"partial affordability is visible")
    ui.apply_preset("half")
    for row in ui.rows:check(ui.quantities[row.id]==ceili(int(row.capacity)*0.5),"half preset respects carry capacity")
    ui.apply_preset("none");ui._confirm_purchase()
    check(not ui.has_selection() and ui.get_ok_button().disabled and purchases==0,"cleared list never invokes legacy full refill")
    ui.apply_preset("full")
    check(build.serialize()==before and money.currency==5 and purchases==0,"presets and quotes are read-only")
    await process_frame;await process_frame
    check(ui.size.y<=600 and ui.body.position.y+ui.body.size.y<=ui.size.y-50,"quote and purchase controls fit in viewport")
    check(ui.row_scroll is ScrollContainer and ui.detail.scroll_active,"long lists and quotes have independent scrolling")
    await photograph()
    ui.free();await process_frame;finish()
