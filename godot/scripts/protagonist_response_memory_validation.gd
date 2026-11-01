extends RefCounted
const MEMORY:=preload("res://scripts/protagonist_response_memory.gd")
const VOICE:=preload("res://scripts/protagonist_voice.gd")
const STATE:=preload("res://scripts/world_state.gd")
const UI:=preload("res://scripts/pilgrimage_interface.gd")
static func run(tree: SceneTree) -> void:
    pure(tree)
    await commits(tree)
    await wishes(tree)
    await journal(tree)

static func pure(tree: SceneTree) -> void:
    var rows:=MEMORY.catalog()
    tree.check(rows.size()==16 and MEMORY.records({}).is_empty(),"all sixteen authored protagonist responses remain private without exact earned identities")
    var modes:={}
    for row in rows:
        modes[row.mode]=true
        var result: Dictionary=row.result
        var last: int=result.lines.size()-1
        var region: String=MEMORY.REGIONS.keys()[0]
        var quoted:=MEMORY.quote(row.npc,result,last,{},region)
        tree.check(not quoted.is_empty() and quoted.marker.length()==MEMORY.PREFIX.length()+64,"fully read canonical response has a bounded stable identity: "+String(row.npc))
        var flags:={String(quoted.marker):true}
        var before:=flags.duplicate(true)
        var public:=MEMORY.records(flags)
        tree.check(public.size()==1 and public[0].description.contains(row.text) and public[0].response_mode==row.mode,"exact earned response reveals only its own words and presentation mode")
        tree.check(public[0].description.contains(String(MEMORY.REGIONS[region])) and public[0].description.contains(result.lines.back()),"response context is its actual commit place and already heard final NPC line")
        tree.check(not public[0].has("grant_flags") and not public[0].has("grant_rewards") and flags==before,"journal response has no executable outcome and cannot mutate the flags it reads")
        tree.check(MEMORY.records({String(quoted.marker):1}).is_empty(),"numeric pseudo-markers cannot disclose a protagonist response")
        tree.check(MEMORY.quote(row.npc,result,last,flags,region).is_empty(),"exact same committed response cannot be granted twice")
        var legacy:={}
        for flag in result.grant_flags:legacy[String(flag)]=true
        if not result.reward_flag.is_empty():legacy[String(result.reward_flag)]=true
        tree.check(MEMORY.records(legacy).is_empty() and MEMORY.quote(row.npc,result,last,legacy,region).is_empty(),"legacy task flags cannot fabricate a remembered response or repeat a completed reaction")
        for index in [-1,last-1,last+1]:tree.check(MEMORY.quote(row.npc,result,index,{},region).is_empty(),"partial or out-of-range line indices cannot authorize a full response")
        for field in ["response","response_mode","state","lines","grant_flags","grant_rewards"]:
            var changed:=result.duplicate(true)
            if field=="lines":changed[field]=["not actually displayed"]
            elif field=="grant_flags":changed[field]=["invented_flag"]
            elif field=="grant_rewards":changed[field]={"currency":999}
            else:changed[field]="forged"
            tree.check(MEMORY.quote(row.npc,changed,changed.lines.size()-1,{},region).is_empty(),"source-bound response rejects changed metadata: "+field)
        tree.check(MEMORY.quote("unknown_npc",result,last,{},region).is_empty() and MEMORY.quote(row.npc,result,last,{},"unknown_region").is_empty(),"unknown speaker or region cannot create narrative history")
        public[0].description="changed"
        tree.check(MEMORY.records(flags)[0].description.contains(row.text),"returned journal rows cannot overwrite the canonical response")
        var restored: Dictionary=JSON.parse_string(JSON.stringify(flags))
        tree.check(MEMORY.records(restored)==MEMORY.records(flags),"existing JSON story flags alone restore the exact response")
    tree.check(modes.size()==3,"speech, needle gestures and resonance all remain distinguishable")
    var before:=MEMORY.catalog()
    rows[0].text="edited"
    rows[0].result.lines.clear()
    tree.check(MEMORY.catalog()==before,"response catalogue callers do not alias persistent canonical data")

static func commits(tree: SceneTree) -> void:
    var row: Dictionary=MEMORY.catalog()[0]
    var region: String=MEMORY.REGIONS.keys()[0]
    var last: int=row.result.lines.size()-1
    var quoted:=MEMORY.quote(row.npc,row.result,last,{},region)
    var world: Node=tree.create_commit_world(row.result,row.npc)
    var area: Area2D=world.ui_shell.dialogue_area
    area.set_meta("world_displayed_index",last)
    world.dialogue_text_label.text=row.result.lines.back()
    world.dialogue_text_label.visible_characters=0
    world._commit_world_dialogue()
    tree.check(not world.story_flags.has(quoted.marker) and world.notices.is_empty(),"unrevealed actual typewriter text creates neither response marker nor toast")
    world.dialogue_text_label.visible_characters=-1
    world.allow_save=false
    var before: Dictionary=world.story_flags.duplicate(true)
    world._commit_world_dialogue()
    tree.check(world.story_flags==before and not world.story_flags.has(quoted.marker),"failed production conversation save rolls the response marker back with every other narrative flag")
    tree.check(not world.notices.has(quoted.text),"failed conversation does not present an uncommitted protagonist reaction")
    world.allow_save=true
    world.notices.clear()
    world._commit_world_dialogue()
    tree.check(world.story_flags.get(quoted.marker,false) and world.notices.has(quoted.text),"successful actual conversation publishes saved response and nonmodal toast together")
    var disk:=STATE.new()
    tree.check(disk.read(tree.SAVE) and disk.data.story_flags.get(quoted.marker,false),"actual WorldState JSON reload retains the response identity")
    var cash: int=world.currency_count
    var bytes:=FileAccess.get_file_as_bytes(tree.SAVE)
    var writes: int=world.writes
    world.notices.clear()
    world._commit_world_dialogue()
    tree.check(world.currency_count==cash and world.writes==writes and world.notices.is_empty() and FileAccess.get_file_as_bytes(tree.SAVE)==bytes,"late duplicate final-line callback cannot repeat reaction, rewards or writes")
    before=world.story_flags.duplicate(true)
    for index in 20:MEMORY.records(world.story_flags)
    tree.check(world.story_flags==before and world.writes==writes and FileAccess.get_file_as_bytes(tree.SAVE)==bytes,"repeated response reading remains independent of progression and saving")
    world.free()
    await tree.process_frame

