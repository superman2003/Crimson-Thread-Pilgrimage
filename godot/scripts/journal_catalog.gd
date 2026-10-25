extends RefCounted
## Reading preferences operate only on documents already exposed by the journal.
const MAX_PROFILES := 8
const MAX_READ := 256
const MAX_STARS := 64
const MAX_BYTES := 1048576
var path := "user://journal_reading_preferences.json"
var scope := ""
var profiles: Dictionary = {}
var loaded := false
var writer: Callable

func _hash(value: Variant) -> bool:
    if not value is String or value.length() != 64:return false
    for index in value.length():
        if "0123456789abcdef".find(value.substr(index, 1)) < 0:return false
    return true

func _key(value: Variant) -> bool:
    return value is String and not value.is_empty() and value.length() <= 128

func configure(journey: String) -> void:
    if not loaded:
        loaded = true
        if FileAccess.file_exists(path):
            var file := FileAccess.open(path, FileAccess.READ)
            if file != null and file.get_length() <= MAX_BYTES:
                var parser := JSON.new()
                if parser.parse(file.get_as_text()) == OK:_load(parser.data)
    scope = journey.sha256_text()
    if not profiles.has(scope):profiles[scope] = {"read": {}, "stars": []}
    while profiles.size() > MAX_PROFILES:profiles.erase(profiles.keys()[0])

func _load(data: Variant) -> void:
    if not data is Dictionary or not (data.get("version") is int or data.get("version") is float) or data.get("version") != 1 or not data.get("profiles") is Dictionary:return
    for id in data.profiles:
        var raw: Variant = data.profiles[id]
        if not _hash(id) or not raw is Dictionary:continue
        var profile := {"read": {}, "stars": []}
        if raw.get("read") is Dictionary:
            for key in raw.read:
                if _key(key) and _hash(raw.read[key]):profile.read[key] = raw.read[key]
            while profile.read.size() > MAX_READ:profile.read.erase(profile.read.keys()[0])
        if raw.get("stars") is Array:
            for key in raw.stars:
                if _key(key) and not profile.stars.has(key) and profile.stars.size() < MAX_STARS:profile.stars.append(key)
        profiles[id] = profile
        while profiles.size() > MAX_PROFILES:profiles.erase(profiles.keys()[0])

func document(key: String, title: String, category: String, text: String) -> Dictionary:
    return {"key": key, "title": title, "text": text, "fingerprint": (title + "\n" + category + "\n" + text).sha256_text()}

func is_read(doc: Dictionary) -> bool:
    return profiles.get(scope, {}).get("read", {}).get(doc.get("key", ""), "") == doc.get("fingerprint", "missing")

func is_starred(key: String) -> bool:
    return profiles.get(scope, {}).get("stars", []).has(key)

func mark_read(doc: Dictionary, value: bool) -> Dictionary:
    if not profiles.has(scope) or not _key(doc.get("key")) or not _hash(doc.get("fingerprint")):return {"ok": false, "reason": "阅读记录无效"}
    var read: Dictionary = profiles[scope].read
    read.erase(doc.key)
    if value:read[doc.key] = doc.fingerprint
    while read.size() > MAX_READ:read.erase(read.keys()[0])
    return _save()

func toggle_star(key: String) -> Dictionary:
    if not profiles.has(scope) or not _key(key):return {"ok": false, "reason": "阅读记录无效"}
    var stars: Array = profiles[scope].stars
    if stars.has(key):stars.erase(key)
    elif stars.size() >= MAX_STARS:return {"ok": false, "reason": "最多收藏64条记录"}
    else:stars.append(key)
    return _save()

func _save() -> Dictionary:
    var data := {"version": 1, "profiles": profiles.duplicate(true)}
    var result: int
    if writer.is_valid():result = int(writer.call(data))
    else:
        var temporary := path + ".tmp"
        var file := FileAccess.open(temporary, FileAccess.WRITE)
        if file == null:result = FileAccess.get_open_error()
        else:
            file.store_string(JSON.stringify(data))
            result = file.get_error()
            file.close()
            if result == OK:result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
            if result != OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
    return {"ok": true, "persisted": result == OK, "error": result,
        "reason": "" if result == OK else "阅读偏好未能写入，当前会话仍有效；旅途进度不受影响。"}

func filter_documents(documents: Array, query: String, unread_only: bool, stars_only: bool, sort_mode: int = 0) -> Array:
    var tokens := query.left(80).to_lower().strip_edges().split(" ", false)
    var result: Array = []
    for doc in documents:
        if unread_only and is_read(doc):continue
        if stars_only and not is_starred(String(doc.key)):continue
        # Never stringify the backing record: hidden ending requirements and
        # undiscovered locations may coexist with public presentation fields.
        var public_text := (String(doc.title) + "\n" + String(doc.text)).to_lower()
        var matches := true
        for token in tokens:
            if not public_text.contains(token):matches = false;break
        if matches:result.append(doc)
    if sort_mode in [1, 2]:
        result.sort_custom(func(a: Dictionary, b: Dictionary):
            if sort_mode == 2 and is_read(a) != is_read(b):return not is_read(a)
            var first := String(a.title).to_lower()
            var second := String(b.title).to_lower()
            return first < second if first != second else String(a.key) < String(b.key))
    return result
