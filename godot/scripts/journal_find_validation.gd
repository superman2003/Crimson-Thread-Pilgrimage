extends SceneTree
const FIND:=preload("res://scripts/journal_literal_find.gd")
const DIALOG:=preload("res://scripts/journal_find_dialog.gd")
var checks:=0
var failures:=0
class Level extends Node:
    var world_save_path:="user://find_component_world.json"
class Shell extends Control:
    var bag: Control
    var bag_category:="旅记"
    var journal_tools: HBoxContainer
    var journal_current_document: Dictionary={}
    var bag_description: RichTextLabel
    var reading_session_generation:=1
    var accessibility:={"subtitle_size":26}
    var level:=Level.new()
    var registrations:=0
    func register_text_entry_window(_window: Window) -> void:registrations+=1
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func frames() -> void:
    for unused in 3:await process_frame
func query(dialog: Window,value: String) -> void:
    dialog.query.text=value;dialog.query.text_changed.emit(value)
func run() -> void:
    root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
    var source:="引言\r\n针线 Needle 😀needle\r尾声针线"
    var result:=FIND.search(source,"针线")
    check(result.ok and result.matches.size()==2 and not result.limited,"literal Chinese matches search this body only")
    check(result.text=="引言\n针线 Needle 😀needle\n尾声针线","CRLF and CR normalize to native plain-text editor lines")
    check(result.matches[0].line==1 and result.matches[0].column==0 and result.matches[1].line==2 and result.matches[1].column==2,"original Unicode codepoint positions map to normalized line and column")
    check(FIND.search(source,"needle").matches.size()==2 and FIND.search(source,"needle",true).matches.size()==1,"optional case sensitivity has separate literal semantics")
    var emoji: Dictionary=FIND.search(source,"😀needle",true).matches[0]
    check(emoji.end-emoji.start==7 and emoji.column==10,"emoji does not shift following native selection by UTF-16 units")
    var overlap:=FIND.search("aaaa","aa")
    check(overlap.matches.size()==3 and overlap.matches[2].start==2,"overlapping matches advance safely and remain individually selectable")
    check(FIND.search("literal -word [a] .*","[a]").matches.size()==1 and FIND.search("plain",".*").matches.is_empty(),"query has no regex or cross-record exclusion syntax")
    var multiline:=FIND.search("a\nb\nc","a\nb")
    check(multiline.matches[0].line==0 and multiline.matches[0].end_line==1 and multiline.matches[0].end_column==1,"multiline literal has valid exclusive end coordinates")
    check(FIND.search("","").ok and FIND.search("a","missing").matches.is_empty(),"empty and unmatched query are usable states")
    check(not FIND.search("x".repeat(FIND.MAX_TEXT+1),"x").ok,"overlong source is rejected without pretending a truncated scan is complete")
    check(not FIND.search("small","x".repeat(FIND.MAX_QUERY+1)).ok,"query bounds reject rather than silently alter requested literal")
    var limited:=FIND.search("x".repeat(FIND.MAX_MATCHES+3),"x")
    check(limited.matches.size()==FIND.MAX_MATCHES and limited.limited and limited.reason.contains("至少"),"bounded result list reports an explicit lower-bound count")
    check(FIND.navigate(0,-1,1)==-1 and FIND.navigate(3,-1,1)==0 and FIND.navigate(3,-1,-1)==2,"first direction chooses nearest end and empty navigation is inert")
    check(FIND.navigate(3,2,1)==0 and FIND.navigate(3,0,-1)==2 and FIND.navigate(3,999999,1)==0,"both directions wrap and invalid selection cannot overflow")
    var ui:=Shell.new();root.add_child(ui);ui.add_child(ui.level)
    ui.bag=Control.new();ui.add_child(ui.bag)
    ui.journal_tools=HBoxContainer.new();ui.bag.add_child(ui.journal_tools)
    ui.bag_description=RichTextLabel.new();ui.bag_description.custom_minimum_size=Vector2(330,160);ui.bag.add_child(ui.bag_description)
    ui.bag_description.text=source
    ui.journal_current_document={"key":"guide:known","title":"已公开记录","text":source,"fingerprint":source.sha256_text()}
    var source_before:=ui.bag_description.text
    DIALOG.install(ui);DIALOG.install(ui)
    var dialog: Window=ui.bag.get_node("JournalDocumentFind")
    check(ui.registrations==1 and ui.journal_tools.get_child_count()==1,"repeated install creates one owned native window and launcher")
    dialog.launcher.pressed.emit();await frames()
    check(dialog.visible and dialog.query.has_focus() and not dialog.editor.editable,"real native dialog opens read-only with query focus")
    check(dialog.editor.get_theme_font_size("font_size")==26,"reader follows current bounded reading preference")
    check(dialog.size.x<=1280 and dialog.size.y<=720,"normal native game viewport encloses complete read-only find window")
    query(dialog,"needle");await frames()
    check(dialog.report.matches.size()==2 and dialog.editor.get_selected_text()=="Needle","actual TextEdit selects original-cased first occurrence")
    dialog.next.pressed.emit();await frames()
    check(dialog.editor.get_selected_text()=="needle" and dialog.selected==1,"next action selects actual second occurrence without source mutation")
    dialog.next.pressed.emit();check(dialog.selected==0,"native next wraps to first match")
    dialog.previous.pressed.emit();check(dialog.selected==1,"native previous wraps to last match")
    dialog.case_button.button_pressed=true;dialog.case_button.toggled.emit(true);await frames()
    check(dialog.report.matches.size()==1 and dialog.editor.get_selected_text()=="needle","case toggle rebuilds actual selected matches")
    query(dialog,"not present");check(dialog.next.disabled and dialog.previous.disabled and dialog.editor.get_selected_text().is_empty(),"no matches clears stale selection and disables navigation")
    query(dialog,"针线");await frames()
    check(dialog.editor.get_selected_text()=="针线" and dialog.query.has_focus(),"Unicode selection does not steal typing focus")
    check(ui.bag_description.text==source_before,"finding and selecting never rewrites original rich text")
    ui.reading_session_generation+=1;dialog.next.pressed.emit();await frames()
    check(not dialog.visible and dialog.source.is_empty() and dialog.editor.text.is_empty(),"expired reading generation closes and clears captured content")
    dialog.open();await frames();ui.journal_current_document={};dialog.refresh_launcher();await frames()
    check(dialog.launcher.disabled and not dialog.visible,"empty or filtered selection cannot keep a stale body open")
    ui.journal_current_document={"key":"guide:known","title":"known","text":source,"fingerprint":source.sha256_text()};dialog.refresh_launcher();dialog.open();await frames()
    ui.bag.hide();await frames()
    check(not dialog.visible and dialog.launcher.disabled,"closing parent tools hides and retires nested reader")
    ui.queue_free();await frames()
    check(not is_instance_valid(dialog),"retiring owner frees native reader without retained source references")
    print("JOURNAL_FIND checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
