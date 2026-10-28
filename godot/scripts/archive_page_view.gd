extends RefCounted
## Treat a browser callback as untrusted data, not a typed save object.
static func number(value: Variant, maximum: int) -> int:
    return clampi(int(value),0,maximum) if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0.0 and float(value)<=maximum else 0
static func text(value: Variant, fallback: String, limit: int=256) -> String:
    return value.left(limit) if value is String else fallback
static func page(value: Variant, requested: int, limit: int, max_offset: int) -> Dictionary:
    var source: Dictionary=value if value is Dictionary else {}
    var offset:=number(source.get("offset",requested),max_offset)
    offset=offset/limit*limit
    var rows: Array=[]
    var raw: Variant=source.get("entries",[])
    if raw is Array:
        for item in raw.slice(0,limit):
            var row: Dictionary=item if item is Dictionary else {}
            var hash:=text(row.get("sha256"),"",64)
            var valid: bool=row.get("valid") is bool and row.valid and hash.length()==64 and hash.is_valid_hex_number(false) and row.get("file") is String and not row.file.is_empty() and row.file.length()<=256
            var clean:={"valid":valid,"file":text(row.get("file"),"不可读取的记录"),"sha256":hash,"modified":number(row.get("modified"),253402300799),"region_name":text(row.get("region_name"),"旧旅途区域"),"error":text(row.get("error"),"记录格式或身份无效。")}
            for key in ["regions","rooms","bosses","currency"]:clean[key]=number(row.get(key),1000000000)
            rows.append(clean)
    return {"entries":rows,"offset":offset,"total":number(source.get("total"),1000000000),"has_more":source.get("has_more",false)==true,"error":text(source.get("error"),"" if value is Dictionary else "记录查询暂不可用，请刷新。")}
static func detail(value: Variant) -> Dictionary:
    if not value is Dictionary:return {"ok":false,"reason":"归档详情暂不可用。"}
    var result:={"ok":value.get("ok")==true,"reason":text(value.get("reason"),"只读浏览。",1024),"sections":[]}
    var raw: Variant=value.get("sections",[])
    if not raw is Array:return {"ok":false,"reason":"归档详情格式无效。"}
    var remaining:=64000
    for item in raw.slice(0,64):
        if not item is Dictionary or not item.get("title") is String or not item.get("lines") is Array:continue
        var lines: Array[String]=[]
        for line in item.lines.slice(0,64):
            if not line is String or remaining<=0:continue
            var clean: String=line.left(mini(remaining,4096));remaining-=clean.length();lines.append(clean)
        result.sections.append({"title":item.title.left(256),"lines":lines})
    return result
