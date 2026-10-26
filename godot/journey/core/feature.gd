extends RefCounted
const VALUES := preload("res://journey/core/values.gd")
const UI := preload("res://journey/core/ui.gd")
var context: RefCounted
var data: Dictionary = {}
var error := ""
var search := ""
var selected := ""

func descriptor() -> Dictionary:
    return {"id":"base", "name":"工作台", "summary":""}

func initial() -> Dictionary:
    return {"version":1}

func valid(candidate: Dictionary) -> bool:
    return candidate.get("version") == 1 and VALUES.json_safe(candidate, 0, [VALUES.MAX_ITEMS])

func setup(value: RefCounted) -> void:
    context = value
    var candidate: Dictionary = context.store.read(String(descriptor().id), initial())
    data = candidate if valid(candidate) else initial()
    error = context.store.error
    if not valid(candidate):
        context.store.identities[String(descriptor().id)] = "unreadable"
        error = "辅助记录版本或字段无效；保留原文件。"

func commit(candidate: Dictionary) -> bool:
    if not valid(candidate):
        error = "候选内容未通过检查。"
        context.tell(error)
        return false
    if not context.editable() or not context.store.write(String(descriptor().id), candidate):
        error = context.store.error if not context.store.error.is_empty() else "当前旅途暂不能编辑。"
        var failure := error
        recover_conflict()
        error = failure
        context.tell(error)
        return false
    data = candidate.duplicate(true)
    error = ""
    context.refresh()
    return true

func announce(result: Dictionary) -> void:
    context.tell(String(result.get("reason", "操作完成。")))

func tick(_snapshot: Dictionary, _delta: float) -> void:
    pass

func release() -> void:
    pass

func draw(parent: Control) -> void:
    UI.label(parent, String(descriptor().name), true)

func header(parent: Control, introduction: String) -> void:
    UI.label(parent, String(descriptor().name), true)
    UI.hint(parent, introduction)
    if not error.is_empty():
        UI.label(parent, error)

func export_document(name: String, document: String) -> void:
    announce(context.store.export_text(name, document))

func shutdown() -> void:
    release()

func restorable() -> bool:
    return true


func recover_conflict() -> bool:
    var id := String(descriptor().id)
    var expected := String(context.store.identities.get(id, "missing"))
    if expected == "unreadable" or context.store.identity(context.store.path_for(id)) == expected:
        return false
    var current: Dictionary = context.store.read(id, initial())
    if not context.store.error.is_empty() or not valid(current):
        context.store.identities[id] = "unreadable"
        return false
    data = current
    selected = ""
    storage_reloaded()
    context.refresh()
    return true

func storage_reloaded() -> void:
    pass
