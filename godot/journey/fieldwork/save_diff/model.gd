extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const MILESTONES := preload("res://journey/fieldwork/milestones/model.gd")
const GRAPH := preload("res://journey/fieldwork/network/model.gd")
const VIEW := preload("res://journey/fieldwork/save_diff/tree.gd")
const ROOTS := [
    "region",
    "room",
    "inventory",
    "equipment",
    "abilities",
    "quests",
    "build_stats",
    "wallet",
    "player",
    "known_rooms"
]
const MAX_OPERATIONS := 256
const MAX_ARRAY := 128


static func introduction() -> String:
    return "比较同槽已保存的公开旅途观察，显示结构化字段差异、只在内存中复演变更和三方冲突。此台不读取任意文件、不写入主档，也不把观察当作完整存档。"


static func public_snapshot(snapshot: Dictionary) -> Dictionary:
    var milestones := MILESTONES.capture(snapshot)
    var inventory := {}
    var gear := {}
    var abilities := []
    var quests := {}
    for row in milestones.facts:
        if row.kind == "物资":
            inventory[row.id] = {"name": row.name, "count": row.count}
        elif row.kind == "装备":
            gear[row.id] = {"name": row.name, "status": row.status}
        elif row.kind == "能力":
            abilities.append({"id": row.id, "name": row.name})
        elif row.kind in ["任务", "结局"]:
            quests[row.id] = {"name": row.name, "count": row.count, "status": row.status}
    var rooms := {}
    for row in GRAPH.capture(snapshot).nodes:
        rooms[row.id] = {"name": row.name, "kind": row.kind}
    var room_name := String(rooms.get(snapshot.get("room", ""), {}).get("name", "当前已知房间"))
    return {
        "region": String(snapshot.get("region_name", "")),
        "room": room_name,
        "inventory": inventory,
        "equipment": gear,
        "abilities": abilities,
        "quests": quests,
        "build_stats": milestones.stats,
        "wallet": int(snapshot.get("wallet", 0)),
        "player":
        {
            "hp": K.safe_number(snapshot.get("player", {}).get("hp")),
            "energy": K.safe_number(snapshot.get("player", {}).get("energy"))
        },
        "known_rooms": rooms
    }


static func capture(snapshot: Dictionary) -> Dictionary:
    return {
        "snapshot": public_snapshot(snapshot),
        "recorded": int(snapshot.get("timestamp", 0)),
        "include_player": false,
        "include_story": true,
        "array_mode": "ordered",
        "epsilon": 0.0,
        "category": "全部",
        "query": ""
    }


static func bounded(value: Variant, depth: int, budget: Array) -> bool:
    budget[0] = int(budget[0]) - 1
    if depth > 12 or int(budget[0]) < 0:
        return false
    if value is Dictionary:
        if value.size() > 1000:
            return false
        for key in value:
            if (
                not key is String
                or key.length() > 200
                or not bounded(value[key], depth + 1, budget)
            ):
                return false
    elif value is Array:
        if value.size() > 512:
            return false
        for item in value:
            if not bounded(item, depth + 1, budget):
                return false
    elif value is String:
        return value.length() <= 10000
    elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
        return V.number(value) and absf(float(value)) <= 1000000000000.0
    elif value != null and not value is bool:
        return false
    return true


static func validate(payload: Dictionary) -> bool:
    if not payload.get("snapshot") is Dictionary or not bounded(payload.snapshot, 0, [30000]):
        return false
    for key in payload.snapshot:
        if key not in ROOTS:
            return false
    if (
        not V.count(payload.get("recorded"), 9999999999)
        or not payload.get("include_player") is bool
        or not payload.get("include_story") is bool
    ):
        return false
    if (
        payload.get("array_mode") not in ["ordered", "multiset"]
        or not V.number(payload.get("epsilon"))
        or payload.epsilon < 0
        or payload.epsilon > 1
    ):
        return false
    if (
        payload.get("category") not in ["全部", "物资资金", "构筑能力", "探索", "剧情", "临时角色", "其它"]
        or not payload.get("query") is String
        or payload.query.length() > 200
    ):
        return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(_payload: Dictionary) -> Array:
    var categories := []
    for name in ["全部", "物资资金", "构筑能力", "探索", "剧情", "临时角色", "其它"]:
        categories.append({"id": name, "name": name})
    return [
        {"id": "include_player", "name": "包含瞬时生命与能量", "kind": "toggle"},
        {"id": "include_story", "name": "包含已知剧情状态", "kind": "toggle"},
        {
            "id": "array_mode",
            "name": "数组比较方式",
            "kind": "choice",
            "choices":
            [{"id": "ordered", "name": "保留顺序并对齐"}, {"id": "multiset", "name": "忽略顺序但保留重复数量"}]
        },
        {"id": "epsilon", "name": "数字绝对容差", "kind": "number", "min": 0, "max": 1, "step": 0.001},
        {"id": "category", "name": "差异类别筛选", "kind": "choice", "choices": categories},
        {"id": "query", "name": "字段或值搜索", "max": 200}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%s · 顶层公开字段%d项 · %s"
        % [
            String(payload.snapshot.get("region", "旅途")),
            payload.snapshot.size(),
            V.date(int(payload.recorded))
        ]
    )


