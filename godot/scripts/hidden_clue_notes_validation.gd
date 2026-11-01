extends RefCounted
const NOTES:=preload("res://scripts/hidden_clue_notes.gd")
const ROUTES:=preload("res://scripts/world_routes.gd")
const ATLAS:=preload("res://scripts/world_atlas.gd")
const JOURNAL:=preload("res://scripts/pilgrimage_cartography.gd")
const INDEX:=preload("res://scripts/map_directory.gd")
const RUNTIME:=preload("res://scripts/map_directory_runtime.gd")
const UI:=preload("res://scripts/map_directory_dialog.gd")
const STATE:=preload("res://scripts/world_state.gd")
static func run(tree: SceneTree,scene: Node) -> void:
    pure(tree)
    await notice(tree,scene)
    await picker(tree,scene)

static func pure(tree: SceneTree) -> void:
    var plan:=ROUTES.cached_hidden_clues()
    tree.check(plan.size()==8 and NOTES.visible(plan,{}).is_empty() and NOTES.journal(plan,{}).is_empty(),"unnoticed catalogue exposes neither future clue titles nor text")
    var flags:={}
    var configs:={}
    for entry in plan:
        var id:=String(entry.id)
        for invalid in [1,0,"true",false,{}]:tree.check(NOTES.journal([entry],{NOTES.SEEN+id:invalid}).is_empty(),"only canonical true noticed flags authorize clue text")
        tree.check(NOTES.journal([entry],{NOTES.FOUND+id:true}).is_empty(),"legacy found state cannot pretend an entrance observation was read")
        flags[NOTES.SEEN+id]=true
        var rows:=NOTES.journal([entry],flags)
        tree.check(rows.size()==1 and rows[0].description.contains(entry.clue.line) and rows[0].title.contains(entry.clue.title),"each of eight actual noticed entrance lines has a readable authored title")
        var public:=JSON.stringify(rows)
        tree.check(not public.contains(String(entry.hidden_room_id)) and not public.contains(String(entry.get("reward_id","not_a_reward"))),"public journal withholds target-room and reward identifiers")
        var map:=NOTES.map_records([entry],{},flags)
        tree.check(map.is_empty(),"a heard line alone cannot authorize a coordinate without known bought paper")
        var data:=ATLAS.configuration(String(entry.region_id))
        configs[String(entry.region_id)]=data
        var point:=Vector2(entry.clue.position[0],entry.clue.position[1])
        var room:=preload("res://scripts/map_player_pins.gd").owner(data,point)
        var journal:=JOURNAL.region(flags,String(entry.region_id))
        journal.owned=true;journal.charted[String(room.id)]=true
        map=NOTES.map_records([entry],configs,flags)
        tree.check(map.size()==1 and map[0].point==point and map[0].clue_state=="noticed","inked actual entrance enables only its exact original clue coordinate")
        tree.check(not JSON.stringify(map).contains(String(entry.hidden_room_id)) and not map[0].has("reward_id"),"map rows do not smuggle hidden destination or reward metadata")
        flags[NOTES.FOUND+id]=true
        tree.check(NOTES.map_records([entry],configs,flags)[0].clue_state=="found" and NOTES.journal([entry],flags)[0].description.contains("已找到"),"actual found flag changes only the known observation's status")
        flags.erase(NOTES.FOUND+id)
    var before:=flags.duplicate(true)
    var original:=plan.duplicate(true)
    var all:=NOTES.map_records(plan,configs,flags)
    tree.check(all.size()==8 and NOTES.journal(plan,flags).size()==8,"all eight independently noticed and charted clues remain distinct")
    tree.check(INDEX.search(all,"","clue","","noticed").size()==8 and INDEX.search(all,"","clue","","found").is_empty(),"status scope intersects known clue type without inventing resolved entries")
    flags[NOTES.FOUND+String(plan[0].id)]=true
    all=NOTES.map_records(plan,configs,flags)
    tree.check(INDEX.search(all,"","all","","found").size()==1,"resolved filter returns only an actually found known entry")
    var row: Dictionary=all[0]
    tree.check(INDEX.search(all,String(plan[0].clue.title),"clue",row.region,"found").size()==1,"name, region, type and discovery status combine without broadening the scope")
    flags.erase(NOTES.FOUND+String(plan[0].id))
    tree.check(flags==before and plan==original,"journal and map indexing never mutate progress or authored route data")
    all[0].detail="changed"
    tree.check(NOTES.map_records(plan,configs,flags)[0].detail!=all[0].detail,"returned map rows do not alias later source descriptions")
    var bad: Dictionary=plan[0].duplicate(true);bad.region_id="unknown"
    tree.check(NOTES.visible([bad],flags).is_empty(),"unknown regions cannot leak names through an otherwise matching noticed id")
    var region:=String(plan[0].region_id)
    var sample: Dictionary=plan[0].duplicate(true)
    sample.clue.position=[60,60]
    var config:={"chapter_name":"示例庭院","map_rooms":[{"id":"hall","layout_rect":[0,0,4000,800]},{"id":"inner","layout_rect":[40,40,100,100]}]}
    var known:={NOTES.SEEN+String(sample.id):true,JOURNAL.KEY:{region:{"owned":true,"charted":{"hall@0":true},"pending":{}}}}
    tree.check(NOTES.map_records([sample],{region:config},known).is_empty(),"charted large hall cannot reveal a nested uncharted entrance point")
    known[JOURNAL.KEY][region].charted.inner=true
    tree.check(NOTES.map_records([sample],{region:config},known).size()==1,"nested entrance becomes locatable only with its own inked room")
    known[JOURNAL.KEY][region].charted={"hall@0":true}
    sample.clue.position=[2000,400]
    tree.check(NOTES.map_records([sample],{region:config},known).is_empty(),"one inked hall segment cannot reveal a clue in an uncharted segment")
    known[JOURNAL.KEY][region].owned=false
    tree.check(NOTES.map_records([sample],{region:config},known).is_empty(),"removing map ownership removes clue coordinates but not the heard journal text")
    var copy:=ROUTES.cached_hidden_clues()
    copy[0].clue.line="edited"
    tree.check(ROUTES.cached_hidden_clues()==original,"small cache-only catalogue does not expose mutable manifest references")

