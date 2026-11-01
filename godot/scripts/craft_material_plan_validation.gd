extends RefCounted
## Called by the existing default craft_cart suite, using its real World fixture.
const PLAN:=preload("res://scripts/craft_material_plan.gd")
const BUILD:=preload("res://scripts/build_system.gd")
static func pure(tree: SceneTree) -> void:
    effects(tree)
    var build:=BUILD.new()
    build.unlock_event("tool_mine_found")
    build.unlock_event("tool_lure_found")
    var wallet:={"currency":100,"inventory_counts":{"wet_chitin":1,"pollen_wax":2}}
    var before: Dictionary=build.serialize()
    var original:=wallet.duplicate(true)
    var ids:=["mod_mine","mod_lure"]
    var plan:=PLAN.report(build,ids,wallet)
    tree.check(plan.valid and not plan.ready and plan.currency=={"required":170,"owned":100,"missing":70,"remaining":0},"planning reports the full price deficit even while the first pattern is missing")
    tree.check(plan.materials==[{"id":"pollen_wax","required":3,"owned":2,"missing":1,"remaining":0},{"id":"wet_chitin","required":3,"owned":1,"missing":2,"remaining":0}],"shopping list includes every material shortage, with deterministic order")
    tree.check(plan.patterns.size()==2 and plan.patterns[0].missing and plan.patterns[1].missing,"all required patterns are presented separately from consumed materials")
    tree.check(plan.rows.size()==2 and not plan.rows[0].ready and not plan.rows[1].ready,"individual blocked rows remain available for inspection")
    var text:=PLAN.text(plan,func(id: String):return "名称_"+id,func(id: String):return "材料用途_"+id)
    tree.check(text.contains("缺70") and text.contains("缺1") and text.contains("缺2"),"native prose includes simultaneous currency and distinct material deficits")
    tree.check(text.contains("名称_pollen_wax") and text.contains("材料用途_wet_chitin") and text.contains("只出示，不消耗"),"public names and material explanations accompany quantities; patterns are explicitly retained")
    tree.check(build.serialize()==before and wallet==original,"planning never mutates the actual build or caller wallet")
    plan.rows[0].materials.wet_chitin=999
    plan.rows[0].patterns.append("invented")
    tree.check(build.catalog.recipes.mod_mine.materials.wet_chitin==3 and not build.catalog.recipes.mod_mine.requires_items.has("invented"),"returned planning rows do not alias authored recipe dictionaries or arrays")
    for request in [[],["mod_mine","mod_mine"],["unknown"],[true],"mod_mine",["a","b","c","d","e","f","g","h","i"]]:
        tree.check(not PLAN.report(build,request,wallet).valid and build.serialize()==before and wallet==original,"invalid requests cannot create an optimistic plan or partial mutation")
    for bad in [{"currency":true,"inventory_counts":{}},{"currency":INF,"inventory_counts":{}},{"currency":1,"inventory_counts":[]},{"currency":10,"inventory_counts":{"wet_chitin":-1}}]:
        tree.check(not PLAN.report(build,ids,bad).valid,"malformed wallet counters are rejected by the same build counter rules")
    wallet.currency=500
    wallet.inventory_counts={"wet_chitin":10,"pollen_wax":3,"evidence_counterweight_echo":1,"evidence_root_track":1}
    plan=PLAN.report(build,ids,wallet)
    var quote: Dictionary=build.quote_craft_batch(ids,wallet)
    tree.check(plan.ready==quote.ok and plan.ready and plan.currency.remaining==330,"ready planning agrees with the actual detached batch transaction")
    tree.check(plan.materials[1].remaining==7 and plan.patterns[0].owned==1 and not plan.patterns[0].missing,"surplus and a single shared proof are displayed without consuming either")
    build.catalog.recipes.mod_lure.materials.wet_chitin=2
    plan=PLAN.report(build,ids,wallet)
    tree.check(plan.materials[1].required==5 and plan.materials[1].remaining==5,"shared consumed material is summed across recipes rather than checked independently")
    build.catalog.recipes.mod_lure.requires_items.append("evidence_counterweight_echo")
    plan=PLAN.report(build,ids,wallet)
    tree.check(plan.patterns.size()==2 and plan.patterns[0].owned==1,"a shared nonconsumed pattern is required once for multiple pieces")
    build.catalog.recipes.mod_mine.currency+=17
    plan=PLAN.report(build,ids,wallet)
    tree.check(plan.currency.required==187 and plan.currency.remaining==313,"planning reads current authored prices, including repricing")
    var second:=PLAN.report(build,["pilgrim_mod_mine"],wallet)
    tree.check(second.valid and not second.ready and second.rows[0].prerequisites==["mod_mine"],"unmade first tier remains an explicit condition even when material totals can be computed")
    # Every actual recipe gets a complete, independent item/material breakdown.
    for id in build.catalog.recipes:
        var recipe: Dictionary=build.catalog.recipes[id]
        var single:=PLAN.report(build,[String(id)],wallet)
        tree.check(single.valid and single.rows.size()==1 and single.currency.required==int(recipe.currency),"every real recipe has its full authored cost and one inspectable row: "+String(id))
        var costs:={}
        for row in single.materials:costs[row.id]=row.required
        var expected:={}
        for material in recipe.materials:expected[String(material)]=int(recipe.materials[material])
        tree.check(costs==expected and single.ready==build.quote_craft_batch([String(id)],wallet).ok,"material costs and actual readiness match the production quote: "+String(id))

