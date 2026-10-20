extends RefCounted
const BUILD := preload("res://scripts/build_system.gd")
const CRAFTS := {"tide_reel":"demo_ch02_rain_foundry_canal","wax_stitch":"demo_ch04_broken_string_greenhouse","ash_ring":"demo_ch01_moss_bell_court","crown_pendant":"demo_ch02_rain_foundry_canal"}

func run(suite: SceneTree) -> void:
    var main: Node=suite.scene
    var model: RefCounted=main.build_system
    for id in CRAFTS:
        var recipe_id := "craft_"+String(id)
        var recipe: Dictionary=model.catalog.recipes[recipe_id]
        suite.check(await suite.stand_at(CRAFTS[id],String(recipe.artisan)),"proof craft reaches the named artisan: "+String(id))
        var check: Callable=suite.check
        var pattern := String(recipe.requires_items[0])
        main.currency_count=600
        main.inventory_counts[pattern]=0
        for material in recipe.materials:main.inventory_counts[material]=recipe.materials[material]
        var before: Dictionary=model.serialize()
        var wallet: Dictionary=main._build_wallet_snapshot()
        var missing: Dictionary=main.perform_build_action("transact",recipe_id)
        check.call(not bool(missing.ok) and model.serialize()==before and main._build_wallet_snapshot()==wallet,"zero-count proof cannot unlock or spend: "+String(id))
        main.inventory_counts[pattern]=1
        var material := String(recipe.materials.keys()[0])
        main.inventory_counts[material]=int(recipe.materials[material])-1
        wallet=main._build_wallet_snapshot()
        var poor: Dictionary=main.perform_build_action("transact",recipe_id)
        check.call(not bool(poor.ok) and main._build_wallet_snapshot()==wallet,"insufficient regional material is atomic: "+String(id))
        main.inventory_counts[material]=recipe.materials[material]
        wallet=main._build_wallet_snapshot()
        before=model.serialize()
        var hp: int=main.player.hp
        var energy: int=main.player.energy
        main.world_save_failure_injected_for_validation=true
        var unsaved: Dictionary=main.perform_build_action("transact",recipe_id)
        main.world_save_failure_injected_for_validation=false
        check.call(not bool(unsaved.ok) and model.serialize()==before and main._build_wallet_snapshot()==wallet,"failed save rolls back new accessory ownership and wallet: "+String(id))
        var made: Dictionary=main.perform_build_action("transact",recipe_id)
        check.call(bool(made.ok) and model.state.unlocked_passives.has(id),"real artisan transaction unlocks accessory: "+String(id))
        check.call(int(main.currency_count)==int(wallet.currency)-int(recipe.currency) and int(main.inventory_counts[material])==0,"craft pays the exact price and three regional materials: "+String(id))
        check.call(int(main.inventory_counts[pattern])==1 and not model.state.passives.has(id),"pattern remains and item is not automatically equipped: "+String(id))
        check.call(main.player.hp==hp and main.player.energy==energy,"crafting grants no HP or energy refill: "+String(id))
        var duplicate_wallet: Dictionary=main._build_wallet_snapshot()
        check.call(not bool(main.perform_build_action("transact",recipe_id).ok) and main._build_wallet_snapshot()==duplicate_wallet,"duplicate craft spends nothing: "+String(id))
        var restored := BUILD.new()
        check.call(restored.restore(JSON.parse_string(JSON.stringify(model.serialize()))).ok and restored.state.unlocked_passives.has(id),"crafted accessory survives JSON restart: "+String(id))
        var ui: Node=main.ui_shell
        ui.build_category="强化"
        ui.refresh_build()
        var row := {}
        for entry in model.get_snapshot().recipes:
            if String(entry.id)==recipe_id:row=entry
        ui._show_build_detail(row)
        check.call(bool(row.get("crafted",false)) and String(ui.build_detail.text).contains("不会自动穿戴") and String(ui.build_detail.text).contains("图样"),"craft UI names ownership, equip condition and retained pattern: "+String(id))
    # All three spindle variants trade off rather than stack their benefits.
    model.unlock_event("charm_reflux_found")
    var result: Dictionary=model.equip_passives(["reflux","tide_reel"])
    suite.check(not bool(result.ok) and String(result.reason).contains("互斥"),"existing spool and inverse spool cannot be stacked")
    result=model.equip_passives(["tide_reel","crown_pendant"])
    suite.check(not bool(result.ok),"two new spindle variants cannot be stacked")
