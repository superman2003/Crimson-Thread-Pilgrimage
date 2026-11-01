extends RefCounted
## JSON boundaries shared by auxiliary workbench records.
const MAX_DEPTH := 16
const MAX_ITEMS := 100000

static func number(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func count(value: Variant, maximum: int = 1000000) -> bool:
    return number(value) and float(value) >= 0 and float(value) <= maximum and floor(float(value)) == float(value)

static func held(value: Variant) -> bool:
    return count(value) and float(value) > 0

static func text(value: Variant, maximum: int = 200) -> String:
    if not value is String:
        return ""
    var result := ""
    for character in value:
        var code: int = character.unicode_at(0)
        if code >= 32 and code != 127:
            result += character
        elif code == 10:
            result += "\n"
        if result.length() >= maximum:
            break
    return result.strip_edges()

static func json_safe(value: Variant, depth: int = 0, budget: Array = [MAX_ITEMS]) -> bool:
    if depth > MAX_DEPTH or budget[0] <= 0:
        return false
    budget[0] -= 1
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_STRING:
            return true
        TYPE_INT, TYPE_FLOAT:
            return number(value)
        TYPE_ARRAY:
            for item in value:
                if not json_safe(item, depth + 1, budget):
                    return false
            return true
        TYPE_DICTIONARY:
            for key in value:
                if not key is String or not json_safe(value[key], depth + 1, budget):
                    return false
            return true
    return false

static func point(value: Variant) -> Vector2:
    if value is Array and value.size() == 2 and number(value[0]) and number(value[1]):
        return Vector2(float(value[0]), float(value[1]))
    return Vector2.INF

static func pair(value: Vector2) -> Array:
    return [value.x, value.y] if value.is_finite() else [0.0, 0.0]

static func fingerprint(value: Variant) -> String:
    return JSON.stringify(value).sha256_text() if json_safe(value, 0, [MAX_ITEMS]) else ""

static func tokens(query: String) -> PackedStringArray:
    return query.to_lower().strip_edges().split(" ", false)

static func matches(query: String, fields: Array) -> bool:
    var combined := " ".join(fields).to_lower()
    for token in tokens(query):
        if not combined.contains(token):
            return false
    return true

static func date(timestamp: int) -> String:
    if timestamp <= 0:
        return "尚未记录"
    return Time.get_datetime_string_from_unix_time(timestamp).replace("T", " ") + " UTC"

static func read_json(path: String, maximum: int = 2097152) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > maximum:
        return {}
    var raw := file.get_as_text()
    file.close()
    var result: Variant = parse_json(raw)
    if not result is Dictionary or not json_safe(result, 0, [MAX_ITEMS]):
        return {}
    return result

static func parse_json(raw: String) -> Variant:
    var parser := JSON.new()
    if parser.parse(raw) != OK:
        return null
    return parser.data
