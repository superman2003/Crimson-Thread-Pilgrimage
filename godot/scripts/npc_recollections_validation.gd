extends SceneTree
const MEMORY:=preload("res://scripts/npc_recollections.gd")
const NARRATIVE:=preload("res://scripts/world_narrative.gd")
const WORLD:=preload("res://scripts/world_state.gd")
const BUILD:=preload("res://scripts/build_system.gd")
const UI:=preload("res://scripts/pilgrimage_interface.gd")
const SAVE:="user://npc_recollection_contract.json"
var checks:=0
var failures:=0

class Shell extends Control:
    var dialogue_area: Area2D
    var forgotten:=0
    func forget_dialogue_reading() -> void:forgotten+=1

class CommitWorld extends "res://scripts/main_level.gd":
    var allow_save:=true
    var writes:=0
    func _ready() -> void:pass
    func _process(_delta: float) -> void:pass
    func _physics_process(_delta: float) -> void:pass
    func _exit_tree() -> void:pass
    func _toast(_message: String) -> void:pass
    func _check_wish_board_rewards(_show: bool=true) -> void:pass
    func _apply_world_npc_state(_area: Area2D) -> void:pass
    func _sync_player_build() -> void:pass
    func _refresh_wish_board_overlay() -> void:pass
    func _refresh_hud() -> void:pass
    func _save_world() -> bool:
        writes+=1
        if not allow_save:return false
        if not world_state.capture_global({"current_region":String(config.id),"currency":currency_count,"story_flags":story_flags}):return false
        return world_state.write(SAVE)

class JournalWorld extends Node:
    var world_mode:=true
    var world_save_path:=SAVE
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
func clean() -> void:
    for file in DirAccess.get_files_at("user://"):
        if file.begins_with(SAVE.get_file()):DirAccess.remove_absolute("user://"+file)
