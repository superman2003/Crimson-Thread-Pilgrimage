extends RefCounted
## Compare saved identities; never install, recover, migrate on disk or mutate play.
const STATE:=preload("res://scripts/world_state.gd")
const HISTORY:=preload("res://scripts/journey_history.gd")
const BUILD:=preload("res://scripts/build_system.gd")
const NARRATIVE:=preload("res://scripts/world_narrative.gd")
const ABILITIES:=preload("res://scripts/permanent_ability_roles.gd")
const MAX_ROWS:=64

static func failure(reason: String) -> Dictionary:
    return {"ok":false,"reason":reason,"sections":[]}

static func _read(path: String, expected: String="") -> Dictionary:
    var directory:=DirAccess.open(path.get_base_dir())
    if directory==null or directory.is_link(path.get_file()):return failure("记录不可读或是符号链接；原文件保留。")
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null:return failure("记录不存在或无法读取；不会使用备份代替。")
    var length:=file.get_length();file.close()
    if length>STATE.MAX_BYTES:return failure("记录超过读取上限；原文件保留。")
    var hash:=FileAccess.get_sha256(path)
    if hash.is_empty() or (not expected.is_empty() and expected!=hash):return failure("归档已变化，请刷新列表后重选。")
    var state:=STATE.new()
    if not state.read(path):return failure("记录损坏或版本不可读；不会修复或覆盖原文件。")
    if FileAccess.get_sha256(path)!=hash:return failure("记录在读取期间变化，请重新核对。")
    return {"ok":true,"data":state.data,"sha":hash}

static func inspect(slot_path: String, name: String, expected_sha: String) -> Dictionary:
    if not HISTORY.archive_name(name,slot_path.get_file()+".previous"):
        return failure("这不是当前槽的旧旅途记录。")
    if expected_sha.length()!=64 or not expected_sha.is_valid_hex_number(false):return failure("缺少归档身份，请刷新后重选。")
    var archive_path:=slot_path.get_base_dir().path_join(name)
    var archive:=_read(archive_path,expected_sha)
    if not archive.ok:return failure("旧旅途："+String(archive.reason))
    var current:=_read(slot_path)
    if not current.ok:return failure("当前已保存旅途："+String(current.reason))
    var result:=project(archive.data,current.data)
    if FileAccess.get_sha256(archive_path)!=archive.sha or FileAccess.get_sha256(slot_path)!=current.sha:
        return failure("比较期间记录已变化，请重新核对。")
    return result

static func _number(title: String, before: int, after: int) -> String:
    var delta:=after-before
    var description:="相同" if delta==0 else "当前多%d" % delta if delta>0 else "当前少%d" % -delta
    return "%s：%d → %d（%s）" % [title,before,after,description]

static func _true_keys(value: Dictionary) -> Dictionary:
    var result:={}
    for key in value:
        if value[key] is bool and value[key]:result[key]=true
    return result

static func _sets(title: String, before: Dictionary, after: Dictionary) -> String:
    var shared:=0
    for key in before:
        if after.has(key):shared+=1
    return "%s：共同%d / 仅旧旅途%d / 仅当前%d" % [title,shared,before.size()-shared,after.size()-shared]

static func _region(data: Dictionary, id: String) -> Dictionary:
    return data.regions.get(id,STATE.fresh_region())

static func _equipment(saved: Dictionary, build: RefCounted) -> Dictionary:
    var result:={"契印":"旧记录未说明"}
    var crest: Variant=saved.get("crest")
    if crest is String and build.catalog.crests.has(crest):result["契印"]=String(build.catalog.crests[crest].name)
    var families: Variant=saved.get("equipped_families")
    for family in BUILD.FAMILY_KEYS:
        var title:=String(BUILD.FAMILY_NAMES[family])
        if not families is Dictionary or not families.get(family) is Array:
            result[title]="旧记录未说明；不推定为空槽";continue
        var entries: Array=families[family]
        var names: Array[String]=[]
        for item in entries.slice(0,BUILD.FAMILY_CAPACITIES[family]):
            if not item is String:names.append("无法识别的旧装备");continue
            if item.is_empty():names.append("空槽");continue
            var table: Dictionary=build.catalog[BUILD.FAMILY_TABLES[family]]
            names.append(String(table[item].name) if table.has(item) else "无法识别的旧装备")
        result[title]=" / ".join(names) if not names.is_empty() else "未配置"
    return result

