extends RefCounted
## Starting a new journey (dialog, backup of the previous one) and loading JSON and shared world metadata.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func build_new_journey_dialog(level: Node) -> void:
    level.new_journey_dialog = ConfirmationDialog.new()
    level.new_journey_dialog.title = "重新开始巡礼"
    level.new_journey_dialog.dialog_text = "是否从苔钟庭开始新的旅途？当前归途记录会保留为上一段旅途的备份。"
    level.new_journey_dialog.ok_button_text = "开始新旅途"
    level.new_journey_dialog.cancel_button_text = "继续当前旅途"
    level.new_journey_dialog.theme = level.ui_shell.theme if level.ui_shell != null else null
    level.add_child(level.new_journey_dialog)
    level.new_journey_dialog.confirmed.connect(level._start_new_journey)
    level.new_journey_dialog.canceled.connect(func():
        level.active_overlay = ""
        level._sync_ui_input_lock())


static func preserve_previous_journey(level: Node) -> bool:
    if not FileAccess.file_exists(level.world_save_path):
        return true
    var absolute = ProjectSettings.globalize_path(level.world_save_path)
    if DirAccess.dir_exists_absolute(absolute + ".previous"):
        return false
    # T02: `.previous` holds the latest abandoned journey; an earlier one moves
    # to its own name first instead of being overwritten.
    if FileAccess.file_exists(level.world_save_path + ".previous") and level.WORLD_STATE_SCRIPT.preserve_copy(level.world_save_path + ".previous", "earlier").is_empty():
        return false
    if DirAccess.copy_absolute(absolute, absolute + ".previous") != OK:
        return false
    return DirAccess.remove_absolute(absolute) == OK


static func start_new_journey(level: Node) -> void:
    if not level._preserve_previous_journey():
        level._toast("旧旅途无法安全备份，当前记录已保留。")
        level.active_overlay = ""
        level._sync_ui_input_lock()
        return
    # Keep the old scene's shared snapshot valid until it has left the tree.
    level.AUDIO_DIRECTOR_SCRIPT.clear_exploration_resume()
    level.world_loading = true
    level._replace_with_save_slot(level.world_slot, level.world_save_path)


static func load_json(level: Node, path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func load_world_shared_json(level: Node, path: String) -> Dictionary:
    if not level.world_mode:
        return level._load_json(path)
    var canonical_path: String = level._world_shared_metadata_key(path)
    level.world_shared_metadata_probes[canonical_path] = int(level.world_shared_metadata_probes.get(canonical_path, 0)) + 1
    var stat_file = FileAccess.open(canonical_path, FileAccess.READ)
    if stat_file == null:
        level.world_shared_metadata_cache.erase(canonical_path)
        level.world_shared_metadata_failures[canonical_path] = int(level.world_shared_metadata_failures.get(canonical_path, 0)) + 1
        return {}
    var source_size = stat_file.get_length()
    stat_file.close()
    var source_mtime = FileAccess.get_modified_time(canonical_path)
    var cached: Variant = level.world_shared_metadata_cache.get(canonical_path)
    if cached is Dictionary and int(cached.get("size", -1)) == source_size and int(cached.get("mtime", -1)) == source_mtime:
        return (cached.get("data", {}) as Dictionary).duplicate(true)

    # A changed or unreadable source must never fall back to a stale snapshot.
    level.world_shared_metadata_cache.erase(canonical_path)
    var file = FileAccess.open(canonical_path, FileAccess.READ)
    if file == null:
        level.world_shared_metadata_failures[canonical_path] = int(level.world_shared_metadata_failures.get(canonical_path, 0)) + 1
        return {}
    var read_size = file.get_length()
    var text = file.get_as_text()
    file.close()
    var bytes_read = read_size
    level.world_shared_metadata_reads[canonical_path] = int(level.world_shared_metadata_reads.get(canonical_path, 0)) + 1
    level.world_shared_metadata_bytes[canonical_path] = int(level.world_shared_metadata_bytes.get(canonical_path, 0)) + bytes_read
    level.world_shared_metadata_parses[canonical_path] = int(level.world_shared_metadata_parses.get(canonical_path, 0)) + 1
    var parser := JSON.new()
    var parse_error = parser.parse(text)
    var parsed: Variant = parser.data
    if parse_error != OK or not parsed is Dictionary:
        level.world_shared_metadata_failures[canonical_path] = int(level.world_shared_metadata_failures.get(canonical_path, 0)) + 1
        return {}
    level.world_shared_metadata_cache[canonical_path] = {"mtime": FileAccess.get_modified_time(canonical_path),
        "size": read_size, "data": parsed.duplicate(true)}
    return parsed.duplicate(true)


static func world_shared_metadata_snapshot(level: Node) -> Dictionary:
    return {"cache_paths": level.world_shared_metadata_cache.keys().duplicate(),
        "probes": level.world_shared_metadata_probes.duplicate(true),
        "reads": level.world_shared_metadata_reads.duplicate(true),
        "bytes": level.world_shared_metadata_bytes.duplicate(true),
        "parses": level.world_shared_metadata_parses.duplicate(true),
        "failures": level.world_shared_metadata_failures.duplicate(true)}
