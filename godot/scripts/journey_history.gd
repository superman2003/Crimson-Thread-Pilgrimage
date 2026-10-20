extends RefCounted
## Read-only summaries of this slot's preserved journeys. Never installs a save.
const WORLD := preload("res://scripts/world_state.gd")
const MAX_ENTRIES := 12
const REGIONS := {"demo_ch01_moss_bell_court":"苔钟庭","demo_ch02_rain_foundry_canal":"铸雨渠","demo_ch03_saltwhite_archive":"盐白书库","demo_ch04_broken_string_greenhouse":"断弦温室","demo_ch05_obsidian_pilgrim_road":"黑曜巡礼道","demo_ch06_silent_crown_core":"无声王冠"}

static func summaries(path: String) -> Dictionary:
    var directory := path.get_base_dir()
    var stem := path.get_file() + ".previous"
    var candidates: Array[Dictionary] = []
    for name in DirAccess.get_files_at(directory):
        if name != stem and not name.begins_with(stem + ".earlier_"):continue
        var file := directory.path_join(name)
        candidates.append({"file":name,"path":file,"modified":FileAccess.get_modified_time(file)})
    candidates.sort_custom(func(a: Dictionary,b: Dictionary):
        if a.modified == b.modified:return String(a.file) > String(b.file)
        return int(a.modified) > int(b.modified))
    var rows: Array[Dictionary] = []
    for index in mini(candidates.size(),MAX_ENTRIES):
        var entry := candidates[index]
        var world := WORLD.new()
        var valid := world.read(String(entry.path))
        var rooms := 0
        var bosses := 0
        if valid:
            for region in world.data.regions.values():
                rooms += region.visited_rooms.size()
                if bool(region.boss_defeated):bosses += 1
        rows.append({"file":entry.file,"modified":entry.modified,"valid":valid,
            "region_id":String(world.data.current_region) if valid else "",
            "region_name":String(REGIONS.get(world.data.current_region,world.data.current_region)) if valid else "",
            "regions":world.data.regions.size() if valid else 0,
            "rooms":rooms,"bosses":bosses,"currency":int(world.data.currency) if valid else 0,
            "ending":String(preload("res://scripts/world_narrative.gd").new().restored_ending_flags(world.data.story_flags).get("ending_chosen","")) if valid else "",
            "error":world.last_error if not valid else ""})
    return {"entries":rows,"total":candidates.size(),"shown":rows.size()}
