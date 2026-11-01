extends ConfirmationDialog
const INSPECT=preload("res://scripts/save_inspector.gd")
var owner_ref: WeakRef
var slot:=1
var action:="switch"
var quote: Dictionary={}
var slots: OptionButton
var actions: OptionButton
var description: RichTextLabel
var overview: AcceptDialog
var overview_list: ItemList
var overview_detail: RichTextLabel
var overview_rows: Array=[]
func _ready() -> void:
    title="存档槽与备份核对";min_size=Vector2i(750,540);dialog_hide_on_ok=false
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
    slots=OptionButton.new()
    for index in range(1,4):slots.add_item("存档槽 %d" % index,index)
    column.add_child(slots)
    slots.item_selected.connect(func(index: int):slot=index+1;refresh_quote())
    actions=OptionButton.new();actions.add_item("切换到主档（空槽开始新旅途）");actions.add_item("恢复备份并进入该槽")
    column.add_child(actions)
    actions.item_selected.connect(func(index: int):action="switch" if index==0 else "recover";refresh_quote())
    description=RichTextLabel.new();description.custom_minimum_size=Vector2(690,350);description.bbcode_enabled=false;description.scroll_active=true;description.focus_mode=Control.FOCUS_ALL;column.add_child(description)
    get_cancel_button().text="留在当前旅途";confirmed.connect(_confirm_operation)
    add_button("查看三槽与备份总览",true,"overview")
    custom_action.connect(func(command: String):
        if command=="overview" and visible:open_overview())
    visibility_changed.connect(func():
        if not visible and is_instance_valid(overview):overview.hide();overview_rows=[])
func setup(ui: Node) -> void:owner_ref=weakref(ui)
func open(index: int, operation: String) -> void:
    slot=index;action=operation;slots.select(slot-1);actions.select(0 if action=="switch" else 1)
    refresh_quote();popup_centered();get_cancel_button().grab_focus()
func refresh_quote() -> void:
    var ui=owner_ref.get_ref()
    if not is_instance_valid(ui):hide();return
    quote=ui.level.quote_save_operation(action,slot)
    var lines: Array[String]=["当前旅途在槽 %d；正在核对槽 %d。" % [ui.level.world_slot,slot]]
    if quote.has("primary"):lines.append("主档："+INSPECT.describe(quote.primary));lines.append("备份："+INSPECT.describe(quote.backup))
    if action=="recover":
        if quote.has("primary") and quote.has("backup"):lines.append(INSPECT.compare(quote.primary,quote.backup))
        lines.append("恢复将使用上面的备份进入旅途；现有主档会另存保留，备份不被覆盖。")
    else:lines.append("离开前先保存当前进度；保存失败会留在当前旅途。")
    if not quote.get("ok",false):lines.append(String(quote.get("reason","暂不可操作。")))
    description.text="\n\n".join(lines)
    description.scroll_to_line(0)
    get_ok_button().disabled=not quote.get("ok",false)
    get_ok_button().text="恢复备份并进入" if action=="recover" else "确认切换旅途"
func _confirm_operation() -> void:
    var ui=owner_ref.get_ref()
    if not is_instance_valid(ui):hide();return
    var fresh: Dictionary=ui.level.quote_save_operation(action,slot)
    if not fresh.get("ok",false):refresh_quote();return
    if not quote.get("ok",false) or String(fresh.fingerprint)!=String(quote.fingerprint):
        refresh_quote();description.text="记录或旅途已变化，请重新核对后再次确认。\n"+description.text;get_cancel_button().grab_focus();return
    var result: Dictionary=ui.level.perform_save_operation(action,slot,String(quote.fingerprint))
    if result.get("ok",false):hide()
    else:refresh_quote();description.text=String(result.get("reason","操作未完成"))+"\n"+description.text

func open_overview() -> void:
    if not visible:return
    var ui: Variant=owner_ref.get_ref() if owner_ref!=null else null
    if not is_instance_valid(ui) or not is_instance_valid(ui.level):return
    if not is_instance_valid(overview):
        overview=AcceptDialog.new();overview.title="三个存档槽与备份";overview.min_size=Vector2i(800,600)
        var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);overview.add_child(column)
        overview_list=ItemList.new();overview_list.custom_minimum_size=Vector2(740,100);column.add_child(overview_list)
        overview_list.item_selected.connect(func(_index: int):_overview_selection())
        overview_detail=RichTextLabel.new();overview_detail.custom_minimum_size=Vector2(740,330)
        overview_detail.bbcode_enabled=false;overview_detail.focus_mode=Control.FOCUS_ALL;column.add_child(overview_detail)
        var controls:=HBoxContainer.new();column.add_child(controls)
        for pair in [["刷新磁盘快照","refresh"],["核对所选主档","switch"],["核对所选备份","recover"]]:
            var button:=Button.new();button.text=pair[0];controls.add_child(button)
            button.pressed.connect(func():_overview_action(pair[1]))
        add_child(overview);ui.register_text_entry_window(overview)
    _refresh_overview();overview.popup_centered();overview_list.grab_focus()

func _refresh_overview() -> void:
    var ui: Variant=owner_ref.get_ref()
    if not is_instance_valid(ui):return
    var chosen:=slot
    var old:=overview_list.get_selected_items()
    if not old.is_empty() and old[0]<overview_rows.size():chosen=int(overview_rows[old[0]].slot)
    overview_rows=preload("res://scripts/save_slot_overview.gd").rows(ui.level.get_save_slots(),int(ui.level.world_slot))
    overview_list.clear()
    for row in overview_rows:
        var index:=overview_list.add_item("槽%d%s · %s" % [row.slot,"（当前）" if row.current else "",row.state])
        if int(row.slot)==chosen:overview_list.select(index)
    if overview_list.get_selected_items().is_empty() and overview_list.item_count>0:overview_list.select(0)
    _overview_selection()

func _overview_selection() -> void:
    var selected:=overview_list.get_selected_items()
    overview_detail.text="暂无可核对记录。" if selected.is_empty() else preload("res://scripts/save_slot_overview.gd").describe(overview_rows[selected[0]],INSPECT.describe)
    overview_detail.scroll_to_line(0)

func _overview_action(operation: String) -> void:
    if not visible or not overview.visible:return
    if operation=="refresh":_refresh_overview();return
    var selected:=overview_list.get_selected_items()
    if selected.is_empty():return
    slot=int(overview_rows[selected[0]].slot);action=operation
    slots.select(slot-1);actions.select(0 if action=="switch" else 1)
    overview.hide();refresh_quote();get_cancel_button().grab_focus()
