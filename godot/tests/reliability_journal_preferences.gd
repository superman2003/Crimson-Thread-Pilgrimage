extends SceneTree
const CATALOG = preload("res://scripts/journal_catalog.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var c := CATALOG.new()
    c.path = "user://preferences.json"
    c.configure("slot0")
    var doc := c.document("quest:one", "已知", "委托", "公开内容")
    var writes: Array = []
    c.writer = func(data: Dictionary):writes.append(data);return ERR_CANT_CREATE
    var result: Dictionary = c.mark_read(doc, true)
    check(result.ok and not result.persisted and c.is_read(doc), "failed disk write preserves visible session state")
    check(c.dirty and not c.flush().persisted, "failure remains retryable")
    c.toggle_star(doc.key)
    c.writer = func(data: Dictionary):writes.append(data);return OK
    c.configure("slot0")
    check(not c.dirty and c.is_read(doc) and c.is_starred(doc.key), "reopening retries both edits")
    check(writes[-1].profiles[c.scope].stars == [doc.key], "retry contains actual favorites")
    var count := writes.size()
    check(c.flush().persisted and writes.size() == count, "clean flush avoids another write")
    var original := c.scope
    for i in 7:c.configure("slot" + str(i + 1))
    c.configure("slot0")
    c.configure("slot8")
    check(c.profiles.has(original) and c.profiles.size() == 8, "recently reopened original survives ninth slot")
    check(not c.profiles.has("slot1".sha256_text()), "least recently visited slot is evicted")
    c.configure("slot0")
    check(c.is_read(doc) and c.is_starred(doc.key), "recent slot keeps its marks")
    var reentrant := [false]
    c.writer = func(_data: Dictionary):
        if not reentrant[0]:
            reentrant[0] = true
            c.toggle_star("quest:later")
        return OK
    result = c.mark_read(doc, false)
    check(not result.persisted and c.dirty, "older snapshot cannot acknowledge reentrant edits")
    check(c.is_starred("quest:later") and not c.is_read(doc), "both reentrant session edits survive")
    check(c.flush().persisted and not c.dirty, "subsequent flush acknowledges the new snapshot")
    c.writer = func(_data: Dictionary):return true
    check(not c.mark_read(doc, true).persisted, "boolean writer response is not an OK error code")
    c.writer = func(data: Dictionary):data.profiles.clear();return OK
    check(c.flush().persisted and c.is_read(doc), "writer snapshot cannot mutate live profiles")
    c.writer = Callable()
    check(c.toggle_star("quest:disk").persisted, "real temporary file replacement succeeds")
    var restarted := CATALOG.new()
    restarted.path = c.path;restarted.configure("slot0")
    check(restarted.is_read(doc) and restarted.is_starred("quest:disk"), "real restart restores last persisted edits")
    check(not FileAccess.file_exists(c.path + ".tmp"), "successful replacement leaves no temporary file")
    var text := FileAccess.get_file_as_string(c.path)
    check(not text.contains("公开内容"), "disk stores IDs and fingerprints only")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(c.path))
    for failure in failures:push_error(failure)
    print("RELIABILITY_JOURNAL_PREFERENCES checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
