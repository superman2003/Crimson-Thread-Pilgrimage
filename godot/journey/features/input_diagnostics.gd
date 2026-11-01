extends "res://journey/core/feature.gd"
const MODEL := preload("res://journey/inputs/model.gd")
const METER := preload("res://journey/inputs/meter.gd")
static var retired_pending: Dictionary = {}
var live_count: Label
var active: Dictionary = {}
var pending: Dictionary = {}
var axes: Dictionary = {}
var started := 0
var family := "all"
var tab := "bindings"
var device := -1
var page := 0
var show_coverage := false
var captured_window: WeakRef
var pending_delete := ""
const PAGE_SIZE := 30

func descriptor() -> Dictionary:
    return {"id":"input_diagnostics", "name":"输入诊断", "summary":"只读按键映射、冲突矩阵、真实窗口事件观察和手柄轴仪表"}

func initial() -> Dictionary:
    return MODEL.fresh()

func valid(candidate: Dictionary) -> bool:
    return MODEL.valid(candidate)

func tick(_snapshot: Dictionary, _delta: float) -> void:
    if active.is_empty():
        return
    var window: Window = captured_window.get_ref() if captured_window != null else null
    if not is_instance_valid(window) or not window.visible:
        _finish()
    elif Time.get_ticks_msec() - started >= 30000 or active.events.size() >= MODEL.MAX_EVENTS:
        _finish()

func draw(parent: Control) -> void:
    header(parent, "读取当前 InputMap，不改键、不注入动作。事件观察只在本工作台窗口明确开始后生效，最多30秒/500条。")
    _bind_window()
    if not active.is_empty():
        live_count = UI.label(parent, "输入观察中 · %d条；切换模块或关闭工作台会结束。" % active.events.size())
        UI.button(parent, "结束并保存输入观察", _finish)
    if not pending.is_empty():
        UI.hint(parent, "上次输入观察待保存，原内存内容仍保留。")
        UI.button(parent, "重试保存观察", _persist)
    var tabs := UI.row(parent)
    for pair in [["bindings", "动作映射"], ["conflicts", "重叠检查"], ["controller", "手柄仪表"], ["events", "事件记录"]]:
        var id := String(pair[0])
        UI.button(tabs, String(pair[1]), func():tab = id;context.refresh())
    if tab == "conflicts":
        _conflicts(parent)
    elif tab == "controller":
        _controller(parent)
    elif tab == "events":
        _events(parent)
    else:
        _bindings(parent)

func _bind_window() -> void:
    var owner: Node = context.level()
    if owner == null:
        return
    var window: Window = owner.ui_shell.settings.get_node_or_null("JourneyWorkbenchWindow")
    if window == null:
        return
    var previous: Window = captured_window.get_ref() if captured_window != null else null
    if previous == window:
        return
    captured_window = weakref(window)
    window.window_input.connect(_event)

func _event(event: InputEvent) -> void:
    if active.is_empty() or captured_window == null:
        return
    var window := captured_window.get_ref() as Window
    if not is_instance_valid(window) or not window.visible:
        return
    var focus := window.gui_get_focus_owner()
    if focus is LineEdit or focus is TextEdit:
        return
    var time := float(Time.get_ticks_msec() - started) / 1000.0
    var row := MODEL.event_row(event, time, axes)
    if not row.is_empty():
        active = MODEL.append(active, row)
        if is_instance_valid(live_count):
            live_count.text = "输入观察中 · %d条；切换模块或关闭工作台会结束。" % active.events.size()
    if active.events.size() >= MODEL.MAX_EVENTS:
        _finish()

func _start(title: String) -> void:
    if not pending.is_empty():
        context.tell("请先保存待写入的观察记录。")
        return
    active = MODEL.session(title)
    started = Time.get_ticks_msec()
    axes.clear()
    context.tell("已开始接收本工作台窗口的事件；文字输入框中的事件不记录。")
    context.refresh()

func _finish() -> void:
    if active.is_empty():
        return
    active.duration = minf(30.0, float(Time.get_ticks_msec() - started) / 1000.0)
    pending = active
    active = {}
    axes.clear()
    if pending.events.is_empty():
        pending = {}
        context.tell("没有有效输入事件，本次观察未写盘。")
    else:
        _persist()
    context.refresh()

func _persist() -> void:
    if pending.is_empty():
        return
    var candidate := MODEL.save(data, pending)
    if candidate != data and commit(candidate):
        selected = String(candidate.sessions[0].id)
        pending = {}
        retired_pending.erase(context.store.scope)

