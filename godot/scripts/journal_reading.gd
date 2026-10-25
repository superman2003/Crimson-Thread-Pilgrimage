extends RefCounted
## Session bookmarks retain fingerprints, never duplicate long journal text.
## Reading a bookmark makes it recent; content changes retire stale offsets.
const LIMIT := 64
const MAX_KEY_LENGTH := 1024
const MAX_SCROLL := 1000000.0
var bookmarks: Dictionary = {}

func capture(key: String, text: String, scroll: float) -> void:
    if key.is_empty() or key.length() > MAX_KEY_LENGTH or not is_finite(scroll):return
    bookmarks.erase(key)
    if text.is_empty():return
    bookmarks[key] = {"fingerprint": text.sha256_text(), "scroll": clampf(scroll, 0.0, MAX_SCROLL)}
    while bookmarks.size() > LIMIT:bookmarks.erase(bookmarks.keys()[0])

func resume(key: String, text: String) -> float:
    var record: Dictionary = bookmarks.get(key, {})
    if record.is_empty():return 0.0
    if record.get("fingerprint") != text.sha256_text():
        bookmarks.erase(key)
        return 0.0
    bookmarks.erase(key)
    bookmarks[key] = record
    return float(record.get("scroll", 0.0))

func forget(key: String) -> void:
    bookmarks.erase(key)

func clear() -> void:
    bookmarks.clear()
