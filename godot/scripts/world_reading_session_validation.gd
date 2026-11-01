extends SceneTree
const SESSION := preload("res://scripts/world_reading_session.gd")
const JOURNAL := preload("res://scripts/journal_reading.gd")
const DIALOGUE := preload("res://scripts/dialogue_reading_memory.gd")
const UI := preload("res://scripts/pilgrimage_interface.gd")
var checks := 0
var failures := 0

class Host extends Node:
    var world_save_path := "user://slot-one.json"
    var world_mode := true

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func run() -> void:
    schema_checks()
    isolation_checks()
    bounded_checks()
    await ui_checks()
    await deferred_and_teardown_checks()
    print("WORLD_READING_SESSION checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func schema_checks() -> void:
    var path := "user://slot-one.json"
    check(SESSION.valid(SESSION.fresh(path),path), "fresh World reading session has exact reader types")
    for value in [null, true, 1, [], "invalid", {}, {"version":1}]:
        check(not SESSION.valid(value,path), "malformed metadata cannot impersonate a session")
    for value in [true, 1.0, "1", 0, 2, null]:
        var candidate := SESSION.fresh(path)
        candidate.version=value
        check(not SESSION.valid(candidate,path), "version type/value is strict")
    var wrong := SESSION.fresh(path)
    wrong.scope="different"
    check(not SESSION.valid(wrong,path), "wrong slot identity invalidates cache")
    for value in [null, true, 1, [], {}, RefCounted.new(), DIALOGUE.new()]:
        var candidate := SESSION.fresh(path)
        candidate.journal=value
        check(not SESSION.valid(candidate,path), "journal reader cannot be replaced with another object")
    for value in [null, true, 1, [], {}, RefCounted.new(), JOURNAL.new()]:
        var candidate := SESSION.fresh(path)
        candidate.dialogue=value
        check(not SESSION.valid(candidate,path), "dialogue reader cannot be replaced with another object")
    check(SESSION.valid(SESSION.acquire(null,path),path), "missing host receives detached valid readers")
    var host := Host.new()
    root.add_child(host)
    host.set_meta(SESSION.KEY,{"scope":"bad"})
    check(SESSION.valid(SESSION.acquire(host,path),path), "corrupted owned metadata is safely replaced")
    host.free()

func isolation_checks() -> void:
    var host := Host.new()
    root.add_child(host)
    var first := SESSION.acquire(host,host.world_save_path)
    first.journal.capture("quest:main","原正文",150)
    first.dialogue.capture("npc:line",100,40,90,false)
    var second := SESSION.acquire(host,host.world_save_path)
    check(first.journal==second.journal and first.dialogue==second.dialogue, "same World and slot share exact bounded reader objects")
    check(is_equal_approx(second.journal.resume("quest:main","原正文"),150), "replacement HUD can restore journal offset")
    check(second.dialogue.restore("npc:line").characters==40, "replacement HUD can restore unfinished dialogue reveal")
    first.scope="spoofed"
    first.version=99
    first.journal=JOURNAL.new()
    var protected := SESSION.acquire(host,host.world_save_path)
    check(SESSION.valid(protected,host.world_save_path) and protected.journal==second.journal, "returned wrapper cannot replace host metadata or reader ownership")
    var other := Host.new()
    root.add_child(other)
    var detached := SESSION.acquire(other,other.world_save_path)
    check(detached.journal!=protected.journal and detached.journal.bookmarks.is_empty(), "same file path in another World cannot inherit reading positions")
    host.world_save_path="user://slot-two.json"
    var slot_two := SESSION.acquire(host,host.world_save_path)
    check(slot_two.journal.bookmarks.is_empty() and slot_two.dialogue.restore("npc:line").is_empty(), "switching slots clears both types of reading state")
    check(slot_two.journal!=protected.journal, "slot switching never reuses another slot's reader object")
    host.world_save_path="user://slot-one.json"
    check(SESSION.acquire(host,host.world_save_path).journal.bookmarks.is_empty(), "returning to a retired slot starts a fresh session rather than reviving stale text offsets")
    var active := SESSION.acquire(host,host.world_save_path)
    active.journal.capture("quest:main","原正文",100)
    active.dialogue.capture("npc:line",10,5,30,false)
    SESSION.clear(host)
    check(active.journal.bookmarks.is_empty() and active.dialogue.restore("npc:line").is_empty(), "explicit retirement also clears readers still referenced by an old HUD")
    check(not host.has_meta(SESSION.KEY), "retirement removes only the owned metadata cache")
    host.set_meta("other_system",123)
    SESSION.clear(host)
    check(host.get_meta("other_system")==123, "retirement leaves other system metadata intact")
    host.free()
    other.free()

func bounded_checks() -> void:
    var host := Host.new()
    root.add_child(host)
    var bundle := SESSION.acquire(host,host.world_save_path)
    var journal: RefCounted=bundle.journal
    var dialogue: RefCounted=bundle.dialogue
    for index in 80:
        var key:="key:"+str(index)
        journal.capture(key,"不会保存这段正文"+str(index),float(index*10))
        dialogue.capture(key,100,index,index*2,false)
        check(journal.bookmarks.size()<=JOURNAL.LIMIT, "shared journal cache remains bounded during long tours")
        check(dialogue._entries.size()<=DIALOGUE.MAX_BOOKMARKS, "shared dialogue cache remains bounded during long tours")
    check(journal.resume("key:0","不会保存这段正文0")==0, "oldest journal entry remains evicted")
    check(dialogue.restore("key:0").is_empty(), "oldest dialogue entry remains evicted")
    for record in journal.bookmarks.values():
        check(record.keys().size()==2 and record.has("fingerprint") and record.has("scroll"), "retained journal records store no source text or scene objects")
    for record in dialogue._entries.values():
        check(record.keys().size()==3 and record.has("characters") and record.has("progress") and record.has("scroll"), "retained dialogue records store only reading numbers")
    journal.capture("changed","first",400)
    check(journal.resume("changed","second")==0, "content fingerprint mismatch retires stale position across HUD rebuilds")
    dialogue.capture("committed",10,10,100,true)
    check(dialogue.restore("committed").is_empty(), "completed/committed dialogue never acquires a replay bookmark")
    host.free()

func make_ui(host: Node) -> Control:
    var ui := UI.new()
    root.add_child(ui)
    ui.level=host
    ui._sync_reading_session()
    return ui

func ui_checks() -> void:
    var host := Host.new()
    root.add_child(host)
    var first := make_ui(host)
    first.journal_reading.capture("record","正文",175)
    first.dialogue_reading.capture("line",50,20,30,false)
    var readers := SESSION.acquire(host,host.world_save_path)
    var old: WeakRef = weakref(first)
    first.free()
    check(old.get_ref()==null, "host metadata does not keep the old HUD alive")
    var second := make_ui(host)
    check(second.journal_reading==readers.journal and second.dialogue_reading==readers.dialogue, "actual replacement UI binds the shared reader objects")
    check(is_equal_approx(second.journal_reading.resume("record","正文"),175), "actual replacement UI restores existing journal state")
    check(second.dialogue_reading.restore("line").characters==20, "actual replacement UI restores existing dialogue state")
    var generation: int=second.reading_session_generation
    second._sync_reading_session()
    check(second.reading_session_generation==generation, "unchanged frame polling does not allocate or rebind readers")
    host.world_save_path="user://different-slot.json"
    second.journal_reading_key="old"
    second.dialogue_reading_key="old-line"
    second.journal_restore_pending=true
    second._sync_reading_session()
    check(second.reading_session_generation==generation+1, "slot change invalidates old asynchronous restore generation")
    check(second.journal_reading_key.is_empty() and second.dialogue_reading_key.is_empty() and not second.journal_restore_pending, "slot change clears stale keys before deferred restore")
    check(second.journal_reading.resume("record","正文")==0, "actual UI does not transfer an offset into another slot")
    var next_host := Host.new()
    next_host.world_save_path=host.world_save_path
    root.add_child(next_host)
    second.journal_reading.capture("record","正文",200)
    second.level=next_host
    second._sync_reading_session()
    check(second.journal_reading.resume("record","正文")==0, "rebinding UI to a different World with same path cannot leak bookmarks")
    second.free()
    host.free()
    next_host.free()
    await process_frame

func reading_controls(ui: Control) -> void:
    ui.bag=ColorRect.new()
    ui.bag.size=Vector2(400,240)
    ui.add_child(ui.bag)
    ui.bag_description=RichTextLabel.new()
    ui.bag_description.size=Vector2(350,160)
    ui.bag_description.text="Long journal line\n".repeat(200)
    ui.bag.add_child(ui.bag_description)
    ui.dialogue=ColorRect.new()
    ui.dialogue.position=Vector2(420,0)
    ui.dialogue.size=Vector2(400,240)
    ui.add_child(ui.dialogue)
    ui.dialogue_scroll=ScrollContainer.new()
    ui.dialogue_scroll.size=Vector2(350,160)
    ui.dialogue.add_child(ui.dialogue_scroll)
    ui.dialogue_body=Label.new()
    ui.dialogue_body.custom_minimum_size=Vector2(300,4000)
    ui.dialogue_body.text="Long subtitle line\n".repeat(200)
    ui.dialogue_body.visible_characters=40
    ui.dialogue_scroll.add_child(ui.dialogue_body)
    ui.dialogue_area=Area2D.new()
    ui.dialogue_area.set_meta("world_line_committed",false)
    ui.dialogue_area.set_meta("world_displayed_index",0)
    ui.add_child(ui.dialogue_area)

func deferred_and_teardown_checks() -> void:
    var host := Host.new()
    root.add_child(host)
    var ui := make_ui(host)
    reading_controls(ui)
    await process_frame
    await process_frame
    var bar: VScrollBar=ui.bag_description.get_v_scroll_bar()
    check(bar.max_value-bar.page>300, "journal fixture has real scrollable content before race assertions")
    check(ui.dialogue_scroll.get_v_scroll_bar().max_value-ui.dialogue_scroll.get_v_scroll_bar().page>300, "subtitle fixture has real scrollable content before race assertions")
    ui.journal_reading_key="same"
    ui.journal_reading_text=ui.bag_description.text
    ui.dialogue_reading_key="same-line"
    ui._restore_journal_scroll("same",ui.bag_description.text,150,ui.reading_session_generation)
    ui._restore_dialogue_scroll("same-line",150)
    await process_frame
    await process_frame
    check(is_equal_approx(bar.value,150), "current generation journal restore applies the saved offset")
    check(ui.dialogue_scroll.scroll_vertical==150, "current generation subtitle restore applies the saved offset")
    # Schedule both real callbacks, then switch the slot before their awaited frame.
    # Keys and text deliberately match again; only generation can reject stale work.
    ui._restore_journal_scroll("same",ui.bag_description.text,250,ui.reading_session_generation)
    ui._restore_dialogue_scroll("same-line",250)
    host.world_save_path="user://replacement.json"
    ui._sync_reading_session()
    ui.journal_reading_key="same"
    ui.journal_reading_text=ui.bag_description.text
    ui.dialogue_reading_key="same-line"
    bar.value=37
    ui.dialogue_scroll.scroll_vertical=43
    await process_frame
    await process_frame
    check(is_equal_approx(bar.value,37), "stale journal callback cannot scroll matching text in a replacement slot")
    check(ui.dialogue_scroll.scroll_vertical==43, "stale subtitle callback cannot scroll a matching line in a replacement slot")
    # A call_deferred invocation can itself start after a slot change. The explicit
    # captured generation must survive that extra event-loop boundary as well.
    var prior_generation: int=ui.reading_session_generation
    ui.call_deferred("_restore_journal_scroll","same",ui.bag_description.text,275,prior_generation)
    host.world_save_path="user://third.json"
    ui._sync_reading_session()
    ui.journal_reading_key="same"
    ui.journal_reading_text=ui.bag_description.text
    ui.dialogue_reading_key="same-line"
    bar.value=59
    await process_frame
    await process_frame
    await process_frame
    check(is_equal_approx(bar.value,59), "deferred journal invocation preserves the original session generation")
    ui.journal_restore_pending=false
    ui.dialogue_body.visible_characters=40
    var body: String=ui.bag_description.text
    var readers:=SESSION.acquire(host,host.world_save_path)
    ui.free()
    check(is_equal_approx(readers.journal.resume("same",body),59), "actual HUD teardown captures the current journal offset")
    check(readers.dialogue.restore("same-line").get("characters",-1)==40, "actual HUD teardown captures unfinished subtitle progress")
    check(readers.dialogue.restore("same-line").get("scroll",-1)==43, "actual HUD teardown captures subtitle scrolling")
    var replacement:=make_ui(host)
    check(replacement.journal_reading==readers.journal and replacement.dialogue_reading==readers.dialogue, "rebuilt HUD receives teardown bookmarks without retaining prior controls")
    reading_controls(replacement)
    replacement.dialogue_reading_key="same-line"
    replacement.dialogue_area.set_meta("world_line_committed",true)
    replacement.close_dialogue()
    check(readers.dialogue.restore("same-line").is_empty(), "committed line is erased by the normal close path rather than replayed")
    replacement.free()
    host.free()
    await process_frame
