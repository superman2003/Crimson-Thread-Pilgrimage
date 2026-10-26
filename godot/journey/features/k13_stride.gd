extends "res://journey/core/feature.gd"
const MODEL := preload("res://journey/k_trials/k13_stride/profile.gd")
const ENGINE := preload("res://journey/k_trials/engine.gd")
const PAGE_SIZE := 8
var run: Dictionary = {}
var pending := false
var retry_elapsed := 0.0
var state_filter := "all"
var page := 0
var draft_target := MODEL.DEFAULT

func descriptor() -> Dictionary:
    return {
        "id":"k13_stride",
        "name":MODEL.TITLE,
        "summary":MODEL.DESCRIPTION,
    }

func initial() -> Dictionary:
    return MODEL.fresh()

func valid(candidate: Dictionary) -> bool:
    return MODEL.valid(candidate)

func setup(value: RefCounted) -> void:
    super.setup(value)
    draft_target = float(data.target)

func tick(snapshot: Dictionary, delta: float) -> void:
    if run.is_empty():
        return
    if run.state == "active" and not snapshot.is_empty():
        run = ENGINE.step(run, snapshot, delta)
        if run.state != "active":
            pending = true
            retry_elapsed = 5.0
    if not pending:
        return
    if is_finite(delta) and delta > 0:
        retry_elapsed += minf(delta, 0.5)
    if retry_elapsed < 5.0 or not context.editable():
        return
    retry_elapsed = 0.0
    var candidate := MODEL.append(data, run, int(Time.get_unix_time_from_system()))
    if commit(candidate):
        pending = false
        context.tell("本次观察已写入独立辅助记录。")

func start() -> void:
    if pending or (not run.is_empty() and run.state == "active"):
        return
    var candidate := MODEL.start(data, context.snapshot())
    if candidate.is_empty():
        context.tell("当前观察不适合开始；请回到存活旅途并满足起点条件。")
        return
    run = candidate
    context.refresh()

func cancel_attempt() -> void:
    if run.is_empty() or run.state != "active":
        return
    run = ENGINE.cancel(run)
    pending = true
    retry_elapsed = 5.0
    context.refresh()

func draw(parent: Control) -> void:
    header(parent, MODEL.DESCRIPTION)
    UI.hint(parent, "观察频率约每秒十次；两次观察之间的损伤或动作可能无法辨认。菜单期间暂停累计，卡顿、切槽及异常数据均不会计为通过。")
    UI.hint(parent, "不修改生命、绯线、物资、敌人或主档；完成只记录在辅助文件。切换页签与关闭工作台后继续观察。")
    var controls := UI.row(parent)
    var goal := UI.spin(controls, draft_target, MODEL.MINIMUM, MODEL.MAXIMUM, 1)
    goal.value_changed.connect(func(value: float):draft_target = value)
    var busy: bool = pending or (not run.is_empty() and run.state == "active")
    UI.button(controls, "保存下次目标", func():commit(MODEL.configure(data, draft_target)), busy)
    UI.button(controls, "开始观察", start, busy)
    UI.button(controls, "结束本次", cancel_attempt, run.is_empty() or run.get("state") != "active")
    UI.label(parent, "已保存目标：%.0f %s" % [data.target, MODEL.UNIT])
    if run.is_empty():
        UI.hint(parent, "尚未开始。先保存目标，再开始并返回旅途。")
    else:
        UI.label(parent, "状态：%s · %.2f / %.2f %s" % [run.state, run.progress, run.target, MODEL.UNIT], true)
        UI.progress(parent, run.progress, run.target)
        UI.hint(parent, "有效观察 %.2f 秒 · %d 次采样 · %d 次暂停 · %d 次间断" % [run.elapsed, run.samples, run.paused, run.gaps])
        if not String(run.reason).is_empty():
            UI.label(parent, String(run.reason))
    if pending:
        UI.hint(parent, "记录尚未保存；失败后每五秒重试。请保留当前旅途以便完成保存。")
    UI.divider(parent)
    UI.label(parent, "最近观察记录", true)
    var filters := UI.row(parent)
    var query := UI.edit(filters, "地区、房间或结束原因", search)
    UI.button(filters, "筛选", func():search = query.text;page = 0;context.refresh())
    var choice := UI.pick(filters, [
        {"id":"all","name":"全部"},
        {"id":"passed","name":"已完成"},
        {"id":"failed","name":"未完成"},
        {"id":"cancelled","name":"已结束"},
        {"id":"interrupted","name":"已中断"},
    ], state_filter)
    choice.item_selected.connect(func(_i: int):state_filter = UI.chosen(choice);page = 0;context.refresh())
    var rows := MODEL.records(data, search, state_filter)
    page = clampi(page, 0, maxi(0, (rows.size() - 1) / PAGE_SIZE))
    var navigation := UI.row(parent)
    UI.button(navigation, "上一页", func():page -= 1;context.refresh(), page <= 0)
    UI.button(navigation, "下一页", func():page += 1;context.refresh(), (page+1)*PAGE_SIZE >= rows.size())
    UI.button(navigation, "导出筛选记录", func():export_document("k13_stride.txt", MODEL.document(data, search, state_filter)))
    UI.hint(parent, "第 %d 页 · %d 条匹配 · 最多保留 %d 条；不会删除主档。" % [page+1, rows.size(), MODEL.HISTORY_LIMIT])
    for index in range(page*PAGE_SIZE, mini(rows.size(), (page+1)*PAGE_SIZE)):
        var r: Dictionary = rows[index]
        var card := UI.card(parent)
        UI.label(card, "%s · %.2f / %.2f %s" % [r.state, r.progress, r.target, MODEL.UNIT])
        UI.hint(card, VALUES.date(int(r.time)) + " · " + String(r.region) + "/" + String(r.room))
        UI.label(card, String(r.reason))
    if rows.is_empty():
        UI.hint(parent, "没有符合当前筛选的已结束记录。")

func storage_reloaded() -> void:
    # Preserve the active observation after another process publishes history.
    draft_target = float(data.target)
    page = 0
