extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/share_cards/advanced.gd")
var card: Dictionary = {}
var layout: Dictionary = {}
var page := 0
var content: VBoxContainer
var indicator: Label
var previous: Button
var next: Button


func configure(data: Dictionary) -> void:
    card = data.get("body",{}).duplicate(true)
    layout = A.paginate(card)
    page = 0


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if not layout.get("ok",false):
        UI.label(self,String(layout.get("reason","公开内容未能排版")))
        return
    UI.hint(self,"使用与分页SVG相同的行流逐页预览。这里只含已经勾选并过滤的公开字段；不会上传。")
    var row := UI.row(self)
    previous = UI.button(row,"上一页",func(): _change(-1))
    indicator = UI.label(row,"")
    next = UI.button(row,"下一页",func(): _change(1))
    content = UI.card(self)
    _show_page()


func _change(direction: int) -> void:
    page = clampi(page+direction,0,maxi(0,layout.pages.size()-1))
    _show_page()


func _show_page() -> void:
    UI.clear(content)
    previous.disabled = page==0
    next.disabled = page+1>=layout.pages.size()
    indicator.text = "第%d / %d页" % [page+1,layout.pages.size()]
    UI.label(content,String(card.get("title","公开旅途卡")),true)
    for row in layout.pages[page]:
        var label := UI.label(content,String(row.text),bool(row.heading))
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    UI.hint(content,"本页%d行 · 全文%d行；窗口宽度变化只影响屏幕换行，SVG使用固定纸面尺寸。" % [layout.pages[page].size(),layout.lines])
