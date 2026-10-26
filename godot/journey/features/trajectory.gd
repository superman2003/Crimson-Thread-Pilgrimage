extends "res://journey/core/feature.gd"
const MODEL := preload("res://journey/trajectory/model.gd")
const PLOT := preload("res://journey/trajectory/plot.gd")
var active: Dictionary = {}
var pending: Dictionary = {}
var mode := "path"
var comparison := ""
var show_overlay := true
var overlay: CanvasLayer
var overlay_label: Label
var pending_delete := ""
var retry_elapsed := 0.0

func descriptor() -> Dictionary:
    return {"id":"trajectory", "name":"机动轨迹", "summary":"实际探索的有限采样、路线与速度折线、资源观察和两次记录比较"}

func initial() -> Dictionary:
    return MODEL.fresh()

func valid(candidate: Dictionary) -> bool:
    return MODEL.valid(candidate)

func tick(snapshot: Dictionary, delta: float) -> void:
    if not active.is_empty():
        active = MODEL.sample(active, snapshot, delta)
        if not String(active.reason).is_empty():
            _finish(String(active.reason))
    if not pending.is_empty():
        retry_elapsed += delta
        if retry_elapsed >= 5.0:
            retry_elapsed = 0.0
            _persist_pending()
    _overlay(snapshot)

func _overlay(snapshot: Dictionary) -> void:
    if not show_overlay or active.is_empty() or not snapshot.get("exploring", false):
        if is_instance_valid(overlay):
            overlay.visible = false
        return
    if not is_instance_valid(overlay):
        var owner: Node = context.level()
        if owner == null:
            return
        overlay = CanvasLayer.new()
        overlay.layer = 40
        owner.get_tree().root.add_child(overlay)
        overlay_label = Label.new()
        overlay_label.position = Vector2(470, 658)
        overlay_label.size = Vector2(340, 30)
        overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay_label.add_theme_font_size_override("font_size", 15)
        overlay_label.add_theme_color_override("font_color", Color("dec6a0"))
        overlay.add_child(overlay_label)
    overlay.visible = true
    overlay_label.text = "轨迹记录 %.1f秒 · %d/%d样本" % [active.duration, active.samples.size(), MODEL.MAX_SAMPLES]

func draw(parent: Control) -> void:
    header(parent, "按实际观察间隔采样位置、速度和资源。不是逐物理帧录像，也不把采样间的增减当成完整战斗事件。")
    _recording_controls(parent)
    UI.divider(parent)
    if data.runs.is_empty():
        UI.hint(parent, "尚无轨迹记录。开始后关闭工作台和设置，恢复探索即可采样。菜单期间暂停采样。")
        return
    if MODEL.get_run(data, selected).is_empty():
        selected = String(data.runs[0].id)
    var choices := _choices()
    var picker := UI.pick(parent, choices, selected)
    picker.item_selected.connect(func(_index: int):selected = UI.chosen(picker);context.refresh())
    var record := MODEL.get_run(data, selected)
    _summary(parent, record)
    _plot(parent, record)
    _edit_record(parent, record)

func _recording_controls(parent: Control) -> void:
    UI.hint(parent, "每次最多60秒有效探索、301个样本（含起点）；最多保留最近8次。跨区、倒下、长帧和容量边界会结束本次记录。")
    UI.toggle(parent, "探索时显示录制状态", show_overlay, func(value: bool):show_overlay = value;context.refresh())
    if active.is_empty():
        var title := UI.edit(parent, "这次记录的名称", "", 50)
        UI.button(parent, "开始观察下一段探索", func():
            if not pending.is_empty():
                context.tell("请先保存或明确放弃待保存记录。")
                return
            var snapshot: Dictionary = context.snapshot()
            if not snapshot.get("player", {}).get("alive", false):
                context.tell("角色当前无法开始观察。")
                return
            active = MODEL.start(snapshot, title.text)
            context.tell("已开始；关闭设置回到探索后采样，打开菜单期间暂停。")
            context.refresh())
    else:
        UI.label(parent, "%s · 已观察%.2f秒 · 菜单暂停%.2f秒 · %d样本" % [active.name, active.duration, active.paused, active.samples.size()])
        var row := UI.row(parent)
        UI.button(row, "停止并保存观察", func():_finish("手动结束");context.refresh())
        UI.button(row, "放弃当前未保存观察", func():pending_delete = "active";context.refresh())
        if pending_delete == "active":
            var confirm := UI.row(parent)
            UI.button(confirm, "继续观察", func():pending_delete = "";context.refresh())
            UI.button(confirm, "确认放弃本次", func():active = {};pending_delete = "";context.refresh())
    if not pending.is_empty():
        var card := UI.card(parent)
        UI.label(card, "记录待保存：" + String(pending.get("name", "机动观察")))
        UI.hint(card, error)
        var row := UI.row(card)
        UI.button(row, "重试写入辅助记录", _persist_pending)
        UI.button(row, "放弃待保存记录", func():pending_delete = "pending";context.refresh())
        if pending_delete == "pending":
            UI.button(card, "确认放弃待保存内容", func():pending = {};pending_delete = "";context.refresh())

func _finish(reason: String) -> void:
    if active.is_empty():
        return
    active.reason = reason
    pending = active.duplicate(true)
    active = {}
    if is_instance_valid(overlay):
        overlay.visible = false
    if pending.samples.size() < 2:
        pending = {}
        context.tell("有效样本不足两次，本次观察未写入记录。")
        return
    _persist_pending()

func _persist_pending() -> void:
    if pending.is_empty():
        return
    var candidate := MODEL.save(data, pending)
    if candidate == data:
        error = "轨迹候选无效；保留内存样本供检查。"
        context.tell(error)
        return
    if commit(candidate):
        selected = String(candidate.runs[0].id)
        pending = {}
        retry_elapsed = 0.0
        context.tell("轨迹已保存到辅助记录。")

