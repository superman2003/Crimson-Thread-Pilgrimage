extends RefCounted
## Keep authored text and gameplay identifiers independent of the display locale.
const ENGLISH := preload("res://scripts/game_translation.gd")
const CATALOGUES := [
    "res://data/ui_translations.json",
    "res://data/ui_en_hints.json",
    "res://data/ui_en_journal.json",
    "res://data/ui_en_story.json",
    "res://data/ui_en_game.json",
]
const SOURCE := "zh_CN"
const NAMES := {"zh_CN": "简体中文", "en": "English"}
static var installed: Translation
var store := preload("res://scripts/journey_desk_store.gd").new()
var locale := SOURCE
var notice := ""
var ready := false

static func catalogue() -> Dictionary:
    var messages := {}
    for path: String in CATALOGUES:
        var file := FileAccess.open(path, FileAccess.READ)
        var part: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
        if not part is Dictionary or not part.get("messages") is Dictionary:
            return {}
        if part.get("locale", "en") != "en":
            return {}
        for source in part.messages:
            if not source is String or source.is_empty() or not part.messages[source] is String or part.messages[source].strip_edges().is_empty():
                return {}
        messages.merge(part.messages)
    return {"locale":"en", "messages":messages}

static func text(source: String) -> String:
    return String(TranslationServer.translate(source)) if installed != null else source

static func uninstall() -> void:
    if installed != null:
        TranslationServer.remove_translation(installed)
        installed = null

static func apply(target: String) -> bool:
    var next: Translation
    if target != SOURCE:
        if not NAMES.has(target):return false
        var data := catalogue()
        if data.is_empty() or data.locale != target:return false
        var english := ENGLISH.new()
        english.configure(data.messages)
        next = english
    var catalogue_changed := installed != null or next != null
    uninstall()
    installed = next
    if installed != null:
        TranslationServer.add_translation(installed)
    if TranslationServer.get_locale() != target:
        TranslationServer.set_locale(target)
    elif catalogue_changed:
        var main_loop := Engine.get_main_loop()
        if main_loop != null:
            main_loop.notification(MainLoop.NOTIFICATION_TRANSLATION_CHANGED)
    if DisplayServer.get_name() != "headless":
        DisplayServer.window_set_title("Crimson Thread Pilgrimage" if target == "en" else "绯线巡礼 - 互联世界")
    return true

## Reads the saved choice. A fresh installation stays in Chinese whatever the
## operating system's language.
func initialize() -> void:
    if ready:return
    ready=true
    store.configure("language","installation")
    var saved:=store.read()
    if saved.is_empty():
        if store.writable and FileAccess.file_exists(store.path):
            store.writable=false;store.error="语言记录无效，保留原文件。"
        notice=store.error;return
    if saved.size()!=1 or not saved.get("locale") is String or not NAMES.has(saved.locale):
        store.writable=false;store.error="语言记录无效，保留原文件。";notice=store.error
        return
    locale=String(saved.locale)
    if not apply(locale):
        locale=SOURCE
        apply(SOURCE)

func choose(target: String) -> Dictionary:
    if not NAMES.has(target):return {"ok":false,"reason":"无效的语言。"}
    if not apply(target):return {"ok":false,"reason":"该语言暂不可用。"}
    locale=target
    if not store.write({"locale":locale}):
        notice="已生效，但未能保存。"+store.error
        return {"ok":false,"applied":true,"reason":notice}
    notice=""
    return {"ok":true,"applied":true,"reason":notice}
