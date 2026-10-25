extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const VIEW := preload("res://journey/fieldwork/quest_reader/view.gd")


static func introduction() -> String:
    return "把已知任务、已获证词和已选结局整理为可调字号的阅读副本，提供全文定位、章节收藏和个人阅读标记。标记只属于此阅读台。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var story := K.story(snapshot)
    var documents := []
    for quest in story.get("quests", []):
        var body := String(quest.get("description", ""))
        var completed := []
        for step in quest.get("steps", []):
            if K.flag(step.get("complete")):
                completed.append(String(step.get("label", "")))
        if not completed.is_empty():
            body += "\n\n已经完成的步骤：\n" + "\n".join(completed)
        documents.append(
            {
                "id": "quest:" + String(quest.get("id", "")),
                "title": String(quest.get("title", "已知任务")),
                "body": body.left(5000),
                "hint": String(quest.get("guidance", "")),
                "kind": "任务",
                "status": String(quest.get("status", "active"))
            }
        )
    for entry in story.get("known_entries", []):
        if not K.flag(entry.get("acquired")):
            continue
        documents.append(
            {
                "id": "evidence:" + String(entry.get("id", "")),
                "title": String(entry.get("title", "已获证词")),
                "body": String(entry.get("description", entry.get("text", ""))).left(5000),
                "hint": "",
                "kind": "证词",
                "status": "acquired"
            }
        )
    for ending in story.get("endings", []):
        if K.flag(ending.get("chosen")):
            documents.append(
                {
                    "id": "ending:" + String(ending.get("id", "")),
                    "title": String(ending.get("title", "已选结局")),
                    "body": String(ending.get("description", "")).left(5000),
                    "hint": "",
                    "kind": "结局",
                    "status": "chosen"
                }
            )
    documents = documents.slice(0, 120)
    return {
        "documents": documents,
        "current": String(documents[0].id) if not documents.is_empty() else "",
        "bookmarks": [],
        "read": [],
        "query": "",
        "width": 32.0,
        "lines": 10.0,
        "page": 1.0,
        "font_size": 20.0,
        "line_spacing": 6.0,
        "reading_speed": 300.0,
        "show_hint": false,
        "annotation": ""
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("documents") is Array
        or payload.documents.size() > 120
        or not payload.get("current") is String
    ):
        return false
    var bounds := {
        "width": [12, 80],
        "lines": [4, 30],
        "page": [1, 500],
        "font_size": [14, 32],
        "line_spacing": [0, 20],
        "reading_speed": [50, 1500]
    }
    for key in bounds:
        if not V.count(payload.get(key), int(bounds[key][1])) or payload[key] < bounds[key][0]:
            return false
    if (
        not payload.get("show_hint") is bool
        or not payload.get("query") is String
        or payload.query.length() > 120
        or not payload.get("annotation") is String
        or payload.annotation.length() > 1000
    ):
        return false
    var known := {}
    for row in payload.documents:
        if not row is Dictionary or not row.get("id") is String or known.has(row.id):
            return false
        for key in ["title", "body", "hint", "kind", "status"]:
            if (
                not row.get(key) is String
                or row[key].length() > (5000 if key in ["body", "hint"] else 200)
            ):
                return false
        known[row.id] = true
    if not payload.current.is_empty() and not known.has(payload.current):
        return false
    for key in ["bookmarks", "read"]:
        if not payload.get(key) is Array or payload[key].size() > 120:
            return false
        var seen := {}
        for id in payload[key]:
            if not id is String or not known.has(id) or seen.has(id):
                return false
            seen[id] = true
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for row in payload.documents:
        choices.append({"id": row.id, "name": row.kind + " · " + row.title})
    return [
        {"id": "current", "name": "阅读章节", "kind": "choice", "choices": choices},
        {"id": "bookmarks", "name": "个人章节收藏", "kind": "checklist", "choices": choices},
        {"id": "read", "name": "个人已读标记", "kind": "checklist", "choices": choices},
        {"id": "query", "name": "章节内全文定位", "max": 120},
        {"id": "width", "name": "参考每行字符数", "kind": "number", "min": 12, "max": 80},
        {"id": "lines", "name": "每参考页行数", "kind": "number", "min": 4, "max": 30},
        {"id": "page", "name": "初始参考页", "kind": "number", "min": 1, "max": 500},
        {"id": "font_size", "name": "阅读字号", "kind": "number", "min": 14, "max": 32},
        {"id": "line_spacing", "name": "行间距", "kind": "number", "min": 0, "max": 20},
        {"id": "reading_speed", "name": "个人每分钟字符假设", "kind": "number", "min": 50, "max": 1500},
        {"id": "show_hint", "name": "附上原有当前指引", "kind": "toggle"},
        {"id": "annotation", "name": "个人阅读摘要", "max": 1000}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d篇已知资料 · 个人已读%d篇 · 收藏%d篇"
        % [payload.documents.size(), payload.read.size(), payload.bookmarks.size()]
    )


