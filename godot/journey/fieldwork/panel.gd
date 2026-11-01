extends "res://journey/core/feature.gd"
const RECORDS := preload("res://journey/fieldwork/records.gd")
const KNOW := preload("res://journey/fieldwork/knowledge.gd")
var domain: Script
var tab := "current"
var selected_id := 0
var compare_id := 0
var favorites := false
var page := 0
var undo_stack: Array = []
var redo_stack: Array = []
var import_candidate: Dictionary = {}
var draft: Dictionary = {}
var draft_title := ""
var draft_note := ""
var draft_favorite := false
var pending_remove := 0
const PAGE_SIZE := 8


func initial() -> Dictionary:
    return RECORDS.fresh()


func valid(candidate: Dictionary) -> bool:
    return domain != null and RECORDS.valid(candidate, domain.validate)


func save_candidate(candidate: Dictionary) -> bool:
    if not valid(candidate):
        context.tell("候选记录未通过功能字段检查。")
        return false
    if candidate.records.size() > maxi(record_limit(), data.get("records", []).size()):
        context.tell("新增记录超过此功能容量；已有旧记录仍可查看、编辑或删除。")
        return false
    if candidate == data:
        context.tell("没有需要保存的变化。")
        return false
    var before := data.duplicate(true)
    if not commit(candidate):
        return false
    undo_stack.append(before)
    if undo_stack.size() > 12:
        undo_stack.pop_front()
    redo_stack.clear()
    return true


func draw(parent: Control) -> void:
    header(parent, String(domain.introduction()))
    var tabs := UI.row(parent)
    for item in [["current", "当前分析"], ["records", "记录库"], ["editor", "编辑候选"], ["transfer", "导入导出"]]:
        var id := String(item[0])
        UI.button(
            tabs,
            String(item[1]),
            func():
                tab = id
                context.refresh()
        )
    var actions := UI.row(parent)
    UI.button(actions, "撤销", undo, undo_stack.is_empty())
    UI.button(actions, "重做", redo, redo_stack.is_empty())
    UI.hint(actions, "%d / %d 份辅助记录" % [data.records.size(), record_limit()])
    match tab:
        "records":
            _library(parent)
        "editor":
            _editor(parent)
        "transfer":
            _transfer(parent)
        _:
            _current(parent)


func _current(parent: Control) -> void:
    var snapshot: Dictionary = context.snapshot()
    var current: Dictionary = domain.capture(snapshot)
    if not domain.validate(current):
        UI.hint(parent, "当前资料尚不足以生成有效记录。")
        return
    UI.button(
        parent,
        "以当前状态建立候选",
        func():
            draft = current.duplicate(true)
            draft_title = (
                String(descriptor().name) + " · " + String(snapshot.get("region_name", "旅途"))
            )
            draft_note = ""
            draft_favorite = false
            selected_id = 0
            tab = "editor"
            context.refresh()
    )
    _sections(parent, domain.analyze(current, snapshot))
    if domain.has_method("svg"):
        UI.button(
            parent,
            "导出当前分析SVG",
            func(): export_document(String(descriptor().id) + ".svg", domain.svg(current))
        )


