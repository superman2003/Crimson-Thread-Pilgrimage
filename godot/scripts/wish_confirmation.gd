extends ConfirmationDialog
var owner_ref: WeakRef
var area_ref: WeakRef
var quest: Dictionary = {}
var fingerprint := ""
var description: Label
func _ready() -> void:
    title="确认心愿交付"
    min_size=Vector2i(650,310)
    dialog_hide_on_ok=false
    description=Label.new();description.custom_minimum_size=Vector2(590,210)
    description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(description)
    get_ok_button().text="确认交付并记录"
    get_cancel_button().text="暂不交付"
    confirmed.connect(_confirm_delivery)
func setup(ui: Node) -> void:owner_ref=weakref(ui)
func open(area: Area2D, request: Dictionary, quote: Dictionary) -> void:
    area_ref=weakref(area);quest=request.duplicate(true)
    _show_quote(quote)
    popup_centered();get_cancel_button().grab_focus()
func _show_quote(quote: Dictionary) -> void:
    fingerprint=String(quote.get("fingerprint",""))
    description.text=String(quote.get("summary",quote.get("reason","心愿已变化，请重新交谈。")))
    get_ok_button().disabled=not quote.get("ok",false) or not quote.get("delivered",false)
func _confirm_delivery() -> void:
    var ui=owner_ref.get_ref() if owner_ref!=null else null
    var area=area_ref.get_ref() if area_ref!=null else null
    if not is_instance_valid(ui) or not is_instance_valid(area):hide();return
    var fresh: Dictionary=ui.level.quote_wish_topic(quest,area)
    if not fresh.get("ok",false) or not fresh.get("delivered",false):_show_quote(fresh);return
    if String(fresh.fingerprint)!=fingerprint:
        _show_quote(fresh);description.text="状态已变化，请重新核对后再次确认。\n"+description.text
        get_cancel_button().grab_focus();return
    if ui._commit_wish_topic(quest,area):hide()
    else:description.text="记录未写入，信物与回礼保持原状。请重试或取消。"
