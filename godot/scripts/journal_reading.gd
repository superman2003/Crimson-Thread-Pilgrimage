extends RefCounted
## Bounded session bookmarks. Content changes invalidate old pixel offsets.
const LIMIT := 64
var bookmarks: Dictionary={}

func capture(key: String, text: String, scroll: float) -> void:
    if key.is_empty() or not is_finite(scroll):return
    bookmarks.erase(key)
    bookmarks[key]={"text":text,"scroll":clampf(scroll,0.0,1000000.0)}
    while bookmarks.size()>LIMIT:bookmarks.erase(bookmarks.keys()[0])

func resume(key: String, text: String) -> float:
    var record: Dictionary=bookmarks.get(key,{})
    return float(record.get("scroll",0.0)) if record.get("text") == text else 0.0
