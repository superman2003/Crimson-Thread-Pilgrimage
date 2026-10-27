extends RefCounted
const STATE=preload("res://scripts/world_state.gd")
const ABILITIES=preload("res://scripts/permanent_ability_roles.gd")
const REGION_NAMES={"demo_ch01_moss_bell_court":"苔钟庭","demo_ch02_rain_foundry_canal":"铸雨渠","demo_ch03_saltwhite_archive":"盐白书库","demo_ch04_broken_string_greenhouse":"断弦温室","demo_ch05_obsidian_pilgrim_road":"黑曜巡礼道","demo_ch06_silent_crown_core":"静默冠心"}
static func inspect(path: String) -> Dictionary:
    var exists:=FileAccess.file_exists(path)
    var before:=FileAccess.get_sha256(path) if exists else "missing"
    var world:=STATE.new()
    var valid:=exists and world.read(path)
    var still_exists:=FileAccess.file_exists(path)
    var digest:=FileAccess.get_sha256(path) if still_exists else "missing"
    var changed:=before!=digest
    valid=valid and not changed
    return {"exists":exists,"valid":valid,"error":"记录在读取时变化，请刷新后重新核对。" if changed else world.last_error if exists and not valid else "",
        "sha":digest,"modified":FileAccess.get_modified_time(path) if still_exists else 0,
        "region_id":String(world.data.current_region) if valid else "","regions":world.data.regions.size() if valid else 0,
        "currency":int(world.data.currency) if valid else 0,"hp":int(world.data.hp) if valid else 0,"energy":int(world.data.energy) if valid else 0,
        "progress":progress(world.data) if valid else {}}

static func progress(data: Dictionary) -> Dictionary:
    var items:=0;var abilities:=0;var visited:=0;var bosses:=0
    for value in data.get("inventory_counts",{}).values():
        if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0.0 and float(value)==floor(float(value)):items+=1
    for id in ABILITIES.IDS:
        if ABILITIES.owns(data.get("inventory_counts",{}),String(id)):abilities+=1
    for region in data.get("regions",{}).values():
        for value in region.get("visited_rooms",{}).values():
            if value is bool and value:visited+=1
        if region.get("boss_defeated") is bool and region.boss_defeated:bosses+=1
    return {"items":items,"abilities":abilities,"visited":visited,"bosses":bosses}

static func compare(primary: Dictionary, backup: Dictionary) -> String:
    if not primary.get("valid",false) or not backup.get("valid",false):
        return "主档或备份不可读，无法比较进度差异；请根据可读取记录的摘要核对。"
    var lines: Array[String]=["若恢复此备份：主档 → 备份"]
    for pair in [["currency","碎钱"],["hp","当前生命"],["energy","当前绯线"]]:
        lines.append(_difference(pair[1],int(primary.get(pair[0],0)),int(backup.get(pair[0],0))))
    if primary.get("progress") is Dictionary and backup.get("progress") is Dictionary:
        for pair in [["items","持有物品种类"],["abilities","已获永久能力"],["visited","已访房间"],["bosses","已败守门者"]]:
            lines.append(_difference(pair[1],int(primary.progress.get(pair[0],0)),int(backup.progress.get(pair[0],0))))
    lines.append("只比较以上资源和记录数量；数量相同不代表剧情、地图或装备内容相同。")
    return "\n".join(lines)

static func _difference(title: String, before: int, after: int) -> String:
    var change:=after-before
    return "%s：%d → %d（%s）" % [title,before,after,"增加%d" % change if change>0 else "减少%d" % -change if change<0 else "不变"]
static func describe(info: Dictionary) -> String:
    if not info.get("exists",false):return "尚无记录"
    if not info.get("valid",false):return "记录无法读取，原文件保留"
    var region:=String(REGION_NAMES.get(String(info.region_id),"旧旅途区域"))
    var time:=Time.get_datetime_string_from_unix_time(int(info.modified)).replace("T"," ")
    return "%s · %d区 · %d碎钱 · 生命%d / 能量%d\n记录时间 %s UTC" % [region,int(info.regions),int(info.currency),int(info.hp),int(info.energy),time]
