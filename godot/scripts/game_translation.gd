extends Translation
## Godot controls retain their authored text. Resolve it at draw time so a locale
## change also updates open windows, cached journal rows and existing toasts.
## Some callers format a string before a Control sees it. Match those lines to
## their original format, preserving numbers, key bindings and rich-text tags.

var entries: Dictionary
var formats := RegEx.new()
var templates := {}
var phrases := {}
var cache := {}
const CACHE_LIMIT := 2048
const PUNCTUATION := {"：":": ", "；":"; ", "，":", ", "。":". ", "、":", ", "｜":" | ", "（":" (", "）":")"}

func configure(messages: Dictionary) -> void:
    entries = messages
    locale = "en"
    formats.compile("%(?:%|[+#0-]*[0-9]*(?:\\.[0-9]+)?[sdifxXoc])|\\{[a-zA-Z_][a-zA-Z_0-9:]*\\}")
    # A source fragment can be authored with its surrounding layout whitespace
    # and later appear inside another page without it.
    for key: String in entries.keys():
        var clean := key.strip_edges()
        if not clean.is_empty() and not entries.has(clean):
            entries[clean] = String(entries[key]).strip_edges()
    for key: String in entries:
        var fields := formats.search_all(key)
        if fields.is_empty():
            var initial := key.left(1)
            if not phrases.has(initial):
                phrases[initial] = []
            phrases[initial].append(key)
            continue
        var literals := formats.sub(key, "\n", true).split("\n", false)
        var anchor := ""
        for literal in literals:
            if literal.strip_edges().length() > anchor.length():
                anchor = literal.strip_edges()
        if anchor.is_empty():
            continue
        var initial := anchor.left(1)
        if not templates.has(initial):
            templates[initial] = []
        templates[initial].append({"key":key, "anchor":anchor, "regex":null})
    for bucket: Array in phrases.values():
        bucket.sort_custom(func(a: String, b: String): return a.length() > b.length())

func _get_message(src_message: StringName, _context: StringName) -> StringName:
    var translated := resolve(String(src_message))
    return StringName(translated) if translated != String(src_message) else &""

func resolve(source: String) -> String:
    if entries.has(source):
        return entries[source]
    if cache.has(source):
        return cache[source]
    if not contains_han(source):
        return source
    var result := _compose(source, 0, {})
    if cache.size() >= CACHE_LIMIT:
        cache.clear()
    cache[source] = result
    return result

static func contains_han(value: String) -> bool:
    for i in value.length():
        var c := value.unicode_at(i)
        if c >= 0x3400 and c <= 0x9fff:
            return true
    return false

func _compile(key: String) -> RegEx:
    var pattern := "\\A"
    var offset := 0
    for field in formats.search_all(key):
        pattern += "\\Q" + key.substr(offset, field.get_start() - offset) + "\\E"
        var token := field.get_string()
        if token == "%%":
            pattern += "%"
        elif token.ends_with("s") or token.begins_with("{"):
            pattern += "(.*?)"
        elif token.ends_with("f"):
            pattern += "([+-]?[0-9]+(?:\\.[0-9]+)?)"
        elif token.right(1) in ["x", "X"]:
            pattern += "([0-9a-fA-F]+)"
        elif token.ends_with("c"):
            pattern += "(.)"
        else:
            pattern += "([+-]?[0-9]+)"
        offset = field.get_end()
    var expression := RegEx.new()
    var multiline := "(?s)" if key.contains("\n") else ""
    expression.compile(multiline + pattern + "\\Q" + key.substr(offset) + "\\E\\z")
    return expression

func _compose(source: String, depth: int, memo: Dictionary) -> String:
    if entries.has(source):
        return entries[source]
    if memo.has(source):
        return memo[source]
    if depth >= 16 or not contains_han(source):
        return source
    var result := _piece(source, depth, memo)
    memo[source] = result
    return result

func _piece(source: String, depth: int, memo: Dictionary) -> String:
    var clean := source.strip_edges()
    if clean != source:
        var start := source.find(clean)
        return source.left(start) + _compose(clean, depth + 1, memo) + source.substr(start + clean.length())
    for bullet in ["● ", "○ ", "· ", "★ ", "☆ ", "• ", "◆ ", "◇ ", "✓ "]:
        if source.begins_with(bullet):
            return bullet + _compose(source.substr(bullet.length()), depth + 1, memo)
    # Index by a fixed part of the format. An ordinary HUD update should never
    # scan the full dialogue catalogue or compile every format in the game.
    var seen := {}
    var candidates := []
    for initial in source:
        if seen.has(initial) or not templates.has(initial):
            continue
        seen[initial] = true
        for rule: Dictionary in templates[initial]:
            if source.contains(rule.anchor):
                candidates.append(rule)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.key.length() > b.key.length())
    for rule: Dictionary in candidates:
        if rule.regex == null:
            rule.regex = _compile(rule.key)
        var matched: RegExMatch = rule.regex.search(source)
        if matched == null:
            continue
        var translated: String = entries[rule.key]
        var result := ""
        var offset := 0
        var values := []
        var named := {}
        var group := 0
        for source_field in formats.search_all(rule.key):
            var token := source_field.get_string()
            if token == "%%":
                continue
            group += 1
            var value := _compose(matched.get_string(group), depth + 1, memo)
            if token.begins_with("{"):
                named[token] = value
            else:
                values.append(value)
        var index := 0
        for field in formats.search_all(translated):
            result += translated.substr(offset, field.get_start() - offset)
            var token := field.get_string()
            if token == "%%":
                result += "%"
            elif token.begins_with("{"):
                result += String(named.get(token, token))
            else:
                if index >= values.size():
                    return source
                result += String(values[index])
                index += 1
            offset = field.get_end()
        return result + translated.substr(offset)

    # Journal pages and tooltips often join fully authored lines and names with
    # separators. Split the outer structure before resolving the individual rows.
    var joined := _joined_phrases(source)
    if joined != source:
        return joined
    var best := source
    for separator in ["\n", "  ", "：", " · ", " / ", "｜", "；", "。"]:
        if source.contains(separator):
            var pieces := source.split(separator)
            var changed := false
            for i in pieces.size():
                var part := pieces[i]
                if separator == "。" and i < pieces.size() - 1:
                    part += "。"
                if part == source:
                    continue
                var translated := _compose(part, depth + 1, memo)
                if separator == "。" and translated == part:
                    pieces[i] = part
                if translated != part:
                    changed = true
                    pieces[i] = translated
            if changed:
                var english_separator: String = {"｜":" | ", "；":"; ", "：":": ", "。":" "}.get(separator, separator)
                var candidate := english_separator.join(pieces).strip_edges()
                if not contains_han(candidate):
                    return candidate
                if best == source:
                    best = candidate
    return best

func _joined_phrases(source: String) -> String:
    # Concatenated headings, BBCode and item names can surround raw player
    # input. Leave an unrecognised Chinese word intact.
    var result := ""
    var i := 0
    var previous_word := false
    while i < source.length():
        var found := ""
        for phrase: String in phrases.get(source[i], []):
            if source.substr(i, phrase.length()) == phrase:
                found = phrase
                break
        if found.is_empty():
            var code := source.unicode_at(i)
            if code >= 0x3400 and code <= 0x9fff:
                return source
            result += String(PUNCTUATION.get(source[i], source[i]))
            previous_word = false
            i += 1
        else:
            if previous_word:
                result += " "
            result += String(entries[found])
            previous_word = true
            i += found.length()
    return result.strip_edges()
