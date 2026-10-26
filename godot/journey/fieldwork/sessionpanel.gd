extends "res://journey/fieldwork/panel.gd"
const PUMP := preload("res://journey/fieldwork/pump.gd")
var live: RefCounted
var pending: Dictionary = {}
var window_ref: WeakRef
var pump: Node
var live_label: WeakRef
var live_progress: WeakRef
var last_display := 0.0
var comparison_record_id := 0


func _current(parent: Control) -> void:
    var card := UI.card(parent)
    UI.label(card, "显式练习会话", true)
    UI.hint(card, "使用编辑中的候选或最近保存方案。录制只在明确启动后进行；结果先写辅助记录，失败时可保留当前窗口重试。")
    var actions := UI.row(card)
    UI.button(actions, "启动练习", _start_session, _active() or not pending.is_empty())
    UI.button(actions, "暂停", _pause_session, not _active())
    UI.button(actions, "继续", _resume_session, not _active())
    UI.button(actions, "结束并保存", func(): _finish_session("个人结束练习"), not _active())
    live_label = weakref(UI.hint(card, "尚未启动。"))
    live_progress = weakref(UI.progress(card, 0, 1))
    draw_session_controls(card)
    if not pending.is_empty():
        UI.hint(card, "练习结果尚未写入。请先整理记录库或解决写入问题，再重试；关闭旅途将结束此内存候选。")
        UI.button(card, "重试保存结果", _save_pending)
        UI.button(
            card,
            "放弃未保存结果",
            func():
                pending = {}
                context.refresh()
        )
    super._current(parent)


func draw_session_controls(_parent: Control) -> void:
    pass


func requires_window() -> bool:
    return true


func _active() -> bool:
    return live != null and bool(live.get("active"))


func _window() -> Window:
    var value: Window = window_ref.get_ref() if window_ref != null else null
    return value if is_instance_valid(value) else null


func _host() -> Node:
    var owner: Node = context.level()
    if owner == null:
        return null
    var host: Node = owner.get_tree().root.get_node_or_null("JourneyWorkbench")
    if host == null or host.context == null or host.context.store.scope != context.store.scope:
        return null
    return host


func configuration() -> Dictionary:
    if not draft.is_empty() and domain.validate(draft):
        return draft.duplicate(true)
    if selected_id > 0:
        var row := RECORDS.find(data, selected_id)
        if not row.is_empty():
            return row.payload.duplicate(true)
    if not data.records.is_empty():
        return data.records[0].payload.duplicate(true)
    return domain.capture(context.snapshot())


func _start_session() -> void:
    var host := _host()
    if live != null or not pending.is_empty() or host == null or not context.editable():
        return
    if (
        not is_instance_valid(host.dialog)
        or not host.dialog.visible
        or host.selected != String(descriptor().id)
    ):
        return
    var payload := configuration()
    if not domain.validate(payload):
        context.tell("当前候选配置无效。")
        return
    live = domain.new()
    if not live.begin(payload, _clock()):
        live = null
        context.tell("练习无法启动。")
        return
    window_ref = weakref(host.dialog)
    if requires_window():
        host.dialog.window_input.connect(_session_input)
        if host.dialog.has_signal("focus_exited"):
            host.dialog.connect("focus_exited", _lost_focus)
    pump = PUMP.new()
    host.add_child(pump)
    pump.stepped.connect(_on_step)
    last_display = 0
    context.refresh()


func _clock() -> float:
    return float(Time.get_ticks_usec()) / 1000000.0


func _session_input(event: InputEvent) -> void:
    var window := _window()
    if not _active() or window == null or not window.visible or bool(live.get("paused")):
        return
    var focus := window.gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit:
        return
    accept_session_event(event, _clock())


func accept_session_event(_event: InputEvent, _clock_value: float) -> void:
    pass


func _on_step(clock: float) -> void:
    if live == null:
        return
    if not _active():
        _finish_session(String(live.get("stop_reason")))
        return
    if context.level() == null:
        _finish_session("所属旅途已经退役")
        return
    if requires_window():
        var window := _window()
        if window == null or not window.visible or context.level().active_overlay != "settings":
            _finish_session("练习窗口已关闭")
            return
    session_tick(clock)
    if not _active():
        _finish_session(String(live.get("stop_reason")))
        return
    if clock - last_display >= 0.03:
        last_display = clock
        var label: Label = live_label.get_ref() if live_label != null else null
        var progress: ProgressBar = live_progress.get_ref() if live_progress != null else null
        if is_instance_valid(label):
            label.text = String(live.status_text()) if live.has_method("status_text") else "练习进行中。"
        if is_instance_valid(progress) and live.has_method("progress"):
            progress.value = clampf(float(live.progress()), 0, 1)


func session_tick(clock: float) -> void:
    live.advance(clock)


func _pause_session() -> void:
    if _active():
        live.pause(_clock())


func _resume_session() -> void:
    if _active():
        live.resume(_clock())


func _lost_focus() -> void:
    if requires_window():
        _pause_session()


func _finish_session(reason: String) -> void:
    if live == null:
        return
    if _active():
        live.end(reason)
    var result: Dictionary = live.result()
    _disconnect()
    live = null
    if domain.validate(result):
        pending = result
        _save_pending()
    else:
        context.tell("练习结果字段检查失败，未写入辅助记录。")
    context.refresh()


func _disconnect() -> void:
    var window := _window()
    if window != null:
        if window.window_input.is_connected(_session_input):
            window.window_input.disconnect(_session_input)
        if window.has_signal("focus_exited") and window.is_connected("focus_exited", _lost_focus):
            window.disconnect("focus_exited", _lost_focus)
    window_ref = null
    if is_instance_valid(pump):
        pump.queue_free()
    pump = null


func _save_pending() -> void:
    if pending.is_empty():
        return
    var title := (
        String(descriptor().name) + " · " + VALUES.date(int(Time.get_unix_time_from_system()))
    )
    if data.records.size() >= record_limit():
        context.tell("记录数量已达本功能上限，结果保留待整理后重试。")
        return
    var candidate := RECORDS.append(data, title, pending)
    if candidate == data:
        context.tell("记录库已满，练习结果仍保留在本窗口。")
        return
    if context.level() == null:
        if valid(candidate) and context.store.write(String(descriptor().id), candidate):
            data = candidate
            pending = {}
        return
    if save_candidate(candidate):
        selected_id = int(candidate.sequence)
        draft = pending.duplicate(true)
        draft_title = title
        draft_note = ""
        draft_favorite = false
        tab = "editor"
        pending = {}
        context.tell("练习结果已写入辅助记录。")


func release() -> void:
    if live != null:
        _finish_session("离开练习页面")


func shutdown() -> void:
    release()
    _disconnect()


func restorable() -> bool:
    return not _active() and pending.is_empty() and super.restorable()


func _compare(parent: Control, record: Dictionary) -> void:
    var choices := []
    for other in data.records:
        if int(other.id) != int(record.id):
            choices.append({"id":str(int(other.id)),"name":String(other.title)})
    if choices.is_empty():
        UI.hint(parent, "请先保存另一份已结束的练习结果，再比较两次记录。")
        return
    if RECORDS.find(data, comparison_record_id).is_empty() or comparison_record_id == int(record.id):
        comparison_record_id = int(choices[0].id)
    var pick := UI.pick(parent, choices, str(comparison_record_id))
    pick.item_selected.connect(func(_index: int): comparison_record_id = int(UI.chosen(pick)); context.refresh())
    var other := RECORDS.find(data, comparison_record_id)
    _sections(parent, domain.compare(record.payload, other.payload))
