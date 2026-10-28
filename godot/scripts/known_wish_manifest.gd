extends RefCounted
## Public projection of already asked/completed delivery wishes, never an offer/transaction.
const MAX_ROWS:=64
static func marked(flags: Dictionary,key: String) -> bool:
    return not key.is_empty() and flags.get(key) is bool and flags[key]
static func counter(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0 and float(value)<=1000000 and floor(float(value))==float(value)
static func public_name(callback: Callable,id: String) -> String:
    var value: Variant=callback.call(id) if callback.is_valid() else ""
    return String(value) if value is String and not value.is_empty() and value!=id else "已询问的信物"
static func collect(configs: Array,inventory: Dictionary,flags: Dictionary,name_for: Callable) -> Dictionary:
    var rows: Array=[]
    var seen: Dictionary={}
    for config in configs:
        if not config is Dictionary or not config.get("npcs") is Array or not config.get("id") is String or not config.get("name") is String:return {"ok":false,"reason":"已到地区资料暂不可读取。"}
        if config.npcs.size()>256:return {"ok":false,"reason":"地区人物记录超过读取上限。"}
        for npc in config.npcs:
            if not npc is Dictionary or not npc.get("dialogue_topics") is Dictionary:continue
            var quest: Variant=npc.dialogue_topics.get("quest",{})
            if not quest is Dictionary:continue
            var accept: Variant=quest.get("accept_flag","")
            var finish: Variant=quest.get("complete_flag","")
            if not accept is String or not finish is String:continue
            var accepted:=marked(flags,accept)
            var complete:=marked(flags,finish)
            if not accepted and not complete:continue
            if not npc.get("id") is String or not npc.get("name") is String or not quest.get("item") is String or String(quest.item).is_empty() or not quest.get("consume",false) is bool:return {"ok":false,"reason":"已询问心愿的记录无效，未列出不完整清单。"}
            var key:=String(config.id)+":"+String(npc.id)
            if seen.has(key):return {"ok":false,"reason":"人物记录重复，未计算重复交付。"}
            seen[key]=true
            if rows.size()>=MAX_ROWS:return {"ok":false,"reason":"已知心愿超过读取上限，未截取为完整清单。"}
            var held: Variant=inventory.get(quest.item,0)
            var valid:=counter(held)
            rows.append({"key":key,"npc":String(npc.name),"region":String(config.name),"region_id":String(config.id),"item":String(quest.item),"item_name":public_name(name_for,String(quest.item)),"consume":quest.get("consume",false),"complete":complete,"stock_valid":valid,"stock":int(held) if valid else 0,"ready":not complete and valid and int(held)>=1})
    rows.sort_custom(func(a: Dictionary,b: Dictionary):
        var order:=String(a.region).naturalnocasecmp_to(String(b.region))
        return order<0 if order!=0 else String(a.npc).naturalnocasecmp_to(String(b.npc))<0)
    return {"ok":true,"rows":rows}
static func browse(report: Dictionary,query: String="",mode: int=0,region: String="") -> Array:
    var rows: Array=[]
    if not report.get("ok",false):return rows
    var tokens:=query.left(80).to_lower().replace("　"," ").replace("\t"," ").split(" ",false)
    for row in report.rows:
        if mode==1 and (row.complete or not row.ready):continue
        if mode==2 and (row.complete or row.ready):continue
        if mode==3 and not row.complete:continue
        if mode==0 and row.complete:continue
        if not region.is_empty() and row.region_id!=region:continue
        var public_text:=(String(row.npc)+" "+String(row.region)+" "+String(row.item_name)).to_lower()
        var matches:=true
        for token in tokens:
            if not public_text.contains(token):matches=false;break
        if matches:rows.append(row.duplicate(true))
    return rows
static func requirements(rows: Array,preserve_proof: bool=false) -> Array:
    var groups: Dictionary={}
    for row in rows:
        if row.complete:continue
        if not groups.has(row.item):groups[row.item]={"item":row.item,"name":row.item_name,"stock":row.stock,"valid":row.stock_valid,"consume":0,"show":0,"people":[]}
        var group: Dictionary=groups[row.item]
        group.valid=group.valid and row.stock_valid and group.stock==row.stock
        group.consume+=1 if row.consume else 0
        group.show+=0 if row.consume else 1
        group.people.append(String(row.npc))
    var result: Array=[]
    for group in groups.values():
        var proof:=1 if group.show>0 else 0
        group["required"]=int(group.consume)+proof if preserve_proof else maxi(int(group.consume),proof)
        group["deficit"]=maxi(0,int(group.required)-int(group.stock)) if group.valid else -1
        result.append(group.duplicate(true))
    result.sort_custom(func(a: Dictionary,b: Dictionary):return String(a.name).naturalnocasecmp_to(String(b.name))<0)
    return result
static func detail(row: Dictionary) -> String:
    return "%s · 登记地区：%s\n所需：%s × 1\n%s\n%s\n登记地点不保证人物始终在原位；实际交付仍需返回人物身旁，核对当时的正式报价。" % [row.npc,row.region,row.item_name,"消耗一份信物。" if row.consume else "只需出示，不消耗。","已经完成，不重复计入需求。" if row.complete else "库存暂不可读取。" if not row.stock_valid else "当前持有%d；%s" % [row.stock,"信物已备齐。" if row.ready else "尚缺一份信物。"]]
static func totals(rows: Array,preserve_proof: bool) -> String:
    var lines: Array[String]=["以下只汇总当前筛选中未完成的已知心愿；不会预约物品或执行交付。"]
    for group in requirements(rows,preserve_proof):
        lines.append("\n%s：消耗%d份，出示%d次；%s。\n需备%d份；%s。" % [group.name,group.consume,group.show,"消耗后另留一份出示用" if preserve_proof and group.show>0 else "先出示后消耗，可复用一份信物",group.required,"持有%d，缺%d" % [group.stock,group.deficit] if group.valid else "库存无效，未推算缺额"])
    if requirements(rows,preserve_proof).is_empty():lines.append("当前筛选没有未完成的交付需求。")
    return "\n".join(lines)