static func current(payload: Dictionary) -> Dictionary:
    for row in payload.documents:
        if row.id == payload.current:
            return row
    return {"id": "", "title": "尚无已知阅读资料", "body": "", "hint": "", "kind": "", "status": ""}


static func content(payload: Dictionary) -> String:
    var row := current(payload)
    var text := String(row.body)
    if payload.show_hint and not String(row.hint).is_empty():
        text += "\n\n原有当前指引：\n" + String(row.hint)
    return text.replace("\r\n", "\n").replace("\r", "\n")


static func wrap_text(text: String, width: int) -> Array:
    var lines := []
    for paragraph in text.split("\n", true):
        var remaining := String(paragraph)
        if remaining.is_empty():
            lines.append("")
            continue
        while remaining.length() > width:
            var split := width
            var space := remaining.left(width + 1).rfind(" ")
            if space >= width / 2:
                split = space
            var punctuation := "，。！？；：、）》】」』"
            if split < remaining.length() and punctuation.contains(remaining[split]):
                split += 1
            lines.append(remaining.left(split).strip_edges())
            remaining = remaining.substr(split).strip_edges()
        lines.append(remaining)
    return lines


static func pages(payload: Dictionary) -> Array:
    var lines := wrap_text(content(payload), int(payload.width))
    var result := []
    for start in range(0, lines.size(), int(payload.lines)):
        var page: Array = lines.slice(start, start + int(payload.lines))
        result.append("\n".join(page))
    return result if not result.is_empty() else [""]


static func occurrences(text: String, query: String) -> Array:
    var result := []
    var needle := query.strip_edges().to_lower()
    if needle.is_empty():
        return result
    var haystack := text.to_lower()
    var cursor := 0
    while cursor < haystack.length() and result.size() < 80:
        var found := haystack.find(needle, cursor)
        if found < 0:
            break
        result.append(
            {
                "offset": found,
                "length": needle.length(),
                "excerpt": text.substr(maxi(0, found - 20), needle.length() + 40).replace("\n", " ")
            }
        )
        cursor = found + maxi(1, needle.length())
    return result


static func search(payload: Dictionary) -> Array:
    var result := []
    for row in payload.documents:
        for match in occurrences(
            String(row.title) + "\n" + String(row.body), String(payload.query)
        ):
            result.append(
                {"章节": row.title, "资料类": row.kind, "字符位置": match.offset, "上下文": match.excerpt}
            )
            if result.size() >= 120:
                return result
    return result


