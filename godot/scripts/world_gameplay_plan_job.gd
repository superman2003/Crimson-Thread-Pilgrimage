extends RefCounted
## Resumable landing selection. Normal selection retains only category top-k;
## only the <=12 winners are deep-copied before any result becomes visible.
## Route overlays can append comparator-equal records after identity validation.
## Such a category is rescanned incrementally and uses the legacy engine sort
## on candidate references. That rare compatibility sort is NOT bounded by k
## or preemptible; its size/time have separate metrics rather than an FPS claim.
const COPY_JOB := preload("res://scripts/world_variant_copy_job.gd")
const HALF := Vector2(1280, 900)
const FIELDS := ["enemy_spawns", "npcs", "save_points", "interactives"]
const CATEGORIES := ["enemy", "npc", "save_point", "interaction"]
const LIMITS := [4, 3, 2, 3]
const COPY_EDGES_PER_OPERATION := 64
var done := true
var cancelled := false
var phase := "idle"
var result: Array = []
var operation_count := 0
var scanned_count := 0
var candidate_count := 0
var copy_edges := 0
var last_step_operations := 0
var max_step_operations := 0
var max_retained_candidates := 0
var compatibility_scanned := 0
var compatibility_sorts := 0
var max_compatibility_candidates := 0
var max_compatibility_sort_usec := 0
var _config: Dictionary = {}
var _entry := Vector2.ZERO
var _window := Rect2()
var _buckets: Array = [[], [], [], []]
var _field_i := 0
var _record_i := 0
var _selected: Array = []
var _copy: RefCounted
var _needs_compatibility := false
var _compatibility_candidates: Array = []

func begin(config: Dictionary, entry: Vector2) -> void:
    _config = config
    _entry = entry
    _window = Rect2(entry - HALF, HALF * 2)
    _buckets = [[], [], [], []]
    _selected = []
    _field_i = 0
    _record_i = 0
    _copy = null
    _needs_compatibility = false
    _compatibility_candidates = []
    result = []
    done = false
    cancelled = false
    phase = "scan"
    operation_count = 0
    scanned_count = 0
    candidate_count = 0
    copy_edges = 0
    last_step_operations = 0
    max_step_operations = 0
    max_retained_candidates = 0
    compatibility_scanned = 0
    compatibility_sorts = 0
    max_compatibility_candidates = 0
    max_compatibility_sort_usec = 0

func step(max_operations: int = 1) -> int:
    last_step_operations = 0
    while not done and last_step_operations < maxi(0, max_operations):
        match phase:
            "scan": _scan_one()
            "compatibility_scan": _compatibility_scan_one()
            "compatibility_sort": _compatibility_sort_one()
            "merge": _merge_one()
            "sort":
                # Category concatenation and comparator exactly match plan().
                # This final sort has at most twelve descriptors.
                _selected.sort_custom(func(a,b): return a.distance < b.distance or (a.distance == b.distance and a.key < b.key))
                phase = "copy"
            "copy": _copy_one()
            "publish":
                # The partial copy is private until this single assignment.
                result = _copy.result
                _copy = null
                _selected = []
                _buckets = []
                _compatibility_candidates = []
                _config = {}
                phase = "done"
                done = true
        last_step_operations += 1
        operation_count += 1
    max_step_operations = maxi(max_step_operations, last_step_operations)
    return last_step_operations

func cancel() -> void:
    cancelled = true
    done = true
    phase = "cancelled"
    result = []
    _config = {}
    _buckets = []
    _selected = []
    _compatibility_candidates = []
    _copy = null
    last_step_operations = 0