static func wishes(tree: SceneTree) -> void:
    var row: Dictionary=MEMORY.catalog()[0]
    var region: String=MEMORY.REGIONS.keys()[0]
    var last: int=row.result.lines.size()-1
    var quoted:=MEMORY.quote(row.npc,row.result,last,{},region)
    var world: Node=tree.create_commit_world(row.result,row.npc)
    world.world_save_path=tree.SAVE
    world.player=tree.make_response_transaction_player()
    world.add_child(world.player)
    world.inventory_counts={"pollen_wax":1}
    var area: Area2D=world.ui_shell.dialogue_area
    area.set_meta("world_displayed_index",last)
    var quest:={"item":"pollen_wax","consume":true,"reward":"map_fragment","complete_flag":"response_wish_complete","accept_flag":"response_wish_accepted"}
    var before: Dictionary=world.story_flags.duplicate(true)
    var plan: Dictionary=world._wish_topic_plan(quest,area)
    tree.check(plan.flags.get(quoted.marker,false) and plan.dialogue.response_text==quoted.text and world.story_flags==before,"wish preview prepares response and outcome together without publishing either")
    var bytes:=FileAccess.get_file_as_bytes(tree.SAVE)
    world.world_save_failure_injected_for_validation=true
    var failed: Dictionary=world.perform_wish_topic(quest,area)
    tree.check(not failed.ok and world.story_flags==before and not world.notices.has(quoted.text),"failed wish checkpoint publishes neither protagonist response nor narrative outcome")
    tree.check(world.inventory_counts=={"pollen_wax":1} and FileAccess.get_file_as_bytes(tree.SAVE)==bytes,"failed wish preserves offering and exact previous checkpoint bytes")
    world.world_save_failure_injected_for_validation=false
    var saved: Dictionary=world.perform_wish_topic(quest,area)
    tree.check(saved.ok and saved.delivered and world.story_flags.get(quoted.marker,false) and world.notices.has(quoted.text),"actual one-write wish transaction commits its short protagonist response with the accepted offering")
    var disk:=STATE.new()
    tree.check(disk.read(tree.SAVE) and disk.data.story_flags.get(quoted.marker,false) and MEMORY.records(disk.data.story_flags).size()==1,"successful wish reload reconstructs exactly its earned response")
    world.notices.clear();bytes=FileAccess.get_file_as_bytes(tree.SAVE)
    var wallet: int=world.currency_count
    world.perform_wish_topic(quest,area)
    tree.check(world.currency_count==wallet and world.notices.is_empty() and FileAccess.get_file_as_bytes(tree.SAVE)==bytes,"repeated accepted wish cannot repeat protagonist reaction, rewards or save write")
    world.free()
    await tree.process_frame

static func journal(tree: SceneTree) -> void:
    var world: Node=tree.make_response_journal_world()
    var ui:=UI.new()
    tree.root.add_child(ui)
    ui.level=world
    ui.journal_preferences_path=tree.SAVE+".responses.preferences"
    ui._build_bag();ui.bag_category="旅记";ui.bag.show()
    ui.journal_filter_buttons.voice.pressed.emit()
    await tree.process_frame
    tree.check(ui.journal_documents.is_empty(),"actual self-reflection category reveals no future protagonist responses")
    var row: Dictionary=MEMORY.catalog()[0]
    var region: String=MEMORY.REGIONS.keys()[0]
    var quoted:=MEMORY.quote(row.npc,row.result,row.result.lines.size()-1,{},region)
    world.story_flags[quoted.marker]=true
    var before: Dictionary=world.story_flags.duplicate(true)
    ui.refresh_inventory()
    await tree.process_frame
    tree.check(ui.journal_documents.size()==1 and ui.bag_grid.get_child_count()==1,"one actual saved response creates exactly one native self-reflection card")
    tree.check(ui.bag_description.text.contains(row.text) and ui.bag_description.text.contains(String(MEMORY.REGIONS[region])),"native reader displays the canonical brief response and commit location")
    ui.journal_search.text=String(row.text).left(4)
    ui.refresh_inventory()
    await tree.process_frame
    tree.check(ui.bag_grid.get_child_count()==1,"known response words are searchable through the existing public-document index")
    ui._toggle_journal_star();ui._toggle_journal_read()
    await tree.process_frame
    tree.check(world.story_flags==before and world.currency_count==0 and world.inventory_counts.is_empty(),"reading/favorite preferences cannot replay a reaction or grant a quest reward")
    world.story_flags={}
    ui.journal_search.text="";ui.refresh_inventory()
    await tree.process_frame
    tree.check(ui.journal_documents.is_empty(),"switching to an unearned journey removes stale response cards")
    ui.free();world.free()
    await tree.process_frame
