extends "res://journey/core/feature.gd"
const MODEL := preload("res://journey/supplies/model.gd")
var observe_wait := 0.0
var tab := "plans"
var comparison := ""
var missing_only := false
var pending_remove := ""
var pending_identity := ""
var import_preview: Dictionary = {}
var inventory_query := ""
var item_page := 0
const ITEM_PAGE := 15

func descriptor() -> Dictionary:
    return {"id":"supplies", "name":"物资储备", "summary":"多份储备清单、保护库存、跨清单优先分配与缺口比较"}

func initial() -> Dictionary:
    return MODEL.fresh()

func valid(candidate: Dictionary) -> bool:
    return MODEL.valid(candidate)

func tick(snapshot: Dictionary, delta: float) -> void:
    observe_wait = maxf(0.0, observe_wait - maxf(0.0, delta))
    if snapshot.is_empty() or observe_wait > 0:
        return
    var candidate := MODEL.observe(data, snapshot)
    if candidate == data:
        return
    observe_wait = 2.0
    if context.store.write("supplies", candidate):
        data = candidate
        error = ""
    else:
        var failure: String = context.store.error
        recover_conflict()
        error = failure
        context.tell(error)


func draw(parent: Control) -> void:
    header(parent, "给已见物资设储备目标，先保护预留量，再按优先级分配。这里的分配仅用于核算，不移动实际物品。")
    var tabs := UI.row(parent)
    for pair in [["plans", "储备清单"], ["stock", "已见库存"], ["compare", "清单比较"], ["transfer", "导入 / 导出"]]:
        var id := String(pair[0])
        UI.button(tabs, String(pair[1]), func():tab = id;context.refresh())
    if tab == "stock":
        _stock(parent)
    elif tab == "compare":
        _compare(parent)
    elif tab == "transfer":
        _transfer(parent)
    else:
        _plans(parent)

func _inventory() -> Dictionary:
    return context.latest.get("inventory", {}).duplicate(true)

func _choices() -> Array:
    var result := []
    for record in data.packs:
        result.append({"id":record.id, "name":record.name})
    return result

func _current() -> String:
    if not selected.is_empty() and not MODEL.pack(data, selected).is_empty():
        return selected
    selected = String(data.get("selected", ""))
    if MODEL.pack(data, selected).is_empty() and not data.packs.is_empty():
        selected = String(data.packs[0].id)
    return selected

func _plans(parent: Control) -> void:
    var create_row := UI.row(parent)
    var name := UI.edit(create_row, "新清单名称（最多8份）", "", 40)
    UI.button(create_row, "建立清单", func():
        var candidate := MODEL.create(data, name.text)
        if candidate == data:
            context.tell("请使用未重复的名称；最多保留8份清单。")
        elif commit(candidate):
            selected = String(candidate.selected))
    if data.packs.is_empty():
        UI.hint(parent, "先建立一份旅行、战具补给或工匠成长的物资清单。")
        return
    var picker := UI.pick(parent, _choices(), _current())
    picker.item_selected.connect(func(_index: int):
        var candidate := data.duplicate(true)
        candidate.selected = UI.chosen(picker)
        if commit(candidate):
            selected = String(candidate.selected)
            pending_remove = "")
    var record := MODEL.pack(data, _current())
    var summary := MODEL.summary(data, _inventory(), String(record.id))
    UI.label(parent, "目标 %d · 可分配 %d · 缺口 %d · 完备条目 %d" % [summary.requested, summary.allocated, summary.missing, summary.complete])
    UI.progress(parent, float(summary.allocated), float(summary.requested))
    _pack_tools(parent, record)
    UI.divider(parent)
    _add_line(parent, record)
    UI.toggle(parent, "只看未满足目标", missing_only, func(value: bool):missing_only = value;context.refresh())
    var available: Dictionary = {}
    for row in summary.rows:
        available[row.item] = row
    for entry in record.lines:
        if missing_only and (entry.done or int(available.get(entry.item, {}).get("missing", 0)) == 0):
            continue
        _line_card(parent, record, entry, available.get(entry.item, {}))
    if record.lines.is_empty():
        UI.hint(parent, "清单尚无物资。可添加已在旅途中持有过的物资，不会提前列出未知物品。")
    var memo := UI.memo(parent, String(record.note), 80)
    UI.button(parent, "保存清单备注", func():commit(MODEL.note(data, String(record.id), memo.text)))