static func effects(tree: SceneTree) -> void:
    var build:=BUILD.new()
    build.unlock_event("tool_mine_found")
    var wallet:={"currency":1000,"inventory_counts":{}}
    for recipe in build.catalog.recipes.values():
        for id in recipe.materials:wallet.inventory_counts[id]=100
        for id in recipe.get("requires_items",[]):wallet.inventory_counts[id]=1
    var before: Dictionary=build.serialize()
    var plan:=PLAN.report(build,["mod_mine"],wallet)
    tree.check(plan.ready and plan.effects.available and plan.effects.tools.size()==1,"eligible actual tool craft exposes a detached capacity result")
    var tool: Dictionary=plan.effects.tools[0]
    tree.check(tool.id=="mine" and tool.after==tool.before+1 and tool.stock_after==tool.stock_before,"capacity preview shows one extra empty slot, without a free tool charge")
    tree.check(build.serialize()==before and wallet.currency==1000,"effect comparison changes neither original build nor wallet")
    var model:=BUILD.new()
    model.restore(before)
    var actual: Dictionary=model.transact("mod_mine",wallet)
    tree.check(actual.ok and model.tool_capacity("mine")==tool.after and model.state.tool_counts.mine==tool.stock_after,"preview capacity and stock equal an actual model transaction")
    var text:=PLAN.text(plan,func(id: String):return id,func(_id: String):return "")
    tree.check(text.contains("现有次数") and text.contains("不会自动装备"),"readable report distinguishes purchased capacity from stock and active equipment")
    plan=PLAN.report(build,["clasp_travel"],wallet)
    tree.check(plan.ready and plan.effects.parts.size()==1 and plan.effects.slots.is_empty(),"an unrepaired crest does not gain a usable slot merely because a part is crafted")
    build.unlock_event("repair_crimson")
    plan=PLAN.report(build,["clasp_travel"],wallet)
    tree.check(plan.effects.slots.size()==1 and plan.effects.slots[0].crest=="crimson" and plan.effects.slots[0].family=="travel_accessory" and plan.effects.slots[0].index==2,"repaired crest preview identifies the exact newly opened third travel slot")
    before=build.serialize()
    plan=PLAN.report(build,["craft_pilgrim_braid"],wallet)
    tree.check(plan.ready and plan.effects.equipment.size()==1 and plan.effects.equipment[0].id=="pilgrim_braid","crafted accessory is presented as newly available equipment")
    tree.check(build.state.passives==before.passives and plan.effects.slots.is_empty(),"unlocking an accessory never predicts a silent auto-equip or extra slot")
    plan=PLAN.report(build,["branch_cleave_a"],wallet)
    tree.check(plan.ready and plan.effects.skills.size()==1 and plan.effects.skills[0].id=="cleave" and plan.effects.skills[0].before=="未校习","skill crafting preview distinguishes a selected direction from an untrained skill")
    tree.check(plan.effects.skills[0].after==build.catalog.skills.cleave.branches.a.name,"skill preview uses the production branch label")
    var poor:=wallet.duplicate(true);poor.currency=0
    plan=PLAN.report(build,["mod_mine"],poor)
    tree.check(not plan.ready and not plan.effects.available and plan.effects.tools.is_empty(),"a rejected real quote never produces a purchasable effect preview")
    tree.check(build.serialize()==before,"all mixed effect previews leave the live model unchanged")

