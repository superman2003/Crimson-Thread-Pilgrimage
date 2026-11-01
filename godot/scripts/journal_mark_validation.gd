extends SceneTree
const STORE:=preload("res://scripts/journal_mark_store.gd")
const DOCUMENT:={"key":"guide:reading_contract","fingerprint":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","title":"Only the hash is stored","text":"Never persist this body"}
var checks:=0
var failures:=0
class FailingInstall extends "res://scripts/settings_persistence.gd":
    var fail:=true
    func _install(temporary: String, destination: String) -> Error:
        return ERR_CANT_CREATE if fail else super._install(temporary,destination)
class InterleavingInstall extends "res://scripts/settings_persistence.gd":
    var concurrent: ConfigFile
    func _install(temporary: String, destination: String) -> Error:
        if concurrent.save(destination)!=OK:return ERR_CANT_CREATE
        return super._install(temporary,destination)
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func done(marker: String) -> void:
    print("%s checks=%d failures=%d" % [marker,checks,failures]);quit(0 if failures==0 else 1)
func run() -> void:
    var arguments:=OS.get_cmdline_user_args()
    var model:=STORE.new()
    if "--seed" in arguments:
        model.configure("cross_process_contract")
        check(model.capture(DOCUMENT,125.0,500.0,330.0,17.0).ok,"first native process saves explicit reading mark")
        check(FileAccess.file_exists(model.path),"first native process leaves actual preferences file")
        done("JOURNAL_MARKS_SEED");return
    if "--reload" in arguments:
        model.configure("cross_process_contract")
        check(model.records.size()==1 and model.position(DOCUMENT,500.0,330.0,17.0).offset==125.0,"second native process loads exact saved mark")
        check(model.position(DOCUMENT,1000.0,660.0,26.0).offset==250.0,"second process adapts saved ratio to changed typography")
        check(model.remove(DOCUMENT).ok,"second process explicitly removes saved mark")
        DirAccess.remove_absolute(ProjectSettings.globalize_path(model.path))
        done("JOURNAL_MARKS_RELOAD");return
    model.configure("native_store_contract")
    check(model.writable and model.records.is_empty(),"new slot has no fabricated persisted mark")
    check(not model.position(DOCUMENT,100.0,330.0,17.0).ok,"missing mark is explained without automatic restore")
    var document_before:=DOCUMENT.duplicate(true)
    check(model.capture(DOCUMENT,125.0,500.0,330.0,17.0).ok,"explicit save uses real verified preference transaction")
    check(model.records.size()==1 and not model.has_pending,"successful save publishes one record only")
    var bytes:=FileAccess.get_file_as_bytes(model.path)
    var serialized:=FileAccess.get_file_as_string(model.path)
    check(not serialized.contains("Never persist") and not serialized.contains("Only the hash"),"neither journal body nor title is written to preferences")
    check(DOCUMENT==document_before,"saving never mutates borrowed public document")
    var position:=model.position(DOCUMENT,500.0,330.0,17.0)
    check(position.ok and position.offset==125.0 and not position.relative,"same layout restores exact pixel position")
    check(model.position(DOCUMENT,1000.0,400.0,17.0).offset==250.0,"width change restores normalized reading ratio")
    check(model.position(DOCUMENT,200.0,330.0,26.0).offset==50.0,"font change restores normalized ratio")
    check(model.position(DOCUMENT,50.0,330.0,17.0).offset==50.0,"shorter layout clamps offset to actual maximum")
    var changed:=DOCUMENT.duplicate(true);changed.fingerprint="b".repeat(64)
    check(not model.position(changed,500.0,330.0,17.0).ok and model.records.has(DOCUMENT.key),"changed text refuses old offset while preserving stored mark")
    for pair in [[NAN,500.0,330.0,17.0],[INF,500.0,330.0,17.0],[-1.0,500.0,330.0,17.0],[501.0,500.0,330.0,17.0],[0.0,0.0,0.0,17.0]]:
        check(not model.capture(DOCUMENT,pair[0],pair[1],pair[2],pair[3]).ok,"malformed or out-of-range geometry is not written")
    check(FileAccess.get_file_as_bytes(model.path)==bytes,"rejected measurements preserve original preference bytes")
    check(not STORE.valid_record({"fingerprint":"a".repeat(64),"offset":true,"maximum":50,"width":330,"font":17}),"boolean is not a saved numeric measurement")
    check(not STORE.identity({"key":"x","fingerprint":"invalid"}),"bad content identity cannot become a usable mark")
    var reloaded:=STORE.new();reloaded.configure("native_store_contract")
    check(reloaded.records==model.records,"fresh store instance reads verified records exactly")
    var other:=STORE.new();other.configure("different_slot_contract")
    check(other.path!=model.path and other.records.is_empty(),"different save slots isolate reading marks")
    var failure:=FailingInstall.new();model.persistence=failure
    check(not model.capture(DOCUMENT,250.0,500.0,330.0,17.0).ok,"replacement failure remains a real failed save")
    check(model.has_pending and model.records[DOCUMENT.key].offset==125.0 and FileAccess.get_file_as_bytes(model.path)==bytes,"failed save retains old live and disk mark plus pending candidate")
    check(not model.capture(changed,0.0,0.0,330.0,17.0).ok and not model.remove(DOCUMENT).ok,"new actions cannot silently discard pending candidate")
    failure.fail=false
    check(model.retry().ok and model.records[DOCUMENT.key].offset==250.0 and not model.has_pending,"retry commits the original pending candidate once")
    var external:=STORE.new();external.configure("native_store_contract")
    check(external.capture(DOCUMENT,375.0,500.0,330.0,17.0).ok,"another owner can publish a newer mark")
    var external_bytes:=FileAccess.get_file_as_bytes(model.path)
    check(not model.capture(DOCUMENT,0.0,500.0,330.0,17.0).ok and not model.writable,"stale owner refuses to overwrite external preference changes")
    check(FileAccess.get_file_as_bytes(model.path)==external_bytes,"new owner bytes remain exact after stale save")
    model.configure("native_store_contract",true)
    check(model.writable and model.records[DOCUMENT.key].offset==375.0,"explicit reload adopts newer file without applying it to reading UI")
    var interleaved:=InterleavingInstall.new();interleaved.concurrent=ConfigFile.new()
    interleaved.concurrent.set_value("marks","version",1)
    var concurrent_records:=model.records.duplicate(true);concurrent_records[DOCUMENT.key].offset=400.0
    interleaved.concurrent.set_value("marks","records",concurrent_records)
    model.persistence=interleaved
    check(not model.capture(DOCUMENT,50.0,500.0,330.0,17.0).ok,"change after preflight is refused inside the existing transaction lock")
    var after_race:=STORE.new();after_race.configure("native_store_contract")
    check(after_race.records[DOCUMENT.key].offset==400.0,"atomic rollback retains concurrently installed newer bytes rather than old or candidate bytes")
    check(not FileAccess.file_exists(model.path+".preference-backup"),"guarded refusal restores displaced original without leaving ambiguous backup")
    model.configure("native_store_contract",true);model.persistence=preload("res://scripts/settings_persistence.gd").new()
    check(model.remove(DOCUMENT).ok and model.records.is_empty(),"explicit removal only changes reading mark store")
    check(not model.retry().ok,"no pending candidate does not report success on retry")
    var broken:=FileAccess.open(model.path,FileAccess.WRITE);broken.store_string("broken config");broken.close()
    var broken_bytes:=FileAccess.get_file_as_bytes(model.path)
    model.configure("native_store_contract",true)
    check(not model.writable and not model.capture(DOCUMENT,0.0,0.0,330.0,17.0).ok,"damaged stored file blocks writes instead of overwriting evidence")
    check(FileAccess.get_file_as_bytes(model.path)==broken_bytes,"damaged preference bytes remain untouched")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(model.path))
    model.configure("capacity_contract")
    var record:={"fingerprint":"a".repeat(64),"offset":0.0,"maximum":0.0,"width":330.0,"font":17.0}
    for index in STORE.LIMIT:model.records["key%d" % index]=record.duplicate()
    check(not model.capture(DOCUMENT,0.0,0.0,330.0,17.0).ok and model.records.size()==STORE.LIMIT,"capacity limit rejects new mark without evicting saved identities")
    check(model.position({"key":"key0","fingerprint":"a".repeat(64)},100.0,400.0,26.0).offset==0.0,"non-scrolling old body has stable normalized origin")
    for store in [model,reloaded,external,other]:
        if FileAccess.file_exists(store.path):DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
    done("JOURNAL_MARKS")