static func statistics(text: String) -> Dictionary:
    var characters := 0
    var han := 0
    var latin := 0
    var punctuation := 0
    var sentences := 0
    var distinct := {}
    for symbol in text:
        var code := symbol.unicode_at(0)
        if symbol.strip_edges().is_empty():
            continue
        characters += 1
        distinct[symbol] = true
        if (code >= 0x3400 and code <= 0x9fff) or (code >= 0xf900 and code <= 0xfaff):
            han += 1
        elif (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
            latin += 1
        elif "，。！？；：、,.!?;:".contains(symbol):
            punctuation += 1
        if "。！？.!?".contains(symbol):
            sentences += 1
    return {
        "characters": characters,
        "han": han,
        "latin": latin,
        "punctuation": punctuation,
        "sentences": sentences,
        "distinct": distinct.size(),
        "paragraphs": text.split("\n\n", false).size()
    }


static func document_rows(payload: Dictionary) -> Array:
    var result := []
    for row in payload.documents:
        var stats := statistics(String(row.body))
        result.append(
            {
                "资料": row.title,
                "类型": row.kind,
                "字符数": stats.characters,
                "个人已读": payload.read.has(row.id),
                "个人收藏": payload.bookmarks.has(row.id),
                "个人估算分钟": float(stats.characters) / float(payload.reading_speed)
            }
        )
    return result


static func readability(payload: Dictionary) -> Array:
    var text := content(payload)
    var stats := statistics(text)
    var lines := wrap_text(text, int(payload.width))
    var longest := 0
    var blank := 0
    for line in lines:
        longest = maxi(longest, String(line).length())
        blank += 1 if String(line).is_empty() else 0
    return [
        {"指标": "非空白字符", "值": stats.characters},
        {"指标": "汉字代码点数", "值": stats.han},
        {"指标": "拉丁字母数", "值": stats.latin},
        {"指标": "不同字符数", "值": stats.distinct},
        {"指标": "标点数", "值": stats.punctuation},
        {"指标": "参考句界数", "值": stats.sentences},
        {"指标": "参考段落数", "值": stats.paragraphs},
        {"指标": "参考换行数", "值": lines.size()},
        {"指标": "参考空行数", "值": blank},
        {"指标": "最长参考行字符数", "值": longest},
        {"指标": "个人估算阅读分钟", "值": float(stats.characters) / float(payload.reading_speed)}
    ]


static func reading_plan(payload: Dictionary) -> Array:
    var rows := document_rows(payload)
    var result := []
    var total := 0.0
    for row in rows:
        if row["个人已读"]:
            continue
        total += float(row["个人估算分钟"])
        result.append(
            {
                "未读资料": row["资料"],
                "类型": row["类型"],
                "个人估算分钟": row["个人估算分钟"],
                "累计个人分钟": total,
                "收藏优先": row["个人收藏"]
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if a["收藏优先"] != b["收藏优先"]:
                return bool(a["收藏优先"])
            return float(a["个人估算分钟"]) < float(b["个人估算分钟"])
    )
    total = 0
    for row in result:
        total += float(row["个人估算分钟"])
        row["累计个人分钟"] = total
    return result


static func length_distribution(payload: Dictionary) -> Dictionary:
    var result := {"100字符以内": 0, "101—300字符": 0, "301—1000字符": 0, "1000字符以上": 0}
    for row in payload.documents:
        var count := int(statistics(String(row.body)).characters)
        var key := (
            "100字符以内"
            if count <= 100
            else "101—300字符" if count <= 300 else "301—1000字符" if count <= 1000 else "1000字符以上"
        )
        result[key] += 1
    return result


static func typography_study(payload: Dictionary) -> Array:
    var result := []
    for width in [16, 24, 32, 48, 64]:
        var sample := payload.duplicate(true)
        sample.width = float(width)
        result.append(
            {
                "参考行字符数": width,
                "参考行数": wrap_text(content(sample), width).size(),
                "参考页数": pages(sample).size(),
                "当前字号": payload.font_size
            }
        )
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var document := current(payload)
    var book := pages(payload)
    return [
        K.notice("已知资料阅读副本", summary(payload)),
        {
            "kind": "custom",
            "title": document.title,
            "view": VIEW,
            "data":
            {
                "title": document.title,
                "pages": book,
                "page": payload.page,
                "font_size": payload.font_size,
                "line_spacing": payload.line_spacing,
                "query": payload.query
            }
        },
        K.table("章节目录", ["资料", "类型", "字符数", "个人已读", "个人收藏", "个人估算分钟"], document_rows(payload)),
        K.table("全文定位", ["章节", "资料类", "字符位置", "上下文"], search(payload)),
        K.table("当前章节字符统计", ["指标", "值"], readability(payload)),
        K.bars("已知资料篇幅", length_distribution(payload)),
        K.table("个人未读安排", ["未读资料", "类型", "个人估算分钟", "累计个人分钟", "收藏优先"], reading_plan(payload)),
        K.table("参考分行比较", ["参考行字符数", "参考行数", "参考页数", "当前字号"], typography_study(payload)),
        K.notice("个人摘要", String(payload.annotation)),
        K.notice("阅读边界", "只复制已知任务、已取得证词与已选结局。参考字符分页不等同于屏幕实际排版；窗口变化后可在页内滚动。个人已读不会设置原旅记进度。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var known := {}
    for row in a.documents:
        known[row.id] = row
    var added := []
    var changed := []
    for row in b.documents:
        if not known.has(row.id):
            added.append({"资料": row.title, "类型": row.kind})
        elif known[row.id].body != row.body:
            changed.append(
                {
                    "资料": row.title,
                    "旧字符数": statistics(known[row.id].body).characters,
                    "新字符数": statistics(row.body).characters
                }
            )
    return [
        K.table("新增已知阅读资料", ["资料", "类型"], added), K.table("已知文本变化", ["资料", "旧字符数", "新字符数"], changed)
    ]
