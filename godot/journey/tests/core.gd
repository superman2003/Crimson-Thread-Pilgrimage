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
    for field in ["last_region", "last_room"]:
        var missing := MODEL.fresh()
        missing.erase(field)
        check(not MODEL.valid(missing), "chronicle rejects missing observation state: " + field)
        missing[field] = 123
        check(not MODEL.valid(missing), "chronicle rejects non-string observation state: " + field)
    check(not context.store.export_text("empty.svg", "").ok, "empty export fails instead of publishing a successful zero-byte document")
    await lifecycle_checks()
    finish()

class RegionShell extends Control:
    var settings: Control
    func _init() -> void:
        settings = Control.new()
        add_child(settings)
    func _button(parent: Node, _title: String, _at: Vector2, _size: Vector2, action: Callable) -> Button:
        var button := Button.new()
        button.pressed.connect(action)
        parent.add_child(button)
        return button

class RegionHost extends Node:
    var initial_region_ready := true
    var ui_shell: Control
    var world_save_path := "user://lifecycle.json"
    var active_overlay := "settings"
    var world_loading := false

func lifecycle_checks() -> void:
    var host := RegionHost.new()
    root.add_child(host)
    host.ui_shell = RegionShell.new()
    host.add_child(host.ui_shell)
    var desk := preload("res://journey/workbench.gd").new()
    root.add_child(desk)
    desk.owner_ref = weakref(host)
    desk.bind_region_ui(host)
    check(is_instance_valid(desk.entry) and desk.context == null, "HUD completion installs the entry before the first observation tick")
    desk.context = CONTEXT.new()
    desk.context.store.configure(host.world_save_path)
    var retained := preload("res://journey/core/feature.gd").new()
    retained.data = {"draft":"keep"}
    desk.features = {"test":retained}
    desk.bind_region_ui(host)
    var context_id: int = desk.context.get_instance_id()
    check(is_instance_valid(desk.entry), "initial region has workbench entry")
    host.ui_shell.free()
    host.ui_shell = RegionShell.new()
    host.add_child(host.ui_shell)
    desk.bind_region_ui(host)
    check(is_instance_valid(desk.entry) and desk.entry.get_parent()==host.ui_shell.settings, "region publication regains entry without waiting for another frame")
    check(desk.context.get_instance_id()==context_id and desk.features.test==retained and retained.data.draft=="keep", "UI reattachment preserves feature state and pending draft")
    var original_entry: int = desk.entry.get_instance_id()
    host.active_overlay = ""
    host.world_loading = true
    desk._process(0.01)
    check(desk.entry.visible, "settings parent owns entry visibility between observation ticks")
    desk.bind_region_ui(host)
    check(desk.entry.get_instance_id()==original_entry, "repeated HUD completion cannot install duplicate entries")
    desk._process(0.2)
    check(desk.entry.get_instance_id()==original_entry, "stable region does not repeatedly install entries")
    host.ui_shell.free()
    host.ui_shell = RegionShell.new()
    host.add_child(host.ui_shell)
    desk._process(0.01)
    check(is_instance_valid(desk.entry) and desk.entry.get_parent()==host.ui_shell.settings, "per-frame fallback still rebinds externally replaced UI below the observation interval")
    desk.free()
    host.free()
    await process_frame
