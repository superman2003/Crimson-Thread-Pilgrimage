extends SceneTree
const MODEL:=preload("res://scripts/achievements.gd")
const PROGRESS:=preload("res://scripts/journey_progress.gd")
const ABILITIES:=preload("res://scripts/permanent_ability_roles.gd")
const NOTICE:=preload("res://scripts/achievement_notice.gd")
const CARD:=preload("res://scripts/title_card.gd")
var checks:=0
var failures:=0
class World extends Node:
    var audio_director:=Node.new()
    var new_journey_dialog:=ConfirmationDialog.new()
    var active_overlay:=""
    func _ready() -> void:add_child(audio_director);add_child(new_journey_dialog)
    func _sync_ui_input_lock() -> void:pass
class Shell extends Control:
    var settings:=Control.new()
    func _ready() -> void:add_child(settings)
    func _button(parent: Node,text: String,point: Vector2,dimensions: Vector2,callback: Callable) -> Button:
        var button:=Button.new();button.text=text;button.position=point;button.size=dimensions
        parent.add_child(button);button.pressed.connect(callback);return button
    func register_text_entry_window(_window: Window) -> void:pass
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func journey(abilities: int,bosses: int,room_share: float,pickup_share: float,endings: Array=[]) -> Dictionary:
    var totals:=PROGRESS.totals()
    var data:={"inventory_counts":{},"regions":{},"story_flags":{}}
    for index in abilities:data.inventory_counts[ABILITIES.IDS[index]]=1
    for letter in endings:data.story_flags["ending_%s_done" % letter]=true
    var order:=totals.keys();order.sort()
    for index in order.size():
        var known: Dictionary=totals[order[index]]
        var region:={"visited_rooms":{},"collected_ids":{},"boss_defeated":index<bosses}
        for position in int(ceil(known.rooms.size()*room_share)):region.visited_rooms[known.rooms[position]]=true
        for position in int(ceil(known.pickups.size()*pickup_share)):region.collected_ids[known.pickups[position]]=true
        data.regions[order[index]]=region
    return data
func fresh_record() -> RefCounted:
    var record:=MODEL.new();record.store.configure("achievements","installation")
    if FileAccess.file_exists(record.store.path):DirAccess.remove_absolute(ProjectSettings.globalize_path(record.store.path))
    return MODEL.new()
