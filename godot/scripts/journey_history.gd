extends RefCounted
## Read-only summaries of this slot's preserved journeys. Never installs a save.
const WORLD := preload("res://scripts/world_state.gd")
const MAX_ENTRIES := 12
const REGIONS := {"demo_ch01_moss_bell_court":"苔钟庭","demo_ch02_rain_foundry_canal":"铸雨渠","demo_ch03_saltwhite_archive":"盐白书库","demo_ch04_broken_string_greenhouse":"断弦温室","demo_ch05_obsidian_pilgrim_road":"黑曜巡礼道","demo_ch06_silent_crown_core":"无声王冠"}

const MAX_PAGE_SIZE := 24
const MAX_OFFSET := 240
const PAGE_BYTES := 12 * 1024 * 1024

static func summaries(path: String, offset: int=0, limit: int=MAX_ENTRIES) -> Dictionary:
    offset=clampi(offset,0,MAX_OFFSET)
    limit=clampi(limit,1,MAX_PAGE_SIZE)
    var directory:=DirAccess.open(path.get_base_dir())
    if directory==null:return {"entries":[],"total":0,"shown":0,"offset":offset,"error":"无法打开存档目录。"}
    var stem:=path.get_file()+".previous"
    var candidates: Array[Dictionary]=[]
    var total:=0
    directory.list_dir_begin()
    var name:=directory.get_next()
    while not name.is_empty():
        if not directory.current_is_dir() and not directory.is_link(name) and archive_name(name,stem):
            var file:=path.get_base_dir().path_join(name)
            candidates.append({"file":name,"path":file,"modified":FileAccess.get_modified_time(file)})
            total+=1
            # Retain only the requested window of newest identities, even in a
            # directory with years of archives. No saves are parsed in this loop.
            candidates.sort_custom(_newer)
            if candidates.size()>offset+limit:candidates.pop_back()
        name=directory.get_next()
    directory.list_dir_end()
    var rows: Array[Dictionary]=[]
    var remaining:=PAGE_BYTES
    for index in range(offset,candidates.size()):
        var entry:=candidates[index]
        var handle:=FileAccess.open(String(entry.path),FileAccess.READ)
        var bytes:=handle.get_length() if handle!=null else -1
        if handle!=null:handle.close()
        var row: Dictionary={"file":entry.file,"modified":entry.modified,"valid":false,"region_id":"","region_name":"","regions":0,"rooms":0,"bosses":0,"currency":0,"ending":"","error":""}
        if bytes<0:row.error="无法读取归档。"
        elif bytes>WORLD.MAX_BYTES:row.error="归档超过单份大小上限。"
        elif bytes>remaining:row.error="本页读取预算已用完；可单独查看这份归档。"
        else:
            remaining-=bytes
            var identity:=FileAccess.get_sha256(String(entry.path))
            var world:=WORLD.new()
            if not world.read(String(entry.path)):row.error=world.last_error
            elif identity.is_empty() or FileAccess.get_sha256(String(entry.path))!=identity:
                row.error="归档在读取期间发生变化，请重新打开。"
            else:
                row.valid=true
                row.region_id=String(world.data.current_region)
                row.region_name=String(REGIONS.get(row.region_id,"旧旅途区域"))
                row.currency=int(world.data.currency)
                for id in world.data.regions:
                    if not REGIONS.has(id):continue
                    var region: Dictionary=world.data.regions[id]
                    row.regions+=1
                    for visited in region.visited_rooms.values():
                        if visited is bool and visited:row.rooms+=1
                    if region.boss_defeated is bool and region.boss_defeated:row.bosses+=1
                row.ending=String(preload("res://scripts/world_narrative.gd").new().restored_ending_flags(world.data.story_flags).get("ending_chosen",""))
                row["sha256"]=identity
        rows.append(row)
    return {"entries":rows,"total":total,"shown":rows.size(),"offset":offset,"next_offset":offset+rows.size(),"has_more":offset+rows.size()<total}

static func archive_name(name: String, stem: String) -> bool:
    if name==stem:return true
    if not name.begins_with(stem+".earlier_"):return false
    var suffix:=name.trim_prefix(stem+".earlier_")
    # The writer's Unix timestamp contains a decimal point. Exclude known
    # sidecars, while retaining that timestamp and damaged archive identities.
    return not suffix.is_empty() and not suffix.ends_with(".bak") and not suffix.ends_with(".tmp") and not suffix.ends_with(".pending") and not suffix.contains("/") and not suffix.contains("\\")

static func _newer(a: Dictionary,b: Dictionary) -> bool:
    if a.modified==b.modified:return String(a.file)>String(b.file)
    return int(a.modified)>int(b.modified)
