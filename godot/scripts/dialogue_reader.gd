extends HBoxContainer
## Reading controls own no story state. Reveal never advances or commits a line.
var body: Label
var scroll: ScrollContainer
var reveal_action: Callable
var reveal_button: Button
var previous_button: Button
var next_button: Button
var progress: Label

func configure(text: Label, viewport: ScrollContainer, reveal: Callable) -> void:
    body=text;scroll=viewport;reveal_action=reveal
    add_theme_constant_override("separation",8)
    reveal_button=_button("显示全文",func():
        if reveal_action.is_valid():reveal_action.call()
        refresh())
    previous_button=_button("上翻",func():turn(-1))
    next_button=_button("下翻",func():turn(1))
    progress=Label.new();progress.custom_minimum_size.x=180;progress.add_theme_font_size_override("font_size",12);add_child(progress)
    refresh()

func _button(title: String, action: Callable) -> Button:
    var button:=Button.new();button.text=title;button.custom_minimum_size=Vector2(72,27)
    button.add_theme_font_size_override("font_size",13);button.pressed.connect(action);add_child(button)
    return button

func _process(_delta: float) -> void:
    if is_visible_in_tree():refresh()

func refresh() -> void:
    if not is_instance_valid(body) or not is_instance_valid(scroll) or progress==null:return
    var length:=body.text.length()
    var visible_count:=length if body.visible_characters<0 else mini(body.visible_characters,length)
    reveal_button.disabled=visible_count>=length or not reveal_action.is_valid()
    var bar:=scroll.get_v_scroll_bar()
    var maximum:=maxf(0.0,bar.max_value-bar.page)
    previous_button.disabled=scroll.scroll_vertical<=0
    next_button.disabled=float(scroll.scroll_vertical)>=maximum-1.0
    var read_percent:=100 if maximum<=0.0 else int(round(clampf(float(scroll.scroll_vertical)/maximum,0.0,1.0)*100.0))
    progress.text="逐字 %d%% · 位置 %d%%" % [100 if length==0 else int(100.0*visible_count/length),read_percent]
    progress.tooltip_text="显示全文与翻页只改变当前文字的阅读位置。交谈、记录与交付仍使用原按钮。"

func turn(direction: int) -> void:
    if direction==0 or not is_instance_valid(scroll):return
    var bar:=scroll.get_v_scroll_bar()
    scroll.scroll_vertical=int(clampf(float(scroll.scroll_vertical)+signi(direction)*maxf(1.0,scroll.size.y*0.8),0.0,maxf(0.0,bar.max_value-bar.page)))
    refresh()
