extends SceneTree
const QUERY := preload("res://scripts/journal_query.gd")
const CATALOG := preload("res://scripts/journal_catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func keys(rows: Array) -> Array:
    return rows.map(func(row):return row.key)
func run() -> void:
    var catalog := CATALOG.new()
    catalog.path = "user://isolated_query_preferences.json"
    catalog.configure("query_contract")
    catalog.writer = func(_data):return OK
    var first: Dictionary = catalog.document("one", "铜根 主教", "人物", "修女说 Copper　Bridge，回礼未领取。")
    var second: Dictionary = catalog.document("two", "铜根暗格主教", "人物", "桥上回礼已领取。")
    var third: Dictionary = catalog.document("three", "盐白书库", "证据", "普通标记 -salt；刻字 Copper Bridge。")
    first["entry"] = {"hidden_requirements":"绝密镜塔", "unseen_room":"未来密室"}
    var documents: Array = [first, second, third]
    var snapshot: Array = documents.duplicate(true)
    var cases := [
        ["铜根 修女", ["one"]],
        ["铜根\t修女", ["one"]],
        ["铜根\n修女", ["one"]],
        ["铜根　修女", ["one"]],
        ["铜根\u00a0修女", ["one"]],
        ["\"铜根 主教\"", ["one"]],
        ["“铜根 主教”", ["one"]],
        ["铜根 -已领取", ["one"]],
        ["-已领取", ["one", "three"]],
        ["\"copper bridge\"", ["one", "three"]],
        ["\"Copper　Bridge\"", ["one", "three"]],
        ["\"-salt\"", ["three"]],
        ["盐白 -\"铜根 主教\"", ["three"]],
        ["\"铜根 主教", ["one"]],
        ["铜根 铜根", ["one", "two"]],
        ["绝密镜塔", []],
        ["未来密室", []],
        ["-绝密镜塔", ["one", "two", "three"]],
        ["", ["one", "two", "three"]],
        ["\t　\n", ["one", "two", "three"]],
        ["-", ["three"]]
    ]
    for item in cases:
        check(keys(catalog.filter_documents(documents, item[0], false, false)) == item[1], "public query: " + String(item[0]))
    check(QUERY.matches(QUERY.compile("\"a\\\"b\""), "a\"b"), "escaped quotes remain literal phrase content")
    check(QUERY.matches(QUERY.compile("\"a\\\\b\""), "a\\b"), "escaped backslash remains literal")
    check(QUERY.matches(QUERY.compile("“她说“愿意\\”不能代填”"), "她说“愿意”不能代填"), "escaped Chinese closing quote remains inside the phrase")
    check(QUERY.matches(QUERY.compile("“\\“愿意\\””"), "“愿意”"), "both Chinese quote marks can be escaped")
    check(not QUERY.matches(QUERY.compile("-\\“愿意\\”"), "她说“愿意”"), "escaped Chinese quotes work in exclusions")
    check(QUERY.compile("铜根 铜根 -铜根 -铜根").size() == 2, "duplicate terms remain bounded without losing opposite conditions")
    check(QUERY.compile("a".repeat(120))[0].text.length() == 80, "query length uses the UI's eighty-character bound")
    for code in QUERY.SPACE_CODES + [8192, 8197, 8202]:
        var separator := String.chr(code)
        check(QUERY.compile("铜根" + separator + "修女").size() == 2, "Unicode whitespace tokenizes consistently: %d" % code)
        check(QUERY.matches(QUERY.compile("\"copper bridge\""), "Copper" + separator + "Bridge"), "phrase whitespace normalizes consistently: %d" % code)
    catalog.mark_read(first, true)
    catalog.toggle_star(first.key)
    var profiles: Dictionary = catalog.profiles.duplicate(true)
    var revision: int = catalog.revision
    check(keys(catalog.filter_documents(documents, "铜根", true, false)) == ["two"], "unread filtering still applies")
    check(keys(catalog.filter_documents(documents, "铜根 -已领取", false, true)) == ["one"], "favorite filtering still applies")
    check(keys(catalog.filter_documents(documents, "", false, false, 1)) == ["three", "one", "two"], "existing title ordering remains in control")
    check(catalog.profiles == profiles and catalog.revision == revision, "queries never change reading preferences")
    check(documents == snapshot, "query syntax never modifies disclosed or backing records")
    catalog.configure("other_slot")
    check(keys(catalog.filter_documents(documents, "铜根", false, true)).is_empty(), "search cannot import another slot's favorites")
    print("JOURNAL_QUERY checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