static func notice(tree: SceneTree,scene: Node) -> void:
    var plan:=ROUTES.cached_hidden_clues()
    var entry: Dictionary=plan[0]
    var clue: Node2D=scene.get_node("HiddenClue_"+String(entry.id))
    var flags: Dictionary=scene.story_flags.duplicate(true)
    var world: Dictionary=scene.world_state.data.duplicate(true)
    var position: Vector2=scene.player.position
    var physics: bool=scene.player.is_physics_processing()
    scene.player.set_physics_process(false)
    scene.player.position=clue.position
    scene.story_flags.erase(NOTES.SEEN+String(entry.id))
    var before: Dictionary=scene.story_flags.duplicate(true)
    var disk:=FileAccess.get_file_as_bytes(tree.SAVE)
    scene.world_save_failure_injected_for_validation=true
    NOTES.notice(scene)
    tree.check(scene.story_flags==before and scene.world_state.data==world and FileAccess.get_file_as_bytes(tree.SAVE)==disk,"failed actual clue write retains exact live flags, WorldState and checkpoint bytes")
    tree.check(scene.toast_label.text.contains(entry.clue.line) and scene.toast_label.text.contains("暂未写入"),"write failure still shows the real observation and honest pending feedback")
    var deadline:=int(clue.get_meta(NOTES.RETRY,0))
    NOTES.notice(scene)
    tree.check(deadline>Time.get_ticks_msec() and int(clue.get_meta(NOTES.RETRY,0))==deadline and scene.story_flags==before,"failure backoff prevents per-frame I/O retries while retaining an unrecorded clue")
    scene.world_save_failure_injected_for_validation=false
    clue.set_meta(NOTES.RETRY,0)
    NOTES.notice(scene)
    tree.check(scene.story_flags.get(NOTES.SEEN+String(entry.id),false) and not clue.has_meta(NOTES.RETRY),"after retry becomes due, actual successful save publishes the clue once")
    var reloaded:=STATE.new()
    tree.check(reloaded.read(tree.SAVE) and reloaded.data.story_flags.get(NOTES.SEEN+String(entry.id),false),"actual checkpoint reload retains the observed entrance")
    var bytes:=FileAccess.get_file_as_bytes(tree.SAVE)
    NOTES.notice(scene)
    tree.check(FileAccess.get_file_as_bytes(tree.SAVE)==bytes,"already recorded observation cannot rewrite the checkpoint on later frames")
    scene._toggle_backpack()
    var ui: Node=scene.ui_shell
    ui.bag_category="旅记"
    ui.journal_filter_buttons.guide.pressed.emit()
    ui.journal_search.text=String(entry.clue.title)
    ui.refresh_inventory()
    await tree.process_frame
    tree.check(ui.bag_grid.get_child_count()==1 and ui.bag_description.text.contains(entry.clue.line),"real handbook reader finds the one saved entrance observation by its authored title")
    var resources: Dictionary=scene._build_wallet_snapshot()
    var recorded: Dictionary=scene.story_flags.duplicate(true)
    ui._toggle_journal_star();ui._toggle_journal_read()
    await tree.process_frame
    tree.check(scene._build_wallet_snapshot()==resources and scene.story_flags==recorded,"reading and favorite preferences never consume resources or discover a room")
    scene.story_flags[NOTES.FOUND+String(entry.id)]=true
    ui.refresh_inventory()
    await tree.process_frame
    tree.check(ui.bag_description.text.contains("已找到这处藏室"),"actual handbook updates a known observation after the hidden room is found")
    scene.story_flags.erase(NOTES.SEEN+String(entry.id))
    ui.refresh_inventory()
    await tree.process_frame
    tree.check(ui.bag_grid.get_child_count()==0 and not ui.journal_documents.any(func(doc: Dictionary):return String(doc.entry.get("description","")).contains(entry.clue.line)),"removing earned observation suppresses its source text even when the found flag remains")
    scene._close_overlays()
    scene.story_flags=flags;scene.world_state.data=world;scene.player.position=position
    scene.player.set_physics_process(physics)
    tree.check(scene._save_world(),"explicit notice fault fixture restores its original starting checkpoint")
    await tree.process_frame

