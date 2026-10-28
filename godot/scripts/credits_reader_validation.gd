extends SceneTree
const CATALOG:=preload("res://scripts/credits_catalog.gd")
const DESK:=preload("res://scripts/credits_reader.gd")
var checks:=0
var failures:=0
class Shell extends Control:
    var accessibility:={"subtitle_size":26}
    var settings:=Control.new()
    func _ready() -> void:
        add_child(settings)
        var title:=Label.new();title.name="InscriptionSubtitle";title.size=Vector2(310,28);settings.add_child(title)
    func _button(parent: Node,text: String,point: Vector2,dimensions: Vector2,callback: Callable) -> Button:
        var button:=Button.new();button.text=text;button.position=point;button.size=dimensions
        parent.add_child(button);button.pressed.connect(callback);return button
    func register_text_entry_window(_window: Window) -> void:pass
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func run() -> void:
    var catalog:=CATALOG.new()
    check(catalog.load_catalog() and catalog.entries.size()>=2,"actual packaged catalog loads")
    var original:=catalog.entries.duplicate(true)
    var first: Dictionary=original[0]
    var doc:=catalog.document(first.id)
    check(doc.ok and not String(doc.text).is_empty(),"actual notice bytes match recorded digest")
    doc.entry.title="mutated"
    check(catalog.entries[0].title==first.title,"document metadata cannot mutate future reads")
    var rows:=catalog.select("")
    rows[0].title="mutated"
    check(catalog.entries[0].title==first.title,"search rows are detached")
    check(catalog.select(String(first.source).to_upper()).any(func(row):return row.id==first.id),"source search is case insensitive")
    check(catalog.select("no-such-component-823").is_empty(),"unknown query is empty without exposing unrelated files")
    check(catalog.select("", "not-a-category").is_empty(),"unknown category does not become all categories")
    check(catalog.groups().has("项目说明"),"categories derive from real entries")
    var data:={"version":1,"entries":original}
    for bad in [null,{}, {"version":true,"entries":original},{"version":2,"entries":original},{"version":1,"entries":[]},{"version":1,"entries":original,"extra":true}]:
        check(not catalog.restore(bad) and catalog.entries.is_empty(),"malformed index fails closed")
    for field in ["id","sha256","title","source","group","file","bytes"]:
        var entry:=first.duplicate(true);entry.erase(field)
        check(not CATALOG.valid_entry(entry),"required field cannot be omitted")
    for source in ["../LICENSE","/etc/passwd","a/../LICENSE","a\\LICENSE","user://save.json","a/./LICENSE","bad\nsource"]:
        var entry:=first.duplicate(true);entry.source=source
        check(not CATALOG.valid_entry(entry),"source labels cannot encode hidden paths")
    for count in [true,0,-1,1.5,INF,NAN,262145]:
        var entry:=first.duplicate(true);entry.bytes=count
        check(not CATALOG.valid_entry(entry),"document count bounds remain strict")
    var duplicate:=original.duplicate(true);duplicate.append(first)
    check(not catalog.restore({"version":1,"entries":duplicate}) and catalog.entries.is_empty(),"duplicate identity rejects the whole catalog")
    duplicate=original.duplicate(true);var other:=first.duplicate(true);other.id="aaaaaaaaaaaa";other.file="res://data/credits/aaaaaaaaaaaa.txt";duplicate.append(other)
    check(not catalog.restore({"version":1,"entries":duplicate}),"duplicate provenance rejected even with distinct identity")
    catalog.restore(data)
    check(not catalog.document("missing").ok,"unknown selection cannot read another resource")
    var broken:=first.duplicate(true);broken.bytes=int(first.bytes)+1
    catalog.restore({"version":1,"entries":[broken]})
    check(not catalog.document(first.id).ok,"length mismatch does not display partial text")
    broken=first.duplicate(true);broken.sha256="0".repeat(64)
    catalog.restore({"version":1,"entries":[broken]})
    check(not catalog.document(first.id).ok,"digest mismatch cannot display altered text")
    broken=first.duplicate(true);broken.id="eeeeeeeeeeee";broken.file="res://data/credits/eeeeeeeeeeee.txt"
    catalog.restore({"version":1,"entries":[broken]})
    check(not catalog.document(broken.id).ok,"missing packaged source is an explicit error")
    var shell:=Shell.new();root.add_child(shell);shell.size=Vector2(1280,720)
    DESK.install(shell);DESK.install(shell)
    check(shell.get_child_count()==2,"repeated reader installation owns one component")
    var reader=shell.get_node("CreditsReader")
    check(shell.settings.get_node("InscriptionSubtitle").size.x==200,"settings title leaves a distinct focusable source entry")
    check(reader.launcher.position==Vector2(420,20) and reader.launcher.size==Vector2(160,32),"source entry avoids y60 audio and x600 motion controls")
    reader.launcher.pressed.emit();await process_frame
    check(reader.window.visible and reader.search.has_focus(),"real launcher opens native reader with search focus")
    check(reader.reader.get_theme_font_size("normal_font_size")==26,"reader follows current subtitle size")
    check(not reader.reader.bbcode_enabled and reader.reader.selection_enabled,"licenses remain literal selectable text")
    check(reader.rows.size()==original.size() and not reader.reader.text.is_empty(),"native list immediately displays a verified document")
    reader.bottom();reader.top()
    check(reader.reader.has_focus(),"document navigation is keyboard focusable")
    reader.search.text="no-such-component-823";reader.search.text_changed.emit(reader.search.text);await process_frame
    check(reader.rows.is_empty() and reader.selected.is_empty() and reader.reader.text.contains("没有符合"),"empty search clears stale text")
    reader.clear_search();await process_frame
    check(reader.rows.size()==original.size() and reader.search.has_focus(),"clear restores complete bounded list")
    reader.show_document(-1);reader.show_document(9999)
    check(not reader.reader.text.is_empty(),"stale indices are ignored safely")
    shell.settings.hide();await process_frame
    check(not reader.window.visible and reader.reader.text.is_empty(),"parent settings hide retires displayed text")
    reader.open();check(not reader.window.visible,"hidden settings cannot reopen reader")
    shell.settings.show();reader.open();await process_frame
    check(reader.rows.size()==original.size() and reader.selected==first.id,"reopen restores deterministic first source")
    shell.free();await process_frame
    print("CREDITS_READER checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
