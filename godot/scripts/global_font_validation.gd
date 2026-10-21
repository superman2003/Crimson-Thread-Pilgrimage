extends SceneTree
var FONT: FontFile
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
    checks+=1
    if not value:
        failures+=1
        push_error(message)
func inspect_fonts(node: Node) -> void:
    var font_key := ""
    if node is Label or node is Button or node is OptionButton:font_key="font"
    elif node is RichTextLabel:font_key="normal_font"
    if not font_key.is_empty():
        var actual: Font=node.get_theme_font(font_key)
        check(actual.get_font_name()==FONT.get_font_name(),"All text shares the global font: %s uses %s" % [node.name,actual.get_font_name()])
    for child in node.get_children():inspect_fonts(child)
func run() -> void:
    FONT=load("res://assets/fonts/GlobalTypeface.otf") as FontFile
    if FONT==null:
        push_error("Apply the global font before running its validation")
        quit(1)
        return
    var plain:=Label.new()
    root.add_child(plain)
    check(plain.get_theme_font("font").get_font_name()==FONT.get_font_name(),"New controls inherit the project-wide font without manual overrides")
    plain.free()
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false
    world.world_save_path="user://global_font_validation.json"
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    inspect_fonts(world.ui_shell)
    for text in ["契印行囊旅记地图绯线巡礼","名字不会因为被抹去就从未存在","0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"]:
        for index in text.length():check(FONT.has_char(text.unicode_at(index)),"The actual font covers "+text[index])
    check(world.ui_shell.survey_font().get_font_name()==FONT.get_font_name(),"Map MSDF cache uses the same typeface")
    check(world.ui_shell.dialogue_body.get_theme_font("font").get_font_name()==FONT.get_font_name(),"Dialogue body has no old body-font exception")
    world.free()
    await process_frame
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://global_font_validation.json"+suffix))
    print("GLOBAL_FONT_VALIDATION_%s checks=%d failures=%d" % ["PASS" if failures==0 else "FAIL",checks,failures])
    quit(1 if failures else 0)
