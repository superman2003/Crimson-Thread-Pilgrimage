extends RefCounted
## Read-only provenance: an interpretation is not another piece of evidence.
const PATH := "res://data/testimony_sources.json"
const IDS := ["testimony_01", "testimony_02", "testimony_03", "testimony_04", "testimony_05", "testimony_06"]
static var _data: Dictionary = {}

static func _text(value: Variant, maximum: int = 180) -> bool:
    return value is String and not value.strip_edges().is_empty() and value.length() <= maximum and not value.contains("\n")

static func valid(data: Variant) -> bool:
    if not data is Dictionary or typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1:
        return false
    if not data.get("sources") is Dictionary or data.sources.size() != IDS.size():
        return false
    for id in IDS:
        var row: Variant = data.sources.get(id)
        if not row is Dictionary:
            return false
        for key in ["region", "room", "place", "medium", "supports"]:
            if not _text(row.get(key)):
                return false
        for key in ["observations", "limits"]:
            if not row.get(key) is Array or row[key].is_empty() or row[key].size() > 3:
                return false
            for line in row[key]:
                if not _text(line):
                    return false
        if not row.get("cross_checks") is Array or row.cross_checks.size() > 3:
            return false
        for check in row.cross_checks:
            if not check is Dictionary or not _text(check.get("text")):
                return false
            var required: Variant = check.get("evidence_all")
            if not required is Array or required.size() < 2 or required.size() > IDS.size() or not required.has(id):
                return false
            var unique := {}
            for evidence in required:
                if evidence not in IDS or unique.has(evidence):
                    return false
                unique[evidence] = true
    return true

static func catalog() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if valid(parsed):
            _data = parsed
    return _data.duplicate(true)

static func owns(inventory: Dictionary, id: String) -> bool:
    var amount: Variant = inventory.get(id, 0)
    return id in IDS and typeof(amount) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(amount)) \
        and float(amount) > 0.0 and float(amount) <= 1000000.0 and float(amount) == floor(float(amount))

static func for_evidence(id: String, inventory: Dictionary) -> Dictionary:
    if not owns(inventory, id):
        return {}
    var all := catalog()
    if not all.get("sources", {}).has(id):
        return {}
    var source: Dictionary = all.sources[id]
    var comparisons: Array[String] = []
    var comparison_keys: Array[String] = []
    for check in source.cross_checks:
        var ready := true
        for required in check.evidence_all:
            ready = ready and owns(inventory, String(required))
        if ready:
            comparisons.append(String(check.text))
            for required in check.evidence_all:
                var key := "evidence:" + String(required)
                if required != id and not comparison_keys.has(key):
                    comparison_keys.append(key)
    source.erase("cross_checks")
    source["comparisons"] = comparisons
    source["comparison_keys"] = comparison_keys
    return source

static func appendix(id: String, inventory: Dictionary) -> Array[String]:
    var source := for_evidence(id, inventory)
    var lines: Array[String] = []
    if source.is_empty():
        return lines
    lines.append("\n证词出处 · " + String(source.place))
    lines.append(String(source.medium))
    lines.append("\n可确认的实物痕迹")
    for observation in source.observations:
        lines.append("· " + String(observation))
    lines.append("\n这些痕迹能支持")
    lines.append(String(source.supports))
    lines.append("\n仍不能据此断言")
    for limit in source.limits:
        lines.append("· " + String(limit))
    for comparison in source.comparisons:
        lines.append("\n与已取得证词对读")
        lines.append(String(comparison))
    return lines
