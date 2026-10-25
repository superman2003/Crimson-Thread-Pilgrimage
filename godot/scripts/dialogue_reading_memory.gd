extends RefCounted
## Session-only reading bookmarks. No text, NPC objects, rewards or save state.
const MAX_BOOKMARKS := 64
const MAX_KEY_LENGTH := 1024
const MAX_SCROLL := 1000000
var _entries: Dictionary = {}

func capture(key: String, length: int, characters: int, scroll: int, committed: bool) -> void:
    if key.is_empty() or key.length() > MAX_KEY_LENGTH:return
    _entries.erase(key)
    if committed or length <= 0:return
    var visible := length if characters < 0 else clampi(characters, 0, length)
    _entries[key] = {"characters": visible, "progress": float(visible) / length, "scroll": clampi(scroll, 0, MAX_SCROLL)}
    while _entries.size() > MAX_BOOKMARKS:_entries.erase(_entries.keys()[0])

func restore(key: String) -> Dictionary:
    var entry: Dictionary = _entries.get(key, {})
    if entry.is_empty():return {}
    _entries.erase(key)
    _entries[key] = entry
    return entry.duplicate(true)

func forget(key: String) -> void:
    _entries.erase(key)

func clear() -> void:
    _entries.clear()
