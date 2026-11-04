extends RefCounted
## Source links are reconstructed from public, currently earned origin records.
const ECHOES := preload("res://scripts/observed_echoes.gd")
const RETURNS := preload("res://scripts/ending_return_journal.gd")
const CONTACTS := preload("res://scripts/quest_contacts.gd")
const HISTORY := preload("res://scripts/scene_history.gd")
const PROVENANCE := preload("res://scripts/testimony_sources.gd")

static func key(entry: Dictionary) -> String:
    return String(entry.get("record_kind", "")) + ":" + String(entry.get("id", ""))

static func links(origin_key: String, inventory: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var held := CONTACTS.confirmed_inventory(inventory)
    var clean := CONTACTS.confirmed_flags(flags)
    var origin := {}
    var origins: Array = ECHOES.records(held, clean)
    origins.append_array(RETURNS.records(held, clean))
    for row in origins:
        if key(row) == origin_key:
            origin = row
            break
    if origin.is_empty() and origin_key.begins_with("evidence:"):
        var id := origin_key.trim_prefix("evidence:")
        var provenance := PROVENANCE.for_evidence(id, held)
        if not provenance.is_empty():
            origin = {"journal_source_keys": provenance.get("comparison_keys", [])}
    if origin.is_empty():
        return result
    var requested: Array = origin.get("journal_source_keys", [])
    if requested.is_empty() or requested.size() > 6:
        return result
    var public: Array = HISTORY.records(clean)
    var narrative := CONTACTS.narrative()
    for row in narrative.evaluate_evidence(held, clean).get("known_entries", []):
        public.append(row.merged({"record_kind": "evidence"}))
    for row in narrative.quest_journal(held, clean):
        public.append(row.merged({"record_kind": "quest"}))
    var indexed := {}
    for row in public:
        indexed[key(row)] = row
    var seen := {}
    for target in requested:
        if not target is String or seen.has(target) or not indexed.has(target):
            continue
        seen[target] = true
        result.append({"key": target, "title": String(indexed[target].title), "entry": indexed[target].duplicate(true)})
    return result