func _pack_tools(parent: Control, record: Dictionary) -> void:
    var row := UI.row(parent)
    var title := UI.edit(row, "清单名称", String(record.name), 40)
    UI.button(row, "更名", func():commit(MODEL.rename(data, String(record.id), title.text)))
    UI.button(row, "复制为新清单", func():
        var candidate := MODEL.duplicate_pack(data, String(record.id), title.text)
        if candidate == data:
            context.tell("复制时请先输入一个新名称。")
        elif commit(candidate):
            selected = String(candidate.selected))
    var order := UI.row(parent)
    UI.button(order, "优先于上一清单", func():commit(MODEL.reorder(data, String(record.id), -1)))
    UI.button(order, "移到下一清单之后", func():commit(MODEL.reorder(data, String(record.id), 1)))
    UI.button(order, "删除清单", func():
        pending_remove = String(record.id)
        pending_identity = VALUES.fingerprint(record)
        context.refresh())
    if pending_remove == String(record.id):
        var confirm := UI.card(parent)
        UI.label(confirm, "确认删除「%s」及其中的规划备注？实际库存不受影响。" % record.name)
        var buttons := UI.row(confirm)
        UI.button(buttons, "保留清单", func():pending_remove = "";context.refresh())
        UI.button(buttons, "确认删除", func():
            if VALUES.fingerprint(MODEL.pack(data, pending_remove)) != pending_identity:
                pending_remove = ""
                context.tell("清单已变化，请重新核对。")
                context.refresh()
                return
            commit(MODEL.remove(data, pending_remove))
            pending_remove = ""
            selected = "")

func _add_line(parent: Control, record: Dictionary) -> void:
    UI.label(parent, "添加 / 更新目标")
    var choices := []
    for item in MODEL.items(data, _inventory()):
        choices.append({"id":item.id, "name":"%s · 当前%d" % [item.name, item.held]})
    if choices.is_empty():
        UI.hint(parent, "当前尚无已见物资，取得物资后会记录可规划的名称。")
        return
    var row := UI.row(parent)
    var picker := UI.pick(row, choices)
    var amount := UI.spin(row, 1, 1, 9999)
    var priority := UI.pick(row, [{"id":"0", "name":"急需"}, {"id":"1", "name":"备用"}, {"id":"2", "name":"长期"}], "1")
    UI.button(row, "更新目标", func():
        var candidate := MODEL.line(data, String(record.id), UI.chosen(picker), int(amount.value), int(UI.chosen(priority)))
        if candidate == data:
            context.tell("数量未变化或该清单已满24种物资。")
        else:
            commit(candidate))

func _line_card(parent: Control, record: Dictionary, entry: Dictionary, allocation: Dictionary) -> void:
    var card := UI.card(parent)
    var title := String(data.seen.get(entry.item, "旧物资"))
    UI.label(card, "%s · %s" % [title, MODEL.PRIORITIES[int(entry.priority)]])
    if entry.done:
        UI.hint(card, "已手动结束此目标，不参与分配。")
    else:
        UI.label(card, "目标 %d / 可分配 %d / 缺 %d" % [entry.target, allocation.get("allocated", 0), allocation.get("missing", entry.target)])
        UI.progress(card, float(allocation.get("allocated", 0)), float(entry.target))
    var actions := UI.row(card)
    UI.button(actions, "重新纳入规划" if entry.done else "手动结束目标", func():commit(MODEL.set_done(data, String(record.id), String(entry.item), not bool(entry.done))))
    UI.button(actions, "移除此项", func():commit(MODEL.remove_line(data, String(record.id), String(entry.item))))