func _scan_one() -> void:
    if _field_i >= FIELDS.size():
        _field_i = 0
        _record_i = 0
        phase = "merge"
        return
    var items: Variant = _config.get(FIELDS[_field_i], [])
    if not items is Array or _record_i >= items.size():
        _record_i = 0
        if _needs_compatibility:
            phase = "compatibility_scan"
        else:
            _field_i += 1
        return
    var candidate := _candidate(items[_record_i])
    _record_i += 1
    scanned_count += 1
    if candidate.is_empty():
        return
    candidate_count += 1
    var bucket: Array = _buckets[_field_i]
    # Any comparator-equal group that can survive top-k has a representative
    # in this bucket when its next member arrives. Groups already below the
    # cutoff cannot affect the distinct winners. This needs no O(n) key index.
    for retained_candidate in bucket:
        if candidate.key == retained_candidate.key and candidate.distance == retained_candidate.distance:
            _needs_compatibility = true
            break
    # Each of the tie check and insertion has at most four comparisons.
    _insert_bounded(bucket, candidate, LIMITS[_field_i])
    var retained := 0
    for bounded_bucket in _buckets:
        retained += bounded_bucket.size()
    max_retained_candidates = maxi(max_retained_candidates, retained)

func _candidate(value: Variant) -> Dictionary:
    if not value is Dictionary:
        return {}
    var data: Dictionary = value
    var category: String = CATEGORIES[_field_i]
    var kind := String(data.get("kind", "")) if category == "interaction" else category
    if kind not in ["enemy", "npc", "save_point", "lever", "boss_gate", "world_portal"]:
        return {}
    var position: Variant = data.get("position", [])
    var id := String(data.get("id", ""))
    if not position is Array or position.size() != 2 or id.is_empty():
        return {}
    if typeof(position[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(position[1]) not in [TYPE_INT, TYPE_FLOAT]:
        return {}
    var point := Vector2(position[0], position[1])
    if not point.is_finite() or not _window.has_point(point):
        return {}
    return {"key": kind + ":" + id, "kind": kind, "data": data, "distance": point.distance_squared_to(_entry)}

func _compatibility_scan_one() -> void:
    var items: Array = _config.get(FIELDS[_field_i], [])
    if _record_i >= items.size():
        phase = "compatibility_sort"
        return
    var candidate := _candidate(items[_record_i])
    _record_i += 1
    compatibility_scanned += 1
    if not candidate.is_empty():
        _compatibility_candidates.append(candidate)
        max_compatibility_candidates = maxi(max_compatibility_candidates, _compatibility_candidates.size())

func _compatibility_sort_one() -> void:
    var started := Time.get_ticks_usec()
    # Same source order, comparator and engine sort as the unchanged oracle.
    # No payload copies occur here, but this engine call may exceed the shared
    # admission window. Preserve accepted overlay semantics and report it.
    _compatibility_candidates.sort_custom(func(a,b): return a.distance < b.distance or (a.distance == b.distance and a.key < b.key))
    _compatibility_candidates.resize(mini(_compatibility_candidates.size(), LIMITS[_field_i]))
    compatibility_sorts += 1
    max_compatibility_sort_usec = maxi(max_compatibility_sort_usec, Time.get_ticks_usec() - started)
    _buckets[_field_i] = _compatibility_candidates
    _compatibility_candidates = []
    _needs_compatibility = false
    _field_i += 1
    _record_i = 0
    phase = "scan"

func _merge_one() -> void:
    if _field_i >= _buckets.size():
        phase = "sort"
        return
    var bucket: Array = _buckets[_field_i]
    if _record_i >= bucket.size():
        _field_i += 1
        _record_i = 0
        return
    _selected.append(bucket[_record_i])
    _record_i += 1

func _copy_one() -> void:
    if _copy == null:
        _copy = COPY_JOB.new()
        _copy.begin(_selected)
        return
    if not _copy.done:
        copy_edges += _copy.step(COPY_EDGES_PER_OPERATION)
    if _copy.done:
        phase = "publish"

func _insert_bounded(items: Array, candidate: Dictionary, limit: int) -> void:
    var index := 0
    while index < items.size() and not _less(candidate, items[index]):
        index += 1
    if index >= limit:
        return
    items.insert(index, candidate)
    if items.size() > limit:
        items.pop_back()

func _less(a: Dictionary, b: Dictionary) -> bool:
    return a.distance < b.distance or (a.distance == b.distance and a.key < b.key)
