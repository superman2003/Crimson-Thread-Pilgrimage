extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    var history:=preload("res://scripts/journey_history.gd")
    var world:=preload("res://scripts/world_state.gd").new()
    var path:="user://upgrade_g_history.json"
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with(path.get_file()):DirAccess.remove_absolute("user://"+name)
    world.capture_global({"current_region":"demo_ch01_moss_bell_court","currency":71})
    world.capture_region("demo_ch01_moss_bell_court",{"visited_rooms":{"yes":true,"no":false},"boss_defeated":true})
    check(world.write(path+".previous"),"real archive fixture written")
    var bytes:=FileAccess.get_file_as_bytes(path+".previous")
    for index in 16:world.write(path+".previous.earlier_%03d"%index)
    world.write(path+".previous.earlier_000.bak")
    var first:=history.summaries(path,0,6);var second:=history.summaries(path,6,6)
    check(first.total==17 and first.shown==6 and first.has_more,"bounded archive page and total")
    check(second.offset==6 and second.entries[0].file!=first.entries[0].file,"next page contains different archive identities")
    for row in first.entries:
        check(row.valid and row.rooms==1 and row.bosses==1 and row.currency==71,"only true visit records count")
        check(row.sha256.length()==64,"summary carries verified source identity")
    check(FileAccess.get_file_as_bytes(path+".previous")==bytes,"browsing preserves bytes")
    check(not history.archive_name("slot.previous.earlier_1.tmp","slot.previous"),"temporary sidecar rejected")
    check(not history.archive_name("slot.previous.earlier_","slot.previous"),"empty suffix rejected")
    check(history.archive_name("slot.previous.earlier_broken","slot.previous"),"damaged archive identity remains discoverable")
    check(history.archive_name("slot.previous.earlier_1792922200.123_987","slot.previous"),"actual writer decimal timestamp is accepted")
    check(history.summaries(path,999,999).shown==0,"out of range page is empty")
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with(path.get_file()):DirAccess.remove_absolute("user://"+name)
    print("UPGRADE_G09 checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
