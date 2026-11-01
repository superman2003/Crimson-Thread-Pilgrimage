extends ConfirmationDialog
const TRANSFER:=preload("res://scripts/settings_profile_transfer.gd")
var owner_ref: WeakRef
var source_ref: WeakRef
var transfer_mode:="import"
var name_input: LineEdit
var code: TextEdit
var detail: RichTextLabel
var pending: Dictionary={}
var clipboard_writer: Callable
var clipboard_reader: Callable
var copy_button: Button
var paste_button: Button

func _ready() -> void:
    min_size=Vector2i(820,580)
    dialog_hide_on_ok=false
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
    var intro:=Label.new();intro.text="分享阅读、画面、手柄参数与按键；不含音量或旅途存档。导入后仍须另行应用。";intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;intro.custom_minimum_size=Vector2(760,44);column.add_child(intro)
    name_input=LineEdit.new();name_input.placeholder_text="新方案名称（不覆盖同名方案）";name_input.max_length=24;column.add_child(name_input)
    code=TextEdit.new();code.custom_minimum_size=Vector2(760,240);code.placeholder_text="在这里粘贴设置分享码";code.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;column.add_child(code)
    var tools:=HBoxContainer.new();column.add_child(tools)
    copy_button=Button.new();copy_button.text="复制分享码";tools.add_child(copy_button);copy_button.pressed.connect(copy_code)
    paste_button=Button.new();paste_button.text="粘贴分享码";tools.add_child(paste_button);paste_button.pressed.connect(paste_code)
    detail=RichTextLabel.new();detail.bbcode_enabled=false;detail.scroll_active=true;detail.focus_mode=Control.FOCUS_ALL;detail.custom_minimum_size=Vector2(760,130);column.add_child(detail)
    detail.add_theme_font_size_override("normal_font_size",16)
    name_input.text_changed.connect(func(_value: String):reset_preview())
    code.text_changed.connect(reset_preview)
    confirmed.connect(confirm_transfer)
    canceled.connect(restore_focus)
    visibility_changed.connect(func():
        if not visible:pending={})

func owned() -> bool:
    if owner_ref==null:return false
    var owner: Variant=owner_ref.get_ref()
    return is_instance_valid(owner) and not owner.is_queued_for_deletion() and owner.is_inside_tree() and is_instance_valid(owner.ui) and not owner.ui.is_queued_for_deletion() and owner.ui.settings.is_visible_in_tree() and is_instance_valid(owner.window) and owner.window.visible

func open_export(owner: Node, source: Control) -> void:
    owner_ref=weakref(owner);source_ref=weakref(source);transfer_mode="export";pending={}
    if not owned():return
    var result:=TRANSFER.export_code(owner.selected,owner.model.profiles.get(owner.selected,{}),owner.ui.REMAPPABLE_ACTIONS)
    if not result.ok:owner.window.status.text=String(result.reason);return
    title="导出设置分享码";name_input.hide();copy_button.show();paste_button.hide();code.editable=false;code.text=result.text
    detail.text="选中分享码后可使用系统复制操作。\n"+String(result.reason)+"\n分享码不包含旅途存档、资源或任务进度。"
    get_ok_button().text="返回方案管理";get_cancel_button().text="关闭"
    popup_centered();code.grab_focus();code.select_all()

func open_import(owner: Node, source: Control) -> void:
    owner_ref=weakref(owner);source_ref=weakref(source);transfer_mode="import";pending={}
    if not owned():return
    title="从分享码创建新方案";name_input.show();copy_button.hide();paste_button.show();name_input.text="";code.editable=true;code.text=""
    detail.text="先填写新名称并粘贴分享码，再预览全部差异。不会覆盖已有方案或立即应用。"
    get_ok_button().text="预览分享码";get_cancel_button().text="取消"
    popup_centered();name_input.grab_focus()

func reset_preview() -> void:
    pending={}
    if transfer_mode=="import" and is_instance_valid(get_ok_button()):get_ok_button().text="预览分享码"

func confirm_transfer() -> void:
    if not visible or not is_inside_tree() or is_queued_for_deletion() or not owned():return
    if transfer_mode=="export":hide();restore_focus();return
    var owner: Variant=owner_ref.get_ref()
    if pending.is_empty() or pending.get("name")!=name_input.text or pending.get("fingerprint")!=code.text.sha256_text():
        var result:=TRANSFER.preview(code.text,owner.ui)
        pending={}
        if not result.ok:detail.text=String(result.reason);return
        if not preload("res://scripts/settings_profiles.gd").valid_name(name_input.text):detail.text="新方案名称需1至24字，不能有首尾空白或控制字符。";return
        if owner.model.profiles.has(name_input.text):detail.text="同名方案已存在，请换一个新名称。";return
        pending={"name":name_input.text,"fingerprint":result.fingerprint}
        detail.text=String(result.reason)+"\n\n与当前设置的差异\n"+("\n".join(result.lines) if not result.lines.is_empty() else "与当前设置一致。")
        detail.scroll_to_line(0);get_ok_button().text="确认创建新方案";get_cancel_button().grab_focus();return
    var result:=TRANSFER.import_new(owner.model,name_input.text,code.text,owner.ui,String(pending.fingerprint))
    pending={}
    if not result.ok:detail.text=String(result.reason);get_ok_button().text="预览分享码";return
    owner.selected=name_input.text;owner.refresh();owner.window.status.text=String(result.reason)
    hide();restore_focus()

func restore_focus() -> void:
    if not owned() or source_ref==null:return
    var source: Variant=source_ref.get_ref()
    if is_instance_valid(source) and source.is_inside_tree() and not source.is_queued_for_deletion() and source.is_visible_in_tree():source.grab_focus()

func copy_code() -> void:
    if not visible or transfer_mode!="export" or not owned():return
    if clipboard_writer.is_valid():clipboard_writer.call(code.text)
    elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):DisplayServer.clipboard_set(code.text)
    else:detail.text="当前环境无法访问剪贴板，可选中分享码手动复制。";return
    detail.text="分享码已复制；当前设置与旅途记录没有变化。"

func paste_code() -> void:
    if not visible or transfer_mode!="import" or not owned():return
    var text: String
    if clipboard_reader.is_valid():text=str(clipboard_reader.call())
    elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):text=DisplayServer.clipboard_get()
    else:detail.text="当前环境无法访问剪贴板，请手动粘贴分享码。";return
    if text.to_utf8_buffer().size()>TRANSFER.MAX_BYTES:detail.text="分享码最多64 KiB，原编辑内容保留。";return
    code.text=text;reset_preview();code.grab_focus()
