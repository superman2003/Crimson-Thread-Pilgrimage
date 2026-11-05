extends SceneTree
const STATE := preload("res://scripts/world_state.gd")
const JOB := preload("res://scripts/world_save_backup_job.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const REGION := "demo_ch01_moss_bell_court"
const PREFIX := "world_save_backup_validation_"
var checks := 0
var failures := 0
var records: Array = []
var cancelled_target_unpublished := false

class HeldJob:
    extends "res://scripts/world_save_backup_job.gd"
    var gate := Semaphore.new()
    var hold_next := true
    func _prepare_backup(source: String, pending_path: String, expected: String) -> Dictionary:
        if hold_next:
            hold_next = false
            gate.wait()
        return super._prepare_backup(source,pending_path,expected)

class CorruptCopy:
    extends "res://scripts/world_save_backup_job.gd"
    func _copy_source(source: String, pending_path: String) -> Error:
        var status := super._copy_source(source,pending_path)
        if status == OK:
            var file := FileAccess.open(pending_path,FileAccess.WRITE)
            file.store_string("{corrupt copied backup")
            file.close()
        return status

class HeldCopy:
    extends "res://scripts/world_save_backup_job.gd"
    var copied := Semaphore.new()
    var gate := Semaphore.new()
    func _copy_source(source: String, pending_path: String) -> Error:
        var status := super._copy_source(source,pending_path)
        copied.post()
        gate.wait()
        return status

class HeldInstall:
    extends "res://scripts/world_save_backup_job.gd"
    var entered := Semaphore.new()
    var gate := Semaphore.new()
    func _rename_backup(pending_path: String, backup_path: String) -> Error:
        entered.post()
        gate.wait()
        return super._rename_backup(pending_path,backup_path)

class UnavailableInstall:
    extends "res://scripts/world_state.gd"
    var install_attempts := 0
    func _install_candidate(_temporary: String, _absolute: String) -> Error:
        install_attempts += 1
        return ERR_CANT_CREATE

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func write_text(path: String, text: String) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(text)
    file.close()

func make_checkpoint_fixture(name: String) -> Dictionary:
    var path := "user://"+PREFIX+name+".json"
    var state := STATE.new()
    check(state.capture_global({"current_region":REGION,"entry":Vector2(300,420),"currency":100}), "seed global snapshot is valid")
    check(state.capture_region(REGION,STATE.fresh_region()) and state.write(path), "seed installs a valid primary")
    return {"state":state,"path":path}

func wait_job(job: RefCounted) -> Dictionary:
    var issued: String = job._pending_path
    var deadline := Time.get_ticks_msec()+5000
    while job.busy() and Time.get_ticks_msec() < deadline: await process_frame
    check(not job.busy(), "owned backup finishes within fixture deadline")
    var result: Dictionary = job.take() if not job.busy() else {}
    check(issued.is_empty() or not FileAccess.file_exists(issued), "owned private backup files retire after completion or rejection")
    return result

func ordinary_and_faults() -> void:
    var fixture := make_checkpoint_fixture("ordinary")
    var state: RefCounted = fixture.state
    var path: String = fixture.path
    var original := FileAccess.get_file_as_bytes(path)
    var digest: String = state.backup_source_hash(path)
    check(digest.length() == 64 and state._source_hashes.is_empty(), "writer validation proof does not acquire a reader lease")
    var job := JOB.new()
    check(job.begin(path,digest) and not job.begin(path,digest), "one owned worker refuses overlapping requests")
    var result := await wait_job(job)
    check(bool(result.get("ok",false)) and not bool(result.get("worker_is_main",true)), "verified source copy runs off the main thread")
    check(bool(result.get("copied",false)) and bool(result.get("installed",false)), "a missing backup is actually copied and installed")
    check(FileAccess.get_file_as_bytes(path) == original and FileAccess.get_file_as_bytes(path+".bak") == original,
        "warming leaves the primary untouched and preserves exact source backup bytes")
    check(state._source_hashes.is_empty(), "backup maintenance cannot upgrade writer-only authority")
    records.append(result)
    # A real obstruction proves the normal writer reuses the identical verified
    # backup, rather than silently performing another backup copy/rename.
    check(DirAccess.make_dir_absolute(path+".bak.pending") == OK, "fixture obstructs only the legacy backup copy path")
    var candidate: Dictionary = state.data.duplicate(true)
    candidate.currency = 200
    check(state.write_candidate(candidate,path), "target write reuses the verified backup despite an obstructed duplicate-copy path")
    check(FileAccess.get_file_as_bytes(path+".bak") == original and JSON.parse_string(FileAccess.get_file_as_string(path)).currency == 200,
        "target installation retains the exact prior source backup")
    DirAccess.remove_absolute(path+".bak.pending")
    var second := FileAccess.get_file_as_bytes(path)
    write_text(path+".bak","{damaged backup")
    candidate.currency = 300
    check(state.write_candidate(candidate,path) and FileAccess.get_file_as_bytes(path+".bak") == second,
        "a changed backup forces the original verified-copy fallback")
    var good_backup := FileAccess.get_file_as_bytes(path+".bak")
    write_text(path,"{damaged primary")
    check(state.backup_source_hash(path).is_empty() and not job.begin(path,""), "damaged source bytes cannot authorize a backup worker")
    check(not state.write_candidate(candidate,path) and FileAccess.get_file_as_string(path) == "{damaged primary"
        and FileAccess.get_file_as_bytes(path+".bak") == good_backup, "failed primary validation preserves corrupt evidence and the good backup")
    check(state.restore_backup(path), "failed writes release the mutex and explicit recovery still works")
    job.shutdown()
    check(job.closed and not job.pending() and not job.begin(path,digest), "shutdown retires ownership and refuses new work")

func corruption_and_stale_sources() -> void:
    var fixture := make_checkpoint_fixture("copied_corruption")
    var state: RefCounted = fixture.state
    var path: String = fixture.path
    write_text(path+".bak","older backup evidence")
    var old_backup := FileAccess.get_file_as_bytes(path+".bak")
    var primary := FileAccess.get_file_as_bytes(path)
    var corrupt := CorruptCopy.new()
    check(corrupt.begin(path,state.backup_source_hash(path)), "corrupted-copy fixture enters the actual worker")
    var bad := await wait_job(corrupt)
    check(not bool(bad.get("ok",true)) and String(bad.get("reason","")) == "copied bytes changed",
        "copied-byte corruption is rejected before backup installation")
    check(FileAccess.get_file_as_bytes(path) == primary and FileAccess.get_file_as_bytes(path+".bak") == old_backup,
        "corrupt private copies cannot change either public file")
    corrupt.shutdown()
    fixture = make_checkpoint_fixture("stale_reader")
    state = fixture.state
    path = fixture.path
    var reader := STATE.new()
    check(reader.read(path), "stale-reader fixture acquires the normal source lease")
    var held := HeldJob.new()
    check(held.begin(path,reader.backup_source_hash(path)), "held worker owns a validated original source")
    var candidate: Dictionary = state.data.duplicate(true)
    candidate.currency = 150
    check(state.write_candidate(candidate,path), "another writer can install a newer valid primary")
    candidate.currency = 200
    check(state.write_candidate(candidate,path), "another writer can advance twice while source copying is held")
    var latest := FileAccess.get_file_as_bytes(path)
    var previous := FileAccess.get_file_as_bytes(path+".bak")
    held.gate.post()
    var stale := await wait_job(held)
    check(not bool(stale.get("ok",true)), "stale source work refuses to overwrite the newer backup")
    check(FileAccess.get_file_as_bytes(path) == latest and FileAccess.get_file_as_bytes(path+".bak") == previous,
        "two newer generations survive stale backup completion")
    check(reader.backup_source_hash(path).is_empty() and not reader.write_candidate(candidate,path),
        "stale reader authority remains rejected after background work")
    check(FileAccess.get_file_as_bytes(path) == latest and FileAccess.get_file_as_bytes(path+".bak") == previous,
        "rejected stale writes preserve both newer files")
    held.shutdown()

func bounded_proofs_and_links() -> void:
    var state := STATE.new()
    for index in 18:
        check(state.write("user://"+PREFIX+"bounded_%d.json" % index), "bounded proof fixture persists a valid source")
    check(state._verified_hashes.size() <= 16 and state._source_hashes.is_empty(), "validation proofs stay bounded without creating reader leases")
    check(state.backup_source_hash("user://"+PREFIX+"bounded_0.json").is_empty()
        and not state.backup_source_hash("user://"+PREFIX+"bounded_17.json").is_empty(), "evicted proof falls back while a current proof remains usable")
    state.reset()
    check(state._verified_hashes.is_empty() and state._source_hashes.is_empty(), "reset drops source proof and authority together")
    if OS.get_name() != "Windows":
        var fixture := make_checkpoint_fixture("linked_backup")
        state = fixture.state
        var path: String = fixture.path
        var directory := DirAccess.open("user://")
        check(directory.create_link(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".bak")) == OK,
            "POSIX fixture creates a link to the primary")
        check(not STATE._backup_matches(path,STATE._file_hash(path)), "a primary-pointing link cannot count as an independent backup")
        var candidate: Dictionary = state.data.duplicate(true)
        candidate.currency = 250
        check(state.write_candidate(candidate,path), "normal persistence replaces the linked backup with a verified independent file")
        check(not directory.is_link(ProjectSettings.globalize_path(path+".bak"))
            and JSON.parse_string(FileAccess.get_file_as_string(path+".bak")).currency == 100, "linked backup retains the old checkpoint after target installation")
    else:
        records.append({"link_fixture":"POSIX CI only; Windows symbolic-link privileges are not changed"})

