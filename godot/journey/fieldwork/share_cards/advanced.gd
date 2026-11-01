extends RefCounted
## Portable, resource-free SVG sheets built only from the sanitized public body.
const K := preload("res://journey/fieldwork/knowledge.gd")
const COLUMNS := 72
const LINES := 34
const MAX_LINES := 4096
const WIDTH := 1000
const HEIGHT := 1120


static func width(character: String) -> int:
    var code := character.unicode_at(0)
    if code >= 0x300 and code <= 0x36f:
        return 0
    if code < 32:
        return 0
    if code >= 0x1100 and (
        code <= 0x115f or code >= 0x2e80 and code <= 0xa4cf
        or code >= 0xac00 and code <= 0xd7a3
        or code >= 0xf900 and code <= 0xfaff
        or code >= 0xff01 and code <= 0xff60
        or code >= 0x1f300
    ):
        return 2
    return 1


static func wrap_text(text: String, columns: int = COLUMNS) -> Array:
    if columns < 2:
        return []
    var rows := []
    var current := ""
    var used := 0
    for character in text.replace("\r\n", "\n").replace("\r", "\n"):
        if character == "\n":
            rows.append(current)
            current = ""
            used = 0
            continue
        if character == "\t":
            character = " "
        var amount := width(character)
        if amount == 0 and character.unicode_at(0) < 32:
            continue
        if used + amount > columns and not current.is_empty():
            rows.append(current)
            current = ""
            used = 0
        current += character
        used += amount
    rows.append(current)
    return rows


static func entries(card: Dictionary) -> Array:
    var rows := []
    var captions := {
        "date": "观察日期", "summary": "本次收录数量", "location": "公开位置",
        "abilities": "公开能力", "equipment": "公开装备", "quests": "公开任务",
        "inventory": "公开物资", "stats": "公开构筑", "note": "公开备注"
    }
    for key in captions:
        if not card.has(key):
            continue
        rows.append({"text": String(captions[key]), "heading": true, "field": key})
        var value: Variant = card[key]
        if value is Dictionary:
            var keys: Array = value.keys()
            keys.sort()
            for field in keys:
                rows.append({"text": String(field) + "：" + str(value[field]), "heading": false, "field": key})
        elif value is Array:
            for item in value:
                var text := ""
                if item is Dictionary:
                    var fields: Array = item.keys()
                    fields.sort()
                    var parts := PackedStringArray()
                    for field in fields:
                        parts.append(String(field) + "：" + str(item[field]))
                    text = " · ".join(parts)
                else:
                    text = str(item)
                rows.append({"text": text, "heading": false, "field": key})
        else:
            rows.append({"text": str(value), "heading": false, "field": key})
    return rows


static func paginate(card: Dictionary, per_page: int = LINES) -> Dictionary:
    if per_page < 2 or per_page > 100:
        return {"ok": false, "reason": "页容量无效"}
    var lines := []
    for entry in entries(card):
        for text in wrap_text(String(entry.text)):
            lines.append({"text": text, "heading": entry.heading, "field": entry.field})
            if lines.size() > MAX_LINES:
                return {"ok": false, "reason": "排版超过4096行；未输出截断文档"}
    var pages := []
    var page := []
    for i in lines.size():
        var row: Dictionary = lines[i]
        # Keep a section heading with the first content line when possible.
        if page.size() >= per_page or row.heading and page.size() == per_page - 1 and i + 1 < lines.size():
            pages.append(page)
            page = []
        page.append(row)
    if not page.is_empty() or pages.is_empty():
        pages.append(page)
    return {"ok": true, "pages": pages, "lines": lines.size(), "title": String(card.get("title", "旅途分享卡"))}


static func escape(text: String) -> String:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;").replace("'", "&apos;")


static func svg(card: Dictionary) -> String:
    var layout := paginate(card)
    if not layout.ok:
        return ""
    var parts := PackedStringArray()
    parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" role="img">' % [WIDTH, HEIGHT * layout.pages.size(), WIDTH, HEIGHT * layout.pages.size()])
    parts.append("<title>" + escape(layout.title) + "</title>")
    parts.append("<desc>明确白名单处理后的完整公开分享卡；按页连续排列，不包含远程资源。</desc>")
    for index in layout.pages.size():
        var top: int = index * HEIGHT
        parts.append('<g transform="translate(0 %d)" font-family="Noto Sans Mono CJK SC, monospace">' % top)
        parts.append('<rect x="12" y="12" width="976" height="1096" fill="#f1e7d1" stroke="#594938"/>')
        var title := wrap_text(layout.title, 50)
        for row in title.size():
            parts.append('<text x="50" y="%d" font-size="28" fill="#302c25">%s</text>' % [58 + row * 34, escape(title[row])])
        var y := 220
        for line in layout.pages[index]:
            parts.append('<text x="50" y="%d" font-size="20" fill="%s">%s</text>' % [y, "#7b381f" if line.heading else "#302c25", escape(line.text)])
            y += 25
        parts.append('<text x="50" y="1085" font-size="15">公开分享卡 · 第%d / %d页 · 内容由用户选择，不代表身份认证</text>' % [index + 1, layout.pages.size()])
        parts.append("</g>")
    parts.append("</svg>")
    return "".join(parts)


static func sections(card: Dictionary) -> Array:
    var layout := paginate(card)
    if not layout.ok:
        return [K.notice("完整分页排版", layout.reason)]
    var rows := []
    for index in layout.pages.size():
        var fields := []
        for row in layout.pages[index]:
            if not fields.has(row.field):
                fields.append(row.field)
        rows.append({"页": index + 1, "文本行": layout.pages[index].size(), "公开字段组": "、".join(fields)})
    return [
        K.notice("公开分享卡分页", "%d行内容排为%d页，导出SVG按页连续排列。汉字按双列宽换行；保留所有公开文本，不用省略号丢弃尾部。" % [layout.lines, layout.pages.size()]),
        K.table("分页目录", ["页", "文本行", "公开字段组"], rows,
            "排版只接收已有白名单与格式过滤后的公开卡片。未勾选的位置、任务、物资和备注不会进入分页数据或SVG。字体由查看器提供。")
    ]