func run() -> void:
    clean()
    pure_records_checks()
    await commit_checks()
    await journal_checks()
    clean()
    print("NPC_RECOLLECTIONS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func pure_records_checks() -> void:
    var catalog:=MEMORY.catalog()
    check(not catalog.is_empty() and catalog.size()<=MEMORY.MAX_NPCS,"authored NPC conversations form a bounded catalogue")
    check(MEMORY.records({}).is_empty(),"old/new saves without committed memory identities reveal no transcript")
    var region: String=MEMORY.REGIONS.keys()[0]
    var flags: Dictionary={}
    for npc_id in catalog:
        var npc: Dictionary=catalog[npc_id]
        check(not npc.states.is_empty(),"each readable NPC has a canonical conversation")
        for state in npc.states:
            var result:={"state":state.id,"lines":state.lines.duplicate()}
            var marker:=MEMORY.completion_marker(npc_id,result,state.lines.size()-1,region)
            check(marker.begins_with(MEMORY.PREFIX) and marker.length()==MEMORY.PREFIX.length()+64,"canonical fully read line gets a stable bounded marker")
            for index in range(-1,state.lines.size()-1):
                check(MEMORY.completion_marker(npc_id,result,index,region).is_empty(),"partial lines cannot publish the rest of a conversation")
            check(MEMORY.completion_marker(npc_id,result,state.lines.size(),region).is_empty(),"out-of-range metadata is not accepted as a fully read line")
            var changed:=result.duplicate(true)
            changed.lines.append("not displayed")
            check(MEMORY.completion_marker(npc_id,changed,changed.lines.size()-1,region).is_empty(),"changed or forged source text cannot authorize unread words")
            check(MEMORY.completion_marker(npc_id,result,state.lines.size()-1,"unknown_region").is_empty(),"unknown location cannot impersonate a known region")
            check(MEMORY.records({marker:1}).is_empty(),"numeric pseudo-flags cannot reveal dialogue")
            var isolated:=MEMORY.records({marker:true})
            check(isolated.size()==1 and isolated[0].title==npc.name,"one seen conversation reveals only its speaker")
            check(isolated[0].conversations==1 and isolated[0].places==[MEMORY.REGIONS[region]],"transcript location comes from the actual commit region")
            for line in state.lines:check(isolated[0].description.contains(line),"only canonical heard dialogue is copied into the public record")
            check(not isolated[0].has("grant_rewards") and not isolated[0].has("grant_flags"),"read-only recollection contains no executable reward instructions")
            flags[marker]=true
    var all:=MEMORY.records(flags)
    check(all.size()==catalog.size(),"many heard states collapse into one bounded journal card per NPC")
    check(MEMORY.completion_marker("not_known",{},0,region).is_empty(),"fallback/unregistered speakers cannot forge canonical memories")
    var id: String=catalog.keys()[0]
    var state: Dictionary=catalog[id].states[0]
    var result:={"state":state.id,"lines":state.lines}
    var another: String=MEMORY.REGIONS.keys()[1]
    var one:=MEMORY.completion_marker(id,result,state.lines.size()-1,region)
    var two:=MEMORY.completion_marker(id,result,state.lines.size()-1,another)
    var records:=MEMORY.records({one:true,two:true})
    check(one!=two and records.size()==1 and records[0].places.size()==2,"same speaker can be remembered at distinct real reunion locations")
    var pristine:=MEMORY.records(flags)
    all[0].places.clear()
    check(MEMORY.records(flags)==pristine,"caller edits cannot corrupt later public records")

func create_commit_world(result: Dictionary, npc_id: String) -> Node:
    var world:=CommitWorld.new()
    world.world_mode=true
    world.world_loading=false
    world.config={"id":"demo_ch01_moss_bell_court"}
    world.world_state=WORLD.new()
    world.build_system=BUILD.new()
    world.story_flags={}
    world.currency_count=12
    world.active_overlay="dialogue"
    var shell:=Shell.new()
    var area:=Area2D.new()
    area.set_meta("npc_id",npc_id)
    area.set_meta("kind","npc")
    area.set_meta("dialogue_state",result.state)
    area.set_meta("dialogue_state_indices",{})
    area.set_meta("world_dialogue_result",result.duplicate(true))
    area.set_meta("world_displayed_total",result.lines.size())
    shell.dialogue_area=area
    world.add_child(area)
    world.add_child(shell)
    world.ui_shell=shell
    world.dialogue_text_label=Label.new()
    world.dialogue_text_label.text=result.lines.back()
    world.dialogue_text_label.visible_characters=-1
    world.add_child(world.dialogue_text_label)
    root.add_child(world)
    return world

func commit_checks() -> void:
    var narrative:=NARRATIVE.new()
    var chosen_id:=""
    var chosen: Dictionary={}
    for id in narrative.entries:
        for state in narrative.entries[id].states:
            if state.lines.size()>=2:
                chosen_id=id
                chosen=narrative._state_result(narrative.entries[id],state,[])
                break
        if not chosen_id.is_empty():break
    check(not chosen.is_empty(),"multi-line fixture comes from actual authored NPC dialogue")
    var world:=create_commit_world(chosen,chosen_id)
    var area: Area2D=world.ui_shell.dialogue_area
    area.set_meta("world_displayed_index",0)
    world.dialogue_text_label.text=chosen.lines[0]
    world._commit_world_dialogue()
    check(MEMORY.records(world.story_flags).is_empty(),"production commit of an early line does not expose later lines")
    area.set_meta("world_line_committed",false)
    area.set_meta("world_displayed_index",chosen.lines.size()-1)
    world.dialogue_text_label.text=chosen.lines.back()
    world.dialogue_text_label.visible_characters=0
    var writes: int=world.writes
    world._commit_world_dialogue()
    check(world.writes==writes and MEMORY.records(world.story_flags).is_empty(),"unrevealed typewriter text cannot enter persistence or recollections")
    world.dialogue_text_label.visible_characters=-1
    world.allow_save=false
    var before: Dictionary=world.story_flags.duplicate(true)
    var bytes:=FileAccess.get_file_as_bytes(SAVE)
    world._commit_world_dialogue()
    check(world.story_flags==before and FileAccess.get_file_as_bytes(SAVE)==bytes and not area.get_meta("world_line_committed",false),"failed production save rolls back memory identity and leaves exact disk bytes and readable retry intact")
    world.allow_save=true
    world._commit_world_dialogue()
    var records:=MEMORY.records(world.story_flags)
    check(records.size()==1 and records[0].conversations==1 and area.get_meta("world_line_committed"),"production final-line commit publishes one canonical recollection only after saving")
    var saved:=WORLD.new()
    check(saved.read(SAVE) and MEMORY.records(saved.data.story_flags)==records,"actual World-state JSON reload reconstructs the same heard transcript")
    writes=world.writes
    var cash: int=world.currency_count
    world._commit_world_dialogue()
    check(world.writes==writes and world.currency_count==cash,"same already-committed visible line cannot be committed again")
    bytes=FileAccess.get_file_as_bytes(SAVE)
    for index in 20:MEMORY.records(world.story_flags)
    check(FileAccess.get_file_as_bytes(SAVE)==bytes and world.currency_count==cash,"repeated transcript browsing never executes rewards or saves")
    world.free()
    await process_frame

func journal_checks() -> void:
    var world:=JournalWorld.new()
    root.add_child(world)
    world.player=Node.new()
    world.add_child(world.player)
    var ui:=UI.new()
    root.add_child(ui)
    ui.level=world
    ui.journal_preferences_path=SAVE+".preferences"
    ui._build_bag()
    ui.bag_category="旅记"
    ui.bag.show()
    ui.journal_filter_buttons.people.pressed.emit()
    await process_frame
    check(ui.journal_filter=="people" and ui.journal_documents.is_empty(),"actual production people filter shows no unseen dialogue")
    check(ui.bag_description.text.contains("完整读完") and ui.bag_grid.get_child_count()==0,"empty view explains full-read persistence without revealing NPC names")
    var catalog:=MEMORY.catalog()
    var id: String=catalog.keys()[0]
    var state: Dictionary=catalog[id].states[0]
    var marker:=MEMORY.completion_marker(id,{"state":state.id,"lines":state.lines},state.lines.size()-1,"demo_ch01_moss_bell_court")
    world.story_flags[marker]=true
    var original:=world.story_flags.duplicate(true)
    ui.refresh_inventory()
    await process_frame
    check(ui.journal_documents.size()==1 and ui.bag_grid.get_child_count()==1 and ui.bag_name.text==catalog[id].name,"actual journal renders only the committed speaker's memory card")
    check(ui.bag_category_label.text=="人物重逢 · 已确认交谈" and ui.bag_description.text.contains(state.lines[0]),"native card opens the canonical heard transcript through the normal scrolling reader")
    var before:=world.story_flags.duplicate(true)
    ui.journal_search.text="不存在的交谈"
    ui.refresh_inventory()
    await process_frame
    check(ui.bag_grid.get_child_count()==0,"search only filters committed memories rather than searching the authored NPC catalogue")
    ui.journal_search.text=String(catalog[id].name)
    ui.refresh_inventory()
    await process_frame
    check(ui.bag_grid.get_child_count()==1,"known speaker names are searchable through existing journal documents")
    ui._toggle_journal_star()
    ui._toggle_journal_read()
    await process_frame
    check(world.story_flags==before and world.currency_count==0 and world.inventory_counts.is_empty(),"favorite/read toggles affect only reading preferences, never narrative progress or rewards")
    world.story_flags={}
    ui.journal_search.text=""
    ui.refresh_inventory()
    await process_frame
    check(ui.journal_documents.is_empty(),"switching to a journey with no heard identities removes stale NPC records")
    check(original.size()==1,"adding a recollection requires only one bounded boolean identity in primary story flags")
    ui.free()
    world.free()
    await process_frame
    await process_frame
