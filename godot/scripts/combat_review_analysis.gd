extends RefCounted
## Analysis uses saved observations only. Rates are absent for zero exposure;
## direct needle damage must never be presented as total combat damage.
const LEDGER := preload("res://scripts/combat_ledger.gd")
const SCOPES := ["全部已保存观察", "所选地区", "所选地区与契印"]

static func select(history: Array, anchor: Dictionary, scope: int) -> Array:
    var result: Array = []
    if scope not in [0, 1, 2] or (scope > 0 and anchor.is_empty()):return result
    for raw in history.slice(0, LEDGER.LIMIT):
        var row := LEDGER.sanitize(raw)
        if row.is_empty():continue
        if scope > 0 and row.region != anchor.get("region"):continue
        if scope > 1 and row.crest != anchor.get("crest"):continue
        result.append(row)
    return result

static func summarize(records: Array) -> Dictionary:
    var totals := {"observations":0, "seconds":0.0, "deaths":0, "timed_observations":0}
    for key in LEDGER.COUNTERS:totals[key] = 0
    for raw in records:
        var row := LEDGER.sanitize(raw)
        if row.is_empty():continue
        totals.observations += 1
        totals.seconds += row.seconds
        if row.seconds > 0:totals.timed_observations += 1
        if row.reason == "倒下":totals.deaths += 1
        for key in LEDGER.COUNTERS:totals[key] += row[key]
    totals["heal_attempts"] = totals.heals + totals.interruptions
    # Aggregated rates have a shared exposure denominator. A zero-duration
    # observation contributes to raw totals but not to timed rate numerators.
    var timed_damage := 0
    var timed_incoming := 0
    for raw in records:
        var row := LEDGER.sanitize(raw)
        if row.is_empty() or row.seconds <= 0:continue
        timed_damage += row.outgoing
        timed_incoming += row.incoming
    totals["damage_per_minute"] = timed_damage * 60.0 / totals.seconds if totals.seconds > 0 else null
    totals["incoming_per_minute"] = timed_incoming * 60.0 / totals.seconds if totals.seconds > 0 else null
    totals["heal_completion"] = totals.heals * 100.0 / totals.heal_attempts if totals.heal_attempts > 0 else null
    totals["perfect_share"] = totals.perfect * 100.0 / totals.guards if totals.guards > 0 else null
    return totals

static func metric(value: Variant, suffix: String = "") -> String:
    return "暂无可计算记录" if value == null else "%.1f%s" % [float(value), suffix]

static func report(history: Array, anchor: Dictionary, scope: int) -> String:
    var selected := select(history, anchor, scope)
    var totals := summarize(selected)
    var lines: Array[String] = [SCOPES[clampi(scope, 0, 2)], "仅统计保留的最近20次记录；没有记录的游玩时间不计入。"]
    if selected.is_empty():
        lines.append("这个范围还没有可读取的已保存观察。")
        return "\n".join(lines)
    lines.append("\n%d次观察 · 有效时长 %.1f秒 · 倒下%d次" % [totals.observations, totals.seconds, totals.deaths])
    lines.append("针击伤害%d · 实际承伤%d · 击倒%d（首领%d）" % [totals.outgoing, totals.incoming, totals.kills, totals.boss_kills])
    lines.append("针击伤害/分钟：" + metric(totals.damage_per_minute))
    lines.append("承伤/分钟：" + metric(totals.incoming_per_minute))
    lines.append("格挡%d · 及时%d · 及时占比：%s" % [totals.guards, totals.perfect, metric(totals.perfect_share, "%")])
    lines.append("疗伤完成%d · 中断%d · 完成占比：%s" % [totals.heals, totals.interruptions, metric(totals.heal_completion, "%")])
    lines.append("施术%d · 绯线流入%d / 流出%d" % [totals.casts, totals.energy_in, totals.energy_out])
    lines.append("\n针击伤害不含战具或持续效果；绯线变化包括休整与退款。未记录未命中次数，不能据此计算命中率。")
    lines.append("不同观察的敌群、时长与构筑可能不同；这些数字供复盘，不表示难度或契印强弱排名。零时长记录保留计数，不参与每分钟速率。")
    return "\n".join(lines)

static func comparable(history: Array, anchor: Dictionary) -> Array:
    var result := select(history, anchor, 2)
    # Equality is intentional: persisted records do not have stable IDs. Never
    # compare a selected observation with another copy of itself.
    return result.filter(func(row: Dictionary):return row != anchor)
