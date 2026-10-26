extends "res://journey/core/feature.gd"
const ARCHIVE := preload("res://journey/backups/archive.gd")
var archive := ARCHIVE.new()
var quote: Dictionary = {}
var prepared: Dictionary = {}
var opened: Dictionary = {}
var opened_path := ""
var tab := "create"
var pending_restore: Dictionary = {}
var pending_delete: Dictionary = {}
var component_id := ""
var import_preview: Dictionary = {}

func descriptor() -> Dictionary:
    return {"id":"backups", "name":"旅途导出", "summary":"稳定读取校验、主档只读副本、辅助记录单模块恢复和恢复前保留"}

func initial() -> Dictionary:
    return {"version":1, "notes":{}}

func valid(candidate: Dictionary) -> bool:
    if candidate.get("version") != 1 or not candidate.get("notes") is Dictionary or candidate.notes.size() > 20:
        return false
    for key in candidate.notes:
        if not key is String or not candidate.notes[key] is String or candidate.notes[key].length() > 600:
            return false
    return VALUES.json_safe(candidate, 0, [VALUES.MAX_ITEMS])

func _configure() -> void:
    archive.directory = context.store.directory.path_join("bundles")

func draw(parent: Control) -> void:
    _configure()
    header(parent, "生成主档和辅助记录的经校验副本。此页不安装或恢复游戏主档；辅助记录可逐模块复核后恢复。照片图像文件不打包。")
    var tabs := UI.row(parent)
    for pair in [["create", "制作导出包"], ["browse", "浏览与整理"], ["import", "核验外部包"]]:
        var id := String(pair[0])
        UI.button(tabs, String(pair[1]), func():tab = id;context.refresh())
    if tab == "browse":
        _browse(parent)
    elif tab == "import":
        _import(parent)
    else:
        _create(parent)

func _create(parent: Control) -> void:
    var title := UI.edit(parent, "导出包名称 / 此次备份的用途", "", 60)
    UI.button(parent, "核对当前记录范围", func():
        quote = archive.quote(context.store, String(context.latest.get("save_path", "")))
        prepared = {}
        announce(quote)
        context.refresh())
    if not quote.get("ok", false):
        UI.hint(parent, String(quote.get("reason", "先核对记录范围。")))
        return
    UI.label(parent, "共%d份记录 · 原始文本%.1f KiB" % [quote.sources.size(), float(quote.bytes) / 1024.0])
    for source in quote.sources:
        UI.hint(parent, "%s · %.1f KiB · %s" % ["游戏主档副本" if source.id == "primary" else _module_name(String(source.id)), float(source.bytes) / 1024.0, String(source.sha256).left(16)])
    UI.button(parent, "按此范围生成并保存导出包", func():
        prepared = archive.build(context.store, String(context.latest.get("save_path", "")), title.text, String(quote.fingerprint))
        if not prepared.get("ok", false):
            announce(prepared)
            prepared = {}
            return
        var installed := archive.install(prepared)
        announce(installed)
        if installed.get("ok", false):
            opened_path = String(installed.path)
            opened = archive.open(opened_path)
            prepared = {}
            quote = {}
            tab = "browse"
            context.refresh())
    UI.hint(parent, "导出前后逐份复核来源哈希，任一记录变化都会要求重新核对。包内保留主档原始UTF8字节与SHA256，但没有主档恢复按钮。")

func _module_name(id: String) -> String:
    var feature := _feature(id)
    return String(feature.descriptor().name) if feature != null else "辅助模块 " + id

func _feature(id: String) -> RefCounted:
    var owner: Node = context.level()
    if owner == null:
        return null
    var host := owner.get_tree().root.get_node_or_null("JourneyWorkbench")
    if host == null:
        return null
    return host.features.get(id)

