extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const COURSE := preload("res://journey/fieldwork/curriculum/model.gd")
const VIEW := preload("res://journey/fieldwork/input_trials/view.gd")
var active := false
var paused := false
var stop_reason := ""
var settings: Dictionary = {}
var origin := 0.0
var pause_start := 0.0
var pause_total := 0.0
var last_clock := 0.0
var elapsed := 0.0
var trial_start := 0.0
var pressed_at := -1.0
var cursor := 0
var held: Dictionary = {}
var neutral := true
var trials: Array = []
var events: Array = []


static func introduction() -> String:
    return "显式启动并聚焦练习区域后，练习当前已获动作的按下、按住和释放。只记录动作标识与软件时间，不读取文字内容，也不向游戏注入输入。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var actions := COURSE.known_actions(snapshot)
    var sequence := []
    for row in actions:
        if row.id in ["jump", "attack", "move_left", "move_right"]:
            sequence.append(row.id)
    return {
        "actions": actions,
        "sequence": sequence,
        "mode": "press",
        "repeats": 2.0,
        "deadline": 3.0,
        "hold": 0.5,
        "tolerance": 0.15,
        "trials": [],
        "events": [],
        "elapsed": 0.0,
        "completed": false,
        "reason": "尚未启动"
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("actions") is Array
        or payload.actions.size() > 32
        or not payload.get("sequence") is Array
        or payload.sequence.size() > 16
    ):
        return false
    if (
        payload.get("mode") not in ["press", "hold", "release"]
        or not V.count(payload.get("repeats"), 8)
        or payload.repeats < 1
    ):
        return false
    for key in ["deadline", "hold", "tolerance", "elapsed"]:
        if not V.number(payload.get(key)) or float(payload[key]) < 0 or float(payload[key]) > 600:
            return false
    if (
        payload.deadline < 0.2
        or payload.deadline > 10
        or payload.hold < 0.05
        or payload.hold > 5
        or payload.tolerance < 0.01
        or payload.tolerance > 1
    ):
        return false
    if (
        not payload.get("completed") is bool
        or not payload.get("reason") is String
        or payload.reason.length() > 200
    ):
        return false
    if payload.mode == "hold" and maxf(0, float(payload.hold) - float(payload.tolerance)) >= float(payload.deadline):
        return false
    var ids := {}
    for row in payload.actions:
        if (
            not row is Dictionary
            or not row.get("id") is String
            or ids.has(row.id)
            or not row.get("name") is String
            or not row.get("binding") is String
        ):
            return false
        ids[row.id] = true
    for id in payload.sequence:
        if not id is String or not ids.has(id):
            return false
    if (
        not payload.get("trials") is Array
        or payload.trials.size() > 128
        or not payload.get("events") is Array
        or payload.events.size() > 512
    ):
        return false
    for row in payload.trials:
        if (
            not row is Dictionary
            or not ids.has(row.get("expected"))
            or not V.count(row.get("index"), 128)
            or not row.get("correct") is bool
            or not row.get("outcome") is String
        ):
            return false
        for field in ["time", "interval", "held"]:
            if not V.number(row.get(field)) or row[field] < 0 or row[field] > 600:
                return false
    for row in payload.events:
        if (
            not row is Dictionary
            or not row.get("actions") is Array
            or row.actions.size() > 32
            or not row.get("pressed") is bool
            or not V.number(row.get("time"))
        ):
            return false
        for id in row.actions:
            if not ids.has(id):
                return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for row in payload.actions:
        choices.append({"id": row.id, "name": row.name + " · " + row.binding})
    return [
        {
            "id": "sequence",
            "name": "练习目标顺序",
            "kind": "ordered",
            "choices": choices,
            "limit": 16,
            "allow_duplicates": true
        },
        {
            "id": "mode",
            "name": "目标类型",
            "kind": "choice",
            "choices":
            [
                {"id": "press", "name": "按下"},
                {"id": "hold", "name": "按住后释放"},
                {"id": "release", "name": "按下再释放"}
            ]
        },
        {"id": "repeats", "name": "重复轮数", "kind": "number", "min": 1, "max": 8},
        {"id": "deadline", "name": "每项等待上限秒", "kind": "number", "min": 0.2, "max": 10, "step": 0.1},
        {"id": "hold", "name": "个人按住目标秒", "kind": "number", "min": 0.05, "max": 5, "step": 0.05},
        {"id": "tolerance", "name": "按住容差秒", "kind": "number", "min": 0.01, "max": 1, "step": 0.01}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d项目标 × %d轮 · %s · 已记录%d项结果"
        % [payload.sequence.size(), payload.repeats, payload.mode, payload.trials.size()]
    )


