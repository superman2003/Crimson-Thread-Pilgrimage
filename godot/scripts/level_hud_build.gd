extends RefCounted
## Building the HUD and dialogue overlay in budgeted steps.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const PILGRIMAGE_UI_SCRIPT := preload("res://scripts/pilgrimage_interface.gd")

static func build_hud(level: Node) -> void:
    for job in level._hud_build_jobs():
        level.callv(job.method, job.args)
    level._check_wish_board_rewards()
    level._refresh_hud()


static func hud_build_jobs(level: Node) -> Array:
    var jobs: Array = [{"method": "_begin_hud", "args": []}]
    for method in PILGRIMAGE_UI_SCRIPT.build_steps():
        jobs.append({"method": "_build_interface_step", "args": [method]})
    jobs.append_array([
        {"method": "_build_hud_labels", "args": []},
        {"method": "_build_backpack_overlay", "args": []},
        {"method": "_build_interface_step", "args": ["begin_inventory_refresh"]}])
    var item_ids: Array[String] = ["currency"]
    for section in level.BACKPACK_SECTIONS:
        item_ids.append_array(level._inventory_ids_for_category(String(section[1])))
    for item_id in item_ids:
        jobs.append({"method": "_build_interface_step", "args": ["append_inventory_item", [item_id]]})
    jobs.append_array([
        {"method": "_build_interface_step", "args": ["finish_inventory_refresh"]},
        {"method": "_build_map_overlay", "args": []},
        {"method": "_refresh_map_overlay", "args": []},
        {"method": "_build_dialogue_overlay", "args": []},
        {"method": "_build_settings_overlay", "args": []},
        {"method": "_finish_hud", "args": []}])
    return jobs


static func begin_hud(level: Node) -> void:
    level.ui_canvas=CanvasLayer.new()
    level.add_child(level.ui_canvas)
    level.ui_shell=PILGRIMAGE_UI_SCRIPT.new()
    level.ui_canvas.add_child(level.ui_shell)
    level.ui_shell.begin_bind(level)


static func build_interface_step(level: Node, method: String, args: Array = []) -> void:
    level.ui_shell.callv(method, args)


static func build_hud_labels(level: Node) -> void:
    level.hud_label=Label.new()
    level.hud_label.visible=false
    level.ui_shell.add_child(level.hud_label)
    level.toast_label=level.ui_shell.toast
    level.lore_banner_label=Label.new()
    level.lore_banner_label.position=Vector2(325,603)
    level.lore_banner_label.size=Vector2(620,54)
    level.lore_banner_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    level.lore_banner_label.add_theme_font_size_override("font_size",17)
    level.lore_banner_label.add_theme_color_override("font_color",PILGRIMAGE_UI_SCRIPT.IVORY)
    level.lore_banner_label.visible=false
    level.ui_shell.add_child(level.lore_banner_label)
    level.win_label=Label.new()
    level.win_label.position=Vector2(350,132)
    level.win_label.size=Vector2(600,60)
    level.win_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    level.win_label.add_theme_font_size_override("font_size",30)
    level.win_label.visible=false
    level.ui_shell.add_child(level.win_label)


static func finish_hud(level: Node) -> void:
    level.ui_shell.frame(level.map_panel)
    level.ui_shell.finish_bind()
    if level.world_mode:
        var workbench = level.get_node_or_null("/root/JourneyWorkbench")
        if workbench != null:
            workbench.bind_region_ui(level)


static func build_dialogue_overlay(level: Node) -> void:
    level.dialogue_panel=level.ui_shell.dialogue
    level.dialogue_name_label=level.ui_shell.dialogue_name
    level.dialogue_meta_label=level.ui_shell.dialogue_identity
    level.dialogue_text_label=level.ui_shell.dialogue_body
    level.dialogue_hint_label=level.ui_shell.dialogue_hint
