extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const VIEW := preload("res://journey/fieldwork/rhythm/view.gd")
var active := false
var paused := false
var origin := 0.0
var pause_start := 0.0
var pause_total := 0.0
var last_clock := 0.0
var elapsed := 0.0
var settings: Dictionary = {}
var taps: Array = []
var stop_reason := ""


static func introduction() -> String:
    return "显式启动后在本工作台窗口用T或击拍按钮练习节拍，记录单调时钟上的输入时间。结果包含窗口事件处理延迟，不能测量硬件或音频延迟。"


static func capture(_snapshot: Dictionary) -> Dictionary:
    return {
        "bpm": 80.0,
        "beats": 16.0,
        "subdivision": "1",
        "swing": 50.0,
        "lead": 2.0,
        "tolerance": 150.0,
        "taps": [],
        "elapsed": 0.0,
        "completed": false,
        "reason": "尚未启动"
    }


static func validate(payload: Dictionary) -> bool:
    var bounds := {
        "bpm": [30, 240],
        "beats": [4, 64],
        "swing": [50, 75],
        "lead": [1, 10],
        "tolerance": [10, 500],
        "elapsed": [0, 600]
    }
    for key in bounds:
        if (
            not V.number(payload.get(key))
            or payload[key] < bounds[key][0]
            or payload[key] > bounds[key][1]
        ):
            return false
    if (
        not V.count(payload.beats, 64)
        or payload.get("subdivision") not in ["1", "2", "4"]
        or not payload.get("completed") is bool
    ):
        return false
    if (
        not payload.get("reason") is String
        or payload.reason.length() > 200
        or not payload.get("taps") is Array
        or payload.taps.size() > 512
    ):
        return false
    var previous := -1.0
    for tap in payload.taps:
        if not V.number(tap) or float(tap) < 0 or float(tap) > 600 or float(tap) < previous:
            return false
        previous = float(tap)
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(_payload: Dictionary) -> Array:
    return [
        {"id": "bpm", "name": "每分钟节拍数", "kind": "number", "min": 30, "max": 240},
        {"id": "beats", "name": "节拍数", "kind": "number", "min": 4, "max": 64},
        {
            "id": "subdivision",
            "name": "每拍细分",
            "kind": "choice",
            "choices":
            [{"id": "1", "name": "一分"}, {"id": "2", "name": "二分"}, {"id": "4", "name": "四分"}]
        },
        {"id": "swing", "name": "偶数细分的前半段比例百分比", "kind": "number", "min": 50, "max": 75},
        {"id": "lead", "name": "准备秒数", "kind": "number", "min": 1, "max": 10},
        {"id": "tolerance", "name": "命中容差毫秒", "kind": "number", "min": 10, "max": 500, "step": 10}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%.0f BPM · %d拍 × %s细分 · %d次窗口击拍"
        % [payload.bpm, payload.beats, payload.subdivision, payload.taps.size()]
    )


static func targets(payload: Dictionary) -> Array:
    var result := []
    var subdivision := int(payload.subdivision)
    var step := 60.0 / float(payload.bpm) / subdivision
    var swing := float(payload.swing) / 100 if subdivision > 1 else 0.5
    for i in int(payload.beats) * subdivision:
        var time: float = float(payload.lead) + floor(float(i) / 2) * step * 2
        if i % 2:
            time += step * 2 * swing
        result.append(time)
    return result


static func finish_time(payload: Dictionary) -> float:
    var schedule := targets(payload)
    return float(schedule[-1]) + maxf(0.5, 60.0 / float(payload.bpm))


func begin(payload: Dictionary, clock: float) -> bool:
    if active or not validate(payload) or not is_finite(clock):
        return false
    settings = payload.duplicate(true)
    settings.taps = []
    taps = []
    origin = clock
    pause_total = 0
    elapsed = 0
    last_clock = clock
    paused = false
    active = true
    stop_reason = "进行中"
    return true


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
    if elapsed >= finish_time(settings):
        elapsed = finish_time(settings)
        end("预定节拍结束")


func tap(clock: float) -> bool:
    if not active or paused or taps.size() >= 512:
        return false
    advance(clock)
    if not active:
        return false
    if not taps.is_empty() and elapsed - float(taps[-1]) < 0.025:
        return false
    taps.append(elapsed)
    return true


func pause(clock: float) -> void:
    if not active or paused:
        return
    advance(clock)
    if active:
        paused = true
        pause_start = clock


