extends RefCounted
## A bounded query language over already-disclosed text; no record introspection.
const MAX_QUERY := 80
const SPACE_CODES := [9, 10, 11, 12, 13, 32, 133, 160, 5760, 8232, 8233, 8239, 8287, 12288]

static func space(code: int) -> bool:
    return code in SPACE_CODES or (code >= 8192 and code <= 8202)

static func normalize(text: String) -> String:
    var words := PackedStringArray()
    var start := 0
    for index in text.length():
        if space(text.unicode_at(index)):
            if index > start:words.append(text.substr(start, index - start))
            start = index + 1
    if start < text.length():words.append(text.substr(start))
    return " ".join(words).to_lower()

static func _append(terms: Array[Dictionary], seen: Dictionary, text: String, excluded: bool) -> void:
    var clean := normalize(text)
    if clean.is_empty():return
    var key := ("-" if excluded else "+") + clean
    if seen.has(key):return
    seen[key] = true
    terms.append({"text":clean, "excluded":excluded})

static func compile(query: String) -> Array[Dictionary]:
    var text := query.left(MAX_QUERY)
    var terms: Array[Dictionary] = []
    var seen := {}
    var token := ""
    var excluded := false
    var closing := ""
    var index := 0
    while index < text.length():
        var character := text.substr(index, 1)
        if character == "\\" and index + 1 < text.length() and text.substr(index + 1, 1) in ["\\", "\"", "“", "”"]:
            token += text.substr(index + 1, 1)
            index += 2
            continue
        if not closing.is_empty():
            if character == closing:closing = ""
            else:token += character
        elif character in ["\"", "“"]:
            closing = "”" if character == "“" else "\""
        elif space(text.unicode_at(index)):
            _append(terms, seen, token, excluded)
            token = ""
            excluded = false
        elif character == "-" and token.is_empty() and not excluded and index + 1 < text.length() and not space(text.unicode_at(index + 1)):
            excluded = true
        else:
            token += character
        index += 1
    # An unfinished quote is still useful while the player is typing it.
    _append(terms, seen, token, excluded)
    return terms

static func matches(terms: Array[Dictionary], public_text: String) -> bool:
    if terms.is_empty():return true
    var text := normalize(public_text)
    for term in terms:
        var found := text.contains(String(term.text))
        if found == bool(term.excluded):return false
    return true