func _browse(parent: Control) -> void:
    var bundles := archive.list_bundles()
    UI.label(parent, "导出目录：" + ProjectSettings.globalize_path(archive.directory))
    UI.hint(parent, "最多20份导出包；不会自动清理旧包。列表只显示导出目录中的固定命名文件。")
    if bundles.is_empty():
        UI.hint(parent, "尚未制作导出包。")
    for record in bundles:
        var card := UI.card(parent)
        UI.label(card, String(record.name))
        UI.hint(card, "%.1f KiB · %s" % [float(record.bytes) / 1024.0, VALUES.date(int(record.modified))])
        var row := UI.row(card)
        UI.button(row, "读取并核验", func():
            opened_path = String(record.path)
            opened = archive.open(opened_path)
            pending_restore = {}
            context.refresh())
        UI.button(row, "删除这份导出包", func():pending_delete = record.duplicate(true);pending_delete["sha256"] = FileAccess.get_sha256(String(record.path));context.refresh())
        if pending_delete.get("path") == record.path:
            UI.hint(card, "将删除这份经哈希核对的导出包，主档、辅助记录和照片均不变。")
            var actions := UI.row(card)
            UI.button(actions, "保留导出包", func():pending_delete = {};context.refresh())
            UI.button(actions, "确认删除此包", func():
                announce(archive.remove(String(pending_delete.path), String(pending_delete.sha256)))
                if opened_path == pending_delete.path:
                    opened = {}
                    opened_path = ""
                pending_delete = {}
                context.refresh())
    UI.divider(parent)
    _opened(parent)

func _opened(parent: Control) -> void:
    if opened.is_empty():
        return
    if not opened.get("ok", false):
        UI.label(parent, String(opened.get("reason", "导出包无法读取。")))
        return
    var payload: Dictionary = opened.payload
    UI.label(parent, String(payload.get("name", "旅途导出包")), true)
    UI.hint(parent, VALUES.date(int(payload.get("created", 0))))
    var same_scope: bool = payload.get("scope") == context.store.scope
    UI.hint(parent, "属于当前存档槽。" if same_scope else "来自其它存档身份；允许核验，但不恢复辅助记录。")
    var summary: Dictionary = payload.get("primary", {}).get("summary", {})
    if not summary.is_empty():
        UI.label(parent, "主档副本：%d区 / %d房间 / %d守门者 / %d类物品 / %d碎钱" % [summary.get("regions", 0), summary.get("rooms", 0), summary.get("bosses", 0), summary.get("items", 0), summary.get("currency", 0)])
        UI.hint(parent, "主档副本仅保存在导出包中，当前旅途没有被替换。")
        var owner: Node = context.level()
        if owner != null:
            var current := ARCHIVE.summarize_world(owner.world_state.data)
            UI.label(parent, "当前主档记录 → 导出包副本（只读比较）")
            for difference in ARCHIVE.compare_summaries(current, summary):
                UI.hint(parent, "%s：%.0f → %.0f（%+.0f）" % [difference.name, difference.before, difference.after, difference.difference])
    var choices := []
    for component in payload.components:
        choices.append({"id":component.id, "name":_module_name(String(component.id))})
    if choices.is_empty():
        UI.hint(parent, "导出包不含辅助模块。")
        return
    var picker := UI.pick(parent, choices, component_id)
    picker.item_selected.connect(func(_index: int):component_id = UI.chosen(picker);pending_restore = {};context.refresh())
    component_id = UI.chosen(picker)
    var target := _feature(component_id)
    var candidate := archive.component(opened, component_id)
    var valid: bool = target != null and component_id != "backups" and target.valid(candidate)
    UI.hint(parent, "辅助记录通过当前模块格式检查。" if valid else "当前模块未安装、版本不兼容或属于导出管理器自身；不恢复此组件。")
    if target != null and valid:
        _difference(parent, target.data, candidate)
    UI.button(parent, "核对恢复此模块", func():_prepare_restore(component_id), not same_scope or not valid)
    _restore_confirmation(parent)

