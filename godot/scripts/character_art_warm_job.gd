extends RefCounted
## Incremental descriptor scan plus a bounded shared threaded texture queue.
## Cancelling drops this lease's plan, never joins a running engine request.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const FIELDS := ["enemy_spawns", "npcs", "boss"]
var done := true
var cancelled := false
var error := ""
var scanned := 0
var max_step_operations := 0
var paths: Array[String] = []
var _seen: Dictionary = {}
var _manifests: Dictionary = {}
var _config: Dictionary = {}
var _selection: Array = []
var _selected_mode := false
var _field := 0
var _index := 0
var _texture_index := 0
var _scanning := true

func begin(config: Dictionary, selection: Array = [], selected_mode: bool = false) -> void:
    _config = config
    _selection = selection
    _selected_mode = selected_mode
    _field = 0
    _index = 0
    _texture_index = 0
    _scanning = true
    _seen = {}
    _manifests = {}
    paths = []
    scanned = 0
    done = false
    cancelled = false
    error = ""
    max_step_operations = 0

func step(max_operations: int = 2, budget_usec: int = 2000) -> void:
    if done: return
    var started := Time.get_ticks_usec()
    var operations := ART.poll_textures(max_operations, budget_usec)
    while not done and operations < max_operations and Time.get_ticks_usec() - started < budget_usec:
        if _scanning:
            _scan_one()
        elif _texture_index < paths.size():
            var path := paths[_texture_index]
            if ART.texture_failures.has(path):
                error = String(ART.texture_failures[path])
                done = true
            elif ART.textures.has(path):
                _texture_index += 1
            else:
                # Request the next <=2 outstanding textures. A request denied by
                # shared capacity remains pending, rather than falling back.
                for index in range(_texture_index, mini(paths.size(), _texture_index + ART.MAX_TEXTURE_REQUESTS)):
                    ART.request_texture(paths[index])
                break
        else:
            done = true
            _config = {}
            _selection = []
        operations += 1
    max_step_operations = maxi(max_step_operations, operations)

func _scan_one() -> void:
    if _selected_mode:
        if _index >= _selection.size():
            _scanning = false
            return
        var descriptor: Dictionary = _selection[_index]
        _index += 1
        _add_actor(String(descriptor.kind), descriptor.data)
        return
    if _field >= FIELDS.size():
        _scanning = false
        return
    if FIELDS[_field] == "boss":
        var boss: Variant = _config.get("boss", {})
        _field += 1
        if boss is Dictionary and not boss.is_empty(): _add_actor("enemy", boss)
        return
    var records: Array = _config.get(FIELDS[_field], [])
    if _index >= records.size():
        _field += 1
        _index = 0
        return
    var data: Variant = records[_index]
    _index += 1
    if data is Dictionary: _add_actor("npc" if FIELDS[_field] == "npcs" else "enemy", data)

func _add_actor(kind: String, data: Dictionary) -> void:
    scanned += 1
    for manifest_path in ART.character_manifests(kind, data):
        if _manifests.has(manifest_path): continue
        _manifests[manifest_path] = true
        if manifest_path.ends_with(".json") and ART.manifest(manifest_path).is_empty():
            error = "Character manifest is missing or invalid: " + manifest_path
            done = true
            return
        for path in ART.atlas_paths(manifest_path):
            if _seen.has(path): continue
            _seen[path] = true
            paths.append(path)

func cancel() -> void:
    cancelled = true
    done = true
    _config = {}
    _selection = []
    paths = []
