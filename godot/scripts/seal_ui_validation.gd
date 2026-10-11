extends SceneTree
## Real Control button emissions with the persistent loadout model, independent of
## story acquisition (covered by narrative integration). Optional rendered proof:
## --seal-ui-evidence=/absolute/output/directory using a graphical Godot display.
const FIXTURE = preload("res://scripts/ui_build_accessibility_validation.gd")
const UI = preload("res://scripts/pilgrimage_interface.gd")
const BUILD = preload("res://scripts/build_system.gd")
var failures := 0
var checks := 0
var evidence_dir := ""
func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--seal-ui-evidence="):evidence_dir=argument.trim_prefix("--seal-ui-evidence=")
    call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if not value:failures+=1;push_error(message)
func click_id(ui: Control,id: String) -> bool:
    for child in ui.build_grid.get_children():
        if child is Button and String(child.get_meta("build_id",""))==id:child.pressed.emit();return true
    return false
func run() -> void:
    root.size=Vector2i(1280,720)
    var runtime:=FIXTURE.MockRuntime.new()
    root.add_child(runtime)
    runtime.player=FIXTURE.MockPlayer.new()
    runtime.add_child(runtime.player)
    runtime.build_system=BUILD.new()
    var model: RefCounted=runtime.build_system
    # UI fixture models an endgame inventory; no gameplay unlock path is bypassed
    # in runtime. This allows validating every locked/unlocked page deliberately.
    model.state.unlocked_crests=model.catalog.crests.keys()
    model.state.unlocked_skills=model.catalog.skills.keys()
    model.state.unlocked_tools=model.catalog.tools.keys()
    model.state.unlocked_passives=model.catalog.passives.keys()
    var ui:=UI.new()
    ui.accessibility_path="user://seal_ui_validation.cfg"
    runtime.add_child(ui)
    ui.bind(runtime)
    ui.set_process(false)
    ui.build_panel.visible=true
    check(ui.build_tabs.map(func(tab: Button):return tab.text)==["契印","技能","战具","铭饰","强化","构筑"],"Six visible tabs use the approved system vocabulary")
    ui.build_category="技能"
    ui.refresh_build()
    check(ui.build_grid.get_child_count()==6,"All six tactical skills have real button entries")
    ui.build_slot_buttons[1].pressed.emit()
    check(click_id(ui,"needle"),"Second skill can be selected by actual button")
    check(runtime.last_slot==1 and model.state.skills[1]=="needle","Equipment location2 routes through model to second permanent slot")
    ui.build_slot_buttons[0].pressed.emit()
    click_id(ui,"shockwave")
    check(model.state.skills[0]=="shockwave" and model.state.skills[1]=="needle","Selecting slot1 preserves slot2")
    check(ui.build_detail.text.contains("动作风险") and ui.build_detail.text.contains("契印协同"),"Skill detail exposes risk and seal collaboration")
    ui.build_category="战具"
    ui.refresh_build()
    check(ui.build_grid.get_child_count()==4,"Four finite-use tools have actual UI entries")
    ui.build_slot_buttons[1].pressed.emit()
    click_id(ui,"fog")
    check(model.state.tools[1]=="fog","Second tool slot stores selected tool")
    check(ui.build_detail.text.contains("免费补满") and ui.build_detail.text.contains("不会补充"),"Refill rules distinguish shrine rest from loadout switching")
    ui.build_category="契印"
    ui.refresh_build()
    check(not ui.build_slot_buttons[0].visible,"Single seal page hides two-slot selector")
    check(ui.build_detail.text.contains("来源") and ui.build_detail.text.contains("专属机制") and ui.build_detail.text.contains("治疗完成"),"Seal page shows source, unique mechanism, and healing effect")
    check(ui.build_detail.text.contains("专属机制尚未修复"),"Initial seal presents its mechanism as locked while retaining basic combat")
    ui.build_category="铭饰"
    ui.refresh_build()
    check(ui.build_grid.get_child_count()==6,"Six capacity-consuming ornaments exist")
    model.state.passives=["reflux","shell"]
    ui._show_build_detail(model.catalog.passives.needlecase)
    check(ui.build_detail.text.contains("容量不足"),"Capacity failure uses explicit text in addition to a visual marker")
    ui.build_category="构筑"
    ui.refresh_build()
    check(ui.build_detail.text.contains("当前整体配置") and ui.build_detail.text.contains("钟鸣震波") and ui.build_detail.text.contains("盐雾瓶"),"Build page previews both tactical slots and passive composition")
    model.cooldowns["shockwave"]=1.7
    runtime.active_overlay=""
    ui._refresh_combat_status(runtime.player)
    check(ui.combat_status.text.contains("1.7s") and ui.combat_status.text.contains("回声针"),"HUD shows independently equipped skills and actual cooldown")
    check(ui.combat_status.text.contains("线势") and ui.combat_status.text.contains("2 / 3"),"HUD reads seal mechanism from the live player interface")
    check(ui.combat_status.text.contains("盐雾瓶"),"HUD shows both finite-use tool slots")
    ui.accessibility.subtitle_size=26
    ui._apply_accessibility()
    check(ui.build_detail.get_theme_font_size("normal_font_size")==26 and ui.build_detail.scroll_active,"Large-font details remain scrollable")
    check(ui.REMAPPABLE_ACTIONS.has("skill_cycle") and ui.REMAPPABLE_ACTIONS.has("tool_cycle") and ui.REMAPPABLE_ACTIONS.has("tool_cast"),"Keyboard and controller capture exposes all tactical selection actions")
    ui.settings.visible=true
    ui._begin_remap("skill_cycle")
    var trigger:=InputEventJoypadMotion.new()
    trigger.axis=JOY_AXIS_TRIGGER_LEFT
    trigger.axis_value=0.9
    ui._input(trigger)
    check(ui.remap_target.is_empty() and InputMap.event_is_action(trigger,"skill_cycle"),"L2 trigger capture changes actual cycle action")
    check(ui.remap_buttons.skill_cycle.text.contains("L2"),"Trigger bindings have readable controller names")
    var restored:=UI.new()
    restored.accessibility_path=ui.accessibility_path
    InputMap.action_erase_events("skill_cycle")
    restored._load_accessibility()
    check(InputMap.event_is_action(trigger,"skill_cycle"),"Controller trigger bindings persist on reload")
    restored.free()
    ui.settings.visible=false
    if not evidence_dir.is_empty() and DisplayServer.get_name()!="headless":
        DirAccess.make_dir_recursive_absolute(evidence_dir)
        runtime.active_overlay="build"
        ui.build_panel.visible=true
        for category in ["契印","技能","战具","铭饰","强化","构筑"]:
            ui.build_category=category
            ui.refresh_build()
            await process_frame
            await RenderingServer.frame_post_draw
            var result:=root.get_texture().get_image().save_png(evidence_dir.path_join("seal_ui_%d.png" % [ui.build_tabs.map(func(tab: Button):return tab.text).find(category)]))
            check(result==OK,"Rendered large-font %s evidence saved" % category)
    runtime.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://seal_ui_validation.cfg"))
    await process_frame
    print("SEAL_UI_VALIDATION_%s checks=%d failures=%d" % ["PASS" if failures==0 else "FAIL",checks,failures])
    quit(1 if failures else 0)