static func canonical(value: Variant) -> String:
    if value is Dictionary:
        var keys: Array = value.keys()
        keys.sort()
        var parts: Array[String] = []
        for key in keys:
            parts.append(JSON.stringify(key) + ":" + canonical(value[key]))
        return "{" + ",".join(parts) + "}"
    if value is Array:
        var parts: Array[String] = []
        for item in value:
            parts.append(canonical(item))
        return "[" + ",".join(parts) + "]"
    if typeof(value) in [TYPE_INT, TYPE_FLOAT] and floor(float(value)) == float(value):
        return str(int(value))
    return JSON.stringify(value)


static func equivalent(a: Variant, b: Variant, epsilon: float = 0.0) -> bool:
    var a_number := typeof(a) in [TYPE_INT, TYPE_FLOAT]
    var b_number := typeof(b) in [TYPE_INT, TYPE_FLOAT]
    if a_number and b_number:
        return absf(float(a) - float(b)) <= epsilon
    if typeof(a) != typeof(b):
        return false
    if a is Dictionary:
        if a.size() != b.size():
            return false
        for key in a:
            if not b.has(key) or not equivalent(a[key], b[key], epsilon):
                return false
        return true
    if a is Array:
        if a.size() != b.size():
            return false
        for i in a.size():
            if not equivalent(a[i], b[i], epsilon):
                return false
        return true
    return a == b


static func masked(payload: Dictionary) -> Dictionary:
    var result: Dictionary = payload.snapshot.duplicate(true)
    if not payload.include_player:
        result.erase("player")
    if not payload.include_story:
        result.erase("quests")
    return result


static func token(value: String) -> String:
    return value.replace("~", "~0").replace("/", "~1")


static func decode(value: String) -> String:
    return value.replace("~1", "/").replace("~0", "~")


static func category(path: String) -> String:
    var parts := path.split("/", false)
    var root := String(parts[0]) if not parts.is_empty() else ""
    if root in ["inventory", "wallet"]:
        return "物资资金"
    if root in ["equipment", "abilities", "build_stats"]:
        return "构筑能力"
    if root in ["region", "room", "known_rooms"]:
        return "探索"
    if root == "quests":
        return "剧情"
    if root == "player":
        return "临时角色"
    return "其它"


static func operation(
    kind: String, path: String, old: Variant, new: Variant, array_root: String = ""
) -> Dictionary:
    return {
        "op": kind,
        "path": path,
        "old_exists": kind != "add",
        "new_exists": kind != "remove",
        "old": old,
        "new": new,
        "category": category(path),
        "array_root": array_root
    }


static func align_equal(a: Variant, b: Variant, epsilon: float) -> bool:
    if a is Dictionary and b is Dictionary and a.get("id") is String and b.get("id") is String:
        return a.id == b.id
    return equivalent(a, b, epsilon)


static func array_lcs(a: Array, b: Array, epsilon: float) -> Array:
    var table := []
    for i in range(a.size() + 1):
        var row := []
        row.resize(b.size() + 1)
        row.fill(0)
        table.append(row)
    for i in range(a.size() - 1, -1, -1):
        for j in range(b.size() - 1, -1, -1):
            table[i][j] = (
                1 + int(table[i + 1][j + 1])
                if align_equal(a[i], b[j], epsilon)
                else maxi(int(table[i + 1][j]), int(table[i][j + 1]))
            )
    return table