func begin(payload: Dictionary, clock: float) -> bool:
    if active or not validate(payload) or payload.sequence.is_empty() or not is_finite(clock):
        return false
    settings = payload.duplicate(true)
    origin = clock
    last_clock = clock
    elapsed = 0
    pause_total = 0
    cursor = 0
    trials = []
    events = []
    held = {}
    neutral = true
    pressed_at = -1
    active = true
    paused = false
    stop_reason = "进行中"
    return true


func expected() -> String:
    return (
        String(settings.sequence[cursor % settings.sequence.size()])
        if not settings.is_empty() and not settings.sequence.is_empty()
        else ""
    )


func set_neutral(pressed: Array, clock: float) -> void:
    if not active or paused:
        return
    advance(clock)
    if neutral and pressed.is_empty():
        held.clear()
        neutral = false
        trial_start = elapsed
        pressed_at = -1


func advance(clock: float) -> void:
    if not active or not is_finite(clock):
        return
    if clock < last_clock:
        end("单调时钟发生回退")
        return
    last_clock = clock
    if paused:
        return
    elapsed = maxf(0, clock - origin - pause_total)
    if elapsed > 180:
        end("练习达到三分钟总上限")
        return
    if not neutral and elapsed - trial_start > float(settings.deadline):
        _score(false, "目标等待超时", maxf(0, elapsed - pressed_at) if pressed_at >= 0 else 0.0)


func feed(actions: Array, pressed: bool, clock: float) -> void:
    if not active or paused or events.size() >= 512:
        return
    advance(clock)
    if not active:
        return
    var transitions := []
    for action in actions:
        var was := held.has(action)
        if pressed != was:
            transitions.append(action)
            if pressed:
                held[action] = true
            else:
                held.erase(action)
    if transitions.is_empty():
        return
    events.append({"actions": transitions, "pressed": pressed, "time": elapsed})
    if neutral:
        return
    if transitions.size() != 1:
        return
    var action := String(transitions[0])
    if action != expected():
        return
    if pressed:
        pressed_at = elapsed
        if settings.mode == "press":
            _score(true, "正确按下", 0.0)
    elif pressed_at >= 0:
        var duration := elapsed - pressed_at
        var good: bool = (
            settings.mode == "release"
            or absf(duration - float(settings.hold)) <= float(settings.tolerance)
        )
        _score(good, "正确释放" if good else "按住时间超出个人容差", duration)


func _score(correct: bool, outcome: String, duration: float) -> void:
    trials.append(
        {
            "index": cursor + 1,
            "expected": expected(),
            "correct": correct,
            "outcome": outcome,
            "time": elapsed,
            "interval": maxf(0, elapsed - trial_start),
            "held": maxf(0, duration)
        }
    )
    cursor += 1
    neutral = true
    pressed_at = -1
    if cursor >= settings.sequence.size() * int(settings.repeats):
        end("预定练习结束")


func pause(clock: float) -> void:
    if not active or paused:
        return
    advance(clock)
    if active:
        pause_start = clock
        paused = true
        neutral = true
        pressed_at = -1
        held.clear()


func resume(clock: float) -> void:
    if not active or not paused or not is_finite(clock) or clock < pause_start:
        return
    pause_total += clock - pause_start
    last_clock = clock
    paused = false
    neutral = true


func end(reason: String) -> void:
    if active:
        active = false
        paused = false
        stop_reason = reason.left(200)


func result() -> Dictionary:
    var payload := settings.duplicate(true)
    payload.trials = trials.duplicate(true)
    payload.events = events.duplicate(true)
    payload.elapsed = elapsed
    payload.completed = stop_reason == "预定练习结束"
    payload.reason = stop_reason
    return payload