func _stock(parent: Control) -> void:
    UI.label(parent, "保护库存与全部清单的合计需求", true)
    var search_row := UI.row(parent)
    var query := UI.edit(search_row, "搜索已见物资", inventory_query)
    UI.button(search_row, "筛选", func():inventory_query = query.text;item_page = 0;context.refresh())
    var items := MODEL.items(data, _inventory(), inventory_query)
    var allocation := MODEL.allocate(data, _inventory())
    var audit := MODEL.audit(data, _inventory(), allocation)
    UI.hint(parent, "库存守恒复核通过：每份库存最多分配一次。" if audit.ok else "分配复核失败：" + " / ".join(audit.errors))
    item_page = clampi(item_page, 0, maxi(0, (items.size() - 1) / ITEM_PAGE))
    var navigation := UI.row(parent)
    UI.button(navigation, "上一页", func():item_page -= 1;context.refresh(), item_page == 0)
    UI.label(navigation, "%d / %d 项" % [mini(items.size(), (item_page + 1) * ITEM_PAGE), items.size()])
    UI.button(navigation, "下一页", func():item_page += 1;context.refresh(), (item_page + 1) * ITEM_PAGE >= items.size())
    for index in range(item_page * ITEM_PAGE, mini(items.size(), (item_page + 1) * ITEM_PAGE)):
        var item: Dictionary = items[index]
        var total: Dictionary = allocation.totals.get(item.id, {})
        var card := UI.card(parent)
        UI.label(card, String(item.name))
        UI.hint(card, "持有%d · 预留%d · 合计目标%d · 缺%d · 规划余量%d" % [item.held, item.reserve, total.get("requested", 0), total.get("missing", 0), allocation.remaining.get(item.id, 0)])
        var row := UI.row(card)
        UI.label(row, "不参与分配的预留量")
        var value := UI.spin(row, float(item.reserve), 0, 9999)
        UI.button(row, "保存预留", func():commit(MODEL.reserve(data, String(item.id), int(value.value))))
    if items.is_empty():
        UI.hint(parent, "没有符合条件的已见物资。")

func _compare(parent: Control) -> void:
    UI.label(parent, "比较两份清单的目标量", true)
    UI.hint(parent, "这里比较请求数量；实际跨清单分配请回储备页查看，避免把同一份库存重复计算。")
    if data.packs.size() < 2:
        UI.hint(parent, "至少建立两份清单后可比较。")
        return
    if comparison.is_empty() or MODEL.pack(data, comparison).is_empty():
        comparison = String(data.packs[-1].id)
    var row := UI.row(parent)
    var left := UI.pick(row, _choices(), _current())
    var right := UI.pick(row, _choices(), comparison)
    UI.button(row, "比较", func():selected = UI.chosen(left);comparison = UI.chosen(right);context.refresh())
    for difference in MODEL.compare(data, _current(), comparison):
        var card := UI.card(parent)
        UI.label(card, "%s：%d → %d（%+d）" % [difference.name, difference.left, difference.right, difference.difference])
    UI.hint(parent, "相同物资按身份合并；差值为右侧清单减左侧清单。")

func _transfer(parent: Control) -> void:
    UI.label(parent, "可携带的规划清单", true)
    UI.hint(parent, "导入只接受当前已见物资和有效整数目标；不会授予物资，也不会安装游戏存档。")
    UI.button(parent, "导出全部清单与缺口报告", func():export_document("物资储备.txt", MODEL.document(data, _inventory())))
    if not data.packs.is_empty():
        var picker := UI.pick(parent, _choices(), _current())
        UI.button(parent, "导出选中清单 JSON", func():
            var record := MODEL.pack(data, UI.chosen(picker))
            var document := {"version":1, "lines":record.get("lines", [])}
            export_document("物资清单.json", JSON.stringify(document, "  ")))
    var title := UI.edit(parent, "导入后使用的新名称", "", 40)
    var raw := UI.memo(parent, "", 120)
    UI.button(parent, "检查导入内容", func():
        import_preview = MODEL.import_pack(data, raw.text, title.text)
        import_preview["source"] = VALUES.fingerprint(data)
        context.tell(String(import_preview.reason))
        context.refresh())
    if import_preview.get("ok", false):
        var preview := UI.card(parent)
        var candidate: Dictionary = import_preview.data
        var record := MODEL.pack(candidate, String(candidate.selected))
        UI.label(preview, "将新增「%s」，共%d项" % [record.name, record.lines.size()])
        var actions := UI.row(preview)
        UI.button(actions, "放弃导入", func():import_preview = {};context.refresh())
        UI.button(actions, "确认保存清单", func():
            if VALUES.fingerprint(data) != String(import_preview.source):
                import_preview = {}
                context.tell("规划记录已变化，请重新检查导入内容。")
                context.refresh()
                return
            if commit(import_preview.data):
                selected = String(import_preview.data.selected)
                import_preview = {})
