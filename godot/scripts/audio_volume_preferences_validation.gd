extends SceneTree
const DIRECTOR := preload("res://scripts/audio_director.gd")
const STORE := preload("res://scripts/audio_volume_preferences.gd")
const USER_VOLUME := preload("res://scripts/audio_user_volume_validation.gd")
const PATH := "user://atomic_audio_preferences.cfg"
var checks := 0
var failures := 0
class RejectInstall extends "res://scripts/audio_volume_preferences.gd":
    var reject := true
    func _install(temporary: String, path: String) -> int:
        return ERR_FILE_CANT_WRITE if reject else super._install(temporary,path)
class RejectStage extends "res://scripts/audio_volume_preferences.gd":
    func _stage(_candidate: ConfigFile, _temporary: String) -> int:
        return ERR_FILE_CANT_WRITE
class ChangedReadback extends "res://scripts/audio_volume_preferences.gd":
    func _stage(candidate: ConfigFile, temporary: String) -> int:
        var result := super._stage(candidate,temporary)
        if result != OK:return result
        var changed := ConfigFile.new()
        changed.load(temporary)
        changed.set_value("volumes","music",1.0 if float(candidate.get_value("volumes","music")) != 1.0 else 2.0)
        return changed.save(temporary)
class ReentrantStage extends "res://scripts/audio_volume_preferences.gd":
    var owner: Node
    var once := true
    func _stage(candidate: ConfigFile, temporary: String) -> int:
        if once:
            once = false
            owner.set_user_volume("sfx",49.0)
        return super._stage(candidate,temporary)

func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fresh() -> Node:
    var value := DIRECTOR.new()
    value.settings_path = PATH
    value.autoplay_enabled = false
    root.add_child(value)
    value.set_process(false)
    return value
func values() -> Dictionary:
    return {"master":100.0,"music":30.0,"sfx":40.0,"ambience":50.0}
func read() -> ConfigFile:
    var config := ConfigFile.new()
    check(config.load(PATH) == OK,"actual saved config remains readable")
    return config
func run() -> void:
    var layout := AudioServer.generate_bus_layout()
    for bus in ["BGM","SFX","Ambience","UI"]:DIRECTOR._ensure_bus(bus,"Master")
    var seed := ConfigFile.new()
    seed.set_value("volumes","music",80.0)
    seed.set_value("future","note","保留其它节")
    seed.set_value("future","fraction",0.123456789012345)
    check(seed.save(PATH) == OK,"seed real last-known settings")
    var active := fresh()
    active.set_user_volume("music",30.0)
    check(active.has_method("user_volume_save_status"),"production director exposes persistence status")
    if not active.has_method("user_volume_save_status"):
        active.free()
        AudioServer.set_bus_layout(layout)
        print("AUDIO_VOLUME_SAVE checks=%d failures=%d" % [checks,failures])
        quit(1)
        return
    check(active.user_volume_save_status().persisted,"successful staged replacement is acknowledged")
    check(read().get_value("future","note","") == "保留其它节","audio save preserves unrelated config sections")
    check(read().get_value("volumes","music",-1.0) == 30.0,"new volume reaches real file")
    check(not FileAccess.file_exists(PATH + STORE.TEMP_SUFFIX),"successful replacement leaves no temporary file")
    var before := FileAccess.get_file_as_bytes(PATH)
    var rejecting := RejectInstall.new()
    active.volume_preferences = rejecting
    active.set_user_volume("music",57.0)
    check(active.get_user_volume("music") == 57.0,"failed save keeps current-session volume applied")
    check(not active.user_volume_save_status().persisted,"failed replacement remains visibly pending")
    check(active.user_volume_save_status().error == ERR_FILE_CANT_WRITE,"actual write error is retained")
    check(FileAccess.get_file_as_bytes(PATH) == before,"failed replacement preserves original bytes")
    check(not FileAccess.file_exists(PATH + STORE.TEMP_SUFFIX),"failed replacement removes only its own staging file")
    active.set_user_volume("music",63.0)
    check(FileAccess.get_file_as_bytes(PATH) == before,"later failed changes still preserve last saved settings")
    rejecting.reject = false
    check(active.retry_user_volume_save().persisted,"explicit retry saves the latest settings")
    check(read().get_value("volumes","music",-1.0) == 63.0,"retry acknowledges latest rather than failed first snapshot")
    before = FileAccess.get_file_as_bytes(PATH)
    active.volume_preferences = RejectStage.new()
    active.set_user_volume("ambience",12.0)
    check(not active.user_volume_save_status().persisted and FileAccess.get_file_as_bytes(PATH) == before,"staging failure preserves prior file and pending changes")
    active.volume_preferences = ChangedReadback.new()
    active.set_user_volume("music",67.0)
    check(active.user_volume_save_status().error == ERR_INVALID_DATA,"modified staged values fail the readback gate")
    check(FileAccess.get_file_as_bytes(PATH) == before,"readback mismatch cannot replace the previous file")
    check(not FileAccess.file_exists(PATH + STORE.TEMP_SUFFIX),"readback mismatch cleans staging file")
    active.volume_preferences = STORE.new()
    check(active.retry_user_volume_save().persisted,"normal writer recovers after transient validation failure")
    var racing := ReentrantStage.new()
    racing.owner = active
    active.volume_preferences = racing
    active.set_user_volume("music",71.0)
    check(not active.user_volume_save_status().persisted,"a reentrant change is not acknowledged by an older snapshot")
    check(active.get_user_volume("sfx") == 49.0,"newer reentrant volume is kept in the live mix")
    check(active.retry_user_volume_save().persisted,"retry completes the latest reentrant snapshot")
    check(read().get_value("volumes","sfx",-1.0) == 49.0,"retry persists the newer reentrant value")
    racing.owner = null
    active.volume_preferences = STORE.new()
    before = FileAccess.get_file_as_bytes(PATH)
    var snapshot: Dictionary = active.user_volumes.duplicate(true)
    for invalid in [NAN,INF,-INF]:
        active.set_user_volume("music",invalid)
        check(active.user_volumes == snapshot and FileAccess.get_file_as_bytes(PATH) == before,"non-finite slider input never writes")
    active.set_user_volume("unknown",12.0)
    check(active.user_volumes == snapshot and FileAccess.get_file_as_bytes(PATH) == before,"unknown channel never writes")
    for invalid in [true,"10",-1,101,NAN,INF]:
        var bad := values()
        bad.music = invalid
        check(STORE.new().save(PATH,bad) == ERR_INVALID_DATA and FileAccess.get_file_as_bytes(PATH) == before,"invalid serialized volume is rejected before touching disk")
    var successor := fresh()
    successor.set_user_volume("music",22.0)
    before = FileAccess.get_file_as_bytes(PATH)
    active.set_user_volume("music",99.0)
    check(FileAccess.get_file_as_bytes(PATH) == before,"retired director cannot overwrite successor settings")
    check(not active.retry_user_volume_save().persisted,"retired page cannot retry into a newer owner")
    active.free()
    successor.free()
    var restart := fresh()
    check(restart.get_user_volume("music") == 22.0 and restart.get_user_volume("sfx") == 49.0,"new director loads atomically saved latest channels")
    check(read().get_value("future","note","") == "保留其它节","foreign fields survive all retries and restarts")
    restart.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
    var old_contract := USER_VOLUME.new()
    await old_contract.run(self,check)
    check(old_contract.failures == 0,"unchanged user-volume, duck and mute contract still passes")
    AudioServer.set_bus_layout(layout)
    print("AUDIO_VOLUME_SAVE checks=%d failures=%d" % [checks,failures])
    quit(0 if failures == 0 else 1)

