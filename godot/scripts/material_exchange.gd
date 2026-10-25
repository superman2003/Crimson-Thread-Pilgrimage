extends RefCounted
const LIMIT := 10
static func recipes() -> Array:
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/material_exchange.json"))
    return data.recipes.duplicate(true)

static func entries(level: Node) -> Array:
    var rows: Array=[]
    for recipe in recipes():
        if recipe.region!=level.config.id:continue
        if not preload("res://scripts/field_contracts.gd").known(level,String(recipe.target_region)):continue
        rows.append(recipe)
    return rows

static func counter(value: Variant,maximum: int=999999) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0 and float(value)==floor(float(value)) and float(value)<=maximum

static func quote(level: Node,id: String,batches: Variant) -> Dictionary:
    if not preload("res://scripts/field_transaction.gd").ready(level):return {"ok":false,"reason":"在本区真实钟龛旁打开兑换簿。"}
    if not counter(batches,LIMIT) or int(batches)<1:return {"ok":false,"reason":"一次兑换一至十份，数量须为整数。"}
    var recipe: Dictionary={}
    for row in entries(level):
        if row.id==id:recipe=row;break
    if recipe.is_empty():return {"ok":false,"reason":"当前地区尚无这条已知道路的兑换。"}
    var counts: Dictionary=level.inventory_counts.duplicate(true)
    var proof: Variant=counts.get(recipe.requires_item,0)
    if not counter(proof) or int(proof)<1:return {"ok":false,"reason":"先完成本区契约，出示巡礼印（不消耗）。"}
    for item in [recipe.input,recipe.output]:
        if not counter(counts.get(item,0)):return {"ok":false,"reason":"材料库存无效，未兑换。"}
    var spent:=int(recipe.input_amount)*int(batches);var gained:=int(recipe.output_amount)*int(batches);var cost:=int(recipe.currency)*int(batches)
    if int(counts.get(recipe.input,0))<spent:return {"ok":false,"reason":"本区材料不足。"}
    if not counter(level.currency_count,9999999) or int(level.currency_count)<cost:return {"ok":false,"reason":"松脂不足。"}
    if int(counts.get(recipe.output,0))+gained>999999:return {"ok":false,"reason":"目标材料超过保存上限。"}
    counts[recipe.input]=int(counts.get(recipe.input,0))-spent;counts[recipe.output]=int(counts.get(recipe.output,0))+gained
    var summary:="交出%s × %d、松脂 %d，换取%s × %d。巡礼印保留。" % [level._item_display_name(String(recipe.input)),spent,cost,level._item_display_name(String(recipe.output)),gained]
    return {"ok":true,"counts":counts,"money":int(level.currency_count)-cost,"summary":summary,
        "fingerprint":var_to_str([recipe,int(batches),level.config.id,level.inventory_counts,level.currency_count,level.story_flags,level.build_system.serialize()]).sha256_text()}

static func perform(level: Node,id: String,batches: Variant,fingerprint: String) -> Dictionary:
    var candidate:=quote(level,id,batches)
    if not candidate.ok:return candidate
    if fingerprint!=candidate.fingerprint:return {"ok":false,"reason":"地区、库存或构筑已改变，请重新核对报价。"}
    var result:=preload("res://scripts/field_transaction.gd").commit(level,candidate.counts,level.story_flags.duplicate(true),int(candidate.money))
    if result.ok:result.reason=candidate.summary+" 已写入归途记录。"
    return result
