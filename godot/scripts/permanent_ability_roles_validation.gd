extends SceneTree
const ROLES:=preload("res://scripts/permanent_ability_roles.gd")
const GUIDE:=preload("res://scripts/field_guide.gd")
const UI:=preload("res://scripts/pilgrimage_interface.gd")
const NARRATIVE:=preload("res://scripts/world_narrative.gd")
var checks:=0
var failures:=0

class Runtime extends Node:
    var world_mode:=true
    var world_save_path:="user://ability_roles_test.json"
    var world_narrative:=NARRATIVE.new()
    var inventory_counts: Dictionary={}
    var story_flags: Dictionary={}
    var player: Node
    var currency_count:=0
    var backpack_entry_ids: Array[String]=[]
    var backpack_selection:=-1

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(message)
func controls() -> Dictionary:
    return {"jump":"CustomJump","dash":"CustomDash","move_left":"CustomLeft","move_right":"CustomRight","aim_up":"CustomUp","aim_down":"CustomDown","attack":"CustomAttack","hook":"CustomHook","bell_guard":"CustomGuard","lantern_phase":"CustomPhase","crown_resonance":"CustomResonance"}
func run() -> void:
    catalogue_checks()
    earned_controls_checks()
    await production_journal_checks()
    await pending_reader_lifecycle_checks()
    print("PERMANENT_ABILITY_ROLES checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func catalogue_checks() -> void:
    var data:=ROLES.catalog()
    check(ROLES.valid(data),"authored role catalogue is valid and covers the project's actual permanent abilities")
    check(data.abilities.bell_guard.kind=="combat" and data.abilities.thorn_downstrike.kind=="combat","guard and downstrike are combat techniques, with terrain interaction described separately")
    check(data.abilities.crown_resonance.kind=="ritual" and data.abilities.lantern_phase.kind=="exploration","resonance and phase describe their distinct actual facility roles")
    data.abilities.bell_guard.kind="exploration"
    check(ROLES.catalog().abilities.bell_guard.kind=="combat","returned catalogue cannot mutate cached authored semantics")
    for value in [null,{},[],true,{"version":true,"kinds":ROLES.KINDS,"abilities":{}}]:
        check(not ROLES.valid(value),"invalid display catalogue cannot be used to classify abilities")
    var malformed:=ROLES.catalog()
    malformed.abilities.erase("bell_guard")
    check(not ROLES.valid(malformed),"an omitted authored ability is detected before display release")
    malformed=ROLES.catalog()
    malformed.abilities.bell_guard.equipment_required=true
    check(not ROLES.valid(malformed),"permanent acquisition cannot be mislabeled as removable equipment")
    check(ROLES.select([{"record_kind":"quest"},{"record_kind":"guide"}],"ability").is_empty(),"ordinary handbooks and quests do not masquerade as permanent ability notes")

func earned_controls_checks() -> void:
    check(GUIDE.ability_records({},controls()).is_empty(),"new journey reveals no unearned ability names")
    for id in ROLES.IDS:
        for value in [null,true,false,"1",[],{},-1,0,0.5,NAN,INF,1000001]:
            var inventory:={id:value}
            var original:=inventory.duplicate(true)
            check(GUIDE.ability_records(inventory,controls()).is_empty(),"malformed or absent ownership cannot reveal "+id)
            # NaN cannot be compared with itself; serializing proves no changes.
            check(var_to_str(inventory)==var_to_str(original),"reading does not normalize or grant inventory")
        for count in [1,1.0,3]:
            var records:=GUIDE.ability_records({id:count},controls())
            check(records.size()==1 and ROLES.is_ability(records[0]),"earned permanent ability is tagged exactly once: "+id)
            check(records[0].id=="field_ability_"+id and records[0].record_kind=="guide","existing document identity stays stable across the new category")
            check(records[0].description.contains("永久取得，无需装备铭饰"),"readable note distinguishes ownership from classified loadout slots")
            check(not String(records[0].description).contains("{dash}") and not String(records[0].description).contains("{jump}"),"annotating roles keeps all current control placeholders expanded")
            for other in ROLES.IDS:
                if other!=id:check(not records[0].description.contains(String(ROLES.catalog().abilities[other].title)),"an earned note does not list an unearned ability: "+other)
    var inventory: Dictionary={}
    for id in ROLES.IDS:inventory[id]=1
    var records:=GUIDE.ability_records(inventory,controls())
    check(records.size()==8,"all existing blueprint abilities remain present without changing game mechanics")
    var labels: Dictionary={}
    for entry in records:
        labels[entry.ability_id]=ROLES.label(entry)
        check(not ROLES.label(entry).is_empty(),"every earned entry has an authored classification")
        check(entry.description.contains(String(entry.ability_role)),"role is readable and searchable in the existing plain-text document")
    check(labels.bell_guard=="战斗技巧" and labels.echo_hook=="移动探索" and labels.crown_resonance=="共鸣仪式","three classifications are distinct in public records")
    var full:=GUIDE.records({},controls(),false,inventory)
    check(ROLES.select(full,"ability").size()==8,"ability filter includes only owned ability notes and excludes the four general manuals")
    check(ROLES.select(full,"guide").size()==full.size(),"existing handbook filter retains the ability notes for compatibility")
    check(ROLES.select(full,"all")==full,"all-documents filter preserves original order and contents")
    check(ROLES.select(full,"enemy").is_empty(),"new semantics do not contaminate unrelated journal filters")
    var one:=records[0].duplicate(true)
    one.permanent=1
    check(not ROLES.is_ability(one),"numeric pseudo-booleans cannot forge permanent metadata")
    one=records[0].duplicate(true)
    one.ability_kind="ritual"
    check(not ROLES.is_ability(one),"mismatched categories cannot reclassify an existing ability")
    check(GUIDE.ability_records({"bell_guard":1},controls())[0].description.contains("CustomGuard"),"combat note retains current remapped guard control")
    check(GUIDE.ability_records({"echo_hook":1},controls())[0].description.contains("CustomHook"),"exploration note retains current remapped grapple control")
    check(GUIDE.ability_records({"crown_resonance":1},controls())[0].description.contains("CustomResonance"),"ritual note retains current remapped resonance control")

func production_journal_checks() -> void:
    var world:=Runtime.new()
    root.add_child(world)
    world.player=Node.new()
    world.add_child(world.player)
    var ui:=UI.new()
    root.add_child(ui)
    ui.level=world
    ui.journal_preferences_path="user://ability_roles_preferences.json"
    ui._build_bag()
    ui.bag_category="旅记"
    ui.bag.show()
    var integration:=preload("res://scripts/journal_records_validation.gd")
    check(integration.filters_match(ui.journal_filter_buttons),"the exact ten-key full-World regression also accepts the actual native bag")
    var wrong:=ui.journal_filter_buttons.duplicate()
    wrong.erase("guide")
    wrong.extra=ui.journal_filter_buttons.ability
    check(not integration.filters_match(wrong),"same filter count cannot hide a lost original category or an unexpected replacement")
    wrong=ui.journal_filter_buttons.duplicate()
    wrong.guide=true
    check(not integration.filters_match(wrong),"the full-World filter contract requires actual buttons, not placeholder keys")
    ui.journal_filter_buttons.ability.pressed.emit()
    await process_frame
    check(ui.journal_filter=="ability" and ui.journal_documents.is_empty(),"actual new journal filter opens an empty, spoiler-safe view on a fresh journey")
    check(ui.bag_description.text.contains("实际取得") and not ui.bag_description.text.contains("王冠共鸣"),"empty state describes earned acquisition without future ability spoilers")
    world.inventory_counts={"bell_guard":1,"echo_hook":1}
    ui.refresh_inventory()
    await process_frame
    check(ui.journal_documents.size()==2 and ui.bag_grid.get_child_count()==2,"actual production journal lists only two earned permanent abilities")
    var text:=""
    for button in ui.bag_grid.get_children():text+=button.text
    check(text.contains("战斗技巧") and text.contains("移动探索") and not text.contains("王冠共鸣"),"production list shows classifications while withholding unearned names")
    ui.journal_search.text="共鸣仪式"
    ui.refresh_inventory()
    await process_frame
    check(ui.bag_grid.get_child_count()==0,"category search cannot reveal unearned ritual ability")
    ui.journal_search.text="战斗技巧"
    ui.refresh_inventory()
    await process_frame
    check(ui.bag_grid.get_child_count()==1 and ui.bag_name.text=="钟壳格挡","known category is searchable through actual journal document filtering")
    check(ui.bag_category_label.text=="永久能力 · 战斗技巧","selected detail exposes the same role as the list")
    ui.journal_search.text=""
    ui.refresh_inventory()
    await process_frame
    var former_selection: int=ui.journal_selection
    ui.move_inventory_selection(1)
    check(ui.journal_selection==wrapi(former_selection+1,0,2),"existing controller/keyboard selection still traverses the filtered rows")
    world.inventory_counts={"crown_resonance":1}
    ui.refresh_inventory()
    await process_frame
    check(ui.journal_documents.size()==1 and ui.bag_description.text.contains("共鸣仪式") and ui.journal_selection==0,"slot or inventory changes replace stale ability rows and clamp selection")
    check(world.story_flags.is_empty() and world.inventory_counts=={"crown_resonance":1},"reading categories never sets quest flags or grants additional inventory")
    ui.bag.hide()
    ui.free()
    world.free()
    await process_frame
    if FileAccess.file_exists("user://ability_roles_preferences.json"):DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ability_roles_preferences.json"))

func pending_reader_lifecycle_checks() -> void:
    var old_controls: Array[WeakRef]=[]
    for index in 40:
        var ui:=UI.new()
        root.add_child(ui)
        old_controls.append(weakref(ui))
        ui._restore_journal_scroll("record","text",50,ui.reading_session_generation)
        ui._restore_journal_scroll("record","text",50,ui.reading_session_generation)
        ui._restore_dialogue_scroll("line",50)
        ui._restore_dialogue_scroll("line",50)
        ui.call_deferred("_restore_journal_scroll","record","text",50,ui.reading_session_generation)
        if index%2==0:ui.free()
        else:ui.queue_free()
    await process_frame
    await process_frame
    await process_frame
    for reference in old_controls:check(reference.get_ref()==null,"pending read callbacks retain no destroyed or queued HUD")
    var remaining:=0
    for connection in process_frame.get_connections():
        var callback: Callable=connection.callable
        if callback.get_method() in ["_apply_journal_scroll","_apply_dialogue_scroll"]:remaining+=1
    check(remaining==0,"one-shot reading callbacks leave no process-frame connections after HUD destruction")

    var reader:=UI.new()
    root.add_child(reader)
    reader.bag=ColorRect.new()
    reader.add_child(reader.bag)
    reader.bag_description=RichTextLabel.new()
    reader.bag_description.size=Vector2(300,100)
    reader.bag_description.text="Readable line\n".repeat(100)
    reader.bag.add_child(reader.bag_description)
    reader.journal_reading_key="same"
    reader.journal_reading_text=reader.bag_description.text
    await process_frame
    await process_frame
    var bar: VScrollBar=reader.bag_description.get_v_scroll_bar()
    check(bar.max_value-bar.page>200,"multiple-request fixture has a real scrollable document")
    reader._restore_journal_scroll("same",reader.bag_description.text,70,0)
    reader._restore_journal_scroll("same",reader.bag_description.text,70,0)
    reader._restore_journal_scroll("same",reader.bag_description.text,100,0)
    await process_frame
    await process_frame
    check(is_equal_approx(bar.value,100),"pending requests are replaced by the latest offset rather than retaining an obsolete one")
    reader.free()
    await process_frame
