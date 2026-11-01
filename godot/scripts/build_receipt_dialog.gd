extends "res://scripts/journey_desk_window.gd"
const INSPECT:=preload("res://scripts/build_receipt_inspector.gd")
var owner_ref: WeakRef
var model:=INSPECT.new()
var details: RichTextLabel
var start_button: Button
var stop_button: Button
var root_override:="" # Native fixture injection; normal UI always uses executable directory.
var clipboard_writer: Callable
var elapsed:=0.0

func _ready() -> void:
    super._ready();title="发行构建与文件核对"
    text(column,"读取发行程序同目录的随包清单。只读核对此次文件内容；文件一致不等于完整游玩验收。",50)
    details=RichTextLabel.new();details.bbcode_enabled=false;details.selection_enabled=true
    details.scroll_active=true;details.focus_mode=Control.FOCUS_ALL;details.custom_minimum_size=Vector2(900,340)
    details.add_theme_font_size_override("normal_font_size",17);column.add_child(details)
    var actions:=row(column)
    start_button=button(actions,"开始核对随包文件",start_scan)
    stop_button=button(actions,"停止核对",stop_scan)
    button(actions,"重新读取清单",reload_manifest)
    button(actions,"复制构建摘要",copy_summary)
    footer()
    visibility_changed.connect(func():
        if not visible:model.cancel())

func _owner() -> Node:
    var host: Node=owner_ref.get_ref() if owner_ref!=null else null
    if not is_instance_valid(host) or host.is_queued_for_deletion() or not host.is_inside_tree():return null
    if not is_instance_valid(host.window) or not host.window.visible or not is_instance_valid(host.ui):return null
    return host if host.ui.settings.is_visible_in_tree() else null

func open_for(host: Node) -> void:
    owner_ref=weakref(host)
    if _owner()==null:return
    bind_overlay(host.ui,host.ui.settings)
    _read_manifest();popup_centered();get_ok_button().grab_focus()

func _read_manifest() -> void:
    var folder:=root_override if not root_override.is_empty() else OS.get_executable_path().get_base_dir()
    model.load_manifest(folder);elapsed=0.0;_render()

func reload_manifest() -> void:
    if visible and _owner()!=null:_read_manifest()

func start_scan() -> void:
    if not visible or _owner()==null:return
    model.start();_render()

func stop_scan() -> void:
    if not visible or _owner()==null:return
    model.cancel();_render()

func _process(delta: float) -> void:
    if not visible:return
    if _owner()==null:hide();return
    if not model.working:return
    model.tick();elapsed+=delta
    if elapsed>=0.15 or not model.working:elapsed=0.0;_render()

func _render() -> void:
    var report:=model.report()
    var lines: Array[String]=["运行平台："+OS.get_name(),"当前引擎："+String(Engine.get_version_info().get("string","未提供")),"",model.summary()]
    if not report.metadata.is_empty():
        lines.append("清单声明："+String(report.metadata.qualification))
        lines.append("\n清单列出的流程（不是本机重新执行的验收）：")
        for label in report.metadata.validation:lines.append("· "+String(label))
        lines.append("\n随包文件：")
        for entry in report.files:lines.append(String(entry.path)+" · "+String(entry.status))
    details.text="\n".join(lines)
    start_button.disabled=model.working or report.metadata.is_empty()
    stop_button.disabled=not model.working
    status.text=String(report.error) if not String(report.error).is_empty() else "正在核对随包文件，可停止后重新开始。" if model.working else "本次读取与清单全部一致；不代表完整游玩验收。" if report.passed else "已停止，未完成的文件不作结论。" if model.cancelled else "尚未完成全部文件核对。"

func copy_summary() -> void:
    if not visible or _owner()==null:return
    var value:="运行平台："+OS.get_name()+"\n当前引擎："+String(Engine.get_version_info().get("string","未提供"))+"\n"+model.summary()
    if clipboard_writer.is_valid():clipboard_writer.call(value)
    elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):DisplayServer.clipboard_set(value)
    else:status.text="当前运行环境没有剪贴板，可在上方选择文字。";return
    status.text="已复制构建标识与此次核对状态；不含本机目录路径。"
