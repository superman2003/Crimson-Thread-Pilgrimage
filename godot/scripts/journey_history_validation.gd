extends RefCounted
const HISTORY := preload("res://scripts/journey_history.gd")
const WORLD := preload("res://scripts/world_state.gd")
const PATH := "user://journey_history_validation.json"

func run(check: Callable) -> void:
    _clean()
    check.call(HISTORY.summaries(PATH).total == 0,"history without archives is empty")
    var world := WORLD.new()
    world.capture_global({"current_region":"demo_ch01_moss_bell_court","currency":77,"story_flags":{"ending_a_done":true}})
    world.capture_region("demo_ch01_moss_bell_court",{"visited_rooms":{"one":true,"two":true},"boss_defeated":true})
    world.write(PATH+".previous")
    var before := FileAccess.get_file_as_bytes(PATH+".previous")
    world.write(PATH)
    world.write(PATH+".bak")
    world.write(PATH+"_other.previous")
    var file := FileAccess.open(PATH+".previous.earlier_broken",FileAccess.WRITE)
    file.store_string("not a save")
    file.close()
    var result := HISTORY.summaries(PATH)
    check.call(result.total == 2 and result.shown == 2,"history isolates archives from primary, backup and other slots")
    var valid := {}
    var damaged := {}
    for row in result.entries:
        if row.valid:valid=row
        else:damaged=row
    check.call(valid.get("currency",0)==77 and valid.get("rooms",0)==2 and valid.get("bosses",0)==1,"history summarizes real validated world progress")
    check.call(valid.get("ending","")=="ending_a" and valid.get("region_name","")=="苔钟庭","legacy ending flags and region names are readable")
    check.call(not String(damaged.get("error","")).is_empty(),"damaged archive stays visible with an explicit error")
    check.call(FileAccess.get_file_as_bytes(PATH+".previous")==before,"browsing leaves archived bytes untouched")
    for index in 15:world.write(PATH+".previous.earlier_%02d" % index)
    result=HISTORY.summaries(PATH)
    check.call(result.total==17 and result.shown==HISTORY.MAX_ENTRIES,"large history limits validated rows while preserving total")
    check.call(DirAccess.get_files_at("user://").has(PATH.get_file()+".previous.earlier_00"),"entries omitted from the screen remain on disk")
    _clean()

func _clean() -> void:
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with(PATH.get_file()):DirAccess.remove_absolute("user://"+name)
