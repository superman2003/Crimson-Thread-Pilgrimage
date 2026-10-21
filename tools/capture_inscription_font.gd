extends SceneTree
## Real font rendering with OS font fallback disabled; no gameplay save access.
const FONT := preload("res://assets/fonts/GlobalTypeface.otf")
const FOLIO := preload("res://assets/ui/inscription/v2/folio.png")
const ROWS := [
    ["全局文字", "菜单、正文、对话、地图与数字统一使用同一字库。"],
    ["网页补全", "创　墟　迥　旌　沫　笛"],
    ["简体 / 繁體", "龙龍　马馬　门門　云雲　凤鳳　铃鈴"],
    ["生僻字", "龘　靐　齉　麤　爨　灪　籲　鸞"],
    ["界面符号", "↩　⊣　🔒　0123456789　74 / 100"]
]
var destination := ""
func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="):destination=argument.trim_prefix("--capture-output=")
    call_deferred("capture")
func label(parent: Node, text: String, point: Vector2, font_size: int, color: Color) -> void:
    var node := Label.new()
    node.text=text
    node.position=point
    node.add_theme_font_override("font",FONT)
    node.add_theme_font_size_override("font_size",font_size)
    node.add_theme_color_override("font_color",color)
    parent.add_child(node)
func capture() -> void:
    if destination.is_empty() or FONT.allow_system_fallback:
        push_error("Specify a capture path and disable OS font fallback")
        quit(1)
        return
    root.size=Vector2i(1280,720)
    var background := TextureRect.new()
    background.texture=FOLIO
    background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    background.size=Vector2(1280,720)
    root.add_child(background)
    label(background,"完整字库 · 缝名刻宋",Vector2(66,42),38,Color("e8d7b8"))
    label(background,"44,780 字符　/　完整上游字符集 + 项目符号　/　系统字体后备关闭",Vector2(68,108),21,Color("bca07a"))
    for index in ROWS.size():
        label(background,ROWS[index][0],Vector2(70,180+index*86),21,Color("bca07a"))
        label(background,ROWS[index][1],Vector2(258,175+index*86),30,Color("e8d7b8"))
        for character in ROWS[index][1]:
            if not FONT.has_char(character.unicode_at(0)):
                push_error("Preview character is missing: "+character)
                quit(1)
                return
    for unused in 8:await process_frame
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
    var result := root.get_texture().get_image().save_png(destination)
    background.queue_free()
    for unused in 3:await process_frame
    print("INSCRIPTION_FULL_FONT_CAPTURE_%s system_fallback=false" % ("PASS" if result==OK else "FAIL"))
    quit(0 if result==OK else 1)
