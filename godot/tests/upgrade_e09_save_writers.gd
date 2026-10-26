extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func finish() -> void:
    for failure in failures:push_error(failure)
    print("UPGRADE_%s checks=%d failures=%d" % [get_script().resource_path.get_file().get_basename(),checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
func photograph() -> void:
    var target:=OS.get_environment("UPGRADE_CAPTURE")
    if target.is_empty() or DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(target)
const STATE=preload("res://scripts/world_state.gd")
const PATH:="user://upgrade_e09_save.json"
func cleanup() -> void:
    for suffix in ["",".bak",".tmp",".bak.pending"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH+suffix))
func run() -> void:
    cleanup()
    var first:=STATE.new();var candidate: Dictionary=first.data.duplicate(true);candidate.currency=1
    check(first.write_candidate(candidate,PATH),"writer-only interface creates valid save")
    var reader:=STATE.new();check(reader.read(PATH),"reader acquires snapshot identity")
    candidate.currency=2
    check(first.write_candidate(candidate,PATH),"legacy writer-only authority remains compatible")
    var previous:=FileAccess.get_file_as_string(PATH)
    var stale: Dictionary=reader.data.duplicate(true);stale.currency=9
    check(not reader.write_candidate(stale,PATH) and FileAccess.get_file_as_string(PATH)==previous,"stale reader cannot overwrite newer save")
    check(reader.read(PATH),"explicit reread refreshes identity")
    stale=reader.data.duplicate(true);stale.currency=3
    check(reader.write_candidate(stale,PATH),"refreshed reader may commit")
    check(FileAccess.get_file_as_string(PATH+".bak")==previous,"verified backup preserves exact previous bytes")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
    check(not reader.write_candidate(stale,PATH) and not FileAccess.file_exists(PATH),"stale reader cannot recreate externally deleted save")
    reader.reset();check(reader.write_candidate(stale,PATH),"reset releases reader lease")
    cleanup();finish()