static func picker(tree: SceneTree,scene: Node) -> void:
    var plan:=ROUTES.cached_hidden_clues()
    var entry: Dictionary=plan[0]
    var region:=String(entry.region_id)
    var flags: Dictionary=scene.story_flags.duplicate(true)
    var found: Dictionary=scene.world_state.data.duplicate(true)
    var view_before: bool=scene.world_map_view
    var point:=Vector2(entry.clue.position[0],entry.clue.position[1])
    var owner:=preload("res://scripts/map_player_pins.gd").owner(scene.config,point)
    scene.story_flags[NOTES.SEEN+String(entry.id)]=true
    var journal:=JOURNAL.region(scene.story_flags,region)
    journal.owned=true;journal.charted[String(owner.id)]=true
    scene._toggle_map()
    var records:=RUNTIME.rows(scene)
    var picker:=UI.new();scene.map_panel.add_child(picker)
    var actions: Array=[]
    picker.open(records,func(row: Dictionary):actions.append(row.key);return {"ok":true})
    await tree.process_frame
    picker.clue_states.select(1);picker.clue_states.item_selected.emit(1)
    tree.check(picker.KINDS[picker.kinds.selected]=="clue" and picker.visible_rows.size()==1 and picker.visible_rows[0].clue_state=="noticed","native pending scope selects only actual known entrance observations")
    picker.clue_states.select(2);picker.clue_states.item_selected.emit(2)
    tree.check(picker.visible_rows.is_empty() and picker.locate_button.disabled,"empty found scope disables stale location actions")
    picker._locate_selected()
    tree.check(actions.is_empty(),"empty native scope cannot dispatch a previously selected coordinate")
    picker.clue_states.select(1);picker.clue_states.item_selected.emit(1)
    picker.search.text=String(entry.clue.title);picker.search.text_changed.emit(picker.search.text)
    tree.check(picker.visible_rows.size()==1 and picker.detail.text.contains(entry.clue.line),"native search exposes only the canonical already noticed observation")
    var candidate: Dictionary=picker.visible_rows[0].duplicate(true)
    var position: Vector2=scene.player.position
    var cash: int=scene.currency_count
    scene.story_flags.erase(NOTES.SEEN+String(entry.id))
    var result:=RUNTIME.focus(scene,candidate)
    tree.check(not result.ok and scene.player.position==position and scene.currency_count==cash,"live location revalidation refuses a stale clue whose heard identity has disappeared")
    scene.story_flags[NOTES.SEEN+String(entry.id)]=true
    picker.rows=RUNTIME.rows(scene);picker._refresh()
    picker._locate_selected()
    tree.check(actions==[candidate.key] and not picker.visible,"native activation forwards exactly the current known entrance")
    picker.open([],func(_row: Dictionary):return {"ok":true})
    tree.check(picker.clue_states.selected==0 and picker.visible_rows.is_empty(),"reopening rebuilds scope without preserving another journey's clue state")
    await tree.process_frame
    var bounds:=Rect2(Vector2.ZERO,Vector2(picker.size))
    tree.check(bounds.encloses(picker.clue_states.get_global_rect()) and bounds.encloses(picker.detail.get_global_rect()),"state controls and scrolling observation fit the actual native window")
    tree.check(picker.detail is RichTextLabel and not picker.detail.bbcode_enabled and picker.detail.scroll_active,"long clue/route text remains plain and readable without growing over action buttons")
    picker.free()
    scene._close_overlays()
    scene.story_flags=flags;scene.world_state.data=found;scene.world_map_view=view_before
    await tree.process_frame
