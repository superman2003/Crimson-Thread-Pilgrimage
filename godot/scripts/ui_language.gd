extends RefCounted
## Interface language. Simplified Chinese is the authored text; another language
## is a catalogue from that text to its translation, applied by the engine to
## controls whose text matches an entry exactly. Composed lines (numbers, names)
## and story text stay as authored until they are given entries of their own.
## While Chinese is selected no catalogue is installed and nothing changes.
const CATALOGUE := "res://data/ui_translations.json"
const SOURCE := "zh_CN"
const NAMES := {"zh_CN": "简体中文", "en": "English"}
static var installed: Translation
var store := preload("res://scripts/journey_desk_store.gd").new()
var locale := SOURCE
var notice := ""
var ready := false

static func catalogue() -> Dictionary:
    var file:=FileAccess.open(CATALOGUE,FileAccess.READ)
    var parsed: Variant=JSON.parse_string(file.get_as_text()) if file!=null else null
    if not parsed is Dictionary or not parsed.get("messages") is Dictionary or not NAMES.has(parsed.get("locale")):return {}
    return parsed

static func apply(target: String) -> bool:
    if installed!=null:
        TranslationServer.remove_translation(installed);installed=null
    if target==SOURCE or not NAMES.has(target):
        TranslationServer.set_locale(SOURCE);return target==SOURCE
    var data:=catalogue()
    if data.is_empty() or data.locale!=target:
        TranslationServer.set_locale(SOURCE);return false
    installed=Translation.new();installed.locale=target
    for source in data.messages:
        if source is String and data.messages[source] is String and not String(data.messages[source]).is_empty():
            installed.add_message(source,data.messages[source])
    TranslationServer.add_translation(installed)
    TranslationServer.set_locale(target)
    return true

## Reads the saved choice. A fresh installation stays in Chinese whatever the
## operating system's language: the translation is partial, so it is opt-in.
func initialize() -> void:
    if ready:return
    ready=true
    store.configure("language","installation")
    var saved:=store.read()
    if saved.is_empty():
        notice=store.error;return
    if saved.size()!=1 or not saved.get("locale") is String or not NAMES.has(saved.locale):
        store.writable=false;store.error="语言记录无效，保留原文件。";notice=store.error
        return
    locale=String(saved.locale)
    if locale!=SOURCE and not apply(locale):locale=SOURCE

func choose(target: String) -> Dictionary:
    if not NAMES.has(target):return {"ok":false,"reason":"无效的语言。"}
    if not apply(target):return {"ok":false,"reason":"该语言暂不可用。"}
    locale=target
    if not store.write({"locale":locale}):
        notice="已生效，但未能保存。"+store.error
        return {"ok":false,"applied":true,"reason":notice}
    notice=""
    return {"ok":true,"applied":true,"reason":notice}
