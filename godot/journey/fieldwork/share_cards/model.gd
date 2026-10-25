extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const MILESTONES := preload("res://journey/fieldwork/milestones/model.gd")
const DIFF := preload("res://journey/fieldwork/save_diff/model.gd")
const VIEW := preload("res://journey/fieldwork/share_cards/view.gd")
const MAX_BYTES := 24576
const MAX_CODE := 40000
const FLAGS := [
    "include_counts",
    "include_date",
    "include_location",
    "include_abilities",
    "include_equipment",
    "include_quests",
    "include_inventory",
    "include_stats",
    "include_note"
]


static func introduction() -> String:
    return "用明确勾选的公开旅途字段生成分享预览和校验码。默认只含本次收录条目数量与日期，不含位置、装备名称、任务文字或个人备注；不会自动上传。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var milestones := MILESTONES.capture(snapshot)
    var abilities := []
    var equipment := []
    var quests := []
    var inventory := []
    for row in milestones.facts:
        match String(row.kind):
            "能力":
                abilities.append(row.name)
            "装备":
                equipment.append(row.name)
            "任务":
                quests.append({"title": row.name, "status": row.status})
            "物资":
                inventory.append({"name": row.name, "count": row.count})
    var room_name := String(
        K.room_index(snapshot).get(snapshot.get("room", ""), {}).get("name", "已知房间")
    )
    var stats := {}
    for row in MILESTONES.stat_rows(milestones):
        stats[row["构筑字段"]] = row["记录值"]
    return {
        "title": "我的巡礼观察",
        "recorded": int(snapshot.get("timestamp", 0)),
        "region": String(snapshot.get("region_name", "")),
        "room": room_name,
        "abilities": abilities.slice(0, 40),
        "equipment": equipment.slice(0, 40),
        "quests": quests.slice(0, 40),
        "inventory": inventory.slice(0, 40),
        "stats": stats,
        "known_rooms": K.rooms(snapshot).size(),
        "note": "",
        "include_counts": true,
        "include_date": true,
        "include_location": false,
        "include_abilities": false,
        "include_equipment": false,
        "include_quests": false,
        "include_inventory": false,
        "include_stats": false,
        "include_note": false
    }


static func validate(payload: Dictionary) -> bool:
    for key in FLAGS:
        if not payload.get(key) is bool:
            return false
    for key in ["title", "region", "room", "note"]:
        if (
            not payload.get(key) is String
            or payload[key].length() > (1000 if key == "note" else 200)
        ):
            return false
    if (
        not V.count(payload.get("recorded"), 9999999999)
        or not V.count(payload.get("known_rooms"), 10000)
    ):
        return false
    for key in ["abilities", "equipment"]:
        if not payload.get(key) is Array or payload[key].size() > 40:
            return false
        for value in payload[key]:
            if not value is String or value.length() > 200:
                return false
    for key in ["quests", "inventory"]:
        if not payload.get(key) is Array or payload[key].size() > 40:
            return false
        for row in payload[key]:
            if not row is Dictionary:
                return false
            if (
                key == "quests"
                and (
                    not row.get("title") is String
                    or not row.get("status") is String
                    or row.title.length() > 200
                    or row.status.length() > 100
                )
            ):
                return false
            if (
                key == "inventory"
                and (
                    not row.get("name") is String
                    or row.name.length() > 200
                    or not V.count(row.get("count"))
                )
            ):
                return false
    if not payload.get("stats") is Dictionary or payload.stats.size() > 30:
        return false
    for key in payload.stats:
        if (
            not key is String
            or key.length() > 100
            or not V.number(payload.stats[key])
            or absf(float(payload.stats[key])) > 1000000
        ):
            return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(_payload: Dictionary) -> Array:
    var result := [
        {"id": "title", "name": "公开分享标题", "max": 80}, {"id": "note", "name": "可选公开备注", "max": 1000}
    ]
    var captions := {
        "include_counts": "公开本次收录条目数量（每类最多40项）",
        "include_date": "公开观察日期（UTC日，不含时分）",
        "include_location": "公开当前地区与房间名称",
        "include_abilities": "公开已获能力名称",
        "include_equipment": "公开已获装备名称",
        "include_quests": "公开已知任务标题与状态",
        "include_inventory": "公开持有物资名称与数量",
        "include_stats": "公开当前构筑字段",
        "include_note": "公开个人备注"
    }
    for flag in FLAGS:
        result.append({"id": flag, "name": captions[flag], "kind": "toggle"})
    return result


