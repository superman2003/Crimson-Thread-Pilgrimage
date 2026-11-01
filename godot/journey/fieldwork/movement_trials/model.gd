extends RefCounted
const ADVANCED_VIEW := preload("res://journey/fieldwork/movement_trials/advanced_view.gd")
const ADVANCED := preload("res://journey/fieldwork/movement_trials/advanced.gd")
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const VIEW := preload("res://journey/fieldwork/movement_trials/view.gd")
const MAX_SAMPLES := 601
const RECORD_LIMIT := 12
var active := false
var paused := false
var stop_reason := ""
var settings: Dictionary = {}
var samples: Array = []
var origin_clock := 0.0
var last_clock := 0.0
var last_sample := -1.0
var elapsed := 0.0
var excluded := 0.0
var segment := 0
var exploring := false
var begun := false


static func introduction() -> String:
    return "显式启动后返回旅途，以约10Hz观察当前角色在个人区间内的位置、速度、能量与离地/着地转换。界面时间会分段排除，不改变物理、动作或奖励。"


static func capture(snapshot: Dictionary) -> Dictionary:
    return {
        "region": String(snapshot.get("region", "")),
        "origin": snapshot.get("player", {}).get("position", [0, 0]),
        "radius": 800.0,
        "duration": 30.0,
        "stationary": 20.0,
        "samples": [],
        "elapsed": 0.0,
        "excluded": 0.0,
        "completed": false,
        "reason": "尚未启动"
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("region") is String
        or not V.point(payload.get("origin")).is_finite()
        or not payload.get("samples") is Array
        or payload.samples.size() > MAX_SAMPLES
    ):
        return false
    var bounds := {
        "radius": [50, 10000],
        "duration": [5, 60],
        "stationary": [0, 200],
        "elapsed": [0, 120],
        "excluded": [0, 600]
    }
    for key in bounds:
        if (
            not V.number(payload.get(key))
            or payload[key] < bounds[key][0]
            or payload[key] > bounds[key][1]
        ):
            return false
    if (
        not payload.get("completed") is bool
        or not payload.get("reason") is String
        or payload.reason.length() > 200
    ):
        return false
    var last_time := -1.0
    var last_segment := -1
    for row in payload.samples:
        if (
            not row is Dictionary
            or not V.point(row.get("position")).is_finite()
            or not V.point(row.get("velocity")).is_finite()
        ):
            return false
        if not V.number(row.get("time")) or row.time < last_time or row.time < 0 or row.time > 120:
            return false
        if (
            not V.count(row.get("segment"), 1000)
            or int(row.segment) < last_segment
            or not row.get("grounded") is bool
        ):
            return false
        if int(row.segment) == last_segment and float(row.time) - last_time < 0.001:
            return false
        if (
            not V.number(row.get("energy"))
            or row.energy < 0
            or row.energy > 100000
            or not V.number(row.get("hp"))
            or absf(float(row.hp)) > 100000
        ):
            return false
        last_time = float(row.time)
        last_segment = int(row.segment)
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(_payload: Dictionary) -> Array:
    return [
        {"id": "radius", "name": "个人区间半径", "kind": "number", "min": 50, "max": 10000, "step": 50},
        {"id": "duration", "name": "活动采样秒数上限", "kind": "number", "min": 5, "max": 60},
        {"id": "stationary", "name": "个人低速判定阈值", "kind": "number", "min": 0, "max": 200, "step": 5}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d个观察样本 · 活动%.2f秒 · 排除界面/暂停%.2f秒"
        % [payload.samples.size(), payload.elapsed, payload.excluded]
    )


func begin(payload: Dictionary, clock: float) -> bool:
    if active or not validate(payload) or not is_finite(clock):
        return false
    settings = payload.duplicate(true)
    samples = []
    origin_clock = clock
    last_clock = clock
    last_sample = -1
    elapsed = 0
    excluded = 0
    segment = 0
    exploring = false
    begun = false
    active = true
    paused = false
    stop_reason = "等待返回旅途"
    return true


func advance(clock: float) -> void:
    if not active or not is_finite(clock):
        return
    if clock < last_clock:
        end("单调时钟发生回退")
        return
    last_clock = clock
    if not begun and clock - origin_clock > 30:
        end("等待返回旅途超过30秒")
    elif clock - origin_clock > 300:
        end("达到五分钟总时钟上限")


func idle(clock: float) -> void:
    if not active:
        return
    excluded += maxf(0, clock - last_clock)
    advance(clock)
    if exploring:
        segment += 1
    exploring = false
    last_sample = -1


