extends RefCounted
## Choose an amount through the live quote callback. This planner never pays
## and never estimates affordability from a second copy of price rules.
static func counter(value: Variant, maximum: int=999999) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0 and floor(float(value))==float(value) and float(value)<=maximum

static func plan(owned: Variant, target: Variant, gain: Variant, quote: Callable) -> Dictionary:
    if not counter(owned) or not counter(target) or not counter(gain) or int(gain)<1 or not quote.is_valid():return {"ok":false,"reason":"目标库存或兑换记录无效。"}
    var missing:=maxi(0,int(target)-int(owned))
    if missing==0:return {"ok":false,"satisfied":true,"reason":"目标库存已达到，无需为了这份计划继续兑换。"}
    var needed:=int(ceili(float(missing)/float(gain)))
    var best:=0
    var best_quote: Dictionary={}
    for count in range(mini(10,needed),0,-1):
        var candidate: Variant=quote.call(count)
        if candidate is Dictionary and candidate.get("ok")==true:
            best=count;best_quote=candidate.duplicate(true);break
    if best==0:
        var first: Variant=quote.call(1)
        return {"ok":false,"reason":String(first.get("reason","当前无法兑换。")) if first is Dictionary else "当前无法兑换。"}
    var after:=int(owned)+best*int(gain)
    return {"ok":true,"amount":best,"needed":needed,"owned":int(owned),"target":int(target),"after":after,"shortfall":maxi(0,int(target)-after),"surplus":maxi(0,after-int(target)),"quote":best_quote,
        "reason":"选择%d份后目标材料%d → %d；%s" % [best,int(owned),after,"仍缺%d（受当前资源或十份上限限制）。" % (int(target)-after) if after<int(target) else "达到目标，多出%d。" % maxi(0,after-int(target))]}

static func balance(recipe: Dictionary, before: Dictionary, money: Variant, quoted: Dictionary, name_for: Callable) -> String:
    if not quoted.get("ok",false) or not quoted.get("counts") is Dictionary or not counter(money,9999999) or not counter(quoted.get("money"),9999999):return "本次收支暂不可核对。"
    var lines: Array[String]=["确认成功后的余额（尚未兑换）", "松脂：%d → %d" % [int(money),int(quoted.money)]]
    for id in [recipe.get("input",""),recipe.get("output","")]:
        if not id is String or not counter(before.get(id,0)) or not counter(quoted.counts.get(id,0)):return "本次材料计数无效，暂不可核对。"
        var title:=String(name_for.call(id)) if name_for.is_valid() else "材料"
        lines.append("%s：%d → %d" % [title,int(before.get(id,0)),int(quoted.counts.get(id,0))])
    lines.append("材料、巡礼印、地区与距离仍以确认时的实际报价为准。")
    return "\n".join(lines)