func _choices() -> Array:
    var result := [{"id":"", "name":"不叠加比较记录"}]
    for record in data.runs:
        result.append({"id":record.id, "name":"%s · %.1f秒 · %s" % [record.name, record.duration, record.region_name]})
    return result

func _summary(parent: Control, record: Dictionary) -> void:
    var summary := MODEL.statistics(record)
    UI.label(parent, String(record.name), true)
    UI.hint(parent, String(record.region_name) + " · " + VALUES.date(int(record.started)) + " · " + String(record.reason))
    if record.has("source_id"):
        UI.hint(parent, "此记录是既有观察的裁剪片段，保留了来源身份与原时间范围。")
    UI.label(parent, "采样%d · 路程%.1f · 起终点距离%.1f · 峰值速度%.1f" % [summary.samples, summary.distance, summary.displacement, summary.peak_speed])
    UI.label(parent, "地面%.2f秒 · 空中%.2f秒 · 起跳%d · 高度跨度%.1f" % [summary.groundtime, summary.airtime, summary.jumps, summary.height_range])
    UI.hint(parent, "采样间累计掉血%d、耗线%d、回线%d；同一间隔内相互抵消的变化不可从快照还原。" % [summary.damage_seen, summary.energy_spent_seen, summary.energy_gained_seen])
    UI.label(parent, "折线路程/观察时间 %.2f · 起终点距离/折线路程 %.3f · 最大采样间隔 %.3f秒" % [summary.get("average_speed", 0), summary.get("straightness", 0), summary.get("largest_gap", 0)])
    UI.hint(parent, "暂停菜单时间不计有效时长；路程为相邻采样点折线长度，可能低估高速折返。")

func _plot(parent: Control, record: Dictionary) -> void:
    var row := UI.row(parent)
    var metric := UI.pick(row, [{"id":"path", "name":"位移轨迹"}, {"id":"speed", "name":"速度"}, {"id":"energy", "name":"绯线"}, {"id":"height", "name":"相对高度"}], mode)
    metric.item_selected.connect(func(_index: int):mode = UI.chosen(metric);context.refresh())
    var picker := UI.pick(row, _choices(), comparison)
    picker.item_selected.connect(func(_index: int):comparison = UI.chosen(picker);context.refresh())
    var other := MODEL.get_run(data, comparison)
    var plot := PLOT.new()
    plot.configure(record, other, mode)
    parent.add_child(plot)
    if not other.is_empty():
        UI.hint(parent, "轨迹按各自起点对齐，仅比较相对运动；不同地区、构筑和战斗条件不能视为同一次计时赛。")
        for difference in MODEL.compare(record, other):
            UI.label(parent, "%s：%.2f → %.2f（%+.2f）" % [difference.name, difference.left, difference.right, difference.difference])
    UI.hint(parent, "记录按样本的实际时间间隔合计，不把菜单暂停算作移动时间。")
    UI.hint(parent, "同一段内来回折返会降低起终点距离比值，这不是动作质量评分。")
    UI.label(parent, "采样间状态变化")
    var changes := MODEL.changes(record)
    for index in mini(12, changes.size()):
        var change: Dictionary = changes[index]
        UI.hint(parent, "%.2f秒 · %s：%s → %s" % [change.time, change.kind, str(change.before), str(change.after)])
    UI.label(parent, "地面 / 空中阶段")
    var count := 0
    for segment in MODEL.segments(record):
        UI.hint(parent, "%s · %.2f–%.2f秒 · %d样本" % [segment.state, segment.start, segment.finish, segment.samples])
        count += 1
        if count >= 30:
            UI.hint(parent, "只显示前30段；完整采样可导出CSV。")
            break

func _edit_record(parent: Control, record: Dictionary) -> void:
    UI.label(parent, "裁剪既有采样为独立观察", true)
    var clipping := UI.row(parent)
    var begin := UI.spin(clipping, 0, 0, float(record.duration), 0.1)
    var finish := UI.spin(clipping, float(record.duration), 0, float(record.duration), 0.1)
    UI.button(clipping, "保存所选时间片段", func():
        var outcome := MODEL.trim(record, float(begin.value), float(finish.value), String(record.name) + "片段")
        if not outcome.get("ok", false):
            announce(outcome)
            return
        var candidate := MODEL.save(data, outcome.run)
        if candidate != data:
            commit(candidate))
    var title := UI.edit(parent, "记录名称", String(record.name), 50)
    var note := UI.memo(parent, String(record.note), 80)
    var id := String(record.id)
    var row := UI.row(parent)
    UI.button(row, "保存记录说明", func():commit(MODEL.annotate(data, id, title.text, note.text)))
    UI.button(row, "导出采样CSV", func():export_document("机动轨迹.csv", MODEL.csv(record)))
    UI.button(row, "删除记录", func():pending_delete = id;context.refresh())
    if pending_delete == id:
        var confirm := UI.row(parent)
        UI.button(confirm, "保留记录", func():pending_delete = "";context.refresh())
        UI.button(confirm, "确认删除本次记录", func():commit(MODEL.remove(data, id));pending_delete = "";selected = "")

func shutdown() -> void:
    if not active.is_empty():
        active.reason = "离开当前旅途"
        pending = active
        active = {}
    if not pending.is_empty():
        var candidate := MODEL.save(data, pending)
        if candidate != data:
            context.store.write("trajectory", candidate)
    if is_instance_valid(overlay):
        overlay.queue_free()
    overlay = null
    overlay_label = null

func restorable() -> bool:
    return active.is_empty() and pending.is_empty()
