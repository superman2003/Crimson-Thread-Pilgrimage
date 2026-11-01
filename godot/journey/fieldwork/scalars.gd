extends RefCounted
const BASE := preload("res://journey/core/values.gd")
const MAX_ITEMS := BASE.MAX_ITEMS
const MAX_COORDINATE := 10000000.0


static func number(value: Variant) -> bool:
    return BASE.number(value)


static func count(value: Variant, maximum: int = 1000000) -> bool:
    return BASE.count(value, maximum)


static func held(value: Variant) -> bool:
    return BASE.held(value)


static func point(value: Variant) -> Vector2:
    var result := BASE.point(value)
    return (
        result
        if (
            result.is_finite()
            and absf(result.x) <= MAX_COORDINATE
            and absf(result.y) <= MAX_COORDINATE
        )
        else Vector2.INF
    )


static func pair(value: Vector2) -> Array:
    return BASE.pair(value)


static func text(value: Variant, maximum: int = 200) -> String:
    return BASE.text(value, maximum)


static func json_safe(value: Variant, depth: int = 0, budget: Array = []) -> bool:
    var counter: Array = budget if not budget.is_empty() else [MAX_ITEMS]
    return BASE.json_safe(value, depth, counter)


static func parse_json(raw: String) -> Variant:
    return BASE.parse_json(raw)


static func read_json(path: String, maximum: int = 2097152) -> Dictionary:
    return BASE.read_json(path, maximum)


static func fingerprint(value: Variant) -> String:
    return BASE.fingerprint(value)


static func matches(query: String, fields: Array) -> bool:
    return BASE.matches(query, fields)


static func tokens(query: String) -> PackedStringArray:
    return BASE.tokens(query)


static func date(timestamp: int) -> String:
    return BASE.date(timestamp)