func _filters(parent: Control) -> void:
    var row := UI.row(parent)
    var query := UI.edit(row, "搜索动作或事件说明", search)
    UI.button(row, "搜索", func():search = query.text;page = 0;context.refresh())
    var picker := UI.pick(row, [{"id":"all", "name":"全部设备"}, {"id":"keyboard", "name":"键盘"}, {"id":"mouse", "name":"鼠标"}, {"id":"controller", "name":"手柄"}], family)
    picker.item_selected.connect(func(_index: int):family = UI.chosen(picker);page = 0;context.refresh())

func _bindings(parent: Control) -> void:
    _filters(parent)
    var unbound := []
    for row in MODEL.bindings():
        if not VALUES.matches(search, [String(row.name), String(row.id)]):
            continue
        var events := []
        for event in row.events:
            if family == "all" or event.family == family:
                events.append(event)
        if row.events.is_empty():
            unbound.append(row.name)
        if family != "all" and events.is_empty():
            continue
        var card := UI.card(parent)
        UI.label(card, String(row.name))
        for event in events:
            UI.hint(card, String(event.family) + " · " + String(event.text))
        if events.is_empty():
            UI.hint(card, "当前没有绑定；请在原设置页调整。")
        if row.families.has("controller"):
            UI.hint(card, "此动作的当前死区 %.2f" % float(row.deadzone))
    if not unbound.is_empty():
        UI.label(parent, "未绑定动作：" + " / ".join(unbound))
    UI.hint(parent, "此页只读，保留原设置页的完整冲突和保留键策略。")
    UI.button(parent, "导出当前全部动作绑定", func():export_document("动作绑定.txt", MODEL.bindings_document()))

func _conflicts(parent: Control) -> void:
    UI.label(parent, "当前动作事件的重叠矩阵", true)
    UI.hint(parent, "使用正式输入策略检查设备、按钮、轴方向和物理键。列出重叠并不自动判定组合一定不合理；此页不更改绑定。")
    var rows := MODEL.conflicts()
    if rows.is_empty():
        UI.hint(parent, "所列游戏动作之间没有发现重叠事件。")
    for row in rows:
        var card := UI.card(parent)
        UI.label(card, String(row.name))
        for binding in row.bindings:
            UI.hint(card, String(binding))
    var lines: Array[String] = ["输入映射重叠报告", ""]
    for row in rows:
        lines.append(String(row.name) + "：" + " / ".join(row.bindings))
    UI.button(parent, "导出映射重叠报告", func():export_document("输入重叠报告.txt", "\n".join(lines)))

func _controller(parent: Control) -> void:
    var choices := []
    for id in Input.get_connected_joypads():
        choices.append({"id":str(id), "name":"%s · 设备%d" % [Input.get_joy_name(id), id]})
    if choices.is_empty():
        UI.hint(parent, "未检测到手柄。连接后重新打开此页即可观察原始轴；不伪造设备或校准样本。")
        return
    if device not in Input.get_connected_joypads():
        device = int(choices[0].id)
    var picker := UI.pick(parent, choices, str(device))
    picker.item_selected.connect(func(_index: int):device = int(UI.chosen(picker));context.refresh())
    var meter := METER.new()
    meter.device = device
    meter.threshold = InputMap.action_get_deadzone("move_left") if InputMap.has_action("move_left") else 0.2
    parent.add_child(meter)
    UI.hint(parent, "左右圆盘为原始摇杆；竖条为扳机正向行程。灰圈只是左移动作当前阈值，不将所有动作都当成同一死区。")
    for button in range(JOY_BUTTON_MAX):
        if Input.is_joy_button_pressed(device, button):
            UI.hint(parent, "当前按下按钮 %d" % button)
    UI.button(parent, "刷新设备 / 按钮状态", context.refresh)

