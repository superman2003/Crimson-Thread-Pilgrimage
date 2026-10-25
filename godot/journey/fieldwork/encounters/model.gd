extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const VIEW := preload("res://journey/fieldwork/encounters/view.gd")


static func introduction() -> String:
    return "对已击败敌人的公开攻击字段建立个人复盘单，比较准备窗口、直线弹道假设与已获线技时间。计算不预测实际AI，不替代碰撞或战斗判定。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var enemies := []
    for source in K.enemies(snapshot).slice(0, 60):
        var attacks := []
        for move in source.get("attacks", []).slice(0, 32):
            if not move is Dictionary or not move.get("id") is String:
                continue
            var row := {
                "id": move.id,
                "name": String(move.get("name", move.id)),
                "type": String(move.get("type", "unknown"))
            }
            for field in [
                "windup",
                "active",
                "recover",
                "cooldown",
                "damage",
                "range",
                "projectile_speed",
                "hit_width",
                "hit_height",
                "offset"
            ]:
                row[field] = clampf(K.safe_number(move.get(field)), 0, 100000)
            attacks.append(row)
        enemies.append({"id": source.id, "name": source.name, "attacks": attacks})
    var skills := []
    for row in snapshot.get("build", {}).get("skills", []):
        if not K.flag(row.get("unlocked")):
            continue
        skills.append(
            {
                "id": row.id,
                "name": row.name,
                "cost": K.safe_number(row.get("energy_cost")),
                "duration":
                (
                    K.safe_number(row.get("windup"))
                    + K.safe_number(row.get("active"))
                    + K.safe_number(row.get("recovery"))
                ),
                "damage": K.safe_number(row.get("damage"))
            }
        )
    return {
        "enemies": enemies,
        "enemy": String(enemies[0].id) if not enemies.is_empty() else "",
        "skills": skills,
        "sequence": [],
        "distance": 200.0,
        "reaction": 0.25,
        "move_speed": 250.0,
        "health": maxf(1, K.safe_number(snapshot.get("player", {}).get("hp"), 5)),
        "damage_multiplier":
        maxf(
            0.01,
            K.safe_number(snapshot.get("build", {}).get("stats", {}).get("damage_taken_mult"), 1)
        ),
        "energy": maxf(0, K.safe_number(snapshot.get("player", {}).get("energy"))),
        "gap": 0.5
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("enemies") is Array
        or payload.enemies.size() > 60
        or not payload.get("skills") is Array
        or payload.skills.size() > 30
    ):
        return false
    if (
        not payload.get("enemy") is String
        or not payload.get("sequence") is Array
        or payload.sequence.size() > 8
    ):
        return false
    var bounds := {
        "distance": [0, 10000],
        "reaction": [0, 3],
        "move_speed": [1, 5000],
        "health": [1, 10000],
        "damage_multiplier": [0.01, 10],
        "energy": [0, 10000],
        "gap": [0, 30]
    }
    for key in bounds:
        if (
            not V.number(payload.get(key))
            or payload[key] < bounds[key][0]
            or payload[key] > bounds[key][1]
        ):
            return false
    var ids := {}
    for enemy in payload.enemies:
        if (
            not enemy is Dictionary
            or not enemy.get("id") is String
            or ids.has(enemy.id)
            or not enemy.get("name") is String
        ):
            return false
        if not enemy.get("attacks") is Array or enemy.attacks.size() > 32:
            return false
        var attacks := {}
        for move in enemy.attacks:
            if (
                not move is Dictionary
                or not move.get("id") is String
                or attacks.has(move.id)
                or not move.get("name") is String
                or not move.get("type") is String
            ):
                return false
            for field in [
                "windup",
                "active",
                "recover",
                "cooldown",
                "damage",
                "range",
                "projectile_speed",
                "hit_width",
                "hit_height",
                "offset"
            ]:
                if not V.number(move.get(field)) or move[field] < 0 or move[field] > 100000:
                    return false
            attacks[move.id] = true
        ids[enemy.id] = true
    if not payload.enemy.is_empty() and not ids.has(payload.enemy):
        return false
    var skills := {}
    for row in payload.skills:
        if (
            not row is Dictionary
            or not row.get("id") is String
            or skills.has(row.id)
            or not row.get("name") is String
        ):
            return false
        for key in ["cost", "duration", "damage"]:
            if not V.number(row.get(key)) or row[key] < 0 or row[key] > 100000:
                return false
        skills[row.id] = true
    var available := attack_index(payload)
    for id in payload.sequence:
        if not id is String or not available.has(id):
            return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func enemy(payload: Dictionary) -> Dictionary:
    for row in payload.enemies:
        if row.id == payload.enemy:
            return row
    return {"name": "尚无已击败敌人", "attacks": []}


