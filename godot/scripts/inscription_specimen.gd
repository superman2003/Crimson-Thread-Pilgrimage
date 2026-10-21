extends Control
## A runnable specimen of the same fonts, buttons and geometry used in World.
const UI := preload("res://scripts/pilgrimage_interface.gd")
const CHROME := preload("res://scripts/pilgrimage_chrome.gd")

func _ready() -> void:
    var shell := UI.new()
    shell.set_process(false)
    shell.size=Vector2(1280,800)
    var specimen_theme := Theme.new()
    specimen_theme.default_font=UI.FONT
    specimen_theme.set_font("font","Button",UI.display_font())
    shell.theme=specimen_theme
    add_child(shell)
    var background := ColorRect.new()
    background.size=shell.size
    background.color=Color("050e10")
    shell.add_child(background)
    var paper := CHROME.new()
    paper.kind="specimen"
    paper.position=Vector2(15,15)
    paper.size=Vector2(1250,770)
    shell.add_child(paper)
    shell._icon(shell,preload("res://assets/ui/inscription/v2/pilgrimage.png"),Vector2(40,28),Vector2(835,260))
    shell._label(shell,"C R I M S O N   T H R E A D   P I L G R I M A G E",Vector2(67,290),Vector2(790,29),16,UI.GOLD).add_theme_font_override("font",UI.display_font())
    shell._label(shell,"缝名刻印",Vector2(938,66),Vector2(270,49),35)
    shell._label(shell,"字体与界面",Vector2(943,123),Vector2(260,30),21,UI.GOLD)
    shell._label(shell,"把失去的名字，\n带回钟声里。",Vector2(943,213),Vector2(270,78),24)
    var rule := ColorRect.new()
    rule.position=Vector2(53,320)
    rule.size=Vector2(1174,1)
    rule.color=Color(UI.GOLD,.5)
    shell.add_child(rule)
    var names := ["seal","inventory","journal","map"]
    for i in names.size():
        shell._icon(shell,load("res://assets/ui/inscription/v2/%s.png" % names[i]),Vector2(55+i*210,337),Vector2(160,83))
    shell._label(shell,"0  1  2  3  4  5  6  7  8  9",Vector2(61,430),Vector2(875,72),49)
    shell._label(shell,"标题 / 刻痕、针孔、穿线\n正文 / 清晰、克制、易读",Vector2(947,356),Vector2(277,70),16,UI.MUTED)
    shell._label(shell,"以线缝名，借势出针。",Vector2(947,443),Vector2(277,39),20)
    var line := ColorRect.new()
    line.position=Vector2(53,521)
    line.size=Vector2(1174,1)
    line.color=Color(UI.GOLD,.4)
    shell.add_child(line)
    shell._label(shell,"生命",Vector2(63,551),Vector2(91,37),22,UI.GOLD)
    var tags := CHROME.new()
    tags.kind="health"
    tags.hp=4
    tags.maximum=5
    tags.position=Vector2(161,543)
    tags.size=Vector2(217,50)
    shell.add_child(tags)
    shell._label(shell,"4 / 5",Vector2(403,551),Vector2(113,37),25)
    shell._label(shell,"绯线",Vector2(603,551),Vector2(91,37),22,UI.GOLD)
    var bar := ProgressBar.new()
    bar.position=Vector2(704,565)
    bar.size=Vector2(245,5)
    bar.custom_minimum_size=Vector2(0,5)
    bar.show_percentage=false
    bar.add_theme_font_size_override("font_size",1)
    bar.add_theme_constant_override("outline_size",0)
    bar.value=74
    bar.add_theme_stylebox_override("background",shell._meter_style(Color("34413a")))
    bar.add_theme_stylebox_override("fill",shell._meter_style(UI.RED))
    shell.add_child(bar)
    bar.size=Vector2(245,5)
    shell._label(shell,"74 / 100",Vector2(984,545),Vector2(220,48),32)
    shell._label(shell,"巡礼手札",Vector2(63,632),Vector2(400,28),19,UI.GOLD).add_theme_font_override("font",UI.display_font())
    for i in 3:
        var button := shell._button(shell,["契印","行囊","未解锁"][i],Vector2(64+i*181,679),Vector2(160,49),func():pass)
        button.disabled=i==2
        if i==0:button.grab_focus()
    shell._label(shell,"墨青  ·  骨白  ·  旧铜  ·  绯红  ·  苔绿",Vector2(752,632),Vector2(466,28),16,UI.GOLD)
    var swatches := [Color("0a1d20"),UI.IVORY,UI.GOLD,UI.RED,Color("8cab96")]
    for i in swatches.size():
        var swatch := ColorRect.new()
        swatch.color=swatches[i]
        swatch.position=Vector2(755+i*91,680)
        swatch.size=Vector2(70,49)
        shell.add_child(swatch)
