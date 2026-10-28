extends RefCounted
## Knowledge filtering is separate from the pure search; never load unknown regions.
const MARKET:=preload("res://scripts/material_exchange.gd")
const CONTRACTS:=preload("res://scripts/field_contracts.gd")
static func entries(level: Node) -> Array:
    var result: Array=[]
    for recipe in MARKET.recipes():
        if not CONTRACTS.known(level,String(recipe.region)) or not CONTRACTS.known(level,String(recipe.target_region)):continue
        var permit: Variant=level.inventory_counts.get(recipe.requires_item,0)
        if not MARKET.counter(permit) or int(permit)<1:continue
        result.append(recipe.duplicate(true))
    return result
