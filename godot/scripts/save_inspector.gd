extends RefCounted
const STATE=preload("res://scripts/world_state.gd")
const REGION_NAMES={"demo_ch01_moss_bell_court":"苔钟庭","demo_ch02_rain_foundry_canal":"铸雨渠","demo_ch03_saltwhite_archive":"盐白书库","demo_ch04_broken_string_greenhouse":"断弦温室","demo_ch05_obsidian_pilgrim_road":"黑曜巡礼道","demo_ch06_silent_crown_core":"静默冠心"}
static func inspect(path: String) -> Dictionary:
    var exists:=FileAccess.file_exists(path)
    var world:=STATE.new()
    var valid:=exists and world.read(path)
    return {"exists":exists,"valid":valid,"error":world.last_error if exists and not valid else "",
        "sha":FileAccess.get_sha256(path) if exists else "missing","modified":FileAccess.get_modified_time(path) if exists else 0,
        "region_id":String(world.data.current_region) if valid else "","regions":world.data.regions.size() if valid else 0,
        "currency":int(world.data.currency) if valid else 0,"hp":int(world.data.hp) if valid else 0,"energy":int(world.data.energy) if valid else 0}
static func describe(info: Dictionary) -> String:
    if not info.get("exists",false):return "尚无记录"
    if not info.get("valid",false):return "记录无法读取，原文件保留"
    var region:=String(REGION_NAMES.get(String(info.region_id),"旧旅途区域"))
    var time:=Time.get_datetime_string_from_unix_time(int(info.modified)).replace("T"," ")
    return "%s · %d区 · %d碎钱 · 生命%d / 能量%d\n记录时间 %s UTC" % [region,int(info.regions),int(info.currency),int(info.hp),int(info.energy),time]
