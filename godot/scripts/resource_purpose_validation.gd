extends RefCounted
const MODEL:=preload("res://scripts/resource_purpose_ledger.gd")
const BUILD:=preload("res://scripts/build_system.gd")

func report(build: RefCounted, wallet: Dictionary, flags: Dictionary={}) -> Dictionary:
    return MODEL.collect(build,wallet,flags,{"moss_chitin":{"name":"苔甲","category":"Materials","description":"保留拾得物的原有用途说明。"},"wet_chitin":{"name":"湿甲","category":"Materials"},"unknown":{"name":"秘密物品","category":"Quest"}},50.5,100,{"cost":60,"amount":1})

func find_use(data: Dictionary, id: String) -> Dictionary:
    for value in data.uses:
        if value.id==id:return value
    return {}

func source_checks(config: Dictionary, check: Callable) -> void:
    var source: Dictionary={}
    for entry in config.collectibles:
        if entry.get("kind")=="item" and entry.get("item_id")=="moss_chitin":source=entry.duplicate(true);break
    check.call(not source.is_empty(),"actual region contains an authored optional material source")
    var inventory:={String(source.item_id):2}
    var collected:={String(source.id):true}
    var visited:={String(source.room_id):true}
    var before:=var_to_str([config,inventory,collected,visited])
    var sources:=MODEL.observed_sources(config,collected,visited,inventory)
    check.call(sources.has(source.item_id) and sources[source.item_id].size()==1,"collected material in a visited room has one confirmed current-region source")
    var row: Dictionary=sources[source.item_id][0]
    check.call(row.size()==2 and row.title==source.label and String(row.place).begins_with(String(config.name)),"source exposes only authored public name and current-region place")
    var rendered:=var_to_str(sources)
    check.call(not rendered.contains(String(source.id)) and not rendered.contains(var_to_str(source.position)),"source result carries neither internal collectible identity nor precise coordinates")
    check.call(var_to_str([config,inventory,collected,visited])==before,"source lookup never changes canonical config or observed progress")
    sources[source.item_id][0].title="mutated caller"
    check.call(MODEL.observed_sources(config,collected,visited,inventory)[source.item_id][0].title==source.label,"returned source rows cannot mutate later source lookups")
    check.call(MODEL.observed_sources(config,{},visited,inventory).is_empty(),"visited hidden room alone does not reveal an uncollected material")
    check.call(MODEL.observed_sources(config,collected,{},inventory).is_empty(),"collected marker alone does not reveal an unvisited room name")
    check.call(MODEL.observed_sources(config,collected,visited,{}).is_empty(),"spent or absent material has no public resource row to extend")
    for bad in [true,-1,0,0.5,NAN,INF,"1"]:
        check.call(MODEL.observed_sources(config,collected,visited,{String(source.item_id):bad}).is_empty(),"invalid held quantity cannot expose a material's physical source")
    for bad in [1,"true",[],{}]:
        check.call(MODEL.observed_sources(config,{String(source.id):bad},visited,inventory).is_empty(),"nonboolean collection marker cannot reveal source")
        check.call(MODEL.observed_sources(config,collected,{String(source.room_id):bad},inventory).is_empty(),"nonboolean room visit cannot reveal source")
    var changed:=config.duplicate(true)
    changed.collectibles=[source.duplicate(true),source.duplicate(true)]
    check.call(MODEL.observed_sources(changed,collected,visited,inventory)[source.item_id].size()==1,"duplicate source identity cannot inflate observed locations")
    for patch in [{"kind":"currency"},{"label":""},{"label":7},{"room_id":"unvisited_elsewhere"},{"item_id":"unowned_material"},{"amount":0},{"amount":true},{"amount":0.5}]:
        var invalid:=source.duplicate(true)
        invalid.merge(patch,true)
        changed.collectibles=[invalid]
        check.call(MODEL.observed_sources(changed,collected,visited,inventory).is_empty(),"invalid or unrelated source metadata cannot invent a provenance entry")
    for patch in [{"collectibles":{}},{"map_rooms":{}},{"name":null}]:
        changed=config.duplicate(true)
        changed.merge(patch,true)
        check.call(MODEL.observed_sources(changed,collected,visited,inventory).is_empty(),"malformed source catalog fails closed")
    var report_data:={"rows":[{"count":0}],"uses":[],"reason":"只读核对","observed_sources":MODEL.observed_sources(config,collected,visited,inventory)}
    var material:={"id":source.item_id,"name":"苔甲","count":2,"purpose":"拾得材料"}
    var text:=MODEL.describe(report_data,material,false,func(id: String):return id)
    check.call(text.contains(String(source.label)) and text.contains("已经收取，不是再次领取的承诺"),"provenance text distinguishes observed collection from a repeatable income promise")
    check.call(not text.contains(String(source.note)),"developer source note does not become public material lore")

