extends RefCounted
## Combine only currently observed public tells; retain no actors or history.
const MAX_INPUT := 128
const COLORS := [Color("fff3dc"),Color("ffe19d")]

static func select(rows: Array, limit: int) -> Array[Dictionary]:
    var groups := {}
    var seen := {}
    for value in rows.slice(0,MAX_INPUT):
        if not value is Dictionary:continue
        var source: Variant = value.get("source")
        var rank: Variant = value.get("rank")
        var text: Variant = value.get("text")
        var unblockable: Variant = value.get("unblockable")
        if not source is int or source <= 0 or seen.has(source):continue
        if typeof(rank) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(rank)):continue
        if not text is String or text.is_empty() or text.length()>160 or not unblockable is bool:continue
        seen[source] = true
        var key := JSON.stringify([text,unblockable])
        if not groups.has(key):
            groups[key] = {"text":text,"unblockable":unblockable,"source":source,"rank":float(rank),"count":1}
        else:
            var group: Dictionary = groups[key]
            group.count += 1
            if float(rank)<float(group.rank) or (float(rank)==float(group.rank) and source<int(group.source)):
                group.rank = float(rank)
                group.source = source
    var result: Array[Dictionary] = []
    for group in groups.values():result.append(group)
    result.sort_custom(func(a: Dictionary,b: Dictionary):
        return a.rank<b.rank if a.rank!=b.rank else a.source<b.source)
    return result.slice(0,clampi(limit,1,3))

static func render(labels: Array[Label], rows: Array, font_size: int) -> void:
    for index in labels.size():
        var label := labels[index]
        if not is_instance_valid(label):continue
        label.visible = index<rows.size()
        if not label.visible:
            label.text = ""
            continue
        var row: Dictionary = rows[index]
        label.text = String(row.text) + (" ×%d" % int(row.count) if int(row.count)>1 else "")
        label.add_theme_font_size_override("font_size",clampi(font_size,17,26))
        label.add_theme_color_override("font_color",COLORS[1 if row.unblockable else 0])
