extends RefCounted
## Save slots and journey history: quoting and performing save operations, switching slots and restoring backups.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func get_save_slots(level: Node) -> Array:
    var result: Array=[]
    for index in range(1,4):
        var path = level.world_save_path if index==level.world_slot else level.WORLD_STATE_SCRIPT.slot_path(index)
        var row: Dictionary=preload("res://scripts/save_inspector.gd").inspect(path)
        row["slot"]=index
        row["backup"]=preload("res://scripts/save_inspector.gd").inspect(path+".bak")
        result.append(row)
    return result


static func quote_save_operation(level: Node, action: String, index: int) -> Dictionary:
    if not level.world_mode or level.world_loading or level.chapter_transitioning or level.player==null or level.player.hp<=0 or index<1 or index>3 or action not in ["switch","recover"]:
        return {"ok":false,"reason":"当前无法切换或恢复归途记录。"}
    var path = level.world_save_path if index==level.world_slot else level.WORLD_STATE_SCRIPT.slot_path(index)
    var primary: Dictionary=preload("res://scripts/save_inspector.gd").inspect(path)
    var backup: Dictionary=preload("res://scripts/save_inspector.gd").inspect(path+".bak")
    var result: Dictionary={"ok":true,"slot":index,"primary":primary,"backup":backup,"action":action}
    if action=="switch":
        if index==level.world_slot:result.ok=false;result["reason"]="已经在当前存档槽。"
        elif level.world_save_blocked:result.ok=false;result["reason"]="当前记录暂不可保存，请先处理当前槽的恢复提示。"
        elif primary.exists and not primary.valid:result.ok=false;result["reason"]="目标主档无法读取，请先选择恢复该槽备份。"
    elif not backup.valid:result.ok=false;result["reason"]="该槽没有可读取的备份。"
    elif index!=level.world_slot and level.world_save_blocked:result.ok=false;result["reason"]="离开前必须先处理当前记录的恢复提示。"
    result["fingerprint"]=var_to_str([action,index,path,primary,backup,level.world_save_path,level._build_wallet_snapshot(),level.story_flags,level.build_system.serialize(),level.player.hp,level.player.energy]).sha256_text()
    return result


static func perform_save_operation(level: Node, action: String, index: int, fingerprint: String) -> Dictionary:
    var fresh: Dictionary = level.quote_save_operation(action,index)
    if not fresh.get("ok",false):return fresh
    if String(fresh.fingerprint)!=fingerprint:return {"ok":false,"changed":true,"reason":"记录或当前旅途已变化，请重新核对。"}
    var ok: bool = level.select_save_slot(index) if action=="switch" else level.restore_save_backup(index)
    return {"ok":ok,"reason":"正在进入所选旅途。" if ok else "当前操作未完成，仍停留在原旅途；请查看保存或恢复提示。"}


static func get_journey_history_page(level: Node, offset: int, limit: int) -> Dictionary:
    return preload("res://scripts/journey_history.gd").summaries(level.world_save_path,offset,limit)


static func get_journey_archive_detail(level: Node, file: String, sha: String) -> Dictionary:
    return preload("res://scripts/journey_archive_detail.gd").inspect(level.world_save_path,file,sha)


static func get_journey_history(level: Node) -> Dictionary:
    return preload("res://scripts/journey_history.gd").summaries(level.world_save_path)


static func select_save_slot(level: Node, index: int) -> bool:
    if not level.world_mode or index < 1 or index > 3 or level.chapter_transitioning or level.player.hp <= 0:
        return false
    var path = level.WORLD_STATE_SCRIPT.slot_path(index)
    if path == level.world_save_path:
        return true
    var candidate = level.WORLD_STATE_SCRIPT.new()
    if FileAccess.file_exists(path) and not candidate.read(path):
        level._toast("该旅途记录无法读取，已保留原文件；请先恢复该槽备份。")
        return false
    if not level._save_world():
        level._toast("当前进度未能写入，尚未切换存档槽。")
        return false
    level.chapter_transitioning = true
    level._defer_region_call("_replace_with_save_slot", [index])
    return true


static func replace_with_save_slot(level: Node, index: int, path_override: String = "") -> void:
    var parent_node = level.get_parent()
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_slot = index
    scene.world_startup_options_enabled = false
    scene.world_save_path = path_override if not path_override.is_empty() else level.WORLD_STATE_SCRIPT.slot_path(index)
    var was_current = level.get_tree().current_scene == level
    parent_node.remove_child(level)
    parent_node.add_child(scene)
    if was_current:
        scene.get_tree().current_scene = scene
    level.queue_free()


static func restore_save_backup(level: Node, index: int = 0) -> bool:
    if not level.world_mode or level.chapter_transitioning or level.world_loading or (index!=0 and (index<1 or index>3)):
        return false
    var slot = level.world_slot if index == 0 else index
    if slot!=level.world_slot and not level._save_world():
        level._toast("当前进度未能写入，尚未恢复其他槽备份。")
        return false
    # The current slot restores the file this journey actually uses.
    var path = level.world_save_path if slot == level.world_slot else level.WORLD_STATE_SCRIPT.slot_path(slot)
    var recovered = level.WORLD_STATE_SCRIPT.new()
    if not recovered.restore_backup(path):
        level._toast("备份恢复失败：" + recovered.last_error)
        return false
    level.chapter_transitioning = true
    level._defer_region_call("_replace_with_save_slot", [slot, path])
    return true