func run(tree: SceneTree, level: Node, check: Callable) -> void:
    var build:=BUILD.new()
    var wallet:={"currency":137,"inventory_counts":{"moss_chitin":8,"wet_chitin":3,"unknown":1}}
    var before:=var_to_str([build.serialize(),wallet])
    var data:=report(build,wallet)
    check.call(data.ok and data.rows.size()==4,"resource purpose includes money, fractional live thread and only owned material rows")
    check.call(data.rows[0].id=="currency" and data.rows[1].id=="thread" and data.rows[1].count==50,"resource index keeps the three roles separate and matches integer HUD display")
    check.call(data.rows[2].name=="湿甲" and data.rows[3].name=="苔甲","material names sort independently of inventory insertion order")
    check.call(var_to_str([build.serialize(),wallet])==before,"constructing a resource index leaves live wallet and build byte representation unchanged")
    check.call(find_use(data,"tool_shard").currency==4 and find_use(data,"tool_shard").materials.moss_chitin.required==1,"tool use comes from actual per-charge resupply catalog")
    check.call(find_use(data,"tool_shard").source==build.catalog.tools.shard.get("source", ""),"known tool preserves its authored maker and origin")
    check.call(find_use(data,"tool_shard").complete and not find_use(data,"tool_shard").ready,"full starting stock is described without suggesting free refill")
    check.call(find_use(data,"tool_mine").is_empty() and find_use(data,"skill_needle").is_empty(),"locked equipment names and uses stay outside resource index")
    check.call(find_use(data,"recipe_branch_cleave_a").is_empty(),"unpracticed skill cannot reveal training recipe")
    check.call(find_use(data,"recipe_clasp_travel").is_empty(),"unearned mechanism flag cannot reveal travel slot recipe")
    var thread_uses:=MODEL.uses_for(data,"thread")
    check.call(thread_uses.size()==2 and find_use(data,"heal").thread==60,"thread index uses actual starting skill and current heal quote")
    check.call(not find_use(data,"heal").ready,"insufficient thread is not presented as ready healing")
    var copy:=MODEL.uses_for(data,"moss_chitin")
    check.call(copy.size()==1 and find_use(data,"recipe_mod_shard").is_empty(),"owned material links known supply without inventing an unearned modification pattern")
    copy[0].name="changed"
    copy[0].materials.clear()
    check.call(find_use(data,"tool_shard").name!="changed" and not find_use(data,"tool_shard").materials.is_empty(),"returned use rows cannot mutate retained report data")
    build.state.tool_counts.shard=1
    data=report(build,wallet,{"skill_practiced_cleave":true,"seal_bell_repaired":true})
    check.call(find_use(data,"tool_shard").ready,"unfilled known tool becomes affordable from actual wallet")
    check.call(not find_use(data,"recipe_branch_cleave_a").is_empty() and find_use(data,"recipe_clasp_travel").is_empty(),"earned practice exposes training but mechanism alone cannot replace its missing pattern")
    var branch:=find_use(data,"recipe_branch_cleave_a")
    check.call(branch.currency==100 and branch.materials.moss_chitin.required==2 and branch.ready,"known training cost is read from actual recipe")
    build.state.skill_levels.cleave=1
    data=report(build,wallet,{"skill_practiced_cleave":true})
    check.call(find_use(data,"recipe_branch_cleave_a").complete and not find_use(data,"recipe_branch_cleave_a").ready,"current training branch is not an actionable duplicate")
    check.call(find_use(data,"recipe_branch_cleave_b").ready,"alternative trained branch retains its own current cost")
    var poor:={"currency":3,"inventory_counts":{"moss_chitin":0}}
    data=report(build,poor,{"skill_practiced_cleave":true})
    check.call(data.rows.size()==2 and MODEL.uses_for(data,"currency",true).is_empty(),"empty material and insufficient money do not produce affordable rows")
    var text:=MODEL.describe(data,data.rows[0],false,func(id: String):return "物品"+id)
    check.call(text.contains("需要4 / 持有3") and text.contains("所示费用或前置条件尚未备齐"),"resource explanation shows live required and held money without transacting")
    text=MODEL.describe(data,data.rows[1],true,func(id: String):return id)
    check.call(not text.contains("当前契印疗伤") and text.contains("实际使用还须满足地点"),"affordable filter omits unavailable healing and retains action qualification")

    for bad in [true,-1,0.5,NAN,INF,"8",null,2147483648.0]:
        var bad_wallet:={"currency":bad,"inventory_counts":{}}
        check.call(not report(build,bad_wallet).ok,"malformed wallet amount cannot create a valid purpose report")
        bad_wallet={"currency":50,"inventory_counts":{"moss_chitin":bad}}
        data=report(build,bad_wallet)
        check.call(data.rows.size()==2 and find_use(data,"tool_shard").is_empty(),"malformed owned material neither appears nor proves affordable use")
    for bad in [true,-1,NAN,INF,"50",null]:
        check.call(not MODEL.collect(build,wallet,{}, {},bad,100,{}).ok,"invalid live thread cannot produce resource readout")
    check.call(MODEL.collect(build,wallet,{}, {},50.25,100,{}).ok,"fractional live thread remains readable")
    check.call(not MODEL.collect(build,wallet,{}, {},101,100,{}).ok,"thread above declared maximum is rejected")
    check.call(not MODEL.collect(null,wallet,{}, {},50,100,{}).ok,"missing build cannot publish invented catalog uses")
    check.call(not MODEL.collect(build,{"currency":5,"inventory_counts":[]},{}, {},50,100,{}).ok,"malformed inventory shape is rejected")
    for value in [1,"true",[],{}]:
        var flags:={"skill_practiced_cleave":value,"seal_bell_repaired":value}
        data=report(build,wallet,flags)
        check.call(find_use(data,"recipe_branch_cleave_a").is_empty() and find_use(data,"recipe_clasp_travel").is_empty(),"nonboolean discovery flags do not expose recipes")
    check.call(MODEL.cost_row("test","test","test",1,{"moss_chitin":0},wallet).is_empty(),"zero material requirements cannot become a quote row")
    check.call(MODEL.cost_row("test","test","test",true,{},wallet).is_empty(),"boolean price cannot become an affordable row")
    check.call(MODEL.cost_row("test","test","test",1,[],wallet).is_empty(),"invalid cost table cannot become a quote row")
    var fake: Dictionary=build.catalog.recipes.clasp_travel.duplicate(true)
    fake.id="clasp_travel"
    var clasp_proof: String=fake.requires_items[0]
    check.call(not MODEL.known_recipe(fake,build.state,{},{clasp_proof:1}) and MODEL.known_recipe(fake,build.state,{"seal_bell_repaired":true},{clasp_proof:1}),"slot part requires both authored mechanism and actually owned pattern")
    var owned_state:=build.serialize()
    owned_state.crafted.append("clasp_travel")
    check.call(not MODEL.known_recipe(fake,owned_state,{}),"crafted marker alone cannot bypass the authored mechanism gate")
    fake={"kind":"new_unknown_kind","target":"anything"}
    check.call(not MODEL.known_recipe(fake,build.state,{}),"unknown future recipe kind is omitted rather than guessed")
    fake={"kind":"passive","target":"tide_reel"}
    check.call(not MODEL.known_recipe(fake,build.state,{}),"unearned passive has no inferred recipe knowledge")
    owned_state.unlocked_passives.append("tide_reel")
    check.call(MODEL.known_recipe(fake,owned_state,{}),"earned passive may explain its known crafting use")
    var patterned: Dictionary=build.catalog.recipes.pilgrim_mod_shard.duplicate(true)
    patterned.id="pilgrim_mod_shard"
    var proof: String=patterned.requires_items[0]
    check.call(not MODEL.known_recipe(patterned,build.state,{}),"undiscovered pattern cannot reveal a later tool recipe")
    for value in [true,-1,0,0.5,NAN,INF,"1"]:
        check.call(not MODEL.known_recipe(patterned,build.state,{},{proof:value}),"malformed pattern ownership does not expose later craft source")
    check.call(not MODEL.known_recipe(patterned,build.state,{},{proof:1}),"one pattern cannot stand in for every required second-stage proof")
    var proofs: Dictionary={}
    for id in patterned.requires_items:proofs[id]=1
    check.call(MODEL.known_recipe(patterned,build.state,{},proofs),"all actually owned patterns reveal an already owned tool's crafting use")
    var patterned_wallet:=wallet.duplicate(true)
    for id in proofs:patterned_wallet.inventory_counts[id]=proofs[id]
    data=report(build,patterned_wallet)
    check.call(not find_use(data,"recipe_pilgrim_mod_shard").is_empty(),"known pattern joins the reverse material index without becoming a consumed material")
    check.call(not find_use(data,"recipe_pilgrim_mod_shard").ready and find_use(data,"recipe_pilgrim_mod_shard").conditions.has("仍需前阶改制"),"known second-stage cost still reports a missing first-stage prerequisite")
    text=MODEL.describe(data,data.rows[0],false,func(id: String):return id)
    check.call(text.contains(String(patterned.source)),"known recipe explains the canonical source alongside its use")
    build.state.crafted.append("mod_shard")
    data=report(build,patterned_wallet)
    check.call(find_use(data,"recipe_pilgrim_mod_shard").ready,"known and prepared second stage becomes affordable only after its actual predecessor")
    source_checks(level.config,check)

    # Actual World UI and resource owners. No fake display object replaces the
    # production shell, current player quote or inventory catalog lookup.
    level._close_overlays()
    level._toggle_backpack()
    await tree.process_frame
    var ui: Control=level.ui_shell
    var button:=ui.bag.get_node("ResourcePurposeButton") as Button
    var dialog:=ui.get_node("ResourcePurposeWindow") as AcceptDialog
    var state_before:=var_to_str([level.build_system.serialize(),level.inventory_counts,level.story_flags,level.currency_count,level.player.energy,level.player.hp,level.world_state.data])
    var disk_before:=FileAccess.get_file_as_bytes(level.world_save_path)
    button.pressed.emit()
    await tree.process_frame
    check.call(dialog.visible and dialog.resources.has_focus(),"actual bag button opens a native keyboard-focusable resource ledger")
    check.call(dialog.resources.item_count>=2 and dialog.resources.get_item_metadata(0)=="currency","real World reports current currencies through production dialog")
    check.call(dialog.size.x<=int(ui.get_viewport_rect().size.x) and dialog.size.y<=int(ui.get_viewport_rect().size.y),"native resource window fits the actual viewport")
    var rect:=Rect2(button.position,button.size)
    check.call(not rect.intersects(Rect2(ui.bag_currency.position,ui.bag_currency.size)),"resource entry does not cover wallet count")
    check.call(not rect.intersects(Rect2(ui.bag_tabs[0].position,ui.bag_tabs[0].size)),"resource entry stays above category tabs")
    dialog.resources.select(1)
    dialog.resources.item_selected.emit(1)
    check.call(dialog.detail.text.contains("绯线费用") and dialog.selected=="thread","real thread selection shows current player and learned skill costs")
    dialog.ready_only.set_pressed(true)
    check.call(dialog.selected=="thread" and dialog.resources.is_selected(1),"filtering uses preserves selected resource and list position")
    dialog.refresh_button.pressed.emit()
    check.call(dialog.selected=="thread" and dialog.ready_only.button_pressed,"refresh preserves resource selection and filter")
    var known_source: Dictionary={}
    for source in level.config.collectibles:
        if source.get("item_id")=="moss_chitin":known_source=source;break
    var original_inventory: Dictionary=level.inventory_counts.duplicate(true)
    var original_collected: Dictionary=level.world_collected_ids.duplicate(true)
    var original_visited: Dictionary=level.visited_rooms.duplicate(true)
    level.inventory_counts[known_source.item_id]=2
    level.world_collected_ids[known_source.id]=true
    level.visited_rooms[known_source.room_id]=true
    dialog.refresh_button.pressed.emit()
    for index in dialog.resources.item_count:
        if dialog.resources.get_item_metadata(index)==known_source.item_id:
            dialog.resources.select(index)
            dialog.resources.item_selected.emit(index)
            break
    check.call(dialog.detail.text.contains(String(known_source.label)) and dialog.detail.text.contains("已经收取"),"production resource dialog connects owned material to its confirmed current-region provenance")
    level.inventory_counts=original_inventory
    level.world_collected_ids=original_collected
    level.visited_rooms=original_visited
    dialog.refresh_button.pressed.emit()
    check.call(dialog.selected=="currency" and not dialog.detail.text.contains(String(known_source.label)),"refresh removes disappeared material and stale hidden-source detail")
    var state_after:=var_to_str([level.build_system.serialize(),level.inventory_counts,level.story_flags,level.currency_count,level.player.energy,level.player.hp,level.world_state.data])
    check.call(state_after==state_before and FileAccess.get_file_as_bytes(level.world_save_path)==disk_before,"open select filter refresh leave actual inventory wallet build hp energy flags and save bytes unchanged")
    dialog.hide()
    dialog.return_focus()
    check.call(button.has_focus(),"closing resource window returns focus to actual bag entry")
    button.pressed.emit()
    await tree.process_frame
    level._close_overlays()
    await tree.process_frame
    check.call(not dialog.visible and dialog.report.is_empty(),"closing the bag clears resource report and nested window")
    dialog.refresh()
    dialog.render_detail()
    button.pressed.emit()
    check.call(not dialog.visible and dialog.report.is_empty(),"late callbacks cannot reopen or repopulate a closed bag's report")
    level._toggle_backpack()
    button.pressed.emit()
    await tree.process_frame
    check.call(dialog.visible and dialog.selected=="currency" and not dialog.ready_only.button_pressed,"reopening starts a fresh report with safe selection and filter")
    level._close_overlays()
