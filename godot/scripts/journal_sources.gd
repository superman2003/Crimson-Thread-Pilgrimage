extends RefCounted
## Source links are reconstructed from public, currently earned origin records.
const ECHOES := preload("res://scripts/observed_echoes.gd")
const FOLLOWUPS := preload("res://scripts/known_inquiry_contacts.gd")
const MEMORY := preload("res://scripts/npc_recollections.gd")
const IDENTITIES := preload("res://scripts/guardian_identities.gd")
const INQUIRIES := preload("res://scripts/narrative_inquiries.gd")
const TERMS := preload("res://scripts/known_world_terms.gd")
const RETURNS := preload("res://scripts/ending_return_journal.gd")
const CONTACTS := preload("res://scripts/quest_contacts.gd")
const HISTORY := preload("res://scripts/scene_history.gd")
const MAX_SOURCE_KEYS := 12
const PROVENANCE := preload("res://scripts/testimony_sources.gd")

static func key(entry: Dictionary) -> String:
    return String(entry.get("record_kind", "")) + ":" + String(entry.get("id", ""))

static func links(origin_key: String, inventory: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var held := CONTACTS.confirmed_inventory(inventory)
    var clean := CONTACTS.confirmed_flags(flags)
    var origin := {}
    var origins: Array = []
    if origin_key.begins_with("guide:" + FOLLOWUPS.PREFIX):
        origins = FOLLOWUPS.records(held, clean)
    elif origin_key.begins_with("people:" + INQUIRIES.PREFIX):
        origins = INQUIRIES.records(clean)
    elif origin_key.begins_with("voice:" + ECHOES.PREFIX):
        origins = ECHOES.records(held, clean)
    elif origin_key == "guide:ending_return_contacts":
        origins = RETURNS.records(held, clean)
    elif origin_key.begins_with("guide:" + TERMS.PREFIX):
        origins = TERMS.records(held)
    elif origin_key.begins_with("guide:" + IDENTITIES.PREFIX):
        origins = IDENTITIES.records(clean)
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
    if requested.is_empty() or requested.size() > MAX_SOURCE_KEYS:
        return result
    var public: Array = HISTORY.records(clean)
    if requested.any(func(target): return target is String and target.begins_with("people:")):
        public.append_array(INQUIRIES.records(clean))
        public.append_array(MEMORY.records(clean))
    var narrative := CONTACTS.narrative()
    for row in narrative.evaluate_evidence(held, clean).get("known_entries", []):
        if row.get("acquired", false):
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
