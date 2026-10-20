extends RefCounted
## Public rows contain defeated creatures only, never unreached names or totals.
const PATH := "res://data/enemy_journal.json"
const PREFIX := "journal_enemy_"
static var catalog: Dictionary = {}

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
        result.append({"id":"enemy_"+kind,"title":String(entry.name),"record_kind":"enemy","acquired":true,"description":String(entry.habit)})
    return result
