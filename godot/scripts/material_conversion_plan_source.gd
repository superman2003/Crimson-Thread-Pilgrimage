extends RefCounted
## Snapshot only disclosed conversion opportunities; never opens a future region.
const MARKET:=preload("res://scripts/material_exchange.gd")
const CONTRACTS:=preload("res://scripts/field_contracts.gd")
const MODEL:=preload("res://scripts/material_conversion_plan.gd")
const ROUTES:=preload("res://scripts/world_routes.gd")

static func entries(level: Node) -> Array:
    var result: Array=[]
    for recipe in MARKET.recipes():
        if not CONTRACTS.known(level,String(recipe.region)):continue
        if not CONTRACTS.known(level,String(recipe.target_region)):continue
        var permit: Variant=level.inventory_counts.get(recipe.requires_item,0)
        if not MARKET.counter(permit) or int(permit)<1:continue
        result.append(recipe.duplicate(true))
    return result

static func snapshot(level: Node) -> Dictionary:
    if not is_instance_valid(level) or level.is_queued_for_deletion():return {}
    if not level.initial_region_ready or level.world_loading or level.chapter_transitioning:return {}
    var recipes:=entries(level)
    var inventory: Dictionary=level.inventory_counts.duplicate(true)
    var money: Variant=level.currency_count
    var ids: Array=[]
    for recipe in recipes:
        for id in [recipe.input,recipe.output]:
            if not ids.has(id):ids.append(String(id))
    ids.sort()
    return {
        "recipes":recipes,
        "inventory":inventory,
        "money":money,
        "targets":ids,
        "fingerprint":var_to_str([level.get_instance_id(),level.world_save_path,level.world_state.get_instance_id(),level.config.id,recipes,inventory,money]).sha256_text()
    }

static func allowance(money: Variant,budget: Variant,reserve: Variant) -> Dictionary:
    for value in [money,budget,reserve]:
        if not MODEL.natural(value,9999999):return {"ok":false,"reason":"预算与保留松脂须为有效整数。"}
    if int(reserve)>int(money):return {"ok":false,"reason":"保留松脂超过现有钱包，未规划。"}
    if int(budget)>int(money):return {"ok":false,"reason":"预算超过现有钱包，未规划。"}
    return {"ok":true,"spendable":mini(int(budget),int(money)-int(reserve))}

static func region_name(id: String) -> String:
    var path:=ROUTES.cached_config_path(id)
    if path.is_empty():return "已到地区"
    var config: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    return String(config.get("chapter_name","已到地区")) if config is Dictionary else "已到地区"

static func describe(level: Node,context: Dictionary,target: String,required: int,result: Dictionary,spendable: int,reserve: int) -> String:
    if not result.get("ok",false):return String(result.get("reason","尚无计算结果。"))
    if not MODEL.verify(context.recipes,context.inventory,spendable,target,required,result):
        return "规划重放核对失败，未展示无效收支。"
    var lines: Array[String]=[
        "目标持有总量：%s × %d" % [level._item_display_name(target),required],
        "预计花费松脂 %d；实际钱包预计剩余 %d（含另行保留的 %d）。" % [result.cost,int(context.money)-int(result.cost),reserve]
    ]
    var by_id:={}
    for recipe in context.recipes:by_id[recipe.id]=recipe
    if result.path.is_empty():lines.append("现有材料已满足目标，无须兑换。")
    for index in result.path.size():
        var step: Dictionary=result.path[index]
        var recipe: Dictionary=by_id[step.recipe]
        lines.append("%d. 前往%s的真实钟龛：交出%s × %d、松脂 %d，换取%s × %d（%d份）。" % [
            index+1,region_name(String(recipe.region)),
            level._item_display_name(String(recipe.input)),step.spent,step.cost,
            level._item_display_name(String(recipe.output)),step.gained,step.batches
        ])
    lines.append("材料收支核对：")
    var ids: Array=result.counts.keys()
    ids.sort()
    for id in ids:
        var before:=int(context.inventory.get(id,0))
        var after:=int(result.counts[id])
        if before==after:continue
        lines.append("%s：%d → %d（%+d）" % [level._item_display_name(String(id)),before,after,after-before])
    lines.append("只读安排，没有扣款、预留材料、执行交易、移动角色或保存。巡礼印仅作凭证、不消耗。")
    lines.append("仅在已知兑换中核对最多四次交易；不计算途中战斗、拾取、商店补货或物理可达性。实际到场仍须逐次核对报价。")
    return "\n\n".join(lines)