static func fields(payload: Dictionary) -> Array:
    var enemies := []
    var attacks := []
    for row in payload.enemies:
        enemies.append({"id": row.id, "name": row.name})
    for row in enemy(payload).attacks:
        attacks.append({"id": row.id, "name": row.name})
    return [
        {"id": "enemy", "name": "已击败敌人", "kind": "choice", "choices": enemies},
        {
            "id": "sequence",
            "name": "个人假设攻击顺序",
            "kind": "ordered",
            "choices": attacks,
            "limit": 8,
            "allow_duplicates": true
        },
        {"id": "distance", "name": "个人距离假设", "kind": "number", "min": 0, "max": 10000, "step": 10},
        {"id": "reaction", "name": "个人准备间隔假设秒", "kind": "number", "min": 0, "max": 3, "step": 0.05},
        {
            "id": "move_speed",
            "name": "直线平移速度假设",
            "kind": "number",
            "min": 1,
            "max": 5000,
            "step": 10
        },
        {"id": "health", "name": "个人生命假设", "kind": "number", "min": 1, "max": 10000},
        {"id": "energy", "name": "个人能量假设", "kind": "number", "min": 0, "max": 10000},
        {"id": "gap", "name": "假设攻击间隔秒", "kind": "number", "min": 0, "max": 30, "step": 0.1}
    ]


static func summary(payload: Dictionary) -> String:
    return "%s · 距离假设%.0f · 准备间隔%.2f秒" % [enemy(payload).name, payload.distance, payload.reaction]