func _difference(parent: Control, before: Dictionary, after: Dictionary) -> void:
    UI.label(parent, "辅助记录结构差异（不展开未知剧情字段）")
    var keys := {}
    for key in before:
        keys[key] = true
    for key in after:
        keys[key] = true
    for key in keys:
        if key == "version":
            continue
        var a: Variant = before.get(key)
        var b: Variant = after.get(key)
        if a == b:
            continue
        var a_size: int = a.size() if a is Array or a is Dictionary else (String(a).length() if a is String else 1)
        var b_size: int = b.size() if b is Array or b is Dictionary else (String(b).length() if b is String else 1)
        UI.hint(parent, "%s：%d → %d 个结构单位" % [String(key), a_size, b_size])

func _prepare_restore(id: String) -> void:
    var target := _feature(id)
    var candidate := archive.component(opened, id)
    if target == null or id == "backups" or not target.valid(candidate) or not target.restorable():
        context.tell("模块仍在记录、拍照、等待保存或无法复核，请先结束相关工作。")
        return
    if opened.payload.get("scope") != context.store.scope:
        context.tell("导出包不属于当前存档身份。")
        return
    pending_restore = {"id":id, "candidate":candidate, "before":VALUES.fingerprint(target.data), "primary":FileAccess.get_sha256(String(context.latest.get("save_path", ""))), "package":VALUES.fingerprint(opened.payload)}
    context.refresh()

func _restore_confirmation(parent: Control) -> void:
    if pending_restore.is_empty():
        return
    var card := UI.card(parent)
    UI.label(card, "将恢复「%s」的辅助记录。" % _module_name(String(pending_restore.id)))
    UI.hint(card, "先把当前模块内容另存为恢复前副本；写入成功后才发布新记录。游戏主档不写入。")
    var phrase := UI.edit(card, "输入：恢复辅助记录", "", 20)
    var row := UI.row(card)
    UI.button(row, "保留当前记录", func():pending_restore = {};context.refresh())
    UI.button(row, "确认单模块恢复", func():
        if phrase.text != "恢复辅助记录":
            context.tell("请完整输入确认文字。")
            return
        _restore())

func _restore() -> void:
    if pending_restore.is_empty():
        return
    var id := String(pending_restore.id)
    var target := _feature(id)
    var primary := String(context.latest.get("save_path", ""))
    if target == null or not target.restorable() or VALUES.fingerprint(target.data) != pending_restore.before or FileAccess.get_sha256(primary) != pending_restore.primary or VALUES.fingerprint(opened.get("payload", {})) != pending_restore.package:
        pending_restore = {}
        context.tell("模块、导出包或当前旅途已变化，请重新核对。")
        context.refresh()
        return
    var rollback := {"format":"journey_aux_before_restore", "version":1, "scope":context.store.scope, "feature":id, "data":target.data}
    var saved: Dictionary = context.store.export_text("恢复前辅助记录_" + id + ".json", JSON.stringify(rollback))
    if not saved.get("ok", false):
        announce(saved)
        return
    if not context.store.write(id, pending_restore.candidate):
        context.tell(context.store.error)
        return
    target.data = pending_restore.candidate.duplicate(true)
    pending_restore = {}
    context.tell("辅助记录恢复完成；恢复前副本已保留，游戏主档未改变。")
    context.refresh()

func _import(parent: Control) -> void:
    UI.hint(parent, "可粘贴导出包JSON进行核验；不会读取任意路径或自动安装主档。32MiB是硬上限，界面适合较小文本包。")
    var raw := UI.memo(parent, "", 160)
    UI.button(parent, "核验粘贴的导出包", func():
        import_preview = archive.decode(raw.text)
        announce(import_preview)
        if import_preview.get("ok", false):
            opened = import_preview
            opened_path = ""
        context.refresh())
    if import_preview.get("ok", false):
        UI.label(parent, "当前导出包组件 %d 份" % import_preview.payload.components.size())
        UI.button(parent, "保存核验过的包到导出目录", func():
            var encoded := JSON.stringify(import_preview.payload)
            var envelope := JSON.stringify({"format":"pilgrimage_journey_bundle", "version":1, "sha256":encoded.sha256_text(), "payload":encoded})
            announce(archive.install({"ok":true, "raw":envelope})))
        _opened(parent)
