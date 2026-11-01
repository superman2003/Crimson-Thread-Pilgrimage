extends RefCounted
## Reading preferences operate only on documents already exposed by the journal.
const MAX_PROFILES := 8
const MAX_READ := 256
const MAX_STARS := 64
const MAX_BYTES := 1048576
const QUERY := preload("res://scripts/journal_query.gd")
var path := "user://journal_reading_preferences.json"
var scope := ""
var profiles: Dictionary = {}
var loaded := false
var writer: Callable
var dirty := false
var saving := false
var revision := 0

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
    # Reopening a slot makes it recent. A frequently used first profile must
    # not be the one evicted when a ninth journey is opened.
    var active: Dictionary = profiles.get(scope, {"read": {}, "stars": []})
    profiles.erase(scope)
    profiles[scope] = active
    while profiles.size() > MAX_PROFILES:profiles.erase(profiles.keys()[0])
    if dirty:flush()

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
    revision += 1
    dirty = true
    return _save()

func toggle_star(key: String) -> Dictionary:
    if not profiles.has(scope) or not _key(key):return {"ok": false, "reason": "阅读记录无效"}
    var stars: Array = profiles[scope].stars
    if stars.has(key):stars.erase(key)
    elif stars.size() >= MAX_STARS:return {"ok": false, "reason": "最多收藏64条记录"}
    else:stars.append(key)
    revision += 1
    dirty = true
    return _save()

func batch_quote(documents: Array) -> Dictionary:
    if not profiles.has(scope) or documents.is_empty() or documents.size()>MAX_READ:
        return {"ok":false,"reason":"请先筛选1至256条已知记录。"}
    var identities: Array = []
    var seen := {}
    var unread := 0
    for doc in documents:
        if not doc is Dictionary or not _key(doc.get("key")) or not _hash(doc.get("fingerprint")):
            return {"ok":false,"reason":"筛选结果无效，请重新打开旅记。"}
        if seen.has(doc.key):return {"ok":false,"reason":"筛选结果重复，请重新打开旅记。"}
        seen[doc.key] = true
        identities.append([doc.key,doc.fingerprint])
        if not is_read(doc):unread+=1
    if unread==0:return {"ok":false,"reason":"当前筛选结果已经全部已读。"}
    return {"ok":true,"count":unread,"fingerprint":var_to_str([scope,revision,identities]).sha256_text()}

func mark_read_batch(documents: Array, expected: String) -> Dictionary:
    var quote := batch_quote(documents)
    if not quote.ok:return quote
    if expected.is_empty() or expected!=quote.fingerprint:
        return {"ok":false,"changed":true,"reason":"筛选、内容或阅读状态已变化，请重新核对。"}
    var read: Dictionary=profiles[scope].read
    for doc in documents:
        read.erase(doc.key)
        read[doc.key]=doc.fingerprint
    while read.size()>MAX_READ:read.erase(read.keys()[0])
    revision+=1
    dirty=true
    var result:=_save()
    result["changed_count"]=quote.count
    return result

## Retry session-only edits after a transient write failure. Reopening the
## journal also retries; a successful writer only acknowledges its snapshot.
func flush() -> Dictionary:
    return _save() if dirty else {"ok": true, "persisted": true, "error": OK, "reason": ""}

func _save() -> Dictionary:
    if saving:return {"ok": true, "persisted": false, "error": ERR_BUSY, "reason": "阅读偏好正在写入，修改会在下次重试。"}
    saving = true
    var snapshot_revision := revision
    var data := {"version": 1, "profiles": profiles.duplicate(true)}
    var result: int
    if writer.is_valid():
        var answer: Variant = writer.call(data)
        result = answer if answer is int else ERR_INVALID_DATA
    else:
        var temporary := path + ".tmp"
        var file := FileAccess.open(temporary, FileAccess.WRITE)
        if file == null:result = FileAccess.get_open_error()
        else:
            file.store_string(JSON.stringify(data))
            file.flush()
            result = file.get_error()
            file.close()
            if result == OK:result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
            if result != OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
    saving = false
    dirty = result != OK or revision != snapshot_revision
    return {"ok": true, "persisted": not dirty, "error": result,
        "reason": "" if not dirty else "阅读偏好未能写入，当前会话仍有效；旅途进度不受影响。"}

func filter_documents(documents: Array, query: String, unread_only: bool, stars_only: bool, sort_mode: int = 0) -> Array:
    var terms := QUERY.compile(query)
    var result: Array = []
    for doc in documents:
        if unread_only and is_read(doc):continue
        if stars_only and not is_starred(String(doc.key)):continue
        # Never stringify the backing record: hidden ending requirements and
        # undiscovered locations may coexist with public presentation fields.
        var public_text := String(doc.title) + "\n" + String(doc.text)
        if QUERY.matches(terms, public_text):result.append(doc)
    if sort_mode in [1, 2]:
        result.sort_custom(func(a: Dictionary, b: Dictionary):
            if sort_mode == 2 and is_read(a) != is_read(b):return not is_read(a)
            var first := String(a.title).to_lower()
            var second := String(b.title).to_lower()
            return first < second if first != second else String(a.key) < String(b.key))
    return result