static func walk(
    a: Variant, b: Variant, path: String, options: Dictionary, ops: Array, array_root: String = ""
) -> void:
    if ops.size() > MAX_OPERATIONS or equivalent(a, b, float(options.epsilon)):
        return
    if a is Dictionary and b is Dictionary:
        var keys: Array = a.keys()
        for key in b:
            if not keys.has(key):
                keys.append(key)
        keys.sort()
        for key in keys:
            var next := path + "/" + token(String(key))
            if not a.has(key):
                ops.append(operation("add", next, null, b[key], array_root))
            elif not b.has(key):
                ops.append(operation("remove", next, a[key], null, array_root))
            else:
                walk(a[key], b[key], next, options, ops, array_root)
            if ops.size() > MAX_OPERATIONS:
                return
        return
    if a is Array and b is Array and a.size() <= MAX_ARRAY and b.size() <= MAX_ARRAY:
        var root := array_root if not array_root.is_empty() else path
        if options.array_mode == "multiset":
            var first := []
            var second := []
            for item in a:
                first.append(canonical(item))
            for item in b:
                second.append(canonical(item))
            first.sort()
            second.sort()
            if first != second:
                ops.append(operation("replace", path, a, b, root))
            return
        var table := array_lcs(a, b, float(options.epsilon))
        var i := 0
        var j := 0
        var cursor := 0
        while i < a.size() or j < b.size():
            var next := path + "/" + str(cursor)
            if i < a.size() and j < b.size() and align_equal(a[i], b[j], float(options.epsilon)):
                walk(a[i], b[j], next, options, ops, root)
                i += 1
                j += 1
                cursor += 1
            elif j < b.size() and (i == a.size() or int(table[i][j + 1]) >= int(table[i + 1][j])):
                ops.append(operation("add", next, null, b[j], root))
                j += 1
                cursor += 1
            else:
                ops.append(operation("remove", next, a[i], null, root))
                i += 1
            if ops.size() > MAX_OPERATIONS:
                return
        return
    ops.append(operation("replace", path, a, b, array_root))


static func difference(a: Dictionary, b: Dictionary, options: Dictionary) -> Dictionary:
    var ops := []
    walk(a, b, "", options, ops)
    if ops.size() > MAX_OPERATIONS:
        return {"ok": false, "ops": [], "reason": "差异超过256项，未生成部分变更预览。"}
    return {"ok": true, "ops": ops, "reason": "已生成有界结构差异。"}


static func pointer_parts(path: String) -> Dictionary:
    if path.is_empty():
        return {"ok": true, "parts": []}
    if not path.begins_with("/"):
        return {"ok": false, "parts": []}
    var parts := []
    for encoded in path.substr(1).split("/", true):
        var cursor := 0
        while cursor < encoded.length():
            if encoded[cursor] == "~":
                if cursor + 1 >= encoded.length() or encoded[cursor + 1] not in ["0", "1"]:
                    return {"ok": false, "parts": []}
                cursor += 1
            cursor += 1
        parts.append(decode(encoded))
    return {"ok": true, "parts": parts}


static func array_index(part: String, length: int, append: bool = false) -> int:
    if append and part == "-":
        return length
    if not part.is_valid_int():
        return -1
    var number := int(part)
    if str(number) != part or number < 0 or number > (length if append else length - 1):
        return -1
    return number


static func lookup(root: Variant, path: String) -> Dictionary:
    var parsed := pointer_parts(path)
    if not parsed.ok:
        return {"exists": false}
    var cursor: Variant = root
    for part in parsed.parts:
        if cursor is Dictionary:
            if not cursor.has(part):
                return {"exists": false}
            cursor = cursor[part]
        elif cursor is Array:
            var index := array_index(String(part), cursor.size())
            if index < 0:
                return {"exists": false}
            cursor = cursor[index]
        else:
            return {"exists": false}
    return {"exists": true, "value": cursor}


static func clone_json(value: Variant) -> Variant:
    return value.duplicate(true) if value is Dictionary or value is Array else value