func _events(parent: Control) -> void:
    var row := UI.row(parent)
    var title := UI.edit(row, "输入观察名称", "", 60)
    UI.button(row, "开始30秒输入观察", func():_start(title.text), not active.is_empty())
    UI.hint(parent, "记录窗口收到的时间、设备事件和映射动作，不测量键盘硬件延迟、游戏接受动作或屏幕显示延迟。")
    if data.sessions.is_empty():
        UI.hint(parent, "尚无已保存的输入观察。最多保留最近5次。")
        return
    var choices := []
    for record in data.sessions:
        choices.append({"id":record.id, "name":"%s · %d条" % [record.name, record.events.size()]})
    if selected.is_empty():
        selected = String(data.sessions[0].id)
    var picker := UI.pick(parent, choices, selected)
    picker.item_selected.connect(func(_index: int):selected = UI.chosen(picker);page = 0;context.refresh())
    var record := {}
    for value in data.sessions:
        if value.id == selected:
            record = value
    if record.is_empty():
        return
    var statistics := MODEL.statistics(record)
    UI.label(parent, "观察%.2f秒 · 未匹配动作%d条 · 结束时未见松开%d项" % [record.duration, statistics.unmatched, statistics.held_at_end])
    var coverage := MODEL.coverage(record)
    UI.hint(parent, "所列动作中，观察到%d/%d种按下事件。不是动作成功率。" % [coverage.covered, coverage.total])
    UI.toggle(parent, "展开逐动作观察清单", show_coverage, func(value: bool):show_coverage = value;context.refresh())
    if show_coverage:
        _coverage_rows(parent, coverage)
    for chord in coverage.chords:
        var names := []
        for action in chord.actions:
            names.append(String(MODEL.NAMES.get(action, action)))
        UI.hint(parent, "%.3f秒 · 同时保持的映射：%s" % [chord.time, " + ".join(names)])
    UI.hint(parent, "最短相邻事件间隔 %.4f秒；这是接收节奏，不是设备延迟。" % statistics.shortest_gap)
    _filters(parent)
    var events := MODEL.filtered(record, family, search)
    page = clampi(page, 0, maxi(0, (events.size() - 1) / PAGE_SIZE))
    var navigation := UI.row(parent)
    UI.button(navigation, "上一页", func():page -= 1;context.refresh(), page == 0)
    UI.label(navigation, "%d条 / 第%d页" % [events.size(), page + 1])
    UI.button(navigation, "下一页", func():page += 1;context.refresh(), (page + 1) * PAGE_SIZE >= events.size())
    for index in range(page * PAGE_SIZE, mini(events.size(), (page + 1) * PAGE_SIZE)):
        var event: Dictionary = events[index]
        var card := UI.card(parent)
        UI.label(card, "%.4f秒 · %s" % [event.time, event.label])
        var names := []
        for action in event.actions:
            names.append(String(MODEL.NAMES.get(action, action)))
        UI.hint(card, "按下" if event.pressed else "松开 / 中立")
        UI.hint(card, " / ".join(names) if not names.is_empty() else "没有映射到所列游戏动作")
    var actions := UI.row(parent)
    UI.button(actions, "导出本次记录", func():export_document("输入观察.txt", MODEL.document(record)))
    UI.button(actions, "删除记录", func():pending_delete = String(record.id);context.refresh())
    if pending_delete == record.id:
        UI.button(parent, "确认删除本次输入记录", func():commit(MODEL.remove(data, String(record.id)));selected = "";pending_delete = "")

func release() -> void:
    _finish()

func shutdown() -> void:
    _finish()
    _persist()
    if not pending.is_empty():
        retired_pending[context.store.scope] = pending.duplicate(true)

func setup(value: RefCounted) -> void:
    super.setup(value)
    if retired_pending.has(context.store.scope):
        pending = retired_pending[context.store.scope].duplicate(true)
        _persist()

func restorable() -> bool:
    return active.is_empty() and pending.is_empty()

func _coverage_rows(parent: Control, coverage: Dictionary) -> void:
    UI.label(parent, "当前记录中的动作事件覆盖", true)
    UI.hint(parent, "这里统计映射事件，不表示真实玩家控制器接受了动作。未测到可能只是没有按过相应输入。")
    for row in coverage.get("rows", []):
        var card := UI.card(parent)
        UI.label(card, String(row.name))
        if row.get("seen", false):
            UI.hint(card, "观察到按下%d次、松开/中立%d次" % [row.pressed, row.released])
        else:
            UI.hint(card, "本次记录未观察到此动作的按下事件。")
        var current_events := []
        if InputMap.has_action(String(row.id)):
            for event in InputMap.action_get_events(String(row.id)):
                current_events.append(event.as_text())
        UI.hint(card, "当前绑定：" + (" / ".join(current_events) if not current_events.is_empty() else "未设置"))
        if int(row.pressed) > 0 and int(row.released) == 0:
            UI.hint(card, "记录窗口内未见对应松开；可能在观察结束后或其它窗口才松开。")