func resume(clock: float) -> void:
    if not active or not paused or not is_finite(clock) or clock < pause_start:
        return
    pause_total += clock - pause_start
    last_clock = clock
    paused = false


func end(reason: String) -> void:
    if not active:
        return
    active = false
    paused = false
    stop_reason = reason.left(200)


func result() -> Dictionary:
    var payload := settings.duplicate(true)
    payload.taps = taps.duplicate()
    payload.elapsed = elapsed
    payload.completed = stop_reason == "预定节拍结束"
    payload.reason = stop_reason
    return payload


static func align(payload: Dictionary) -> Dictionary:
    var expected := targets(payload)
    var actual: Array = payload.taps
    var tolerance := float(payload.tolerance) / 1000
    var previous := []
    for j in range(actual.size() + 1):
        previous.append(float(j))
    var back := []
    back.append([])
    for i in range(1, expected.size() + 1):
        var current := [float(i)]
        var directions := [1]
        for j in range(1, actual.size() + 1):
            var error := absf(float(actual[j - 1]) - float(expected[i - 1]))
            var match_cost := (
                float(previous[j - 1]) + error / tolerance if error <= tolerance else INF
            )
            var missing := float(previous[j]) + 1
            var extra := float(current[j - 1]) + 1
            if match_cost <= missing and match_cost <= extra:
                current.append(match_cost)
                directions.append(0)
            elif missing <= extra:
                current.append(missing)
                directions.append(1)
            else:
                current.append(extra)
                directions.append(2)
        back.append(directions)
        previous = current
    var i := expected.size()
    var j := actual.size()
    var matches := []
    var missing := []
    var extras := []
    while i > 0 or j > 0:
        if i == 0:
            extras.push_front(j - 1)
            j -= 1
        elif j == 0 or int(back[i][j]) == 1:
            missing.push_front(i - 1)
            i -= 1
        elif int(back[i][j]) == 2:
            extras.push_front(j - 1)
            j -= 1
        else:
            matches.push_front(
                {
                    "target": i - 1,
                    "tap": j - 1,
                    "time": actual[j - 1],
                    "expected": expected[i - 1],
                    "error_ms": (float(actual[j - 1]) - float(expected[i - 1])) * 1000
                }
            )
            i -= 1
            j -= 1
    return {"matches": matches, "missing": missing, "extras": extras, "targets": expected}


static func statistics(alignment: Dictionary) -> Dictionary:
    var errors := []
    var absolute := []
    for row in alignment.matches:
        errors.append(row.error_ms)
        absolute.append(absf(float(row.error_ms)))
    var signed := K.distribution(errors)
    var magnitude := K.distribution(absolute)
    return {
        "count": errors.size(),
        "mean": signed.mean,
        "deviation": signed.deviation,
        "median_absolute": magnitude.median,
        "max_absolute": magnitude.max,
        "missing": alignment.missing.size(),
        "extras": alignment.extras.size()
    }


static func regression(alignment: Dictionary) -> Dictionary:
    if alignment.matches.size() < 3:
        return {"defined": false, "slope": 0.0, "intercept": 0.0, "rms": 0.0}
    var xs := []
    var ys := []
    for row in alignment.matches:
        xs.append(float(row.expected))
        ys.append(float(row.error_ms))
    var x := K.distribution(xs)
    var y := K.distribution(ys)
    var numerator := 0.0
    var denominator := 0.0
    for i in xs.size():
        numerator += (float(xs[i]) - float(x.mean)) * (float(ys[i]) - float(y.mean))
        denominator += pow(float(xs[i]) - float(x.mean), 2)
    if denominator < 0.000001:
        return {"defined": false, "slope": 0.0, "intercept": 0.0, "rms": 0.0}
    var slope := numerator / denominator
    var intercept := float(y.mean) - slope * float(x.mean)
    var squared := 0.0
    for i in xs.size():
        squared += pow(float(ys[i]) - (slope * float(xs[i]) + intercept), 2)
    return {
        "defined": true, "slope": slope, "intercept": intercept, "rms": sqrt(squared / xs.size())
    }


static func rolling(alignment: Dictionary) -> Array:
    var result := []
    for start in range(0, alignment.matches.size(), 8):
        var values := []
        for row in alignment.matches.slice(start, start + 8):
            values.append(float(row.error_ms))
        var stats := K.distribution(values)
        result.append(
            {
                "匹配序号": str(start + 1) + "—" + str(mini(start + 8, alignment.matches.size())),
                "样本数": stats.count,
                "平均偏差毫秒": stats.mean,
                "偏差标准差": stats.deviation,
                "最早偏差": stats.min,
                "最晚偏差": stats.max
            }
        )
    return result