static func apply(root: Variant, ops: Array) -> Dictionary:
    if ops.size() > MAX_OPERATIONS or not bounded(root, 0, [30000]):
        return {"ok": false, "reason": "内存复演输入超过容量。"}
    var result: Variant = clone_json(root)
    for op in ops:
        if (
            not op is Dictionary
            or op.get("op") not in ["add", "remove", "replace"]
            or not op.get("path") is String
        ):
            return {"ok": false, "reason": "变更操作格式无效。"}
        if (
            not op.get("old_exists") is bool
            or not op.get("new_exists") is bool
            or not op.has("old")
            or not op.has("new")
        ):
            return {"ok": false, "reason": "缺少变更前后条件。"}
        if not bounded(op.old, 0, [30000]) or not bounded(op.new, 0, [30000]):
            return {"ok": false, "reason": "变更值超过容量或含不支持的类型。"}
        var parsed := pointer_parts(op.path)
        if not parsed.ok:
            return {"ok": false, "reason": "字段路径无效。"}
        var parent_path := ""
        for part in parsed.parts.slice(0, maxi(0, parsed.parts.size() - 1)):
            parent_path += "/" + token(String(part))
        var parent := lookup(result, parent_path)
        if not parent.exists:
            return {"ok": false, "reason": "变更的父字段不存在。"}
        var container: Variant = parent.value
        var old := lookup(result, String(op.path))
        var insertion: bool = op.op == "add" and container is Array and not parsed.parts.is_empty()
        if not insertion and bool(op.old_exists) != bool(old.exists):
            return {"ok": false, "reason": "字段存在性与变更前条件不符。"}
        if not insertion and old.exists and not equivalent(old.value, op.old):
            return {"ok": false, "reason": "字段原值与变更前条件不符。"}
        if parsed.parts.is_empty():
            if op.op == "remove":
                return {"ok": false, "reason": "不支持移除整个观察根。"}
            result = clone_json(op.new)
            continue
        var key := String(parsed.parts[-1])
        if container is Dictionary:
            if op.op == "remove":
                container.erase(key)
            else:
                container[key] = clone_json(op.new)
        elif container is Array:
            var index := array_index(key, container.size(), op.op == "add")
            if index < 0:
                return {"ok": false, "reason": "数组位置无效。"}
            if op.op == "add":
                container.insert(index, clone_json(op.new))
            elif op.op == "remove":
                container.remove_at(index)
            else:
                container[index] = clone_json(op.new)
        else:
            return {"ok": false, "reason": "父字段不是容器。"}
    return {"ok": true, "value": result, "reason": "仅在内存中复演完成。"}


static func operation_rows(ops: Array, options: Dictionary) -> Array:
    var result := []
    for op in ops:
        if options.category != "全部" and op.category != options.category:
            continue
        var old := canonical(op.old) if op.old_exists else "（原来不存在）"
        var new := canonical(op.new) if op.new_exists else "（本次移除）"
        if not V.matches(String(options.query), [String(op.path), old, new]):
            continue
        result.append({"操作": op.op, "字段": op.path, "分类": op.category, "记录值": old, "当前值": new})
    return result


static func ancestor(a: String, b: String) -> bool:
    return a == b or a.is_empty() or b.begins_with(a + "/")


static func conflict(a: Dictionary, b: Dictionary) -> bool:
    if not String(a.array_root).is_empty() and a.array_root == b.array_root:
        return true
    return ancestor(String(a.path), String(b.path)) or ancestor(String(b.path), String(a.path))


static func three_way(
    base: Dictionary, left: Dictionary, right: Dictionary, options: Dictionary
) -> Dictionary:
    var first := difference(base, left, options)
    var second := difference(base, right, options)
    if not first.ok or not second.ok:
        return {"ok": false, "conflicts": [], "reason": "至少一侧差异超过分析容量。"}
    if equivalent(left, right, float(options.epsilon)):
        return {"ok": true, "conflicts": [], "value": clone_json(left), "reason": "两侧观察相同。", "operations": first.ops.size()}
    var conflicts := []
    var combined: Array = first.ops.duplicate(true)
    for right_op in second.ops:
        # A complete identical array edit is replayed once, even alongside disjoint edits.
        var root := String(right_op.array_root)
        if not root.is_empty():
            var left_array := lookup(left, root)
            var right_array := lookup(right, root)
            if left_array.exists and right_array.exists and equivalent(left_array.value, right_array.value):
                continue
        var overlaps := []
        var identical := false
        for left_op in first.ops:
            if (
                left_op.path == right_op.path
                and left_op.op == right_op.op
                and equivalent(left_op.new, right_op.new, float(options.epsilon))
            ):
                identical = true
                continue
            if conflict(left_op, right_op):
                overlaps.append(left_op)
        if not overlaps.is_empty():
            for left_op in overlaps:
                conflicts.append(
                    {
                        "左字段": left_op.path,
                        "右字段": right_op.path,
                        "左变化": left_op.op,
                        "右变化": right_op.op,
                        "说明":
                        (
                            "同一数组保守判冲突"
                            if (
                                not String(left_op.array_root).is_empty()
                                and left_op.array_root == right_op.array_root
                            )
                            else "相同或父子字段同时变化"
                        )
                    }
                )
        elif not identical:
            combined.append(right_op)
    if not conflicts.is_empty():
        return {"ok": false, "conflicts": conflicts, "reason": "存在观察结构冲突，不生成合并候选。"}
    var applied := apply(base, combined)
    return {
        "ok": applied.ok,
        "conflicts": [],
        "value": applied.get("value", {}),
        "reason": String(applied.reason),
        "operations": combined.size()
    }


