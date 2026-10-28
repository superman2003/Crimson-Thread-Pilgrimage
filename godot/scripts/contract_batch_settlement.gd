extends RefCounted
## Aggregate detached canonical single-claim quotes, then publish once through
## FieldTransaction. Individual failures must never leave a partial reward.
const LIMIT := 3

static func counter(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0 and floor(float(value))==float(value) and float(value)<=999999

static func quote(entries: Array, counts: Dictionary, flags: Dictionary, single_quote: Callable) -> Dictionary:
    if not single_quote.is_valid():return failure("当前无法核对契约。")
    var selected: Array=[]
    var seen: Dictionary={}
    for row in entries:
        if not row is Dictionary:continue
        if row.get("accepted")!=true or row.get("ready")!=true or row.get("claimed")==true:continue
        var id: Variant=row.get("contract_id")
        if not id is String or id.is_empty() or seen.has(id):return failure("契约清单含重复或无效条目，请刷新。")
        seen[id]=true;selected.append(row)
    if selected.is_empty() or selected.size()>LIMIT:return failure("当前筛选中需要有1至3份待登记回礼。")
    var candidate_counts:=counts.duplicate(true)
    var candidate_flags:=flags.duplicate(true)
    var fingerprints: Array=[]
    var ids: Array[String]=[]
    var lines: Array[String]=["统一登记以下%d份契约；全部成功写入才领取回礼。" % selected.size()]
    for row in selected:
        var quoted: Variant=single_quote.call(String(row.contract_id))
        if not quoted is Dictionary or not quoted.get("ok",false):return failure(String(quoted.get("reason","单份契约无法核对。")) if quoted is Dictionary else "单份契约无法核对。")
        if not quoted.get("counts") is Dictionary or not quoted.get("flags") is Dictionary or not quoted.get("fingerprint") is String:return failure("契约报价记录不完整。")
        for item in quoted.counts:
            var before: Variant=counts.get(item,0)
            var after: Variant=quoted.counts[item]
            var accumulated: Variant=candidate_counts.get(item,0)
            if not counter(before) or not counter(after) or not counter(accumulated):return failure("回礼库存无效，未登记。")
            var difference:=int(after)-int(before)
            if difference<0 or int(accumulated)+difference>999999:return failure("回礼超过库存上限，或报价包含意外扣除。")
            candidate_counts[item]=int(accumulated)+difference
        for key in counts:
            if not quoted.counts.has(key):return failure("报价缺失原库存，未登记。")
        for key in quoted.flags:
            if quoted.flags[key]==flags.get(key):continue
            if quoted.flags[key]!=true:return failure("报价包含非领取状态变化，未登记。")
            candidate_flags[key]=true
        fingerprints.append(quoted.fingerprint)
        ids.append(String(row.contract_id))
        lines.append("· "+String(quoted.get("summary",row.get("title","契约"))))
    var fingerprint:=var_to_str([ids,fingerprints,counts,flags,candidate_counts,candidate_flags]).sha256_text()
    return {"ok":true,"ids":ids,"counts":candidate_counts,"flags":candidate_flags,"fingerprint":fingerprint,"summary":"\n".join(lines)}

static func failure(reason: String) -> Dictionary:
    return {"ok":false,"reason":reason}
