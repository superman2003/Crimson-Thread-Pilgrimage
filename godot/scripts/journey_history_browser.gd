extends AcceptDialog
const HISTORY := preload("res://scripts/journey_history.gd")
const DETAIL := preload("res://scripts/journey_archive_detail.gd")
const PAGE_SIZE := 12
var page_query: Callable
var detail_query: Callable
var offset := 0
var page: Dictionary={}
var rows: Array=[]
var entries: ItemList
var summary_text: RichTextLabel
var detail_text: RichTextLabel
var previous: Button
var next: Button
var refresh_button: Button
var page_label: Label
var loading := false

func _ready() -> void:
    title="当前存档槽 · 旧旅途"
    ok_button_text="返回设置"
    min_size=Vector2i(900,620)
    var root:=VBoxContainer.new()
    root.add_theme_constant_override("separation",10)
    add_child(root)
    var header:=Label.new()
    header.text="只读浏览；关闭后继续当前旅途。选中归档查看当时已知的记录。"
    header.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    root.add_child(header)
    var navigation:=HBoxContainer.new()
    root.add_child(navigation)
    previous=_button(navigation,"上一页",func():request_page(maxi(0,offset-PAGE_SIZE)))
    page_label=Label.new()
    page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    navigation.add_child(page_label)
    next=_button(navigation,"下一页",func():request_page(offset+PAGE_SIZE))
    refresh_button=_button(navigation,"刷新记录",func():request_page(offset))
    var panes:=HSplitContainer.new()
    panes.custom_minimum_size=Vector2(840,410)
    root.add_child(panes)
    var left:=VBoxContainer.new()
    left.custom_minimum_size.x=320
    panes.add_child(left)
    entries=ItemList.new()
    entries.custom_minimum_size=Vector2(310,210)
    entries.size_flags_vertical=Control.SIZE_EXPAND_FILL
    entries.item_selected.connect(select_entry)
    left.add_child(entries)
    summary_text=reader(Vector2(310,180))
    left.add_child(summary_text)
    detail_text=reader(Vector2(480,400))
    panes.add_child(detail_text)

func reader(minimum: Vector2) -> RichTextLabel:
    var label:=RichTextLabel.new()
    label.custom_minimum_size=minimum
    label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    label.size_flags_vertical=Control.SIZE_EXPAND_FILL
    label.bbcode_enabled=false
    label.scroll_active=true
    label.focus_mode=Control.FOCUS_ALL
    label.add_theme_font_size_override("normal_font_size",17)
    return label

func _button(parent: Node, caption: String, action: Callable) -> Button:
    var button:=Button.new()
    button.text=caption
    button.custom_minimum_size=Vector2(100,36)
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func open(query: Callable, inspect: Callable) -> void:
    page_query=query
    detail_query=inspect
    request_page(0)
    popup_centered()
    get_ok_button().grab_focus()

func request_page(requested: int) -> void:
    if loading:return
    loading=true
    var result: Variant=page_query.call(clampi(requested,0,HISTORY.MAX_OFFSET),PAGE_SIZE) if page_query.is_valid() else {}
    page=result.duplicate(true) if result is Dictionary else {}
    offset=int(page.get("offset",0))
    var values: Variant=page.get("entries",[])
    rows=values.duplicate(true) if values is Array else []
    entries.clear()
    detail_text.text="选择左侧归档查看已知记录。浏览不会恢复或覆盖存档。"
    for row in rows:
        var date:=Time.get_datetime_string_from_unix_time(int(row.get("modified",0))).replace("T"," ")+" UTC"
        var caption:=date+" · "+String(row.get("region_name","不可读取"))
        if not row.get("valid",false):caption=date+" · 记录不可读"
        entries.add_item(caption)
        entries.set_item_tooltip(entries.item_count-1,String(row.get("file","")))
    var total:=int(page.get("total",0))
    var shown:=rows.size()
    previous.disabled=offset<=0
    next.disabled=not bool(page.get("has_more",offset+shown<total)) or offset+PAGE_SIZE>HISTORY.MAX_OFFSET or shown==0
    page_label.text="第 %d 页 · 本页 %d / 共 %d 份" % [offset/PAGE_SIZE+1,shown,total]
    var lines: Array[String]=["只读浏览；关闭后继续当前旅途。",""]
    for row in rows:
        lines.append(String(row.get("file","")))
        if row.get("valid",false):
            lines.append("停留：%s · %d 区 / %d 房间 · 守门者 %d · 碎钱 %d" % [String(row.get("region_name","旧旅途区域")),int(row.get("regions",0)),int(row.get("rooms",0)),int(row.get("bosses",0)),int(row.get("currency",0))])
        else:lines.append("无法读取此记录："+String(row.get("error","记录不可读"))+"；文件仍保留。")
        lines.append("")
    if total==0:lines.append("还没有旧旅途。另起新旅途时，旧进度会另存保留。")
    if page.has("error"):lines.append(String(page.error))
    if offset+PAGE_SIZE>HISTORY.MAX_OFFSET and offset+shown<total:lines.append("已到浏览上限；更早记录仍保留在存档目录。")
    summary_text.text="\n".join(lines)
    summary_text.scroll_to_line(0)
    detail_text.scroll_to_line(0)
    loading=false

func select_entry(index: int) -> void:
    if loading or index<0 or index>=rows.size():return
    var row: Dictionary=rows[index]
    if not row.get("valid",false):
        detail_text.text="无法读取此记录："+String(row.get("error","记录不可读"))+"；文件仍保留。"
        return
    var result: Variant=detail_query.call(String(row.get("file","")),String(row.get("sha256",""))) if detail_query.is_valid() else {}
    detail_text.text=DETAIL.text(result if result is Dictionary else DETAIL.failure("归档详情暂不可用。"))
    detail_text.scroll_to_line(0)