func copy_race_and_mutex() -> void:
    var fixture := make_checkpoint_fixture("after_copy")
    var state: RefCounted = fixture.state
    var path: String = fixture.path
    var held_copy := HeldCopy.new()
    check(held_copy.begin(path,state.backup_source_hash(path)), "late-source fixture starts a real copy")
    var copied := false
    for unused in 1500:
        copied = held_copy.copied.try_wait()
        if copied or not held_copy.busy(): break
        await process_frame
    check(copied, "late-source fixture pauses after exact source bytes were copied")
    var candidate: Dictionary = state.data.duplicate(true)
    candidate.currency = 150
    check(state.write_candidate(candidate,path), "first newer checkpoint installs while private copying is held")
    candidate.currency = 200
    check(state.write_candidate(candidate,path), "second newer checkpoint installs before source recheck")
    var latest := FileAccess.get_file_as_bytes(path)
    var previous := FileAccess.get_file_as_bytes(path+".bak")
    held_copy.gate.post()
    var result := await wait_job(held_copy)
    check(not bool(result.get("ok",true)) and String(result.get("reason","")) == "source changed after copy",
        "the final source guard rejects a stale but byte-perfect private copy")
    check(FileAccess.get_file_as_bytes(path) == latest and FileAccess.get_file_as_bytes(path+".bak") == previous,
        "late-source rejection retains both newer generations")
    held_copy.shutdown()

    fixture = make_checkpoint_fixture("mutex")
    state = fixture.state
    path = fixture.path
    var installing := HeldInstall.new()
    check(installing.begin(path,state.backup_source_hash(path)), "mutex fixture reaches actual backup installation")
    var entered := false
    for unused in 1500:
        entered = installing.entered.try_wait()
        if entered or not installing.busy(): break
        await process_frame
    check(entered, "mutex fixture holds the real backup rename boundary")
    var acquired := STATE._file_write_mutex.try_lock()
    check(not acquired, "primary writers cannot enter the worker's backup installation boundary")
    if acquired: STATE._file_write_mutex.unlock()
    # Deliberately overlaps the caller with an 80ms held install. A separate
    # releaser prevents the fixture from needing the blocked main thread.
    var releaser := Thread.new()
    check(releaser.start(func():
        OS.delay_msec(80)
        installing.gate.post()) == OK, "fixture owns a bounded install releaser")
    candidate = state.data.duplicate(true)
    candidate.currency = 250
    check(state.write_candidate(candidate,path), "normal primary write waits for the backup critical section")
    candidate.currency = 300
    check(state.write_candidate(candidate,path), "the following primary generation preserves its own predecessor")
    releaser.wait_to_finish()
    result = await wait_job(installing)
    check(bool(result.get("ok",false)) and JSON.parse_string(FileAccess.get_file_as_string(path)).currency == 300
        and JSON.parse_string(FileAccess.get_file_as_string(path+".bak")).currency == 250,
        "late backup completion cannot overwrite a newer primary's previous generation")
    installing.shutdown()

