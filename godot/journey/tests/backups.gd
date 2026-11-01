extends "res://journey/tests/support.gd"
const ARCHIVE := preload("res://journey/backups/archive.gd")
const WORLD := preload("res://scripts/world_state.gd")
func run() -> void:
    label = "BACKUPS"
    var context := fixture("backups")
    var world := WORLD.new()
    check(world.capture_global({"current_region":REGION, "currency":71}), "fixture prepares valid formal world")
    check(world.capture_region(REGION, {"visited_rooms":{"a":true,"b":false},"boss_defeated":true}), "fixture records true and false visits")
    var primary := String(context.latest.save_path)
    check(world.write(primary), "actual primary fixture written")
    var original := FileAccess.get_file_as_bytes(primary)
    check(context.store.write("chronicle", {"version":1, "events":[]}), "auxiliary source fixture written")
    var archive := ARCHIVE.new()
    archive.directory = context.store.directory.path_join("bundles")
    var quote := archive.quote(context.store, primary)
    check(quote.ok and quote.sources.size() == 2, "quote finds primary and same-slot auxiliary")
    var bundle := archive.build(context.store, primary, "验证导出", String(quote.fingerprint))
    check(bundle.ok and bundle.payload.primary.summary.rooms == 1, "bundle validates actual world and true visit counts")
    var decoded := archive.decode(String(bundle.raw))
    check(decoded.ok and archive.component(decoded, "chronicle").version == 1, "bundle and component hashes roundtrip")
    check(FileAccess.get_file_as_bytes(primary) == original, "building and decoding never write primary")
    var corrupt: Dictionary = JSON.parse_string(bundle.raw)
    corrupt.sha256 = "0".repeat(64)
    check(not archive.decode(JSON.stringify(corrupt)).ok, "whole payload tampering rejected")
    check(not ARCHIVE.utf8_valid(PackedByteArray([192,128])), "overlong UTF8 rejected before engine decode")
    check(ARCHIVE.utf8_valid("绯线巡礼".to_utf8_buffer()), "Chinese UTF8 remains valid")
    var install := archive.install(bundle)
    check(install.ok and archive.open(String(install.path)).ok, "verified archive installs and opens from owned directory")
    check(not archive.open(primary).ok, "archive browser cannot treat arbitrary path as owned bundle")
    check(not archive.remove(String(install.path), "stale").ok, "delete requires current identity")
    var stale := archive.quote(context.store, primary)
    context.store.write("chronicle", {"version":1, "events":[{"changed":true}]})
    check(not archive.build(context.store, primary, "过期", String(stale.fingerprint)).ok, "changed source invalidates quote")
    archive.writable = false
    check(not archive.install(bundle).ok, "write failure does not report installed bundle")
    archive.writable = true
    check(archive.remove(String(install.path), String(install.sha256)).ok, "verified deletion affects only exported bundle")
    var feature := preload("res://journey/features/backups.gd").new()
    feature.setup(context)
    feature.archive.directory = archive.directory
    for tab in ["create", "browse", "import"]:
        var box := node_container()
        feature.tab = tab
        feature.draw(box)
        await process_frame
        check(box.get_child_count() > 2, "backup tab renders: " + tab)
        box.free()
    check(FileAccess.get_file_as_bytes(primary) == original, "all backup UI leaves current game bytes intact")

    var payload: Dictionary = bundle.payload.duplicate(true)
    payload.created = []
    var encoded := JSON.stringify(payload)
    var malformed := JSON.stringify({"format":"pilgrimage_journey_bundle","version":1,"sha256":encoded.sha256_text(),"payload":encoded})
    check(not archive.decode(malformed).ok, "checksum-valid bundle still rejects malformed metadata")
    for i in 17:
        context.store.write("extra_%d" % i, {"version":1})
    check(archive.sources(context.store, "user://missing_primary_for_bundle.json").is_empty(), "auxiliary limit applies even with no primary save")
    finish()