func _library(parent: Control) -> void:
    var row := UI.row(parent)
    var query := UI.edit(row, "搜索记录标题或手记", search)
    UI.button(
        row,
        "搜索",
        func():
            search = query.text
            page = 0
            context.refresh()
    )
    UI.toggle(
        row,
        "仅收藏",
        favorites,
        func(value: bool):
            favorites = value
            page = 0
            context.refresh()
    )
    var records := RECORDS.query(data, search, favorites)
    page = clampi(page, 0, maxi(0, (records.size() - 1) / PAGE_SIZE))
    var nav := UI.row(parent)
    UI.button(
        nav,
        "上一页",
        func():
            page -= 1
            context.refresh(),
        page == 0
    )
    UI.label(nav, "第%d页 · %d份" % [page + 1, records.size()])
    UI.button(
        nav,
        "下一页",
        func():
            page += 1
            context.refresh(),
        (page + 1) * PAGE_SIZE >= records.size()
    )
    for index in range(page * PAGE_SIZE, mini(records.size(), (page + 1) * PAGE_SIZE)):
        var record: Dictionary = records[index]
        var card := UI.card(parent)
        UI.label(card, ("★ " if record.favorite else "") + String(record.title), true)
        UI.hint(card, VALUES.date(int(record.updated)))
        UI.label(card, String(domain.summary(record.payload)))
        if not String(record.note).is_empty():
            UI.hint(card, String(record.note))
        var tools := UI.row(card)
        var id := int(record.id)
        UI.button(tools, "编辑", func(): _select_record(id))
        UI.button(
            tools,
            "比较",
            func():
                compare_id = id
                context.refresh()
        )
        UI.button(
            tools,
            "复制",
            func():
                save_candidate(RECORDS.append(data, String(record.title) + " 副本", record.payload))
        )
        UI.button(
            tools,
            "整理",
            func():
                pending_remove = id
                context.refresh()
        )
        if compare_id == id:
            _compare(card, record)
            UI.button(
                card,
                "收起比较",
                func():
                    compare_id = 0
                    context.refresh()
            )
        if pending_remove == id:
            UI.hint(card, "移除此份辅助记录；不改变游戏进度。可在本次工作台会话撤销。")
            UI.button(
                card,
                "确认移除",
                func():
                    save_candidate(RECORDS.remove(data, id))
                    pending_remove = 0
            )
            UI.button(
                card,
                "保留",
                func():
                    pending_remove = 0
                    context.refresh()
            )
    if records.is_empty():
        UI.hint(parent, "尚无符合条件的记录。可从当前分析页建立一份候选。")


func _compare(parent: Control, record: Dictionary) -> void:
    var current: Dictionary = domain.capture(context.snapshot())
    if not domain.validate(current):
        context.tell("当前状态尚不能比较。")
        return
    var card := UI.card(parent)
    UI.label(card, "记录与当前状态的差异", true)
    _sections(card, domain.compare(record.payload, current))


func _select_record(id: int) -> void:
    var record := RECORDS.find(data, id)
    if record.is_empty():
        return
    selected_id = id
    draft = record.payload.duplicate(true)
    draft_title = String(record.title)
    draft_note = String(record.note)
    draft_favorite = bool(record.favorite)
    tab = "editor"
    context.refresh()


func _editor(parent: Control) -> void:
    if draft.is_empty():
        UI.hint(parent, "先从当前分析建立候选，或选择一份记录。")
        return
    UI.button(
        parent,
        "取消编辑候选",
        func():
            draft = {}
            selected_id = 0
            tab = "records"
            context.refresh()
    )
    var title := UI.edit(parent, "记录标题", draft_title, 100)
    title.text_changed.connect(func(value: String): draft_title = value)
    var note := UI.memo(parent, draft_note, 80)
    note.text_changed.connect(func(): draft_note = note.text.left(2000))
    UI.toggle(parent, "收藏", draft_favorite, func(value: bool): draft_favorite = value)
    UI.hint(parent, "原始观察字段保留。以下参数只影响这份分析记录，不改变角色或世界。")
    for field in domain.fields(draft):
        _field(parent, field)
    UI.button(parent, "预览候选分析", func(): context.refresh())
    if domain.validate(draft):
        _sections(parent, domain.analyze(draft, context.snapshot()))
        if domain.has_method("svg"):
            UI.button(
                parent,
                "导出此候选SVG",
                func(): export_document(String(descriptor().id) + "_候选.svg", domain.svg(draft))
            )
    UI.button(
        parent,
        "保存此候选",
        _save_draft,
        not domain.validate(draft) or draft_title.strip_edges().is_empty()
    )


