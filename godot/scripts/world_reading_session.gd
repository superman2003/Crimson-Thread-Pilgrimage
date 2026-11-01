extends RefCounted
## Reading positions belong to a World session, not its disposable HUD.
## Never retains text, NPCs, UI controls, reward flags or primary save data.
const JOURNAL := preload("res://scripts/journal_reading.gd")
const DIALOGUE := preload("res://scripts/dialogue_reading_memory.gd")
const KEY := "_crimson_world_reading_session_v1"
const VERSION := 1

static func scope(save_path: String) -> String:
    return save_path.sha256_text()

static func fresh(save_path: String) -> Dictionary:
    return {
        "version":VERSION,
        "scope":scope(save_path),
        "journal":JOURNAL.new(),
        "dialogue":DIALOGUE.new(),
    }

static func valid(value: Variant, save_path: String) -> bool:
    if not value is Dictionary:
        return false
    if typeof(value.get("version")) != TYPE_INT or value.version != VERSION:
        return false
    if value.get("scope") != scope(save_path):
        return false
    var journal: Variant = value.get("journal")
    var dialogue: Variant = value.get("dialogue")
    return journal is RefCounted and journal.get_script() == JOURNAL and dialogue is RefCounted and dialogue.get_script() == DIALOGUE

static func acquire(host: Node, save_path: String) -> Dictionary:
    if not is_instance_valid(host) or host.is_queued_for_deletion():
        return fresh(save_path)
    var value: Variant = host.get_meta(KEY) if host.has_meta(KEY) else null
    if not valid(value, save_path):
        value = fresh(save_path)
        host.set_meta(KEY, value)
    # Protect metadata fields from a caller replacing scope/version/reader refs.
    # The two intentionally shared reader objects contain only bounded numbers.
    return value.duplicate(false)

static func clear(host: Node) -> void:
    if not is_instance_valid(host) or not host.has_meta(KEY):
        return
    var value: Variant = host.get_meta(KEY)
    if value is Dictionary:
        var journal: Variant = value.get("journal")
        if journal is RefCounted and journal.get_script() == JOURNAL:
            journal.clear()
        var dialogue: Variant = value.get("dialogue")
        if dialogue is RefCounted and dialogue.get_script() == DIALOGUE:
            dialogue.clear()
    host.remove_meta(KEY)
