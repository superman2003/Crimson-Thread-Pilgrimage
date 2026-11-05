extends RefCounted
## Incremental descriptor scan plus a bounded shared threaded texture queue.
## Cancelling drops this lease's plan, never joins a running engine request.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const FIELDS := ["enemy_spawns", "npcs", "boss", "collectibles"]
var done := true
var cancelled := false
var error := ""
var scanned := 0
var item_scanned := 0
var max_step_operations := 0
var paths: Array[String] = []
var item_paths: Array[String] = []
var _seen: Dictionary = {}
var _manifests: Dictionary = {}
var _config: Dictionary = {}
var _selection: Array = []
var _item_ids: Array = []
var _item_index := 0
var _selected_mode := false
var _field := 0
var _index := 0
var _texture_index := 0
var _scanning := true

func begin(config: Dictionary, selection: Array = [], selected_mode: bool = false, item_ids: Array = []) -> void:
    _config = config
    _selection = selection
    _selected_mode = selected_mode
    _item_ids = item_ids.duplicate()
    _item_index = 0
    _field = 0
    _index = 0
    _texture_index = 0
    _scanning = true
    _seen = {}
    _manifests = {}
    paths = []
    item_paths = []
    scanned = 0
    item_scanned = 0
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
            _item_ids = []
        operations += 1
    max_step_operations = maxi(max_step_operations, operations)

func _scan_one() -> void:
    if _selected_mode:
        if _index >= _selection.size():
            _scan_owned_item()
            return
        var descriptor: Dictionary = _selection[_index]
        _index += 1
        _add_actor(String(descriptor.kind), descriptor.data)
        return
    if _field >= FIELDS.size():
        _scan_owned_item()
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
    if data is Dictionary:
        var kind := "item" if FIELDS[_field] == "collectibles" else ("npc" if FIELDS[_field] == "npcs" else "enemy")
        _add_actor(kind, data)

func _scan_owned_item() -> void:
    if _item_index >= _item_ids.size():
        _scanning = false
        return
    _add_actor("item", {"item_id":String(_item_ids[_item_index])})
    _item_index += 1

func _add_actor(kind: String, data: Dictionary) -> void:
    if kind == "item": item_scanned += 1
    else: scanned += 1
    for manifest_path in ART.character_manifests(kind, data):
        if _manifests.has(manifest_path): continue
        _manifests[manifest_path] = true
        if manifest_path.ends_with(".json") and ART.manifest(manifest_path).is_empty():
            error = "Character manifest is missing or invalid: " + manifest_path
            done = true
            return
        for path in ART.atlas_paths(manifest_path):
            if kind == "item" and not item_paths.has(path): item_paths.append(path)
            if _seen.has(path): continue
            _seen[path] = true
            paths.append(path)

func cancel() -> void:
    cancelled = true
    done = true
    _config = {}
    _selection = []
    _item_ids = []
    paths = []
    item_paths = []
