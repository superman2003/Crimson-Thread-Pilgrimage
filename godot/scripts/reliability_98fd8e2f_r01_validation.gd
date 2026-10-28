extends SceneTree
const STORE = preload("res://scripts/settings_persistence.gd")
const TX = preload("res://scripts/preference_file_transaction.gd")
const PATH := "user://preference.cfg"
var checks := 0
var failures := 0
class FailedPlace extends "res://scripts/preference_file_transaction.gd":
    func _place(_source: String, _target: String) -> int:return ERR_CANT_CREATE
class FailedRollback extends FailedPlace:
    var calls := 0
    func _move(source: String, target: String) -> int:
        if source.ends_with(BACKUP_SUFFIX):return ERR_CANT_CREATE
        return super._move(source, target)
class BadWrite extends "res://scripts/settings_persistence.gd":
    func _write(_config: ConfigFile, target: String) -> Error:
        var file := FileAccess.open(target, FileAccess.WRITE)
        file.store_string("[wrong]\nx=7\n");file.close()
        return OK
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:failures += 1;print("FAIL ",label)
func config(value: int) -> ConfigFile:
    var result := ConfigFile.new();result.set_value("accessibility","subtitle_size",value)
    var event := InputEventKey.new();event.physical_keycode=KEY_H
    result.set_value("bindings","heal",[event])
    result.set_value("other","retain","yes")
    return result
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var store := STORE.new();var tx := TX.new()
    check(store.save(config(21),PATH)==OK,"initial native save")
    var original := FileAccess.get_file_as_bytes(PATH)
    check(BadWrite.new().save(config(26),PATH)!=OK,"wrong candidate rejected")
    check(FileAccess.get_file_as_bytes(PATH)==original,"bad candidate preserves bytes")
    store.transaction=FailedPlace.new()
    check(store.save(config(26),PATH)!=OK and store.pending,"installation failure remains pending")
    check(FileAccess.get_file_as_bytes(PATH)==original,"failed installation rolls back exact original")
    store.transaction=FailedRollback.new()
    check(store.save(config(26),PATH)!=OK,"failed rollback reported")
    check(not FileAccess.file_exists(PATH) and FileAccess.file_exists(PATH+TX.BACKUP_SUFFIX),"backup survives failed rollback")
    store=STORE.new()
    check(store.recover(PATH)==OK,"new reader recovers interrupted transaction")
    check(FileAccess.get_file_as_bytes(PATH)==original,"recovered original bytes")
    var absolute := ProjectSettings.globalize_path(PATH)
    var lock := tx._lock(absolute)
    check(not lock.is_empty(),"lock acquired")
    check(store.save(config(26),PATH)==ERR_BUSY,"second writer refused")
    check(FileAccess.get_file_as_bytes(PATH)==original,"busy writer preserves target")
    tx._unlock(lock)
    var first := tx.temporary(PATH);var second := tx.temporary(PATH)
    check(first!=second,"concurrent candidates have distinct names")
    check(store.save(config(26),PATH)==OK and not store.pending,"retry clears warning after commit")
    var loaded := ConfigFile.new();check(loaded.load(PATH)==OK,"read new settings")
    check(loaded.get_value("accessibility","subtitle_size")==26,"actual latest value")
    check(loaded.get_value("bindings","heal")[0].physical_keycode==KEY_H,"native event preserved")
    check(loaded.get_value("other","retain")=="yes","unrelated sections retained")
    check(config(17).save(PATH+TX.BACKUP_SUFFIX)==OK,"simulate post-install crash")
    check(store.recover(PATH)==OK,"keep installed target and quarantine previous backup")
    check(loaded.load(PATH)==OK and loaded.get_value("accessibility","subtitle_size")==26,"recovery does not replace committed target")
    check(not FileAccess.file_exists(PATH+TX.BACKUP_SUFFIX),"pending backup resolved")
    check(tx.install(PATH,PATH)==ERR_INVALID_PARAMETER,"cannot install onto self")
    check(store.save(config(21),"")==ERR_INVALID_PARAMETER,"empty path refused")
    var directory := DirAccess.open("user://")
    check(Array(directory.get_files()).filter(func(file):return String(file).contains("preference-pending")).is_empty(),"no temporary files after failures")
    check(Array(directory.get_directories()).filter(func(file):return String(file).contains("preference-lock")).is_empty(),"all owned locks released")
    print("RELIABILITY_R01 checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
