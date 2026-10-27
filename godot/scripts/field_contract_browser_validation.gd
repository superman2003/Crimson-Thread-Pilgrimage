extends SceneTree
const CONTRACTS:=preload("res://scripts/field_contracts.gd")
const DESK:=preload("res://scripts/field_contract_desk.gd")
const STATE:=preload("res://scripts/world_state.gd")
var checks:=0
var failures:=0
class Level extends Node:
    var config: Dictionary
    var world_state:=STATE.new()
    var story_flags: Dictionary={}
    var visited_rooms: Dictionary={}
    var inventory_counts: Dictionary={}
    var currency_count:=73
class UI extends Control:
    var level: Node
    var build_panel: Control
    func register_text_entry_window(_window: Window) -> void:pass
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(text)
func run() -> void:
    var level:=Level.new();root.add_child(level)
    var catalog:=CONTRACTS.contracts()
    var survey: Dictionary=catalog[0];var watch: Dictionary=catalog[1];var neighbor: Dictionary=catalog[2]
    level.config={"id":survey.region}
    var known:=CONTRACTS.entries(level)
    check(known.size()==2 and CONTRACTS.regions(known).size()==1,"unvisited region contracts never enter region choices")
    level.world_state.data.regions[neighbor.region]=STATE.fresh_region()
    known=CONTRACTS.entries(level)
    check(known.size()==4 and CONTRACTS.regions(known).size()==2,"a visited region becomes a public filter choice")
    for objective in survey.objectives:level.visited_rooms[objective.target]=true
    check(CONTRACTS.browse(CONTRACTS.entries(level),"",4).is_empty(),"ready but unaccepted contracts cannot appear as pending rewards")
    level.story_flags[CONTRACTS.flag(survey.id,"accepted")]=true
    level.story_flags[CONTRACTS.flag(watch.id,"accepted")]=true
    known=CONTRACTS.entries(level)
    var ready:=CONTRACTS.browse(known,"",4)
    check(ready.size()==1 and ready[0].contract_id==survey.id,"ready filter includes only accepted complete unclaimed contracts")
    check(CONTRACTS.browse(known,"",2).size()==2,"ongoing filter still includes ready contracts until claimed")
    check(CONTRACTS.browse(known,"",4,String(neighbor.region)).is_empty(),"region and reward filters intersect")
    check(CONTRACTS.browse(known,"朝圣断阶",4).size()==1,"search can match an observed public step label")
    check(CONTRACTS.browse(known,"moss_descent",0).is_empty(),"raw objective identities do not enter search")
    var public_row: Dictionary=known[0].duplicate(true)
    public_row.description="Copper Bridge";public_row["hidden_conditions"]="future_secret"
    check(CONTRACTS.browse([public_row],"copper　bridge",0).size()==1,"public terms are case insensitive and normalize pasted whitespace")
    check(CONTRACTS.browse([public_row],"future_secret",0).is_empty(),"hidden backing fields are never searched")
    var source:=known.duplicate(true);ready[0].title="edited"
    check(known==source,"filtered records are detached from original public entries")
    var claimed:=public_row.duplicate(true);claimed.claimed=true;claimed.accepted=false
    check(CONTRACTS.browse([claimed],"",1).is_empty() and CONTRACTS.browse([claimed],"",4).is_empty(),"settled contracts cannot be offered again even with an inconsistent accepted marker")
    var malformed:=public_row.duplicate(true);malformed.ready="yes"
    check(CONTRACTS.browse([malformed],"",4).is_empty(),"non-boolean completion cannot become a pending reward")
    var ui:=UI.new();root.add_child(ui);ui.level=level;ui.build_panel=Control.new();ui.add_child(ui.build_panel)
    var desk:=DESK.new();ui.add_child(desk);desk.ui=ui;desk._build();desk.refresh()
    check(desk.filter.item_count==5 and desk.region_filter.item_count==3,"native board includes ready rewards and public region options")
    var flags:=level.story_flags.duplicate(true);var inventory:=level.inventory_counts.duplicate(true)
    desk.filter.select(4);desk.filter.item_selected.emit(4)
    check(desk.rows.size()==1 and desk.detail.text.contains(survey.reward_name),"native ready filter shows the selected contract's public reward")
    var index:=-1
    for i in desk.region_filter.item_count:
        if desk.region_filter.get_item_metadata(i)==neighbor.region:index=i
    desk.region_filter.select(index);desk.region_filter.item_selected.emit(index)
    check(desk.rows.is_empty() and desk.selected.is_empty(),"native region change clears a stale empty selection")
    desk.region_filter.select(0);desk.region_filter.item_selected.emit(0)
    desk.query.text="朝圣断阶";desk.query.text_changed.emit(desk.query.text)
    check(desk.rows.size()==1 and desk.window.status.text.contains("待登记回礼1份"),"native search and summary reflect current public readiness")
    level.story_flags[CONTRACTS.flag(survey.id,"claimed")]=true;desk.refresh()
    check(desk.rows.is_empty(),"newly settled rewards disappear from the ready filter")
    level.story_flags.erase(CONTRACTS.flag(survey.id,"claimed"))
    check(level.story_flags==flags and level.inventory_counts==inventory and level.currency_count==73,"browsing and filtering consume nothing and grant no reward")
    ui.free();level.free()
    print("FIELD_CONTRACT_BROWSER checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
