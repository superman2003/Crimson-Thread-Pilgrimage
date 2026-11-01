extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
var width := 1000.0
var height := 1800.0
var commands: Array[String] = []
var cursor := 85.0
const PAPER := "#eadcc6"
const MUTED := "#a3b3aa"
const GOLD := "#cfb484"
const GREEN := "#78ae99"
const RED := "#b97864"


func _init(title: String = "旅途观察", w: float = 1000, h: float = 1800) -> void:
    width = clampf(w, 300, 2000)
    height = clampf(h, 200, 6000)
    text(28, 35, title, 24, GOLD)
    text(28, 60, "Godot 巡礼工作台 · 辅助观察与个人假设报告", 13, MUTED)


func escaped(value: Variant) -> String:
    var raw := K.describe(value)
    var clean := ""
    for symbol in raw:
        var code := symbol.unicode_at(0)
        if code >= 32 or code in [9, 10, 13]:
            clean += symbol
    return (
        clean
        . replace("&", "&amp;")
        . replace("<", "&lt;")
        . replace(">", "&gt;")
        . replace('"', "&quot;")
        . replace("'", "&apos;")
    )


func n(value: float) -> String:
    return String.num(value, 3) if is_finite(value) else "0"


func valid_points(values: Array) -> bool:
    for value in values:
        if not is_finite(float(value)) or absf(float(value)) > 10000000:
            return false
    return true


func push(command: String) -> void:
    if commands.size() < 5000:
        commands.append(command)


func text(x: float, y: float, value: Variant, size: int = 14, color: String = PAPER) -> void:
    if valid_points([x, y]):
        push(
            (
                '<text x="'
                + n(x)
                + '" y="'
                + n(y)
                + '" font-size="'
                + str(size)
                + '" fill="'
                + color
                + '">'
                + escaped(value)
                + "</text>"
            )
        )


func line(a: Vector2, b: Vector2, color: String = GREEN, thickness: float = 1.5) -> void:
    if valid_points([a.x, a.y, b.x, b.y]):
        push(
            (
                '<line x1="'
                + n(a.x)
                + '" y1="'
                + n(a.y)
                + '" x2="'
                + n(b.x)
                + '" y2="'
                + n(b.y)
                + '" stroke="'
                + color
                + '" stroke-width="'
                + n(thickness)
                + '"/>'
            )
        )


func rect(area: Rect2, color: String = "#203c39", stroke: String = "") -> void:
    if (
        area.size.x < 0
        or area.size.y < 0
        or not valid_points([area.position.x, area.position.y, area.size.x, area.size.y])
    ):
        return
    var border := ' stroke="' + stroke + '"' if not stroke.is_empty() else ""
    push(
        (
            '<rect x="'
            + n(area.position.x)
            + '" y="'
            + n(area.position.y)
            + '" width="'
            + n(area.size.x)
            + '" height="'
            + n(area.size.y)
            + '" fill="'
            + color
            + '"'
            + border
            + "/>"
        )
    )


func circle(point: Vector2, radius: float, color: String = GOLD) -> void:
    if radius >= 0 and valid_points([point.x, point.y, radius]):
        push(
            (
                '<circle cx="'
                + n(point.x)
                + '" cy="'
                + n(point.y)
                + '" r="'
                + n(radius)
                + '" fill="'
                + color
                + '"/>'
            )
        )


func polyline(points: Array, color: String = GREEN, thickness: float = 2) -> void:
    var coordinates: Array[String] = []
    for point in points:
        if not point is Vector2 or not valid_points([point.x, point.y]):
            return
        coordinates.append(n(point.x) + "," + n(point.y))
    if coordinates.size() > 1:
        push(
            (
                '<polyline points="'
                + " ".join(coordinates)
                + '" fill="none" stroke="'
                + color
                + '" stroke-width="'
                + n(thickness)
                + '"/>'
            )
        )


func title(value: String) -> float:
    text(28, cursor + 20, value, 19, GOLD)
    cursor += 40
    return cursor


func paragraph(value: String, characters: int = 68) -> void:
    for paragraph in value.split("\n", true):
        var content := String(paragraph)
        if content.is_empty():
            cursor += 12
        while not content.is_empty():
            text(28, cursor + 14, content.left(characters), 14, PAPER)
            content = content.substr(characters)
            cursor += 22


func table(caption: String, columns: Array, rows: Array, limit: int = 24) -> void:
    title(caption)
    var column_width := (width - 56) / maxi(1, columns.size())
    rect(Rect2(28, cursor, width - 56, 28), "#354a3f")
    for i in columns.size():
        text(35 + i * column_width, cursor + 19, String(columns[i]).left(18), 13, GOLD)
    cursor += 28
    for row in rows.slice(0, limit):
        rect(Rect2(28, cursor, width - 56, 25), "#1b3431")
        for i in columns.size():
            var raw := K.describe(row.get(columns[i], ""))
            var count := maxi(4, int(column_width / 13))
            var clipped := raw.left(count - 1) + "…" if raw.length() > count else raw
            text(35 + i * column_width, cursor + 17, clipped.replace("\n", " "), 12, PAPER)
        cursor += 25
    if rows.size() > limit:
        paragraph("此表显示前%d行，共%d行；完整结构保留在辅助记录中。" % [limit, rows.size()])
    cursor += 14


func bars(caption: String, values: Dictionary, limit: int = 24) -> void:
    title(caption)
    var maximum := 1.0
    for value in values.values():
        maximum = maxf(maximum, absf(K.safe_number(value)))
    var count := 0
    for label in values:
        if count >= limit:
            break
        var value := K.safe_number(values[label])
        text(28, cursor + 17, String(label).left(20), 13, PAPER)
        rect(
            Rect2(240, cursor + 3, (width - 360) * absf(value) / maximum, 18),
            GREEN if value >= 0 else RED
        )
        text(width - 100, cursor + 17, n(value), 12, MUTED)
        cursor += 27
        count += 1
    cursor += 14


func axes(
    area: Rect2, x_max: float, y_min: float, y_max: float, x_label: String, y_label: String
) -> void:
    rect(area, "#122825", "#5e735b")
    for i in 6:
        var portion := float(i) / 5
        var x := area.position.x + area.size.x * portion
        var y := area.end.y - area.size.y * portion
        line(Vector2(x, area.position.y), Vector2(x, area.end.y), "#2c453a", 1)
        line(Vector2(area.position.x, y), Vector2(area.end.x, y), "#2c453a", 1)
        text(x - 10, area.end.y + 20, n(x_max * portion), 11, MUTED)
        text(maxf(3, area.position.x - 58), y + 4, n(lerpf(y_min, y_max, portion)), 11, MUTED)
    text(area.position.x, area.position.y - 12, y_label, 13, GOLD)
    text(area.end.x - 160, area.end.y + 39, x_label, 12, MUTED)


func finish(note: String = "") -> String:
    if not note.is_empty():
        paragraph(note)
    var final_height := clampf(maxf(height, cursor + 35), 200, 10000)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="'
        + n(width)
        + '" height="'
        + n(final_height)
        + '" viewBox="0 0 '
        + n(width)
        + " "
        + n(final_height)
        + '" role="img"><title>巡礼工作台辅助报告</title><rect width="100%" height="100%" fill="#102323"/><g font-family="Noto Serif CJK SC, Microsoft YaHei, sans-serif">'
        + "\n".join(commands)
        + "</g></svg>"
    )
