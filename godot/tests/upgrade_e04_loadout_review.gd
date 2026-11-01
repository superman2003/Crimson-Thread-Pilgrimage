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
const UI=preload("res://scripts/loadout_manager.gd")
var calls:=0
func run() -> void:
    root.gui_embed_subwindows=true;root.size=Vector2i(1280,720)
    var build:=BUILD.new();build.save_loadout("原方案")
    var before: Dictionary=build.serialize()
    var ui:=UI.new();root.add_child(ui)
    ui.open("原方案",func(name,copy):return build.preview_loadout_management("原方案",name,copy),func(name,copy):calls+=1;return build.copy_loadout("原方案",name) if copy else build.rename_loadout("原方案",name))
    check(ui.source_detail.text.contains("保存的契印") and ui.source_detail.text.contains("战具"),"initial unchanged name still previews saved slots")
    check(build.serialize()==before and calls==0,"opening preview never changes saved builds")
    ui.target_input.text="  新方案  ";ui._refresh_quote();ui.choose_copy_mode(true)
    check(ui.destination_detail.text.contains("「新方案」") and ui.destination_detail.text.contains("新增副本"),"review shows normalized destination and copy semantics")
    await process_frame
    await photograph()
    ui.target_input.text_submitted.emit(ui.target_input.text)
    check(calls==1 and build.state.loadouts.has("新方案") and build.state.loadouts.has("原方案"),"explicit Enter copies the saved build")
    ui._confirm_action()
    check(calls==1,"hidden dialog cannot replay submission")
    ui.open("原方案",func(name,copy):return build.preview_loadout_management("原方案",name,copy),func(_name,_copy):return {"ok":false,"reason":"写入失败"})
    ui.target_input.text="失败方案";ui._refresh_quote();ui._confirm_action()
    check(ui.visible and ui.error_label.text=="写入失败" and not ui.pending,"failed writer preserves review and permits retry")
    ui.free();await process_frame;finish()