static func attack_index(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in enemy(payload).attacks:
        result[row.id] = row
    return result


static func duration(move: Dictionary) -> float:
    return float(move.windup) + float(move.active) + float(move.recover)


static func damage(payload: Dictionary, move: Dictionary) -> int:
    return (
        maxi(1, int(ceil(float(move.damage) * float(payload.damage_multiplier))))
        if float(move.damage) > 0
        else 0
    )


static func attack_rows(payload: Dictionary) -> Array:
    var result := []
    for move in enemy(payload).attacks:
        var direct := float(move.windup) - float(payload.reaction)
        var travel := (
            maxf(0, float(payload.distance) - float(move.offset)) / float(move.projectile_speed)
            if float(move.projectile_speed) > 0
            else 0.0
        )
        var projectile := float(move.windup) + travel - float(payload.reaction)
        var hit := damage(payload, move)
        result.append(
            {
                "攻击": move.name,
                "类型": move.type,
                "目录前摇秒": move.windup,
                "判定秒": move.active,
                "收势秒": move.recover,
                "准备余量秒": direct,
                "直线弹道假设余量秒": projectile if float(move.projectile_speed) > 0 else "不适用",
                "记录基础伤害": move.damage,
                "个人倍率单次伤害": hit,
                "从假设生命至零所需命中": int(ceil(float(payload.health) / hit)) if hit > 0 else "不适用",
                "目录触发距离内": float(payload.distance) <= float(move.range)
            }
        )
    return result


static func displacement_rows(payload: Dictionary) -> Array:
    var result := []
    for move in enemy(payload).attacks:
        var time := maxf(0, float(move.windup) - float(payload.reaction))
        var possible := time * float(payload.move_speed)
        var half_width := float(move.hit_width) * 0.5
        result.append(
            {
                "攻击": move.name,
                "可用准备秒": time,
                "假设直线平移距离": possible,
                "目录判定半宽": half_width,
                "仅长度差": possible - half_width,
                "目录判定半高": float(move.hit_height) * 0.5
            }
        )
    return result


static func response_matrix(payload: Dictionary) -> Array:
    var result := []
    for move in enemy(payload).attacks:
        for skill in payload.skills:
            var window := maxf(0, float(move.recover) - float(payload.reaction))
            result.append(
                {
                    "敌方攻击": move.name,
                    "已获线技": skill.name,
                    "收势余量秒": window,
                    "线技目录时长": skill.duration,
                    "仅时间长度可容纳": float(skill.duration) <= window,
                    "假设能量可支付": float(skill.cost) <= float(payload.energy),
                    "记录费用": skill.cost
                }
            )
    return result


static func sequence_rows(payload: Dictionary) -> Array:
    var attacks := attack_index(payload)
    var elapsed := 0.0
    var health := float(payload.health)
    var result := []
    for i in payload.sequence.size():
        var move: Dictionary = attacks[payload.sequence[i]]
        var hit := damage(payload, move)
        var begin := elapsed
        var active_begin := begin + float(move.windup)
        elapsed += duration(move)
        health -= hit
        result.append(
            {
                "序号": i + 1,
                "攻击": move.name,
                "开始秒": begin,
                "判定开始秒": active_begin,
                "结束秒": elapsed,
                "假设单次伤害": hit,
                "假设累计生命": health,
                "接续间隔": payload.gap
            }
        )
        elapsed += float(payload.gap)
    return result


static func risk_grid(payload: Dictionary) -> Array:
    var result := []
    for delay in [0.1, 0.2, 0.3, 0.5, 0.8, 1.0]:
        var count := 0
        var sample := payload.duplicate(true)
        sample.reaction = float(delay)
        for move in enemy(sample).attacks:
            if float(move.windup) < float(delay):
                count += 1
        result.append(
            {"个人准备间隔秒": delay, "前摇短于假设的攻击数": count, "目录攻击样本数": enemy(payload).attacks.size()}
        )
    return result


static func range_study(payload: Dictionary) -> Array:
    var result := []
    for distance in [50, 100, 200, 400, 800, 1200]:
        var triggers := 0
        var projectiles := []
        for move in enemy(payload).attacks:
            triggers += 1 if float(distance) <= float(move.range) else 0
            if float(move.projectile_speed) > 0:
                projectiles.append(
                    maxf(0, float(distance) - float(move.offset)) / float(move.projectile_speed)
                )
        var stats := K.distribution(projectiles)
        result.append(
            {
                "距离假设": distance,
                "目录触发距离覆盖攻击数": triggers,
                "直线弹道平均秒": stats.mean,
                "弹道字段样本数": stats.count
            }
        )
    return result


static func attack_statistics(payload: Dictionary) -> Array:
    var fields := {
        "windup": "前摇秒",
        "active": "判定秒",
        "recover": "收势秒",
        "cooldown": "目录冷却秒",
        "damage": "基础伤害",
        "range": "目录触发距离"
    }
    var result := []
    for key in fields:
        var values := []
        for move in enemy(payload).attacks:
            values.append(move[key])
        var stats := K.distribution(values)
        result.append(
            {
                "字段": fields[key],
                "样本数": stats.count,
                "最小": stats.min,
                "中位": stats.median,
                "最大": stats.max,
                "平均": stats.mean
            }
        )
    return result


static func efficient_skills(payload: Dictionary) -> Array:
    var result := []
    for skill in payload.skills:
        result.append(
            {
                "已获线技": skill.name,
                "记录伤害": skill.damage,
                "记录费用": skill.cost,
                "目录动作秒": skill.duration,
                "伤害费用比":
                float(skill.damage) / float(skill.cost) if float(skill.cost) > 0 else "免费动作",
                "仅能量约束可用次数":
                (
                    int(floor(float(payload.energy) / float(skill.cost)))
                    if float(skill.cost) > 0
                    else "不受费用限制"
                )
            }
        )
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    if payload.enemies.is_empty():
        return [K.notice("尚无已击败样本", "实际击败敌人后，按原旅记标记公开相应复盘字段。")]
    return [
        K.notice("个人遭遇复盘单", summary(payload)),
        {
            "kind": "custom",
            "title": "已击败敌人的目录阶段",
            "view": VIEW,
            "data": {"attacks": enemy(payload).attacks, "reaction": payload.reaction}
        },
        K.table(
            "攻击准备与资源假设",
            ["攻击", "类型", "目录前摇秒", "判定秒", "收势秒", "准备余量秒", "直线弹道假设余量秒", "个人倍率单次伤害", "从假设生命至零所需命中"],
            attack_rows(payload)
        ),
        K.table(
            "仅几何长度的平移参考",
            ["攻击", "可用准备秒", "假设直线平移距离", "目录判定半宽", "仅长度差", "目录判定半高"],
            displacement_rows(payload),
            "没有模拟角色位置、墙体、落脚、弹道弧线或无敌帧；长度足够不表示一定安全。"
        ),
        K.table(
            "已获线技与收势长度",
            ["敌方攻击", "已获线技", "收势余量秒", "线技目录时长", "仅时间长度可容纳", "假设能量可支付", "记录费用"],
            response_matrix(payload),
            "还需实际装备、朝向和命中条件，不能据此承诺反击。"
        ),
        K.table(
            "个人假设攻击顺序",
            ["序号", "攻击", "开始秒", "判定开始秒", "结束秒", "假设单次伤害", "假设累计生命"],
            sequence_rows(payload),
            "由个人编排，不是实际AI连招、录像或伤害预测。"
        ),
        K.table("准备间隔敏感性", ["个人准备间隔秒", "前摇短于假设的攻击数", "目录攻击样本数"], risk_grid(payload)),
        K.table("距离字段敏感性", ["距离假设", "目录触发距离覆盖攻击数", "直线弹道平均秒", "弹道字段样本数"], range_study(payload)),
        K.table("该敌人的目录字段分布", ["字段", "样本数", "最小", "中位", "最大", "平均"], attack_statistics(payload)),
        K.table(
            "已获线技的资源参考",
            ["已获线技", "记录伤害", "记录费用", "目录动作秒", "伤害费用比", "仅能量约束可用次数"],
            efficient_skills(payload)
        ),
        K.notice("数据边界", "敌人必须已有严格布尔击败标记。伤害计算没有计入防护技能、敌人阶段、防御、状态效果或游戏中的实际接受判定。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    return [
        K.table("记录敌人字段", ["字段", "样本数", "最小", "中位", "最大", "平均"], attack_statistics(a)),
        K.table("当前敌人字段", ["字段", "样本数", "最小", "中位", "最大", "平均"], attack_statistics(b)),
        K.notice("比较前提", "请核对敌人、构筑、距离和准备间隔假设；两份记录不必是同一次实际遭遇。")
    ]


static func field_changed(payload: Dictionary, key: String) -> Dictionary:
    var next := payload.duplicate(true)
    if key == "enemy":
        var known := attack_index(next)
        var sequence := []
        for id in next.sequence:
            if known.has(id):
                sequence.append(id)
        next.sequence = sequence
    return next
