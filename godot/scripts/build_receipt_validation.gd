extends SceneTree
const INSPECT:=preload("res://scripts/build_receipt_inspector.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func settle(model: RefCounted) -> bool:
    var budget_ok:=true
    for unused in 4096:
        if not model.working:break
        var previous: int=model.bytes_read;model.tick()
        budget_ok=budget_ok and model.bytes_read-previous<=INSPECT.CHUNK*INSPECT.BLOCKS_PER_TICK
    return budget_ok and not model.working
func write_manifest(path: String, value: Dictionary) -> void:
    var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func run() -> void:
    var root_path:=OS.get_environment("CRIMSON_RECEIPT_FIXTURE")
    check(not root_path.is_empty(),"runner supplies actual build_release.package_directory fixture")
    if root_path.is_empty():quit(1);return
    var path:=root_path.path_join(INSPECT.MANIFEST)
    var manifest_bytes:=FileAccess.get_file_as_bytes(path)
    var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var model:=INSPECT.new()
    check(model.load_manifest(root_path),"production inspector reads actual release-packager manifest")
    check(not model.report().passed and not model.report().complete,"reading metadata never implies file verification success")
    check(model.start(),"explicit verification can begin")
    model.tick();check(model.working,"bounded tick cannot synchronously consume the entire large-file fixture")
    check(settle(model),"every tick stays within declared byte budget and completes")
    var report:=model.report()
    check(report.passed and report.matches==original.files.size(),"actual package payload matches actual generated hashes")
    check(FileAccess.get_file_as_bytes(path)==manifest_bytes,"verification does not rewrite manifest bytes")
    var detached:=model.report();detached.files.clear();detached.metadata.clear()
    check(model.report().passed and not model.metadata.is_empty(),"report consumers cannot mutate owned verification state")
    check(model.summary().contains(original.source_commit) and not model.summary().contains(root_path),"copyable summary includes source identity without absolute local path")
    check(model.start(),"completed scan can be explicitly restarted")
    model.tick();model.cancel()
    check(not model.working and model.cancelled and not model.report().passed and not model.complete,"cancelled partial scan never reports a complete pass")
    check(model.start() and settle(model) and model.report().passed,"fresh restart clears cancelled partial state")
    var binary_path:=root_path.path_join("game.bin")
    var binary:=FileAccess.get_file_as_bytes(binary_path)
    var changed:=binary.duplicate();changed[0]=int(changed[0])^1
    var file:=FileAccess.open(binary_path,FileAccess.WRITE);file.store_buffer(changed);file.close()
    model.start();settle(model)
    check(model.complete and not model.report().passed,"same-size changed file is detected by actual SHA256")
    var mismatch:=false
    for row in model.report().files:
        if row.path=="game.bin":mismatch=row.status=="摘要不符"
    check(mismatch,"digest mismatch is distinguished from missing or size mismatch")
    file=FileAccess.open(binary_path,FileAccess.WRITE);file.store_string("short");file.close()
    model.start();settle(model);var wrong_size:=false
    for row in model.report().files:
        if row.path=="game.bin":wrong_size=row.status=="大小不符"
    check(wrong_size and not model.report().passed,"length mismatch is rejected without hashing invented content")
    DirAccess.remove_absolute(binary_path);model.start();settle(model)
    check(not model.report().passed,"missing payload cannot become an empty matching file")
    file=FileAccess.open(binary_path,FileAccess.WRITE);file.store_buffer(binary);file.close()
    check(model.load_manifest(root_path) and model.start(),"fixture restores valid original source")
    model.tick()
    var newer:=original.duplicate(true);newer.qualification="changed while reading";write_manifest(path,newer)
    settle(model)
    check(not model.report().passed and not model.complete and model.error.contains("变化"),"manifest replacement during scan invalidates otherwise matching results")
    check(not model.start(),"old loaded manifest cannot be silently reused after replacement")
    check(model.load_manifest(root_path) and model.start() and settle(model) and model.report().passed,"explicit reload accepts a fresh valid package declaration")
    for relative in ["../secret","/absolute","C:/outside","nested/../secret","nested//bad","nested\\bad",INSPECT.MANIFEST,""]:
        check(not INSPECT.relative_path(relative),"manifest entries remain bounded relative payload paths")
    for record in [{"bytes":true,"sha256":"a".repeat(64)},{"bytes":-1,"sha256":"a".repeat(64)},{"bytes":1.5,"sha256":"a".repeat(64)},{"bytes":1,"sha256":"bad"}]:
        check(not INSPECT.file_record(record),"bad sizes or identities cannot enter verifier queue")
    var bad:=original.duplicate(true);bad.schema_version=true
    check(not INSPECT.valid_manifest(bad),"boolean schema is not numeric version one")
    bad=original.duplicate(true);bad.files={}
    check(not INSPECT.valid_manifest(bad),"empty manifest cannot vacuously pass")
    bad=original.duplicate(true);bad.source_dirty=1
    check(not INSPECT.valid_manifest(bad),"dirty flag retains strict boolean type")
    var original_copy:=original.duplicate(true)
    check(INSPECT.valid_manifest(original) and original==original_copy,"schema validation does not mutate caller data")
    file=FileAccess.open(path,FileAccess.WRITE);file.store_string("broken json");file.close()
    var broken_bytes:=FileAccess.get_file_as_bytes(path)
    check(not model.load_manifest(root_path) and not model.start() and not model.report().passed,"malformed declaration has no fallback verification success")
    check(FileAccess.get_file_as_bytes(path)==broken_bytes,"broken declaration remains untouched for diagnosis")
    file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(manifest_bytes);file.close()
    var absent:=INSPECT.new()
    check(not absent.load_manifest(root_path.path_join("not_a_package")) and not absent.report().passed,"development or missing-package path has explicit unavailable state")
    print("BUILD_RECEIPT checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
