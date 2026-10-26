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
    var history:=preload("res://scripts/scene_history.gd")
    var entries:=history.all_entries()
    var notes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/scene_craft_notes.json"))
    check(notes.entries.size()==6,"six regional craft readings authored")
    check(history.records({}).is_empty(),"unread objects remain private")
    var seen: Dictionary={}
    for note in notes.entries:
        check(not seen.has(note.history_id),"craft identity unique");seen[note.history_id]=true
        var matched:=false
        for entry in entries:
            if entry.id!=note.history_id:continue
            matched=true
            check(entry.role=="daily" and not entry.has("evidence_id"),"only daily objects enriched")
            check(entry.text.contains(note.detail) and entry.text.contains(note.question),"full detail and reflection reach actual entry")
            var flags:={history.FLAG_PREFIX+note.history_id:true}
            var before:=flags.duplicate(true);var rows:=history.records(flags)
            check(rows.size()==1 and rows[0].text.contains("近看工艺"),"journal integrates one discovered note")
            check(flags==before,"reading leaves world flags alone")
        check(matched,"note references an existing prop")
    for entry in entries:
        if entry.has("evidence_id"):check(not entry.text.contains("近看工艺"),"witness prose is preserved")
    entries[0].text="changed"
    check(history.all_entries()[0].text!="changed","entry snapshots detached")
    print("UPGRADE_G06 checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
