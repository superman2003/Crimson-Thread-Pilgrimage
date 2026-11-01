extends SceneTree
const BUILD := preload("res://scripts/build_system.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func run() -> void:
    for tool in ["shard","mine","fog","lure"]:
        var b=BUILD.new();b.unlock_event("tool_"+tool+"_found")
        var id: String="pilgrim_mod_"+String(tool)
        var wallet:={"currency":1000,"inventory_counts":{}}
        for recipe in b.catalog.recipes.values():
            for material in recipe.materials:wallet.inventory_counts[material]=100
            for proof in recipe.get("requires_items",[]):wallet.inventory_counts[proof]=1
        var before: Dictionary=b.serialize()
        check(not b.transact(id,wallet).ok and b.serialize()==before,"second tier requires the original upgrade without mutation")
        check(not b.quote_craft_batch(["mod_"+tool,id],wallet).ok,"cart cannot bypass first-tier confirmation")
        var first: Dictionary=b.transact("mod_"+tool,wallet);wallet=first.wallet
        var count: int=b.state.tool_counts[tool];var capacity: int=b.tool_capacity(tool)
        var quote: Dictionary=b.quote_craft_batch([id],wallet)
        check(quote.ok and b.tool_capacity(tool)==capacity,"batch preview uses a detached build")
        var made: Dictionary=b.transact(id,wallet)
        check(made.ok and b.tool_capacity(tool)==capacity+1 and b.state.tool_counts[tool]==count,"second tier adds one capacity with no free charge")
        for proof in b.catalog.recipes[id].requires_items:check(made.wallet.inventory_counts[proof]==1,"original proof and regional permit remain owned")
        check(not b.transact(id,made.wallet).ok,"second tier cannot be bought twice")
        var saved: Dictionary=b.serialize();var restored=BUILD.new()
        check(restored.restore(saved).ok and restored.tool_capacity(tool)==capacity+1,"larger pouch restores")
        saved.crafted.erase("mod_"+tool)
        check(not BUILD.new().restore(saved).ok,"forged second tier without first tier is rejected")
    var b=BUILD.new();var wallet:={"currency":100,"inventory_counts":{}}
    for id in ["pilgrim_braid","watchmans_knot"]:
        var recipe: Dictionary=b.catalog.recipes["craft_"+id]
        for proof in recipe.requires_items:wallet.inventory_counts[proof]=1
        for material in recipe.materials:wallet.inventory_counts[material]=10
        var baseline: Dictionary=b.profile();var made: Dictionary=b.transact("craft_"+id,wallet);wallet=made.wallet
        check(made.ok and b.equip_passives([id]).ok,"crafted accessory fits the actual typed equipment model")
        var profile: Dictionary=b.profile()
        check(profile.move_mult>baseline.move_mult and profile.heal_duration>baseline.heal_duration if id=="pilgrim_braid" else profile.knockback_mult<1.0 and profile.energy_gain_mult<1.0,"equipped accessory changes real stats with its stated tradeoff")
        b.equip_passives([])
    for failure in failures:push_error(failure)
    print("ARTISAN_GROWTH checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