static func summary(payload: Dictionary) -> String:
    var selected := 0
    for key in FLAGS:
        selected += 1 if payload[key] else 0
    return "%d组字段已勾选 · 请先查看将分享的内容" % selected


static func scrub(text: String, limit: int = 1000) -> Dictionary:
    var clean := V.text(text, limit)
    var count := 0
    var patterns := [
        {
            "pattern":
            "(?i)\\b(?:token|password|passwd|secret|api_key|authorization)\\s*[:=]\\s*[^\\s,;]+",
            "replacement": "[口令样式已移除]"
        },
        {"pattern": "(?i)\\bbearer\\s+[A-Za-z0-9._-]+", "replacement": "Bearer [已移除]"},
        {"pattern": '[A-Za-z]:[\\\\/][^\\s<>\\"]+', "replacement": "[本地路径已移除]"},
        {"pattern": '/(?:home|Users|root|workspace|tmp)/[^\\s<>\\"]+', "replacement": "[本地路径已移除]"},
        {"pattern": '(?:user|res)://[^\\s<>\\"]+', "replacement": "[本地资源路径已移除]"},
        {"pattern": "[A-Za-z0-9_.+%-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "replacement": "[邮箱已移除]"},
        {"pattern": "(https?://[^\\s?<>]+)\\?[^\\s<>]+", "replacement": "$1?[查询参数已移除]"}
    ]
    for rule in patterns:
        var expression := RegEx.new()
        if expression.compile(String(rule.pattern)) != OK:
            return {"text": "[备注过滤未就绪，未输出原文]", "removed": count, "ok": false}
        var matches := expression.search_all(clean)
        count += matches.size()
        clean = expression.sub(clean, String(rule.replacement), true)
    return {"text": clean.left(limit), "removed": count, "ok": true}


static func clean_text(text: String, limit: int = 200) -> String:
    return String(scrub(text, limit).text)


static func body(payload: Dictionary) -> Dictionary:
    var card := {
        "format": "pilgrimage-share-card",
        "version": 1,
        "title": clean_text(String(payload.title), 80)
    }
    if payload.include_date:
        card["date"] = (
            V.date(int(payload.recorded)).left(10) if int(payload.recorded) > 0 else "未记录"
        )
    if payload.include_counts:
        card["summary"] = {
            "known_rooms": int(payload.known_rooms),
            "abilities": payload.abilities.size(),
            "equipment": payload.equipment.size(),
            "known_quests": payload.quests.size(),
            "inventory_kinds": payload.inventory.size()
        }
    if payload.include_location:
        card["location"] = {
            "region": clean_text(String(payload.region)), "room": clean_text(String(payload.room))
        }
    for key in ["abilities", "equipment"]:
        if payload["include_" + key]:
            var values := []
            for value in payload[key]:
                values.append(clean_text(String(value)))
            card[key] = values
    if payload.include_quests:
        var rows := []
        for quest in payload.quests:
            rows.append(
                {
                    "title": clean_text(String(quest.title)),
                    "status": clean_text(String(quest.status), 100)
                }
            )
        card["quests"] = rows
    if payload.include_inventory:
        var rows := []
        for item in payload.inventory:
            rows.append({"name": clean_text(String(item.name)), "count": int(item.count)})
        card["inventory"] = rows
    if payload.include_stats:
        var stats := {}
        for key in payload.stats:
            stats[clean_text(String(key), 100)] = float(payload.stats[key])
        card["stats"] = stats
    if payload.include_note:
        card["note"] = clean_text(String(payload.note), 1000)
    return card


static func valid_body(card: Dictionary) -> bool:
    if (
        card.get("format") != "pilgrimage-share-card"
        or card.get("version") != 1
        or not card.get("title") is String
        or card.title.length() > 80
    ):
        return false
    var allowed := [
        "format",
        "version",
        "title",
        "date",
        "summary",
        "location",
        "abilities",
        "equipment",
        "quests",
        "inventory",
        "stats",
        "note"
    ]
    for key in card:
        if key not in allowed:
            return false
    if card.has("date") and (not card.date is String or card.date.length() > 32):
        return false
    if card.has("note") and (not card.note is String or card.note.length() > 1000):
        return false
    if card.has("summary"):
        if not card.summary is Dictionary or card.summary.size() > 5:
            return false
        for key in card.summary:
            if (
                (
                    key
                    not in [
                        "known_rooms", "abilities", "equipment", "known_quests", "inventory_kinds"
                    ]
                )
                or not V.count(card.summary[key], 10000)
            ):
                return false
    if card.has("location"):
        if (
            not card.location is Dictionary
            or card.location.keys().any(func(key: Variant): return key not in ["region", "room"])
        ):
            return false
        for value in card.location.values():
            if not value is String or value.length() > 200:
                return false
    for key in ["abilities", "equipment"]:
        if not card.has(key):
            continue
        if not card[key] is Array or card[key].size() > 40:
            return false
        for value in card[key]:
            if not value is String or value.length() > 200:
                return false
    for key in ["quests", "inventory"]:
        if not card.has(key):
            continue
        if not card[key] is Array or card[key].size() > 40:
            return false
        for row in card[key]:
            if not row is Dictionary or row.size() != 2:
                return false
            if key == "quests":
                if (
                    not row.get("title") is String
                    or row.title.length() > 200
                    or not row.get("status") is String
                    or row.status.length() > 100
                ):
                    return false
            elif (
                not row.get("name") is String
                or row.name.length() > 200
                or not V.count(row.get("count"))
            ):
                return false
    if card.has("stats"):
        if not card.stats is Dictionary or card.stats.size() > 30:
            return false
        for key in card.stats:
            if (
                not key is String
                or key.length() > 100
                or not V.number(card.stats[key])
                or absf(float(card.stats[key])) > 1000000
            ):
                return false
    return (
        V.json_safe(card, 0, [10000]) and DIFF.canonical(card).to_utf8_buffer().size() <= MAX_BYTES
    )


static func encode(card: Dictionary) -> Dictionary:
    if not valid_body(card):
        return {"ok": false, "reason": "分享内容字段无效或超过24KiB，请减少勾选内容。"}
    var raw := DIFF.canonical(card)
    var encoded := Marshalls.utf8_to_base64(raw).replace("+", "-").replace("/", "_").rstrip("=")
    var checksum := raw.sha256_text().left(16)
    return {
        "ok": true,
        "code": "CTP1." + checksum + "." + encoded,
        "raw": raw,
        "sha256": raw.sha256_text(),
        "bytes": raw.to_utf8_buffer().size(),
        "reason": "分享码已生成，尚未发送。"
    }


static func valid_utf8(bytes: PackedByteArray) -> bool:
    var cursor := 0
    while cursor < bytes.size():
        var lead := int(bytes[cursor])
        cursor += 1
        if lead < 0x80:
            continue
        var length := 0
        var lower := 0x80
        var upper := 0xbf
        if lead >= 0xc2 and lead <= 0xdf:
            length = 1
        elif lead >= 0xe0 and lead <= 0xef:
            length = 2
            if lead == 0xe0:
                lower = 0xa0
            elif lead == 0xed:
                upper = 0x9f
        elif lead >= 0xf0 and lead <= 0xf4:
            length = 3
            if lead == 0xf0:
                lower = 0x90
            elif lead == 0xf4:
                upper = 0x8f
        else:
            return false
        if cursor + length > bytes.size():
            return false
        if int(bytes[cursor]) < lower or int(bytes[cursor]) > upper:
            return false
        for i in range(1, length):
            if int(bytes[cursor + i]) < 0x80 or int(bytes[cursor + i]) > 0xbf:
                return false
        cursor += length
    return true


static func decode(code: String) -> Dictionary:
    var raw_code := code.strip_edges()
    if raw_code.length() > MAX_CODE:
        return {"ok": false, "reason": "分享码超过长度上限。"}
    var parts := raw_code.split(".", true)
    if parts.size() != 3 or parts[0] != "CTP1" or parts[1].length() != 16:
        return {"ok": false, "reason": "分享码头无法识别。"}
    for symbol in parts[1]:
        if not "0123456789abcdef".contains(symbol):
            return {"ok": false, "reason": "校验码格式错误。"}
    var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    for symbol in parts[2]:
        if not alphabet.contains(symbol):
            return {"ok": false, "reason": "分享码含不支持的字符。"}
    if parts[2].is_empty() or parts[2].length() % 4 == 1:
        return {"ok": false, "reason": "分享码长度错误。"}
    var encoded := String(parts[2]).replace("-", "+").replace("_", "/")
    while encoded.length() % 4:
        encoded += "="
    var bytes := Marshalls.base64_to_raw(encoded)
    if bytes.size() > MAX_BYTES or not valid_utf8(bytes):
        return {"ok": false, "reason": "分享码内容过大或不是严格UTF-8。"}
    var raw := bytes.get_string_from_utf8()
    if raw.sha256_text().left(16) != parts[1]:
        return {"ok": false, "reason": "校验不符，内容可能缺失或被改动。"}
    var card: Variant = V.parse_json(raw)
    if not card is Dictionary or not valid_body(card):
        return {"ok": false, "reason": "分享内容没有通过字段白名单检查。"}
    return {"ok": true, "body": card, "reason": "校验通过，可只读预览；校验码不证明作者身份。"}


static func public_rows(card: Dictionary) -> Array:
    var result := []
    for key in card:
        if key in ["format", "version"]:
            continue
        result.append(
            {
                "将分享的字段": key,
                "内容": K.describe(card[key]),
                "JSON字节": DIFF.canonical(card[key]).to_utf8_buffer().size()
            }
        )
    return result


static func risk_summary(payload: Dictionary) -> Array:
    var result := []
    var descriptions := {
        "include_location": "地区和房间名称可能暴露当前进度",
        "include_abilities": "能力名称可能包含探索剧透",
        "include_equipment": "装备名称可能包含养成剧透",
        "include_quests": "任务标题和状态可能包含剧情剧透",
        "include_inventory": "持有物资与数量会公开资源情况",
        "include_stats": "构筑数值会公开当前养成情况",
        "include_note": "备注可能包含自己填写的个人内容"
    }
    for key in descriptions:
        result.append({"可选内容": key, "已勾选": payload[key], "预览时核对": descriptions[key]})
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var card := body(payload)
    var encoded := encode(card)
    var note := scrub(String(payload.note), 1000)
    var sections := [
        K.notice("公开分享预览", summary(payload)),
        {"kind": "custom", "title": "实际将分享的卡片", "view": VIEW, "data": {"body": card}},
        K.table("明确字段白名单", ["将分享的字段", "内容", "JSON字节"], public_rows(card)),
        K.table("可选内容核对", ["可选内容", "已勾选", "预览时核对"], risk_summary(payload)),
        K.notice("备注格式过滤", "检测并替换%d处常见路径、邮箱、口令或URL查询样式。过滤不是完整隐私保证，请查看预览。" % note.removed),
        K.notice("分享码边界", "只生成文本文件，不发送或上传。校验用于检测损坏，不是签名、加密或作者认证；外部分享不会写入你的游戏进度。")
    ]
    if encoded.ok:
        sections.append(
            K.notice("公开内容摘要", "规范化JSON %d字节 · SHA256 %s" % [encoded.bytes, encoded.sha256])
        )
    else:
        sections.append(K.notice("生成限制", String(encoded.reason)))
    return sections


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var before := body(a)
    var after := body(b)
    var options := {"epsilon": 0.0, "array_mode": "ordered", "category": "全部", "query": ""}
    var changes := DIFF.difference(before, after, options)
    return [
        K.table(
            "将公开内容的变化",
            ["操作", "字段", "分类", "记录值", "当前值"],
            DIFF.operation_rows(changes.ops, options) if changes.ok else []
        ),
        K.notice("比较范围", "只比较勾选后实际生成的公开内容，未勾选的私人字段不进入此差异。")
    ]
