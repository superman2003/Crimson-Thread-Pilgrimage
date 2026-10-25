extends "res://journey/core/feature.gd"
const MODEL := preload("res://journey/chronicle/model.gd")
var kind := "all"
var favorites_only := false
var newest := true
var dirty := false
var save_elapsed := 0.0
var page := 0
const PAGE_SIZE := 12

func descriptor() -> Dictionary:
    return {"id":"chronicle", "name":"行旅编年", "summary":"实际抵达记录、成长时刻、收藏与逐条手记"}

func initial() -> Dictionary:
    return MODEL.fresh()

func valid(candidate: Dictionary) -> bool:
    return MODEL.valid(candidate)

func tick(snapshot: Dictionary, delta: float) -> void:
    if snapshot.is_empty():
        return
    save_elapsed += delta
    if dirty and save_elapsed < 5.0:
        return
    var candidate := MODEL.observe(data, snapshot)
    if candidate != data:
        save_elapsed = 0.0
        # Publish only after the auxiliary write succeeds; retry failures slowly.
        if context.store.write("chronicle", candidate):
            data = candidate
            dirty = false
            error = ""
        else:
            dirty = true
            error = context.store.error

func draw(parent: Control) -> void:
    header(parent, "从工作台启用时开始记录实际抵达和成长；不会追补未观察的经历，也不改变游戏进度。")
    var stats := MODEL.statistics(data)
    UI.label(parent, "%d 条记录 · %d 地区 · %d 房间 · %d 收藏 · %d 手记" % [data.events.size(), stats.regions, stats.rooms, stats.favorites, stats.notes])
    var controls := UI.row(parent)
    var query := UI.edit(controls, "搜索标题、地点或手记", search)
    UI.button(controls, "搜索", func():search = query.text;page = 0;context.refresh())
    var options := UI.row(parent)
    var choices := [{"id":"all", "name":"全部类型"}]
    for id in MODEL.KINDS:
        choices.append({"id":id, "name":MODEL.KINDS[id]})
    var picker := UI.pick(options, choices, kind)
    picker.item_selected.connect(func(_index: int):kind = UI.chosen(picker);page = 0;context.refresh())
    UI.toggle(options, "仅收藏", favorites_only, func(value: bool):favorites_only = value;page = 0;context.refresh())
    UI.toggle(options, "最新在前", newest, func(value: bool):newest = value;context.refresh())
    var rows := MODEL.records(data, search, kind, favorites_only, newest)
    page = clampi(page, 0, maxi(0, (rows.size() - 1) / PAGE_SIZE))
    UI.hint(parent, "第 %d 页 · 当前筛选 %d 条；最多保留最近 %d 条，旧记录淘汰时一并清理其手记。" % [page + 1, rows.size(), MODEL.LIMIT])
    var navigation := UI.row(parent)
    UI.button(navigation, "上一页", func():page -= 1;context.refresh(), page == 0)
    UI.button(navigation, "下一页", func():page += 1;context.refresh(), (page + 1) * PAGE_SIZE >= rows.size())
    UI.button(navigation, "导出筛选结果", func():export_document("行旅编年.txt", MODEL.document(data, search, kind)))
    for index in range(page * PAGE_SIZE, mini(rows.size(), (page + 1) * PAGE_SIZE)):
        _event_card(parent, rows[index])
    if rows.is_empty():
        UI.hint(parent, "尚无符合条件的观察。回到旅途中抵达房间，或添加一则手记。")
    UI.divider(parent)
    UI.label(parent, "写下此刻", true)
    var draft := UI.edit(parent, "手记标题", "", 120)
    var note := UI.memo(parent, "", 80)
    UI.button(parent, "记入当前旅途", func():
        if VALUES.text(draft.text, 120).is_empty():
            context.tell("请先写下标题。")
            return
        var candidate := MODEL.append(data, "note", draft.text, context.snapshot())
        candidate = MODEL.annotate(candidate, str(int(candidate.sequence)), note.text, false)
        commit(candidate))

func _event_card(parent: Control, event: Dictionary) -> void:
    var card := UI.card(parent)
    UI.label(card, ("★ " if event.favorite else "") + String(event.title))
    UI.hint(card, VALUES.date(int(event.time)) + " · " + String(MODEL.KINDS[event.kind]) + " · " + String(event.get("region_name", "")))
    var id := str(int(event.id))
    if selected == id:
        var memo := UI.memo(card, String(event.note), 90)
        var actions := UI.row(card)
        UI.button(actions, "保存手记", func():commit(MODEL.annotate(data, id, memo.text, bool(event.favorite))))
        UI.button(actions, "取消收藏" if event.favorite else "收藏", func():commit(MODEL.annotate(data, id, memo.text, not bool(event.favorite))))
        UI.button(actions, "收起", func():selected = "";context.refresh())
    else:
        if not String(event.note).is_empty():
            UI.label(card, String(event.note))
        UI.button(card, "编辑手记 / 收藏", func():selected = id;context.refresh())