func sample(snapshot: Dictionary, clock: float) -> void:
    if not active:
        return
    if snapshot.get("region") != settings.region:
        end("离开记录地区")
        return
    if paused or not K.flag(snapshot.get("exploring")):
        idle(clock)
        return
    var player: Dictionary = snapshot.get("player", {})
    var position := V.point(player.get("position"))
    var velocity := V.point(player.get("velocity"))
    if (
        not position.is_finite()
        or not velocity.is_finite()
        or not V.number(player.get("energy"))
        or not V.number(player.get("hp"))
    ):
        end("角色观察字段无效")
        return
    advance(clock)
    if not active:
        return
    if last_sample >= 0 and clock - last_sample > 0.5:
        end("观察间隔超过半秒，保留已有样本")
        return
    if last_sample >= 0 and clock - last_sample < 0.1 - 0.000001:
        return
    if last_sample >= 0:
        elapsed = minf(float(settings.duration), elapsed + clock - last_sample)
        if is_equal_approx(elapsed, float(settings.duration)):
            elapsed = float(settings.duration)
    last_sample = clock
    begun = true
    exploring = true
    samples.append(
        {
            "time": elapsed,
            "position": V.pair(position),
            "velocity": V.pair(velocity),
            "energy": float(player.energy),
            "hp": float(player.hp),
            "grounded": K.flag(player.get("grounded")),
            "segment": segment
        }
    )
    if float(player.hp) <= 0:
        end("观察到角色生命归零")
    elif position.distance_to(V.point(settings.origin)) > float(settings.radius):
        end("离开个人区间半径")
    elif elapsed >= float(settings.duration):
        end("活动采样时长达到上限")
    elif samples.size() >= MAX_SAMPLES:
        end("达到601个样本上限")


func pause(clock: float) -> void:
    if active and not paused:
        idle(clock)
        paused = true


func resume(clock: float) -> void:
    if active and paused and is_finite(clock) and clock >= last_clock:
        excluded += clock - last_clock
        last_clock = clock
        last_sample = -1
        paused = false


func end(reason: String) -> void:
    if active:
        active = false
        paused = false
        stop_reason = reason.left(200)


func result() -> Dictionary:
    var payload := settings.duplicate(true)
    payload.samples = samples.duplicate(true)
    payload.elapsed = elapsed
    payload.excluded = excluded
    payload.completed = stop_reason == "活动采样时长达到上限"
    payload.reason = stop_reason
    return payload


func status_text() -> String:
    if paused:
        return "机动观察已暂停。"
    if not begun:
        return "已准备：关闭工作台并返回旅途后开始采样。"
    return (
        "活动%.1f / %.1f秒 · %d个样本 · 分段%d · 返回此页可结束保存。"
        % [elapsed, settings.duration, samples.size(), segment + 1]
    )


func progress() -> float:
    return elapsed / maxf(1, float(settings.get("duration", 1)))


static func intervals(payload: Dictionary) -> Array:
    var result := []
    for i in range(1, payload.samples.size()):
        var a: Dictionary = payload.samples[i - 1]
        var b: Dictionary = payload.samples[i]
        var dt := float(b.time) - float(a.time)
        if a.segment != b.segment or dt <= 0:
            continue
        var distance := V.point(a.position).distance_to(V.point(b.position))
        result.append(
            {
                "time": b.time,
                "dt": dt,
                "distance": distance,
                "speed": V.point(b.velocity).length(),
                "horizontal": absf(V.point(b.velocity).x),
                "vertical": V.point(b.velocity).y,
                "landed": not a.grounded and b.grounded,
                "energy_change": float(b.energy) - float(a.energy),
                "hp_change": float(b.hp) - float(a.hp),
                "acceleration": (V.point(b.velocity) - V.point(a.velocity)).length() / dt
            }
        )
    return result


static func metrics(payload: Dictionary) -> Dictionary:
    var distance := 0.0
    var active_time := 0.0
    var stationary := 0.0
    var landings := 0
    var drops := 0
    var energy := 0.0
    var speeds := []
    var accelerations := []
    for row in intervals(payload):
        distance += float(row.distance)
        active_time += float(row.dt)
        stationary += float(row.dt) if float(row.speed) <= float(payload.stationary) else 0.0
        landings += 1 if row.landed else 0
        drops += 1 if float(row.energy_change) < 0 else 0
        energy += maxf(0, -float(row.energy_change))
        speeds.append(float(row.speed))
        accelerations.append(float(row.acceleration))
    return {
        "distance": distance,
        "time": active_time,
        "stationary": stationary,
        "landings": landings,
        "energy_drops": drops,
        "energy_loss": energy,
        "speeds": K.distribution(speeds),
        "accelerations": K.distribution(accelerations)
    }


static func bounds(payload: Dictionary) -> Rect2:
    var result := Rect2()
    var first := true
    for row in payload.samples:
        var point := V.point(row.position)
        result = Rect2(point, Vector2.ONE) if first else result.expand(point)
        first = false
    return result


