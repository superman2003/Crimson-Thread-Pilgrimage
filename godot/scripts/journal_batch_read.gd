extends ConfirmationDialog
## Confirmation is bound to the owner's current public filter and slot.
var owner_ref: WeakRef
var quote: Dictionary={}
var scope := ""

func _ready() -> void:
    title="批量标为已读"
    min_size=Vector2i(620,260)
    dialog_hide_on_ok=false
    get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    get_label().custom_minimum_size=Vector2(550,120)
    get_ok_button().text="确认标为已读"
    get_cancel_button().text="保留阅读状态"
    confirmed.connect(apply)

func _owner() -> Variant:
    var owner: Variant=owner_ref.get_ref() if owner_ref!=null else null
    return owner if is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion() and owner._journal_batch_available() else null

func open_for(owner: Control) -> Dictionary:
    owner_ref=weakref(owner)
    var host: Variant=_owner()
    if host==null:return {"ok":false,"reason":"请在当前旅记中操作。"}
    quote=host.journal_catalog.batch_quote(host._journal_batch_documents())
    if not quote.ok:return quote
    scope=String(host.journal_catalog.scope)
    get_ok_button().disabled=false
    _describe("")
    popup_centered()
    get_cancel_button().grab_focus()
    return quote

func _describe(prefix: String) -> void:
    dialog_text=prefix+"将当前筛选结果中的%d条未读记录标为已读。\n只修改本存档的阅读偏好，不推进任务、取得奖励或收藏其它记录。" % int(quote.get("count",0))

func apply() -> void:
    if not visible:return
    var host: Variant=_owner()
    if host==null:hide();return
    if String(host.journal_catalog.scope)!=scope:hide();return
    var documents: Array=host._journal_batch_documents()
    var result: Dictionary=host.journal_catalog.mark_read_batch(documents,String(quote.get("fingerprint","")))
    if result.get("ok",false):
        hide()
        host._journal_preference_result(result)
    else:
        quote=host.journal_catalog.batch_quote(documents)
        if quote.get("ok",false):_describe(String(result.get("reason",""))+"\n请重新核对后再确认。\n\n")
        else:dialog_text=String(quote.get("reason","筛选结果已失效。"))
        get_ok_button().disabled=not quote.get("ok",false)
        get_cancel_button().grab_focus()