func unchanged_primary() -> void:
    var fixture := make_checkpoint_fixture("unchanged")
    var state: RefCounted = fixture.state
    var path: String = fixture.path
    var job := JOB.new()
    check(job.begin(path,state.backup_source_hash(path)), "unchanged-source fixture establishes the independent backup")
    check(bool((await wait_job(job)).get("ok",false)), "unchanged-source backup is verified")
    job.shutdown()
    var unavailable := UnavailableInstall.new()
    check(unavailable.read(path), "unchanged primary is read through the ordinary validator and lease")
    var primary := FileAccess.get_file_as_bytes(path)
    var backup := FileAccess.get_file_as_bytes(path+".bak")
    check(JSON.stringify(state.data).sha256_text() == STATE._file_hash(path), "unchanged fixture supplies the exact original serialized bytes")
    check(unavailable.write_candidate(state.data.duplicate(true),path) and unavailable.install_attempts == 0,
        "already durable identical bytes need no unavailable primary replacement")
    check(FileAccess.get_file_as_bytes(path) == primary and FileAccess.get_file_as_bytes(path+".bak") == backup
        and not FileAccess.file_exists(path+".tmp"), "identical checkpoint keeps both public files and retires its verified temporary copy")
    var changed: Dictionary = state.data.duplicate(true)
    changed.currency += 1
    check(not unavailable.write_candidate(changed,path) and unavailable.install_attempts == 1,
        "a changed checkpoint still requires a real successful primary installation")
    check(FileAccess.get_file_as_bytes(path) == primary and FileAccess.get_file_as_bytes(path+".bak") == backup,
        "failed changed installation retains the verified primary and predecessor")

