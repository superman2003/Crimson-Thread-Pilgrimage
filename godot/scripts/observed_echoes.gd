extends RefCounted
## Derived first-person journal notes. Nothing is played or saved automatically.
const PATH := "res://data/observed_echoes.json"
const HISTORY := preload("res://scripts/scene_history.gd")
const PREFIX := "voice_observed_"
const EVIDENCE := ["testimony_01", "testimony_02", "testimony_03", "testimony_04", "testimony_05", "testimony_06"]
static var _data: Dictionary = {}
static var _observations: Dictionary = {}
static var _proofs: Dictionary = {}

static func _prepare_sources() -> void:
    if not _observations.is_empty():
        return
    for row in HISTORY.all_entries():
        if row.get("role") == "daily":
            _observations[String(row.id)] = {"title": String(row.title), "place": String(row.room_title)}
        elif row.has("evidence_id"):
            _proofs[String(row.evidence_id)] = String(row.title)

static func valid(data: Variant) -> bool:
    _prepare_sources()
    if not data is Dictionary or typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1:
        return false
    if not data.get("entries") is Array or data.entries.is_empty() or data.entries.size() > 24:
        return false
    var identities := {}
    for row in data.entries:
        if not row is Dictionary or row.size() != 5:
            return false
        if not row.get("id") is String or not row.id.is_valid_identifier() or identities.has(row.id):
            return false
        identities[row.id] = true
        for key in ["title", "text"]:
            if not row.get(key) is String or row[key].strip_edges().is_empty() or row[key].contains("\n"):
                return false
        if row.title.length() > 24 or row.text.length() > 90:
            return false
        if not row.get("observations_all") is Array or row.observations_all.is_empty() or row.observations_all.size() > 3:
            return false
        var observations := {}
        for id in row.observations_all:
            if not _observations.has(id) or observations.has(id):
                return false
            observations[id] = true
        if not row.get("evidence_all") is Array or row.evidence_all.size() > 3:
            return false
        var proofs := {}
        for id in row.evidence_all:
            if id not in EVIDENCE or not _proofs.has(id) or proofs.has(id):
                return false
            proofs[id] = true
        # A single ambient object alone should not turn into a second transcript.
        if observations.size() + proofs.size() < 2:
            return false
    return true

static func catalog() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if valid(parsed):
            _data = parsed
    return _data.duplicate(true)

static func held(inventory: Dictionary, id: String) -> bool:
    var value: Variant = inventory.get(id, 0)
    return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
        and float(value) > 0.0 and float(value) <= 1000000.0 and float(value) == floor(float(value))

static func records(inventory: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for row in catalog().get("entries", []):
        var known := true
        for id in row.observations_all:
            known = known and HISTORY.discovered(flags, String(id))
        for id in row.evidence_all:
            known = known and held(inventory, String(id))
        if not known:
            continue
        var sources: Array[String] = []
        for id in row.observations_all:
            var observation: Dictionary = _observations[id]
            sources.append(String(observation.title) + " · " + String(observation.place))
        for id in row.evidence_all:
            sources.append(String(_proofs[id]))
        result.append({"id": PREFIX + String(row.id), "title": String(row.title),
            "description": String(row.text), "record_kind": "voice", "acquired": true,
            "voice_context": "观察遗迹之后", "voice_sources": sources})
    return result
