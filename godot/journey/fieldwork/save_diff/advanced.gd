extends RefCounted
## Reverse operation order and swap explicit pre/postconditions.
## No file access: this only proves reversibility of an observation in memory.
const K := preload("res://journey/fieldwork/knowledge.gd")
const MAX_OPERATIONS := 256


static func inverse(operations: Array) -> Dictionary:
    if operations.size() > MAX_OPERATIONS:
        return {"ok": false, "reason": "逆向操作超过256项"}
    var result := []
    for index in range(operations.size() - 1, -1, -1):
        var op: Variant = operations[index]
        if not op is Dictionary:
            return {"ok": false, "reason": "操作不是字典"}
        if op.get("op") not in ["add", "remove", "replace"] or not op.get("path") is String:
            return {"ok": false, "reason": "操作种类或路径无效"}
        if not op.has("old") or not op.has("new") or not op.get("old_exists") is bool or not op.get("new_exists") is bool:
            return {"ok": false, "reason": "缺少显式前后条件"}
        var kind: String = {"add": "remove", "remove": "add", "replace": "replace"}[op.op]
        if bool(op.old_exists) != (op.op != "add") or bool(op.new_exists) != (op.op != "remove"):
            return {"ok": false, "reason": "操作存在性条件不一致"}
        result.append({
            "op": kind, "path": op.path,
            "old_exists": op.new_exists, "new_exists": op.old_exists,
            "old": clone(op.new), "new": clone(op.old),
            "category": op.get("category", ""),
            "array_root": op.get("array_root", "")
        })
    return {"ok": true, "ops": result}


static func clone(value: Variant) -> Variant:
    return value.duplicate(true) if value is Dictionary or value is Array else value


static func canonical(value: Variant) -> String:
    if value is Dictionary:
        var keys: Array = value.keys()
        keys.sort()
        var fields := PackedStringArray()
        for key in keys:
            fields.append(JSON.stringify(key) + ":" + canonical(value[key]))
        return "{" + ",".join(fields) + "}"
    if value is Array:
        var fields := PackedStringArray()
        for item in value:
            fields.append(canonical(item))
        return "[" + ",".join(fields) + "]"
    return JSON.stringify(value)


static func audit(before: Dictionary, operations: Array, apply: Callable) -> Dictionary:
    var fingerprint := canonical(before).sha256_text()
    var inverted := inverse(operations)
    if not inverted.ok:
        return inverted
    var forward: Dictionary = apply.call(before, operations)
    if not forward.ok:
        return {"ok": false, "reason": "正向前条件未满足：" + String(forward.reason)}
    var backward: Dictionary = apply.call(forward.value, inverted.ops)
    if not backward.ok:
        return {"ok": false, "reason": "逆向前条件未满足：" + String(backward.reason)}
    if canonical(backward.value) != canonical(before):
        return {"ok": false, "reason": "逆向复演未精确回到原观察"}
    if canonical(before).sha256_text() != fingerprint:
        return {"ok": false, "reason": "输入观察被意外修改"}
    var reinverted := inverse(inverted.ops)
    if not reinverted.ok:
        return reinverted
    var repeated: Dictionary = apply.call(backward.value, reinverted.ops)
    if not repeated.ok or canonical(repeated.value) != canonical(forward.value):
        return {"ok": false, "reason": "第二轮正向复演不一致"}
    var checkpoints := []
    var current: Variant = clone(before)
    for i in operations.size():
        var step: Dictionary = apply.call(current, [operations[i]])
        if not step.ok:
            return {"ok": false, "reason": "逐项复演失败"}
        current = step.value
        checkpoints.append({
            "顺序": i + 1, "正向操作": operations[i].op, "字段": operations[i].path,
            "逆向执行位": operations.size() - i,
            "观察指纹": canonical(current).sha256_text().left(16)
        })
    return {
        "ok": true, "ops": inverted.ops, "checkpoints": checkpoints,
        "before": fingerprint, "after": canonical(forward.value).sha256_text(),
        "recovered": canonical(backward.value).sha256_text(),
        "reason": "正向→逆向→再次正向，均按精确前后条件复核"
    }


static func sections(before: Dictionary, operations: Array, apply: Callable) -> Array:
    var result := audit(before, operations, apply)
    if not result.ok:
        return [K.notice("可逆观察审计", result.reason)]
    var rows := []
    for i in result.ops.size():
        var op: Dictionary = result.ops[i]
        rows.append({
            "逆向顺序": i + 1, "操作": op.op, "字段": op.path,
            "原值必须存在": op.old_exists, "复原后存在": op.new_exists
        })
    return [
        K.notice("内存差异可逆性", result.reason + "。不读写任何主档或辅助文件。"),
        K.table("逆向操作预览", ["逆向顺序", "操作", "字段", "原值必须存在", "复原后存在"], rows),
        K.table("逐项中间态证书", ["顺序", "正向操作", "字段", "逆向执行位", "观察指纹"], result.checkpoints),
        K.notice("恢复指纹", "原观察：" + String(result.before) + "；逆向后：" + String(result.recovered)),
        K.notice("复演边界", "这里只反转实际生成的差异操作；被容差、隐私或数组阅读模式排除的内容不属于补丁。逆序处理数组插入与删除，保留空值与不存在的差别。证书不是主档恢复包。")
    ]