func actual_world_cancellation() -> void:
    var world: Node = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://"+PREFIX+"world.json"
    root.add_child(world)
    await READY.wait_for(world)
    current_scene = world
    var source: String = world.config.id
    world.currency_count = 317
    world.story_flags["backup_warm_fixture"] = true
    var captured: bool = world._save_world()
    check(captured,"actual World fixture captures its settled source checkpoint")
    print("BACKUP_FIXTURE_CAPTURE ",JSON.stringify({"captured":captured,"error":world.world_state.last_error,
        "currency":world.currency_count,"saved_currency":world.world_state.data.currency,
        "blocked":world.world_save_blocked,"loading":world.world_loading}))
    var held := HeldJob.new()
    world.world_loader.save_backup_job.shutdown()
    world.world_loader.save_backup_job = held
    var path := ROUTES.config_path("demo_ch02_rain_foundry_canal")
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    world._request_world_travel(path,Vector2(config.player_start[0],config.player_start[1]))
    var backup_removed := false
    for unused in 4000:
        # Model a missing recovery copy after the normal departure checkpoint.
        # This makes source maintenance real work instead of a cache-hit path.
        if world.world_loader.phase == "loading" and not backup_removed:
            DirAccess.remove_absolute(world.world_save_path+".bak")
            backup_removed = true
        if held.started > 0 and held.busy(): break
        await process_frame
    check(held.started == 1 and held.busy() and world.world_loader.phase == "committing", "actual arrival yields while its source-only backup is held")
    var issued: String = held._pending_path
    check(world.process_mode == Node.PROCESS_MODE_DISABLED and not world.ui_shell.can_process(),
        "completed destination UI and gameplay remain disabled until publication")
    var overlay: String = world.active_overlay
    for code in [KEY_B,KEY_V]:
        for pressed in [true,false]:
            var event := InputEventKey.new()
            event.physical_keycode = code
            event.keycode = code
            event.pressed = pressed
            Input.parse_input_event(event)
    await process_frame
    check(world.active_overlay == overlay, "actual build/settings shortcut events cannot open destination UI during backup wait")
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.world_save_path))
    print("BACKUP_FIXTURE_PARTIAL ",JSON.stringify({"live_currency":world.currency_count,"saved_currency":saved.currency,
        "saved_region":saved.current_region,"source":source,"error":world.world_state.last_error}))
    check(String(saved.current_region) == source and saved.currency == 317 and bool(saved.story_flags.get("backup_warm_fixture",false)),
        "backup preparation cannot publish the destination or lose settled source progress")
    world.world_loader.cancel_transition()
    await process_frame
    held.gate.post()
    for unused in 4000:
        if world.world_loader.phase == "idle": break
        await process_frame
    cancelled_target_unpublished = world.world_loader.phase == "idle" and bool(world.world_loader.last_transition.get("rolled_back",false)) and String(world.config.id) == source
    check(cancelled_target_unpublished and world.currency_count == 317 and bool(world.story_flags.get("backup_warm_fixture",false)),
        "cancellation rolls back a complete source without target progress")
    saved = JSON.parse_string(FileAccess.get_file_as_string(world.world_save_path))
    check(String(saved.current_region) == source and not held.pending(), "rollback waits for the owned worker before its source publication")
    check(not FileAccess.file_exists(issued), "cancelled actual source maintenance retires its private file")
    var primary := FileAccess.get_file_as_bytes(world.world_save_path)
    var backup := FileAccess.get_file_as_bytes(world.world_save_path+".bak")
    var before_started := held.started
    world.world_save_blocked = true
    world._request_world_travel(path,Vector2(config.player_start[0],config.player_start[1]))
    for unused in 4000:
        if world.world_loader.phase == "idle": break
        await process_frame
    check(String(world.config.id) == String(config.id) and held.started == before_started,
        "blocked-save travel starts no backup work")
    check(FileAccess.get_file_as_bytes(world.world_save_path) == primary and FileAccess.get_file_as_bytes(world.world_save_path+".bak") == backup,
        "blocked-save travel withholds primary and backup disk writes")
    var loader: RefCounted = world.world_loader
    world.free()
    current_scene = null
    await process_frame
    check(loader.save_backup_job.closed and not loader.save_backup_job.pending(), "whole-host teardown joins and retires its backup owner")
    check(await RETIRE.drain(self), "actual World audio owners retire after backup validation")

func cleanup() -> void:
    var directory := DirAccess.open("user://")
    for name in directory.get_files():
        if String(name).begins_with(PREFIX): DirAccess.remove_absolute("user://"+String(name))

func run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    cleanup()
    await ordinary_and_faults()
    await corruption_and_stale_sources()
    await copy_race_and_mutex()
    await unchanged_primary()
    bounded_proofs_and_links()
    await actual_world_cancellation()
    cleanup()
    print("SAVE_BACKUP METRICS ",JSON.stringify(records))
    print("WORLD_SAVE_BACKUP checks=%d failures=%d cancelled_target_unpublished=%s" % [checks,failures,cancelled_target_unpublished])
    quit(0 if failures == 0 else 1)
