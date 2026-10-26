extends RefCounted
## A read-only projection: never returns save data or invokes recovery/transactions.
const HISTORY := preload("res://scripts/journey_history.gd")
const WORLD := preload("res://scripts/world_state.gd")
const NARRATIVE := preload("res://scripts/world_narrative.gd")
const BUILD := preload("res://scripts/build_system.gd")
const MAX_ROWS := 64

static func failure(reason: String) -> Dictionary:
    return {"ok":false,"reason":reason,"sections":[]}

static func inspect(slot_path: String, file_name: String, expected_sha: String) -> Dictionary:
    if not HISTORY.archive_name(file_name, slot_path.get_file()+".previous"):
        return failure("这不是当前槽的旧旅途记录。")
    if expected_sha.length()!=64 or not expected_sha.is_valid_hex_number(false):
        return failure("缺少记录身份，请刷新列表。")
    var directory := DirAccess.open(slot_path.get_base_dir())
    if directory==null or directory.is_link(file_name):
        return failure("归档目录不可读或记录是符号链接。")
    var path := slot_path.get_base_dir().path_join(file_name)
    var file := FileAccess.open(path,FileAccess.READ)
    if file==null:return failure("归档已移动或无法读取，请刷新列表。")
    var length := file.get_length()
    file.close()
    if length>WORLD.MAX_BYTES:return failure("归档超过单份大小上限。")
    if FileAccess.get_sha256(path)!=expected_sha:return failure("归档已变化，请刷新列表后重选。")
    var world := WORLD.new()
    if not world.read(path):return failure("归档无法读取，文件仍保留。")
    if FileAccess.get_sha256(path)!=expected_sha:return failure("归档在读取时变化，请刷新列表。")
    var result := project(world.data)
    result["file"]=file_name
    result["sha256"]=expected_sha
    return result

static func project(data: Dictionary) -> Dictionary:
    # Only called with a validated World snapshot. Build data may be from an old
    # schema, so its display is independently shape-checked without migrating it.
    var sections: Array[Dictionary]=[]
    var regions: Array[String]=[]
    for id in HISTORY.REGIONS:
        if not data.regions.has(id):continue
        var region: Dictionary=data.regions[id]
        var visited:=0
        for value in region.visited_rooms.values():
            if value is bool and value:visited+=1
        regions.append("%s · 已访%d间 · %s · 钟龛%d次" % [HISTORY.REGIONS[id],visited,"守门者已败" if region.boss_defeated else "守门者未败",int(region.bell_count)])
    sections.append({"title":"到过的地区","lines":regions if not regions.is_empty() else ["尚无区域记录。"]})
    var build := BUILD.new()
    var saved: Dictionary=data.build_state
    var equipment: Array[String]=[]
    var crest: Variant=saved.get("crest","")
    if crest is String and build.catalog.crests.has(crest):
        equipment.append("契印："+String(build.catalog.crests[crest].name))
    var families: Variant=saved.get("equipped_families",{})
    if families is Dictionary:
        for family in BUILD.FAMILY_KEYS:
            var values: Variant=families.get(family,[])
            if not values is Array:continue
            var names: Array[String]=[]
            var table: String=BUILD.FAMILY_TABLES[family]
            for value in values.slice(0,BUILD.FAMILY_CAPACITIES[family]):
                if not value is String or value.is_empty():continue
                if build.catalog[table].has(value):names.append(String(build.catalog[table][value].name))
                else:names.append("旧版装备（未识别）")
            if not names.is_empty():equipment.append(String(BUILD.FAMILY_NAMES[family])+"："+" / ".join(names))
    if equipment.is_empty():equipment.append("旧版本未留下可识别的装备摘要；浏览不会迁移它。")
    sections.append({"title":"归档时的装备","lines":equipment})
    var narrative := NARRATIVE.new()
    var wishes: Array[String]=[]
    for quest in narrative.quest_journal(data.inventory_counts,data.story_flags).slice(0,MAX_ROWS):
        wishes.append("%s · %s\n%s" % [String(quest.title),"已完成" if quest.status=="complete" else "进行中",String(quest.guidance)])
    sections.append({"title":"这份旅途已知的愿望","lines":wishes if not wishes.is_empty() else ["尚未记下愿望。"]})
    var proofs: Array[String]=[]
    for entry in narrative.evaluate_evidence(data.inventory_counts,data.story_flags).get("known_entries",[]).slice(0,MAX_ROWS):
        proofs.append(String(entry.get("title","已知证词"))+" · "+("已持有" if entry.get("acquired",false) else "已知线索"))
    sections.append({"title":"已知证词","lines":proofs if not proofs.is_empty() else ["尚无已知证词。"]})
    var ending := String(narrative.restored_ending_flags(data.story_flags).get("ending_chosen",""))
    if ending in ["ending_a","ending_b","ending_c"]:
        sections.append({"title":"已作出的选择","lines":[String({"ending_a":"重鸣","ending_b":"断冠","ending_c":"改写"}[ending])]})
    return {"ok":true,"reason":"只读核对归档，不应用装备、推进愿望或恢复存档。","sections":sections}

static func text(detail: Dictionary) -> String:
    if not detail.get("ok",false):return String(detail.get("reason","记录不可读。"))
    var lines: Array[String]=[String(detail.reason),""]
    for section in detail.get("sections",[]):
        lines.append(String(section.title))
        for line in section.lines:lines.append(String(line))
        lines.append("")
    return "\n".join(lines)