func _field(parent: Control, field: Dictionary) -> void:
    var key := String(field.id)
    var row := UI.row(parent)
    UI.label(row, String(field.get("name", key)))
    match String(field.get("kind", "text")):
        "notes":
            var box := UI.column(row)
            for choice in field.get("choices", []):
                var id := String(choice.id)
                UI.label(box, String(choice.name))
                var memo := UI.memo(box, String(draft.get(key, {}).get(id, "")), 85)
                memo.text_changed.connect(
                    func():
                        var values: Dictionary = draft.get(key, {}).duplicate()
                        values[id] = memo.text.left(int(field.get("max", 1000)))
                        draft[key] = values
                )
        "ordered":
            var box := UI.column(row)
            var pick := UI.pick(box, field.get("choices", []))
            UI.button(
                box,
                "加入末尾",
                func():
                    var value := UI.chosen(pick)
                    var list: Array = draft.get(key, []).duplicate()
                    if value.is_empty() or list.size() >= int(field.get("limit", 32)):
                        return
                    if not bool(field.get("allow_duplicates", false)) and list.has(value):
                        return
                    list.append(value)
                    draft[key] = list
                    context.refresh(),
                pick.item_count == 0
            )
            var list: Array = draft.get(key, [])
            for i in list.size():
                var offset := i
                var line := UI.row(box)
                var caption := String(list[i])
                for choice in field.get("choices", []):
                    if choice.id == list[i]:
                        caption = String(choice.name)
                UI.label(line, str(i + 1) + " · " + caption)
                UI.button(line, "↑", func(): _move_list(key, offset, -1), i == 0)
                UI.button(line, "↓", func(): _move_list(key, offset, 1), i == list.size() - 1)
                UI.button(
                    line,
                    "移除",
                    func():
                        var values: Array = draft.get(key, []).duplicate()
                        values.remove_at(offset)
                        draft[key] = values
                        context.refresh()
                )
        "weights":
            var box := UI.column(row)
            for choice in field.get("choices", []):
                var id := String(choice.id)
                var line := UI.row(box)
                UI.label(line, String(choice.name))
                var spin := UI.spin(
                    line,
                    KNOW.safe_number(draft.get(key, {}).get(id, field.get("default", 0))),
                    float(field.get("min", 0)),
                    float(field.get("max", 100)),
                    float(field.get("step", 1))
                )
                spin.value_changed.connect(
                    func(value: float):
                        var values: Dictionary = draft.get(key, {}).duplicate()
                        values[id] = value
                        draft[key] = values
                )
        "checklist":
            var box := UI.column(row)
            for choice in field.get("choices", []):
                var id := String(choice.id)
                UI.toggle(
                    box,
                    String(choice.name),
                    draft.get(key, []).has(id),
                    func(value: bool):
                        var values: Array = draft.get(key, []).duplicate()
                        values.erase(id)
                        if value:
                            if values.size() >= int(field.get("limit", 1000000)):
                                context.tell("已达到选择数量上限。")
                                context.refresh()
                                return
                            values.append(id)
                        draft[key] = values
                )
        "number":
            var spin := UI.spin(
                row,
                KNOW.safe_number(draft.get(key)),
                float(field.get("min", 0)),
                float(field.get("max", 100000)),
                float(field.get("step", 1))
            )
            spin.value_changed.connect(func(value: float): draft[key] = value)
        "toggle":
            UI.toggle(row, "启用", bool(draft.get(key, false)), func(value: bool): draft[key] = value)
        "choice":
            var pick := UI.pick(row, field.get("choices", []), String(draft.get(key, "")))
            pick.item_selected.connect(
                func(_index: int):
                    draft[key] = UI.chosen(pick)
                    if domain.has_method("field_changed"):
                        draft = domain.field_changed(draft, key)
                    context.refresh()
            )
        _:
            var line := UI.edit(
                row,
                String(field.get("hint", "")),
                String(draft.get(key, "")),
                int(field.get("max", 200))
            )
            line.text_changed.connect(func(value: String): draft[key] = value)


func _save_draft() -> void:
    if not domain.validate(draft):
        return
    var next: Dictionary
    var candidate_id := selected_id
    if selected_id == 0:
        if data.records.size() >= record_limit():
            context.tell("已达到本功能的记录数量上限。")
            return
        next = RECORDS.append(data, draft_title, draft)
        if next == data:
            context.tell("记录库已满，先整理现有记录。")
            return
        candidate_id = int(next.sequence)
    else:
        if RECORDS.find(data, selected_id).is_empty():
            selected_id = 0
            context.tell("所选记录已被撤销或移除；候选已保留，请再次保存为新记录。")
            return
        next = data.duplicate(true)
    next = RECORDS.replace(next, candidate_id, draft_title, draft_note, draft_favorite, draft)
    if save_candidate(next):
        selected_id = candidate_id
        context.tell("辅助记录已保存。")