static func histogram(alignment: Dictionary) -> Dictionary:
    var result := {
        "早于100ms": 0, "早50—100ms": 0, "早0—50ms": 0, "晚0—50ms": 0, "晚50—100ms": 0, "晚于100ms": 0
    }
    for row in alignment.matches:
        var error := float(row.error_ms)
        var key := (
            "早于100ms"
            if error < -100
            else (
                "早50—100ms"
                if error < -50
                else (
                    "早0—50ms"
                    if error < 0
                    else "晚0—50ms" if error <= 50 else "晚50—100ms" if error <= 100 else "晚于100ms"
                )
            )
        )
        result[key] += 1
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var aligned := align(payload)
    var stats := statistics(aligned)
    var trend := regression(aligned)
    var rows := []
    for row in aligned.matches:
        rows.append(
            {
                "目标序号": int(row.target) + 1,
                "击拍序号": int(row.tap) + 1,
                "目标秒": row.expected,
                "输入秒": row.time,
                "偏差毫秒": row.error_ms
            }
        )
    return [
        K.notice("窗口节奏练习", summary(payload)),
        {
            "kind": "custom",
            "title": "匹配击拍偏差",
            "view": VIEW,
            "data": {"matches": aligned.matches, "tolerance": payload.tolerance}
        },
        K.notice(
            "匹配统计",
            (
                "命中%d · 漏拍%d · 多余击拍%d · 平均偏差%.1fms · 绝对偏差中位数%.1fms · 标准差%.1fms。"
                % [
                    stats.count,
                    stats.missing,
                    stats.extras,
                    stats.mean,
                    stats.median_absolute,
                    stats.deviation
                ]
            )
        ),
        K.table("逐次匹配", ["目标序号", "击拍序号", "目标秒", "输入秒", "偏差毫秒"], rows),
        K.bars("匹配偏差分布", histogram(aligned)),
        K.table("每八次匹配的稳定性", ["匹配序号", "样本数", "平均偏差毫秒", "偏差标准差", "最早偏差", "最晚偏差"], rolling(aligned)),
        K.notice(
            "偏差趋势",
            (
                (
                    "偏差每秒变化%.2fms · 拟合截距%.1fms · 残差RMS %.1fms。"
                    % [trend.slope, trend.intercept, trend.rms]
                )
                if trend.defined
                else "至少三次有效匹配后显示线性偏差趋势。"
            )
        ),
        K.notice("结束状态", String(payload.reason)),
        K.notice("测量边界", "没有播放校准音轨或读取设备时间戳。数值是窗口事件与软件时钟的差，不是硬件反应时间或音频延迟。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := statistics(align(a))
    var right := statistics(align(b))
    return [
        K.table(
            "练习结果比较",
            ["样本", "BPM", "匹配", "漏拍", "绝对偏差中位ms", "标准差ms"],
            [
                {
                    "样本": "记录",
                    "BPM": a.bpm,
                    "匹配": left.count,
                    "漏拍": left.missing,
                    "绝对偏差中位ms": left.median_absolute,
                    "标准差ms": left.deviation
                },
                {
                    "样本": "当前",
                    "BPM": b.bpm,
                    "匹配": right.count,
                    "漏拍": right.missing,
                    "绝对偏差中位ms": right.median_absolute,
                    "标准差ms": right.deviation
                }
            ]
        )
    ]


func status_text() -> String:
    if paused:
        return "练习已暂停；明确继续后恢复。"
    if elapsed < float(settings.lead):
        return "准备中：%.1f秒后开始。" % (float(settings.lead) - elapsed)
    var expected := targets(settings)
    var next := 0
    while next < expected.size() and float(expected[next]) < elapsed:
        next += 1
    var until := maxf(0, float(expected[mini(next, expected.size() - 1)]) - elapsed)
    return (
        "目标%d / %d · 下一目标%.2f秒 · 已记录%d次击拍。"
        % [mini(next + 1, expected.size()), expected.size(), until, taps.size()]
    )


func progress() -> float:
    if settings.is_empty() or elapsed < float(settings.lead):
        return 0.0
    var step := 60.0 / float(settings.bpm) / int(settings.subdivision)
    return 1 - fposmod(elapsed - float(settings.lead), step) / step