func run() -> void:
    var ids:={}
    for entry in MODEL.LIST:
        check(not ids.has(entry.id) and not String(entry.name).is_empty() and String(entry.name).length()<=6 and not String(entry.goal).is_empty(),"achievement is unique, named briefly and explained: "+String(entry.id))
        ids[entry.id]=true
    check(MODEL.earned({}).is_empty() and MODEL.earned(journey(0,0,0.0,0.0)).is_empty(),"a new journey has earned nothing")
    check(MODEL.earned(journey(1,0,0.0,0.0))==["first_ability"],"first ability")
    check(MODEL.earned(journey(0,1,0.0,0.0))==["first_gatekeeper"],"first gatekeeper")
    var most:=MODEL.earned(journey(8,6,0.5,0.5))
    for id in ["first_ability","all_abilities","first_gatekeeper","all_gatekeepers","wanderer","gleaner"]:check(most.has(id),"half-explored full-power journey earns "+id)
    for id in ["cartographer","completionist","ending_a","all_endings"]:check(not most.has(id),"…but not "+id)
    var two:=MODEL.earned(journey(0,0,0.0,0.0,["a","c"]))
    check(two.has("ending_a") and two.has("ending_c") and not two.has("ending_b") and not two.has("all_endings"),"two endings are two achievements, not the set")
    var everything:=MODEL.earned(journey(8,6,1.0,1.0,["a","b","c"]))
    check(everything.size()==MODEL.LIST.size(),"a complete journey earns every achievement")
    var wrong:=journey(0,0,0.0,0.0);wrong.story_flags["ending_a_done"]="yes";wrong.story_flags["ending_d_done"]=true
    check(MODEL.earned(wrong).is_empty(),"wrong types and unknown endings earn nothing")
    # The record: announced once, kept across journeys, never rewritten when unreadable.
    var record:=fresh_record()
    check(record.sync(journey(0,0,0.0,0.0),100).is_empty() and not FileAccess.file_exists(record.store.path),"nothing earned writes nothing")
    check(record.sync(journey(1,1,0.0,0.0),200)==["第一缕线","叩开钟门"],"new achievements are announced in list order")
    check(record.sync(journey(1,1,0.0,0.0),300).is_empty(),"…and only once")
    var later:=MODEL.new()
    check(later.sync(journey(0,0,0.0,0.0),400).is_empty() and later.unlocked.get("first_ability")==200,"a new journey keeps what was earned, with its time")
    check(later.sync(journey(8,1,0.0,0.0),500)==["八线俱全"],"only the new one is announced later")
    var earned_rows:=0
    for row in later.rows():
        if row.earned:earned_rows+=1
    check(later.rows().size()==MODEL.LIST.size() and earned_rows==3,"the list shows every achievement and which are earned")
    var failing:=MODEL.new();failing.load();failing.store.writer=func(_data: Dictionary):return ERR_FILE_CANT_WRITE
    check(failing.sync(journey(8,6,0.0,0.0),600).is_empty() and not failing.unlocked.has("all_gatekeepers"),"an unsaved achievement is not announced, so it is not lost")
    var file:=FileAccess.open(later.store.path,FileAccess.WRITE);file.store_string('{"version":1,"payload":{"first_ability":200,"made_up":1}}');file.close()
    var damaged:=MODEL.new()
    check(damaged.sync(journey(8,6,1.0,1.0),700).is_empty() and FileAccess.get_file_as_string(later.store.path).contains("made_up"),"an unreadable record is left alone")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(later.store.path))
    # Notice: own label, replaces itself, removes itself.
    var host:=Node.new();root.add_child(host)
    NOTICE.show_on(host,[]);check(host.get_child_count()==0,"no names, no notice")
    NOTICE.show_on(host,["第一缕线","叩开钟门"]);await process_frame
    var notice:=host.get_node("AchievementNotice")
    check(notice.label.text=="成就 · 第一缕线 · 叩开钟门","names are shown briefly")
    NOTICE.show_on(host,["八线俱全"]);await process_frame
    check(host.get_child_count()==1 and notice.label.text=="成就 · 八线俱全","a later notice reuses the banner")
    notice.left=0.01;await create_timer(0.2).timeout;await process_frame
    check(not is_instance_valid(notice) or notice.is_queued_for_deletion(),"the banner removes itself")
    host.queue_free()
    # Settings page: the same list, opened from the launcher row.
    var shell:=Shell.new();root.add_child(shell);await process_frame
    var difficulty:=Button.new();difficulty.name="DifficultyButton";shell.settings.add_child(difficulty)
    var desk:=preload("res://scripts/achievements_dialog.gd").new();desk.name="AchievementsDesk";shell.add_child(desk);desk.setup(shell)
    var launcher:=shell.settings.get_node_or_null("AchievementsButton") as Button
    check(launcher!=null and launcher.text=="成就" and not is_instance_valid(desk.window),"settings launcher present; window built on first open")
    check(launcher.get_node(launcher.focus_neighbor_right)==difficulty and difficulty.get_node(difficulty.focus_neighbor_left)==launcher,"launcher joins the d-pad chain before difficulty")
    var record3:=fresh_record();record3.sync(journey(1,1,0.0,0.0),900)
    launcher.pressed.emit();await process_frame
    check(desk.window.visible and desk.list.item_count==MODEL.LIST.size(),"the settings window lists every achievement")
    check(desk.list.get_item_text(0).begins_with("● ") and desk.list.get_item_text(2).begins_with("● ") and desk.list.is_item_disabled(1),"settings list shows what is earned")
    shell.settings.visible=false;await process_frame
    check(not desk.window.visible,"the window closes with the settings page")
    shell.queue_free();await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(record3.store.path))
    # Title card lists them without releasing the held world.
    var record2:=fresh_record();record2.sync(journey(1,0,0.0,0.0),800)
    var level:=World.new();root.add_child(level);await process_frame
    var card: Node=CARD.open(level,true);await process_frame
    check(card.buttons.keys()==["continue","new","achievements","quit"],"title card offers the achievement list")
    card.buttons["achievements"].pressed.emit();await process_frame
    var window:=card.get_node_or_null("Achievements") as AcceptDialog
    var list:=window.get_node("List") as ItemList if window!=null else null
    check(window!=null and window.visible and paused and is_instance_valid(card),"the list opens over the card; the world stays held")
    check(list!=null and list.item_count==MODEL.LIST.size() and list.get_item_text(0).begins_with("● 第一缕线") and list.get_item_text(1).begins_with("○ ") and list.is_item_disabled(1),"earned and unearned entries are told apart")
    window.hide();card.choose("continue");await process_frame
    check(not paused,"continuing still releases the world")
    CARD.shown=false
    DirAccess.remove_absolute(ProjectSettings.globalize_path(record2.store.path))
    level.queue_free();await process_frame
    print("ACHIEVEMENTS checks=%d failures=%d" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
