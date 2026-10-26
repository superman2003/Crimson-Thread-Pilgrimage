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
    var journal:=preload("res://scripts/enemy_journal.gd")
    var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_field_notes.json"))
    var entries: Dictionary=journal._entries()
    check(raw.entries.size()==entries.size() and entries.size()==46,"all 46 existing enemies covered")
    check(journal.records({}).is_empty(),"no unseen enemy revealed")
    var seen: Dictionary={}
    for note in raw.entries:
        check(entries.has(note.enemy_id) and not seen.has(note.enemy_id),"authored key valid and unique")
        seen[note.enemy_id]=true
        var flag:=journal.flag_for(note.enemy_id)
        var flags:={flag:true};var before:=flags.duplicate(true)
        var rows:=journal.records(flags)
        check(rows.size()==1 and rows[0].description.contains(note.review),"only defeated enemy receives its authored review")
        check(rows[0].description.contains("应对思路") and rows[0].description.contains("观察信号"),"existing tactical sections preserved")
        check(flags==before,"review does not alter defeat flags")
        check(journal.records({flag:1}).is_empty(),"numeric truth cannot reveal a creature")
    var rows:=journal.records({journal.flag_for("moss_larva"):true})
    rows[0].description="changed"
    check(journal.records({journal.flag_for("moss_larva"):true})[0].description!="changed","public record mutation cannot poison notes")
    print("UPGRADE_G05 checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
