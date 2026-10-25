extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/quest_reader/model.gd")
const FEATURE := preload("res://journey/features/i_quest_reader.gd")


func run() -> void:
    label = "I16_QUEST_READER"
    var context := field_fixture("i16_quest_reader")
    await exercise(context, M, FEATURE, "quest_reader", "documents")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    payload.documents = [
        {
            "id": "fixture",
            "title": "已知文字样本",
            "body": "甲乙丙丁。\n\nSecond paragraph here.",
            "hint": "当前指引",
            "kind": "任务",
            "status": "active"
        }
    ]
    payload.current = "fixture"
    payload.bookmarks = []
    payload.read = []
    payload.query = "paragraph"
    check(M.validate(payload), "explicit known-text fixture validates")
    check(M.occurrences("王冠王冠", "王冠").size() == 2, "UTF-8 text search preserves character offsets")
    check(M.wrap_text("甲乙丙丁戊己", 3).size() == 2, "reference CJK line wrapping")
    check(M.search(payload).size() == 1, "full-text lookup finds known document only")
    check(M.pages(payload).size() >= 1, "empty or short text still has a readable reference page")