static func _known_quests(data: Dictionary, narrative: RefCounted) -> Dictionary:
    var result:={}
    for quest in narrative.quest_journal(data.inventory_counts,data.story_flags).slice(0,MAX_ROWS):
        result[String(quest.id)]={"title":String(quest.title),"state":"已完成" if quest.status=="complete" else "进行中"}
    return result

static func _known_evidence(data: Dictionary, narrative: RefCounted) -> Dictionary:
    var result:={}
    var known: Array=narrative.evaluate_evidence(data.inventory_counts,data.story_flags).get("known_entries",[])
    for proof in known.slice(0,MAX_ROWS):
        result[String(proof.id)]={"title":String(proof.title),"state":"已持有" if proof.get("acquired",false) else "已知线索"}
    return result

static func _known_rows(before: Dictionary, after: Dictionary) -> Array[String]:
    var keys:=before.keys()
    for key in after:
        if not before.has(key):keys.append(key)
    keys.sort()
    var lines: Array[String]=[]
    for key in keys.slice(0,MAX_ROWS):
        var title:=String(after.get(key,before.get(key,{})).get("title","已知记录"))
        lines.append("%s：%s → %s" % [title,String(before.get(key,{}).get("state","尚未记下")),String(after.get(key,{}).get("state","尚未记下"))])
    if keys.size()>MAX_ROWS:lines.append("这里只显示前%d条已知记录。" % MAX_ROWS)
    if lines.is_empty():lines.append("两份旅途均未记下此类记录。")
    return lines

static func _inventory(before: Dictionary, after: Dictionary) -> Array[String]:
    var source:=FileAccess.open("res://data/item_lore.json",FileAccess.READ)
    if source==null or source.get_length()>1048576:return ["物品名称表暂不可读；不显示内部编号。"]
    var parsed: Variant=JSON.parse_string(source.get_as_text());source.close()
    if not parsed is Dictionary or not parsed.get("items") is Dictionary:return ["物品名称表暂不可读；不显示内部编号。"]
    var keys:=before.keys()
    for id in after:
        if not before.has(id):keys.append(id)
    var records: Array[Dictionary]=[]
    var unknown:=0
    for id in keys:
        var old:=int(before.get(id,0));var current:=int(after.get(id,0))
        if old==0 and current==0:continue
        var item: Variant=parsed.items.get(id)
        if not item is Dictionary or not item.get("display_name") is String:
            unknown+=1;continue
        records.append({"title":String(item.display_name),"old":old,"current":current})
    records.sort_custom(func(a: Dictionary,b: Dictionary):return String(a.title)<String(b.title))
    var lines: Array[String]=[]
    for record in records.slice(0,MAX_ROWS):lines.append(_number(record.title,record.old,record.current))
    if records.size()>MAX_ROWS:lines.append("这里只列前%d种已持有的物品。" % MAX_ROWS)
    if unknown>0:lines.append("另有%d种旧物品未能识别名称；不会推定它们是同一种物品。" % unknown)
    if lines.is_empty():lines.append("两份旅途均未记录持有物品。")
    return lines