func _transfer(parent: Control) -> void:
    UI.hint(parent, "导入只接受同存档槽、同功能的记录；先检查候选，再明确合并。新记录上限%d份，不会替换游戏主档。" % record_limit())
    UI.button(
        parent,
        "导出本功能记录",
        func():
            export_document(
                String(descriptor().id) + ".json",
                RECORDS.export_package(data, String(descriptor().id), context.store.scope)
            )
    )
    var source := UI.memo(parent, "", 160)
    UI.button(
        parent,
        "检查导入文本",
        func():
            var checked := RECORDS.import_package(
                source.text, String(descriptor().id), context.store.scope, domain.validate
            )
            import_candidate = checked.get("data", {})
            context.tell(String(checked.reason))
            context.refresh()
    )
    if import_candidate.is_empty():
        return
    var outcome := RECORDS.merge(data, import_candidate)
    UI.label(parent, "已检查 %d 份输入记录" % [import_candidate.records.size()])
    if outcome.get("ok", false):
        for difference in RECORDS.difference(data, outcome.data):
            UI.hint(parent, String(difference.kind) + " · " + String(difference.title))
        UI.button(
            parent,
            "确认合并导入",
            func():
                if save_candidate(outcome.data):
                    import_candidate = {}
        )
    else:
        UI.hint(parent, String(outcome.reason))
    UI.button(
        parent,
        "取消导入候选",
        func():
            import_candidate = {}
            context.refresh()
    )


func _sections(parent: Control, sections: Array) -> void:
    for section in sections:
        var card := UI.card(parent)
        UI.label(card, String(section.get("title", "分析")), true)
        match String(section.get("kind", "text")):
            "custom":
                var view: Control = section.view.new()
                view.configure(section.get("data", {}))
                card.add_child(view)
                if view.has_signal("edit_requested"):
                    view.connect("edit_requested", _edit_requested)
            "table":
                var columns: Array = section.get("columns", [])
                for record in section.get("rows", []).slice(0, 80):
                    var cells: Array[String] = []
                    for column in columns:
                        cells.append(String(column) + "：" + KNOW.describe(record.get(column, "")))
                    UI.label(card, " · ".join(cells))
                if section.get("rows", []).size() > 80:
                    UI.hint(card, "显示前80行，完整数据可通过导出保留。")
            "bars":
                var maximum := 1.0
                for record in section.get("rows", []):
                    maximum = maxf(maximum, absf(KNOW.safe_number(record.get("value"))))
                for record in section.get("rows", []).slice(0, 40):
                    UI.label(
                        card, String(record.get("label", "")) + " · " + str(record.get("value", 0))
                    )
                    UI.progress(card, absf(KNOW.safe_number(record.get("value"))), maximum)
            _:
                UI.label(card, String(section.get("text", "")))
        if not String(section.get("note", "")).is_empty():
            UI.hint(card, String(section.note))


func undo() -> void:
    if undo_stack.is_empty():
        return
    var candidate: Dictionary = undo_stack[-1]
    var previous := data.duplicate(true)
    if commit(candidate):
        undo_stack.pop_back()
        redo_stack.append(previous)


func redo() -> void:
    if redo_stack.is_empty():
        return
    var candidate: Dictionary = redo_stack[-1]
    var previous := data.duplicate(true)
    if commit(candidate):
        redo_stack.pop_back()
        undo_stack.append(previous)


func restorable() -> bool:
    return draft.is_empty() and import_candidate.is_empty()


func _move_list(key: String, index: int, direction: int) -> void:
    var values: Array = draft.get(key, []).duplicate()
    var next := index + direction
    if index < 0 or next < 0 or index >= values.size() or next >= values.size():
        return
    var value: Variant = values[index]
    values[index] = values[next]
    values[next] = value
    draft[key] = values
    context.refresh()


func _edit_requested(_payload: Dictionary, _id: String) -> void:
    context.tell("请在编辑候选中保存个人记录。")


func record_limit() -> int:
    return int(domain.get_script_constant_map().get("RECORD_LIMIT", RECORDS.LIMIT)) if domain != null else RECORDS.LIMIT


func storage_reloaded() -> void:
    selected_id = 0
    compare_id = 0
    undo_stack.clear()
    redo_stack.clear()