static func footprint(value: Variant, depth: int = 0) -> Dictionary:
    var result := {"objects": 0, "arrays": 0, "scalars": 0, "depth": depth}
    if value is Dictionary:
        result.objects = 1
        for child in value.values():
            var stats := footprint(child, depth + 1)
            result.objects = int(result.objects) + int(stats.objects)
            result.arrays = int(result.arrays) + int(stats.arrays)
            result.scalars = int(result.scalars) + int(stats.scalars)
            result.depth = maxi(int(result.depth), int(stats.depth))
    elif value is Array:
        result.arrays = 1
        for child in value:
            var stats := footprint(child, depth + 1)
            result.objects = int(result.objects) + int(stats.objects)
            result.arrays = int(result.arrays) + int(stats.arrays)
            result.scalars = int(result.scalars) + int(stats.scalars)
            result.depth = maxi(int(result.depth), int(stats.depth))
    else:
        result.scalars = 1
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var data := masked(payload)
    var stats := footprint(data)
    var rows := []
    for key in data:
        var child := footprint(data[key])
        rows.append(
            {
                "公开顶层字段": key,
                "JSON字节": canonical(data[key]).to_utf8_buffer().size(),
                "标量数": child.scalars,
                "最大嵌套": child.depth
            }
        )
    return [
        K.notice("公开旅途观察", summary(payload)),
        K.notice("规范化指纹", canonical(data).sha256_text()),
        K.notice(
            "结构容量",
            (
                "对象%d · 数组%d · 标量%d · 深度%d；最多256项变更、128项数组逐项对齐。"
                % [stats.objects, stats.arrays, stats.scalars, stats.depth]
            )
        ),
        K.table("公开字段大小", ["公开顶层字段", "JSON字节", "标量数", "最大嵌套"], rows),
        K.notice("使用方式", "先保存一份观察，再在记录库选择比较。三方对照可选择两份已存观察与当前状态，所有复演仅在内存中进行。"),
        K.notice("隐私与边界", "观察只包含当前公开事实，不包含原始存档路径、全部剧情旗标、未知房间和未获装备目录。它不是完整主档，不能用于恢复主档。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := masked(a)
    var right := b.duplicate(true)
    right.include_player = a.include_player
    right.include_story = a.include_story
    var target := masked(right)
    var diff := difference(left, target, a)
    if not diff.ok:
        return [K.notice("差异容量", String(diff.reason))]
    var applied := apply(left, diff.ops)
    var replay := (
        difference(applied.get("value", {}), target, a)
        if applied.ok
        else {"ok": false, "ops": [{}]}
    )
    var confirmed: bool = applied.ok and replay.ok and replay.ops.is_empty()
    var rows := operation_rows(diff.ops, a)
    return [
        K.notice(
            "结构差异",
            (
                "完整变更%d项，筛选显示%d项；内存复演%s。"
                % [diff.ops.size(), rows.size(), "在此容差下与目标一致" if confirmed else "未通过"]
            )
        ),
        {"kind": "custom", "title": "可展开的差异树", "view": VIEW, "data": {"rows": rows}},
        K.table("字段变更", ["操作", "字段", "分类", "记录值", "当前值"], rows),
        K.notice("变更边界", "空值与字段不存在分别处理；布尔值与数字不会互相混同。忽略项和数值容差只影响此分析。多重集合按规范化值精确比较，保留重复数量。")
    ]