static func segment_rows(payload: Dictionary) -> Array:
    var groups := {}
    for row in payload.samples:
        var id := str(int(row.segment))
        if not groups.has(id):
            groups[id] = {
                "first": row.time,
                "last": row.time,
                "count": 0,
                "distance": 0.0,
                "position": row.position
            }
        var group: Dictionary = groups[id]
        group.last = row.time
        group.count = int(group.count) + 1
        group.distance = (
            float(group.distance) + V.point(group.position).distance_to(V.point(row.position))
        )
        group.position = row.position
    var result := []
    for id in groups:
        var row: Dictionary = groups[id]
        result.append(
            {
                "分段": int(id) + 1,
                "样本数": row.count,
                "活动秒": float(row.last) - float(row.first),
                "采样折线距离": row.distance
            }
        )
    return result


static func rolling(payload: Dictionary) -> Array:
    var source := intervals(payload)
    var result := []
    for offset in range(0, source.size(), 20):
        var speeds := []
        var distance := 0.0
        var energy := 0.0
        for row in source.slice(offset, offset + 20):
            speeds.append(float(row.speed))
            distance += float(row.distance)
            energy += float(row.energy_change)
        var stats := K.distribution(speeds)
        result.append(
            {
                "观察段": str(offset + 1) + "—" + str(mini(offset + 20, source.size())),
                "样本间隔数": stats.count,
                "平均观测速度": stats.mean,
                "最大观测速度": stats.max,
                "折线距离": distance,
                "净能量变化": energy
            }
        )
    return result


static func speed_bands(payload: Dictionary) -> Dictionary:
    var result := {"个人低速阈值以内": 0.0, "低速阈值至200": 0.0, "200至400": 0.0, "400以上": 0.0}
    for row in intervals(payload):
        var speed := float(row.speed)
        var key := (
            "个人低速阈值以内"
            if speed <= float(payload.stationary)
            else "低速阈值至200" if speed < 200 else "200至400" if speed < 400 else "400以上"
        )
        result[key] += float(row.dt)
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var stats := metrics(payload)
    return [
        K.notice("个人机动区间观察", summary(payload)),
        {
            "kind": "custom",
            "title": "有分段边界的观察轨迹",
            "view": VIEW,
            "data": {"samples": payload.samples, "origin": payload.origin, "radius": payload.radius}
        },
        K.notice(
            "观测汇总",
            (
                "折线距离%.1f · 有效间隔%.2f秒 · 低速%.2f秒 · 观测着地转换%d · 能量下降间隔%d · 观测能量下降合计%.1f。"
                % [
                    stats.distance,
                    stats.time,
                    stats.stationary,
                    stats.landings,
                    stats.energy_drops,
                    stats.energy_loss
                ]
            )
        ),
        K.notice(
            "速度与变化",
            (
                "观测速度平均%.1f、中位%.1f、最大%.1f；速度向量差分均值%.1f。差分不等于引擎实际施加的加速度。"
                % [
                    stats.speeds.mean,
                    stats.speeds.median,
                    stats.speeds.max,
                    stats.accelerations.mean
                ]
            )
        ),
        K.table("分段边界", ["分段", "样本数", "活动秒", "采样折线距离"], segment_rows(payload)),
        K.table(
            "每二十个观察间隔", ["观察段", "样本间隔数", "平均观测速度", "最大观测速度", "折线距离", "净能量变化"], rolling(payload)
        ),
        K.bars("速度带内的观察秒数", speed_bands(payload)),
        K.notice("采样边界", "最多保存12份完整区间记录，另受辅助文件总容量限制。约10Hz观察会漏掉短动作、短暂着地与中间位移；不计真实跳跃数、施放数或命中数。界面和暂停分段之间不会连接折线。"),
        K.notice("结束原因", String(payload.reason))
    ]


static func _before_advanced_compare(a: Dictionary, b: Dictionary) -> Array:
    var left := metrics(a)
    var right := metrics(b)
    return [
        K.table(
            "个人区间结果比较",
            ["样本", "活动秒", "折线距离", "平均观测速度", "低速秒", "观测着地转换", "观测能量下降合计"],
            [
                {
                    "样本": "记录",
                    "活动秒": left.time,
                    "折线距离": left.distance,
                    "平均观测速度": left.speeds.mean,
                    "低速秒": left.stationary,
                    "观测着地转换": left.landings,
                    "观测能量下降合计": left.energy_loss
                },
                {
                    "样本": "当前",
                    "活动秒": right.time,
                    "折线距离": right.distance,
                    "平均观测速度": right.speeds.mean,
                    "低速秒": right.stationary,
                    "观测着地转换": right.landings,
                    "观测能量下降合计": right.energy_loss
                }
            ]
        ),
        K.notice("比较前提", "请核对地区、区间、采样时长与低速阈值。分段和漏采会影响结果。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    return _before_advanced_compare(a, b) + ADVANCED.sections(a, b) + [{"kind":"custom","title":"机动轨迹时间对齐 · 交互预览","view":ADVANCED_VIEW,"data":{"a":a,"b":b}}]
