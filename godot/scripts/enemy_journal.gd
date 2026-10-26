extends RefCounted
## Public rows contain defeated creatures only, never unreached names or totals.
const PATH := "res://data/enemy_journal.json"
const PREFIX := "journal_enemy_"
static var catalog: Dictionary = {}
static var field_notes: Dictionary = {}

static func review_for(kind: String) -> String:
    if field_notes.is_empty():
        var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_field_notes.json"))
        if parsed is Dictionary and parsed.get("entries") is Array:
            for note in parsed.entries:
                if not note is Dictionary or not note.get("enemy_id") is String:continue
                var id: String=note.enemy_id
                if field_notes.has(id) or not note.get("focus") is String or not note.get("review") is String:continue
                field_notes[id]="观察重点："+String(note.focus)+"\n\n复盘问题\n"+String(note.review)
    return String(field_notes.get(kind,""))

static func _entries() -> Dictionary:
    if catalog.is_empty():
        var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if parsed is Dictionary:catalog=parsed.get("entries",{})
    return catalog

static func flag_for(kind: String) -> String:
    return PREFIX+kind if _entries().has(kind) else ""

static func records(flags: Dictionary) -> Array:
    var result: Array = []
    for kind in _entries():
        var known: Variant=flags.get(PREFIX+kind,false)
        if not known is bool or not known:continue
        var entry: Dictionary=catalog[kind]
        var description:=String(entry.habit)
        if not String(entry.get("warning","")).is_empty():description+="\n\n观察信号\n"+String(entry.warning)
        if not String(entry.get("response","")).is_empty():description+="\n\n应对思路\n"+String(entry.response)
        var review:=review_for(kind)
        if not review.is_empty():description+="\n\n"+review
        result.append({"id":"enemy_"+kind,"title":String(entry.name),"record_kind":"enemy","acquired":true,"description":description})
    return result
