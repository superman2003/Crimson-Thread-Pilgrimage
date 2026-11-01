extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/save_diff/advanced.gd")
var source: Dictionary = {}
var operations: Array = []
var apply_operation: Callable
var current: Variant = {}
var cursor := 0
var output: VBoxContainer
var forward: Button
var backward: Button


func configure(data: Dictionary) -> void:
    source = data.get("before",{}).duplicate(true)
    operations = data.get("ops",[]).duplicate(true)
    apply_operation = data.get("apply",Callable())
    current = source.duplicate(true)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UI.hint(self,"逐项前进或逆向撤回，只操作此窗口的内存观察副本。不会保存、导入或恢复主档。")
    var row := UI.row(self)
    backward = UI.button(row,"逆向一步",_backward)
    forward = UI.button(row,"正向一步",_forward)
    UI.button(row,"复位观察",_reset)
    output = UI.column(self)
    _show_state()


func _forward() -> void:
    if cursor>=operations.size() or not apply_operation.is_valid():
        return
    var result: Dictionary = apply_operation.call(current,[operations[cursor]])
    if not result.ok:
        UI.label(output,"正向前条件未满足：" + String(result.reason))
        return
    current = result.value
    cursor += 1
    _show_state()


func _backward() -> void:
    if cursor<=0 or not apply_operation.is_valid():
        return
    var inverse := A.inverse([operations[cursor-1]])
    if not inverse.ok:
        UI.label(output,inverse.reason)
        return
    var result: Dictionary = apply_operation.call(current,inverse.ops)
    if not result.ok:
        UI.label(output,"逆向前条件未满足：" + String(result.reason))
        return
    current = result.value
    cursor -= 1
    _show_state()


func _reset() -> void:
    current = source.duplicate(true)
    cursor = 0
    _show_state()


func _show_state() -> void:
    UI.clear(output)
    backward.disabled = cursor<=0
    forward.disabled = cursor>=operations.size()
    UI.label(output,"已应用%d / %d项" % [cursor,operations.size()],true)
    UI.progress(output,cursor,maxi(1,operations.size()))
    UI.hint(output,"当前观察SHA256：" + A.canonical(current).sha256_text())
    if cursor>0:
        UI.label(output,"最后执行：" + String(operations[cursor-1].op) + " " + String(operations[cursor-1].path))
    if cursor<operations.size():
        UI.label(output,"下一项：" + String(operations[cursor].op) + " " + String(operations[cursor].path))
    var summary := UI.memo(output,JSON.stringify(current,"  "),180)
    summary.editable = false
    UI.hint(output,"完整观察只在本地内存显示；页内没有写入操作。")