static func project(before: Dictionary, after: Dictionary) -> Dictionary:
    if not STATE._valid_data(before) or not STATE._valid_data(after):return failure("记录结构无效，无法比较；不会将坏记录视为零进度。")
    var sections: Array[Dictionary]=[]
    var resource_lines: Array[String]=[]
    resource_lines.append(_number("碎钱",int(before.currency),int(after.currency)))
    for pair in [["hp","保存时生命"],["energy","保存时绯线"]]:
        resource_lines.append("%s：%s → %s" % [pair[1],before[pair[0]],after[pair[0]]])
    resource_lines.append("停留地区：%s → %s" % [HISTORY.REGIONS.get(before.current_region,"未记明地区"),HISTORY.REGIONS.get(after.current_region,"未记明地区")])
    sections.append({"title":"旧旅途 → 当前已保存旅途","lines":resource_lines})
    var region_lines: Array[String]=[]
    for id in HISTORY.REGIONS:
        if not before.regions.has(id) and not after.regions.has(id):continue
        var old:=_region(before,id);var current:=_region(after,id)
        region_lines.append("%s：%s → %s" % [HISTORY.REGIONS[id],"有记录" if before.regions.has(id) else "尚无记录","有记录" if after.regions.has(id) else "尚无记录"])
        region_lines.append(String(HISTORY.REGIONS[id])+" · "+_sets("已访房间",_true_keys(old.visited_rooms),_true_keys(current.visited_rooms)))
        region_lines.append(_sets("已开捷径",_true_keys(old.opened_shortcuts),_true_keys(current.opened_shortcuts)))
        region_lines.append("守门者：%s → %s" % ["已败" if old.boss_defeated else "未败","已败" if current.boss_defeated else "未败"])
    sections.append({"title":"地区记录身份核对（不显示未探地点）","lines":region_lines if not region_lines.is_empty() else ["两份旅途均无地区记录。"]})
    var ability_lines: Array[String]=[]
    for id in ABILITIES.IDS:
        var old:=ABILITIES.owns(before.inventory_counts,id);var current:=ABILITIES.owns(after.inventory_counts,id)
        if not old and not current:continue
        ability_lines.append("%s：%s → %s" % [String(ABILITIES.catalog().get("abilities",{}).get(id,{}).get("title","已记录永久能力")),"已获" if old else "未获","已获" if current else "未获"])
    sections.append({"title":"两份旅途已知的永久能力","lines":ability_lines if not ability_lines.is_empty() else ["两份旅途均未记录永久能力。"]})
    sections.append({"title":"已存行囊（仅列至少一份记录持有的物品）","lines":_inventory(before.inventory_counts,after.inventory_counts)})
    var build:=BUILD.new()
    var equipment_before:=_equipment(before.build_state,build)
    var equipment_after:=_equipment(after.build_state,build)
    var equipment_lines: Array[String]=[]
    for title in equipment_before:equipment_lines.append("%s：%s → %s" % [title,equipment_before[title],equipment_after[title]])
    sections.append({"title":"保存时的配置（只读、不迁移、不装备）","lines":equipment_lines})
    var narrative:=NARRATIVE.new()
    sections.append({"title":"各自已知的愿望","lines":_known_rows(_known_quests(before,narrative),_known_quests(after,narrative))})
    sections.append({"title":"各自已知的证词","lines":_known_rows(_known_evidence(before,narrative),_known_evidence(after,narrative))})
    var ending_names:={"ending_a":"重鸣","ending_b":"断冠","ending_c":"改写"}
    var ending_before:=String(narrative.restored_ending_flags(before.story_flags).get("ending_chosen",""))
    var ending_after:=String(narrative.restored_ending_flags(after.story_flags).get("ending_chosen",""))
    sections.append({"title":"已作出的终局选择","lines":["%s → %s" % [ending_names.get(ending_before,"尚未作出选择"),ending_names.get(ending_after,"尚未作出选择")]]})
    return {"ok":true,"reason":"只比较当前槽的已保存记录：旧旅途 → 当前已保存旅途。未保存的实时变化不在其中；数量相同不表示路线、装备或剧情相同。不会恢复、合并、装备或覆盖任何记录。","sections":sections}
