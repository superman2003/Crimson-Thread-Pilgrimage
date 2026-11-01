extends ConfirmationDialog
var query: Callable
var apply_action: Callable
var name_key := ""
var quote: Dictionary={}
var pending := false
var changes: RichTextLabel
var status: Label
var format_changes: Callable

func _ready() -> void:
    title="核对并恢复构筑"
    min_size=Vector2i(760,570)
    dialog_hide_on_ok=false
    var column:=VBoxContainer.new()
    column.add_theme_constant_override("separation",12)
    add_child(column)
    changes=RichTextLabel.new()
    changes.custom_minimum_size=Vector2(710,410)
    changes.bbcode_enabled=false
    changes.scroll_active=true
    changes.focus_mode=Control.FOCUS_ALL
    changes.add_theme_font_size_override("normal_font_size",17)
    column.add_child(changes)
    status=Label.new()
    status.custom_minimum_size=Vector2(710,44)
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status)
    get_ok_button().text="确认恢复装备"
    get_cancel_button().text="保留当前构筑"
    confirmed.connect(confirm_restore)

func open(name: String, quote_action: Callable, action: Callable, formatter: Callable) -> void:
    name_key=name
    query=quote_action
    apply_action=action
    format_changes=formatter
    pending=false
    refresh_quote()
    popup_centered()
    get_cancel_button().grab_focus()

func refresh_quote() -> void:
    var response: Variant=query.call(name_key) if query.is_valid() else {}
    quote=response.duplicate(true) if response is Dictionary else {}
    var lines: Array[String]=["方案「%s」" % name_key,""]
    if quote.get("ok",false) and quote.get("can_restore",false):
        if format_changes.is_valid():
            var formatted: Variant=format_changes.call(quote)
            if formatted is Array:
                for line in formatted:lines.append(String(line))
        var resources: Dictionary=quote.get("resources",{})
        lines.append("")
        lines.append("生命：%d → %d；绯线：%d → %d" % [int(resources.get("hp_before",0)),int(resources.get("hp_after",0)),int(resources.get("energy_before",0)),int(resources.get("energy_after",0))])
        lines.append("碎钱花费：%d；不会补满生命、绯线或战具次数。" % int(quote.get("currency_cost",0)))
        if int(resources.get("hp_after",0))<int(resources.get("hp_before",0)) or int(resources.get("energy_after",0))<int(resources.get("energy_before",0)):
            lines.append("注意：新配置容量较低，超出上限的当前生命或绯线会被截去。")
        lines.append("战具沿用现有库存，切换后仍须付费补给；保存失败将回滚装备。")
        status.text="核对差异后确认；也可以取消，继续使用当前构筑。"
    else:status.text=String(quote.get("reason","恢复预览暂不可用。"))
    changes.text="\n".join(lines)
    changes.scroll_to_line(0)
    get_ok_button().disabled=pending or not quote.get("ok",false) or not quote.get("can_restore",false) or String(quote.get("fingerprint","")).is_empty()

func confirm_restore() -> void:
    if pending or not visible:return
    var old:=String(quote.get("fingerprint",""))
    refresh_quote()
    if get_ok_button().disabled:return
    if old.is_empty() or old!=String(quote.get("fingerprint","")):
        status.text="方案、装备或资源已变化，请核对新预览后再次确认。"
        get_cancel_button().grab_focus()
        return
    if not apply_action.is_valid():status.text="恢复入口暂不可用。";return
    pending=true
    get_ok_button().disabled=true
    var response: Variant=apply_action.call(name_key,old)
    var result: Dictionary=response if response is Dictionary else {"ok":false,"reason":"恢复未完成。"}
    pending=false
    if result.get("ok",false):hide()
    else:
        refresh_quote()
        status.text=String(result.get("reason","恢复未完成；当前构筑保留。"))
