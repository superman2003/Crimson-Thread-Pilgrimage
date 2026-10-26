extends "res://journey/tests/support.gd"
const MODEL := preload("res://journey/chronicle/model.gd")
func run() -> void:
    label = "CORE"
    var context := fixture("core")
    check(not VALUES.count(true) and not VALUES.held(0.5), "integer boundaries reject truth and fractions")
    check(not VALUES.json_safe({"n":NAN}, 0, [100]), "nonfinite values cannot reach JSON storage")
    var original := MODEL.fresh()
    var observed := MODEL.observe(original, context.snapshot())
    check(observed.events.size() == 2 and original.events.is_empty(), "first observation records actual region and room without mutation")
    check(MODEL.observe(observed, context.snapshot()) == observed, "repeated same observation is idempotent")
    context.latest.room = "moss_descent"
    var candidate := MODEL.observe(observed, context.snapshot())
    check(candidate.events.size() == 3, "new room adds one observation")
    check(context.store.write("chronicle", candidate), "auxiliary store writes verified candidate")
    var other := STORE.new()
    other.directory = context.store.directory
    other.configure("user://journey_validation_core.json")
    var reloaded: Dictionary = other.read("chronicle", MODEL.fresh())
    check(MODEL.valid(reloaded) and int(reloaded.sequence) == int(candidate.sequence) and reloaded.events.size() == candidate.events.size() and reloaded.events[-1].title == candidate.events[-1].title, "new reader restores actual disk record")
    var newest := MODEL.append(candidate, "note", "第二实例", context.snapshot())
    check(other.write("chronicle", newest), "second reader may publish its own current lease")
    check(not context.store.write("chronicle", candidate), "old reader cannot overwrite second writer")
    context.store.read("chronicle", MODEL.fresh())
    context.store.writable = false
    var before := FileAccess.get_file_as_bytes(context.store.path_for("chronicle"))
    check(not context.store.write("chronicle", candidate), "injected write failure rejected")
    check(FileAccess.get_file_as_bytes(context.store.path_for("chronicle")) == before, "failed auxiliary write preserves original bytes")
    var bounded := MODEL.fresh()
    for index in MODEL.LIMIT + 5:
        bounded = MODEL.append(bounded, "note", "记录%d" % index, context.snapshot())
    check(bounded.events.size() == MODEL.LIMIT and MODEL.valid(bounded), "history eviction preserves bounded valid data")
    var id := str(int(bounded.events[-1].id))
    var annotated := MODEL.annotate(bounded, id, "归途", true)
    check(MODEL.records(annotated, "归途", "all", true).size() == 1, "notes and favorites participate in search")
    check(not MODEL.document(annotated).is_empty(), "chronicle exports visible observations")
    var feature := preload("res://journey/features/chronicle.gd").new()
    context.store.writable = true
    feature.setup(context)
    var box := node_container()
    feature.draw(box)
    await process_frame
    check(box.get_child_count() > 10, "native chronicle controls are built")
    box.queue_free()
    await process_frame
    check(context.store.write("chronicle", {"version":1}), "schema-invalid fixture reaches auxiliary envelope")
    var malformed := FileAccess.get_file_as_bytes(context.store.path_for("chronicle"))
    feature.setup(context)
    check(not feature.commit(MODEL.fresh()) and FileAccess.get_file_as_bytes(context.store.path_for("chronicle")) == malformed, "invalid module schema blocks replacement of original record")
    var lock: String = context.store.path_for("chronicle") + ".writer_lock"
    check(DirAccess.make_dir_absolute(lock) == OK, "competing writer acquires exclusive record lock")
    var locked_bytes := FileAccess.get_file_as_bytes(context.store.path_for("chronicle"))
    check(not context.store.write("chronicle", MODEL.fresh()), "record publication refuses an already-held writer lock")
    check(FileAccess.get_file_as_bytes(context.store.path_for("chronicle")) == locked_bytes, "contended publication preserves disk bytes")
    DirAccess.remove_absolute(lock)
    var exhausted := MODEL.fresh()
    exhausted.sequence = 1000000
    check(MODEL.append(exhausted, "note", "满", context.snapshot()) == exhausted, "exhausted chronicle sequence cannot publish an invalid event")
    var future := observed.duplicate(true)
    future.events[0].id = int(future.sequence) + 1
    check(not MODEL.valid(future), "event IDs cannot exceed persisted sequence")
    check(not MODEL.document(annotated, "", "all", true).contains(String(annotated.events[0].title)), "favorites-only export excludes unstarred observations")
    finish()