func status_text() -> String:
    if paused:
        return "练习已暂停，明确继续后恢复。"
    if neutral:
        return "请先释放已按住的动作，并聚焦练习区域。"
    var name := expected()
    for row in settings.actions:
        if row.id == expected():
            name = String(row.name) + " · " + String(row.binding)
    var verb := "按下" if pressed_at < 0 else "保持后释放" if settings.mode == "hold" else "释放"
    return (
        "目标%d / %d：%s %s · 剩余%.1f秒"
        % [
            cursor + 1,
            settings.sequence.size() * int(settings.repeats),
            verb,
            name,
            maxf(0, float(settings.deadline) - (elapsed - trial_start))
        ]
    )


func progress() -> float:
    return (
        float(cursor) / maxi(1, settings.sequence.size() * int(settings.repeats))
        if not settings.is_empty()
        else 0.0
    )


static func action_index(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in payload.actions:
        result[row.id] = row
    return result


static func aggregate(payload: Dictionary) -> Array:
    var groups := {}
    var index := action_index(payload)
    for row in payload.trials:
        if not groups.has(row.expected):
            groups[row.expected] = {"count": 0, "correct": 0, "intervals": [], "held": []}
        var group: Dictionary = groups[row.expected]
        group.count = int(group.count) + 1
        group.correct = int(group.correct) + (1 if row.correct else 0)
        group.intervals.append(float(row.interval))
        group.held.append(float(row.held))
    var result := []
    for id in groups:
        var group: Dictionary = groups[id]
        var timing := K.distribution(group.intervals)
        var held := K.distribution(group.held)
        result.append(
            {
                "动作": index[id].name,
                "目标次数": group.count,
                "匹配次数": group.correct,
                "匹配率": float(group.correct) / group.count,
                "窗口提示后平均间隔秒": timing.mean,
                "间隔标准差": timing.deviation,
                "平均按住秒": held.mean
            }
        )
    return result


static func event_counts(payload: Dictionary) -> Dictionary:
    var result := {"映射按下": 0, "映射释放": 0, "重叠映射事件": 0}
    for row in payload.events:
        result["映射按下" if row.pressed else "映射释放"] += 1
        result["重叠映射事件"] += 1 if row.actions.size() > 1 else 0
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var index := action_index(payload)
    var rows := []
    for row in payload.trials:
        rows.append(
            {
                "目标序号": row.index,
                "动作": index[row.expected].name,
                "匹配": row.correct,
                "结果": row.outcome,
                "窗口提示后间隔秒": row.interval,
                "按住秒": row.held,
                "累计秒": row.time
            }
        )
    return [
        K.notice("显式输入练习", summary(payload)),
        {
            "kind": "custom",
            "title": "窗口输入练习区域",
            "view": VIEW,
            "data": {"active": false, "text": "启动后聚焦练习区域；文字编辑器和其它控件不会被记录。"}
        },
        K.table("逐项目标结果", ["目标序号", "动作", "匹配", "结果", "窗口提示后间隔秒", "按住秒", "累计秒"], rows),
        K.table(
            "动作分组统计",
            ["动作", "目标次数", "匹配次数", "匹配率", "窗口提示后平均间隔秒", "间隔标准差", "平均按住秒"],
            aggregate(payload)
        ),
        K.bars("窗口映射事件", event_counts(payload)),
        K.notice("结束原因", String(payload.reason)),
        K.notice("读数边界", "这些是本窗口事件对当前InputMap的匹配结果，不是游戏接受动作数、命中数或硬件反应时间。未记录文字内容，未注入游戏输入。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    return [
        K.table("记录分组", ["动作", "目标次数", "匹配次数", "匹配率", "窗口提示后平均间隔秒", "平均按住秒"], aggregate(a)),
        K.table("当前分组", ["动作", "目标次数", "匹配次数", "匹配率", "窗口提示后平均间隔秒", "平均按住秒"], aggregate(b)),
        K.notice("比较条件", "需先确认动作、绑定、模式与个人按住容差相同，才适合比较练习表现。")
    ]