static func native(tree: SceneTree, scene: Node, dialog: ConfirmationDialog, save_path: String) -> void:
    var before: Dictionary=tree.snapshot(scene)
    var disk:=FileAccess.get_file_as_bytes(save_path)
    var wallet: Dictionary=scene._build_wallet_snapshot()
    tree.check(dialog.summary is RichTextLabel and dialog.summary.scroll_active and dialog.summary.focus_mode==Control.FOCUS_ALL,"long material reports are keyboard/joypad readable in a native scrolling control")
    tree.check(not dialog.summary.bbcode_enabled and dialog.summary.text.contains("湿锈甲片") and dialog.summary.text.contains("湿冷甲片"),"production planning uses actual public item names and source/use descriptions as plain text")
    tree.check(dialog.summary.text.contains("配重余响") and dialog.summary.text.contains("根网爪痕") and dialog.summary.text.contains("只出示，不消耗"),"actual cart shows all retained patterns alongside consumed material")
    var selected: Array=dialog.selected.duplicate()
    dialog.query.grab_focus()
    dialog.query.text="不匹配任何制作名称"
    dialog.query.text_changed.emit(dialog.query.text)
    tree.check(dialog.switches.is_empty() and dialog.selected==selected and dialog.quote.ok,"empty search preserves the quoted selection instead of silently dropping hidden recipes")
    tree.check(dialog.query.has_focus() and tree.snapshot(scene)==before,"typing in search retains focus and changes no World owner")
    dialog.query.text="铜铃"
    dialog.query.text_changed.emit(dialog.query.text)
    tree.check(dialog.switches.is_empty(),"current smith filter never reveals another artisan's copper-pot recipe")
    dialog.query.text="绊线"
    dialog.query.text_changed.emit(dialog.query.text)
    await tree.process_frame
    tree.check(dialog.switches.has("mod_mine") and dialog.switches.mod_mine.button_pressed and dialog.selected==selected,"search narrows visible rows and restores exact checkbox selection")
    dialog.query.text_submitted.emit(dialog.query.text)
    tree.check(dialog.switches.mod_mine.has_focus() and tree.snapshot(scene)==before,"Enter focuses a matching recipe without buying or changing selection")
    dialog.query.text=""
    dialog.query.text_changed.emit(dialog.query.text)
    scene.build_system.state.crafted.append("mod_mine")
    dialog.unfinished.button_pressed=true
    tree.check(not dialog.switches.has("mod_mine") and dialog.selected==selected,"completed-only filter retains its hidden selected item for an honest rejected quote")
    scene.build_system.state.crafted.erase("mod_mine")
    dialog.unfinished.button_pressed=false
    scene.currency_count=1
    scene.inventory_counts.wet_chitin=0
    scene.inventory_counts.pollen_wax=0
    scene.inventory_counts.erase("evidence_counterweight_echo")
    scene.inventory_counts.erase("evidence_root_track")
    dialog._refresh_quote()
    tree.check(not dialog.quote.ok and dialog.get_ok_button().disabled and dialog.plan.materials.size()==2 and dialog.plan.patterns.size()==2,"actual poor wallet shows all shortages while authoritative confirmation stays disabled")
    tree.check(dialog.plan.currency.missing==169 and dialog.summary.text.contains("缺169"),"currency deficit follows current live wallet exactly")
    tree.check(FileAccess.get_file_as_bytes(save_path)==disk,"search/filter/planning have not written a save")
    scene.currency_count=wallet.currency
    scene.inventory_counts=wallet.inventory_counts.duplicate(true)
    dialog._refresh_quote()
    tree.check(dialog.quote.ok and tree.snapshot(scene)==before,"restoring live resources produces a new valid quote with no hidden transaction")
    dialog.custom_action.emit("clear")
    tree.check(dialog.selected.is_empty() and not dialog.quote.ok and not dialog.staged and dialog.get_cancel_button().has_focus(),"clear action removes even hidden selections and returns to safe cancellation")
    for id in selected:dialog.set_recipe(String(id),true)
    tree.check(dialog.quote.ok and tree.snapshot(scene)==before and FileAccess.get_file_as_bytes(save_path)==disk,"reselecting full cart restores the same quote without touching durable state")
    dialog.hide()
    dialog.staged=true
    dialog.confirmed.emit()
    tree.check(tree.snapshot(scene)==before and FileAccess.get_file_as_bytes(save_path)==disk,"late confirmation from a hidden cart cannot purchase even a previously staged selection")
    dialog.open()
    tree.check(not dialog.staged and dialog.selected.is_empty(),"reopening starts a fresh explicit plan after closing a staged cart")
    for id in selected:dialog.set_recipe(String(id),true)
    var rows: Control=dialog.rows
    await tree.process_frame
    var area:=Rect2(Vector2.ZERO,Vector2(dialog.size))
    tree.check(area.encloses(dialog.summary.get_global_rect()) and area.encloses(dialog.query.get_global_rect()),"search and long scrolling report remain inside the actual native dialog")
    tree.check(not dialog.summary.get_global_rect().intersects(rows.get_parent().get_global_rect()),"report does not print over the selectable recipe scroll area")
