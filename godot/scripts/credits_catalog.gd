extends RefCounted
## Reads the packaged release notices. No network, user files or gameplay state.
const INDEX := "res://data/credits/index.json"
const PREFIX := "res://data/credits/"
const GROUPS := ["项目说明","引擎扩展","字体","素材记录"]
const MAX_DOCUMENT := 262144
const MAX_TOTAL := 1048576
var entries: Array[Dictionary]=[]
var error:=""

static func clean_string(value: Variant, maximum: int) -> bool:
    if not value is String or value.is_empty() or value.length()>maximum:return false
    for index in value.length():
        if value.unicode_at(index)<32 or value.unicode_at(index)==127:return false
    return true

static func hex_string(value: Variant, length: int) -> bool:
    if not value is String or value.length()!=length:return false
    for character in value:
        if not character in "0123456789abcdef":return false
    return true

static func valid_entry(value: Variant) -> bool:
    if not value is Dictionary or value.size()!=7:return false
    if not hex_string(value.get("id"),12) or not hex_string(value.get("sha256"),64):return false
    if not clean_string(value.get("title"),180) or value.get("group") not in GROUPS:return false
    if not clean_string(value.get("source"),512):return false
    var source:=String(value.source)
    if source.begins_with("/") or source.contains("\\") or source.contains(":") or source.split("/").has("..") or source.split("/").has("."):return false
    if value.get("file")!=PREFIX+String(value.id)+".txt":return false
    var count: Variant=value.get("bytes")
    return typeof(count) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(count)) and float(count)==floor(float(count)) and float(count)>0 and float(count)<=MAX_DOCUMENT

func restore(data: Variant) -> bool:
    entries=[];error=""
    if not data is Dictionary or data.size()!=2 or typeof(data.get("version")) not in [TYPE_INT,TYPE_FLOAT] or data.version!=1 or not data.get("entries") is Array or data.entries.is_empty() or data.entries.size()>64:
        error="来源目录格式不兼容，未显示未经核对的内容。";return false
    var ids:={};var sources:={};var total:=0
    for entry in data.entries:
        if not valid_entry(entry) or ids.has(entry.id) or sources.has(entry.source):
            entries=[];error="来源目录存在损坏或重复条目。";return false
        ids[entry.id]=true;sources[entry.source]=true;total+=int(entry.bytes)
        if total>MAX_TOTAL:entries=[];error="来源目录超过阅读容量。";return false
        entries.append(entry.duplicate(true))
    return true

func load_catalog() -> bool:
    entries=[];error=""
    var file:=FileAccess.open(INDEX,FileAccess.READ)
    if file==null:error="发行包未包含来源目录。";return false
    if file.get_length()>131072:error="来源目录过大。";return false
    var parser:=JSON.new()
    if parser.parse(file.get_as_text())!=OK:error="来源目录无法解析。";return false
    return restore(parser.data)

func groups() -> Array[String]:
    var result: Array[String]=["全部"]
    for group in GROUPS:
        for entry in entries:
            if entry.group==group:result.append(group);break
    return result

func select(query: String, group: String="全部") -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    var words:=query.strip_edges().to_lower().split(" ",false)
    for entry in entries:
        if group!="全部" and entry.group!=group:continue
        var haystack:=(String(entry.title)+" "+String(entry.source)+" "+String(entry.group)).to_lower()
        var found:=true
        for word in words:
            if not haystack.contains(word):found=false;break
        if found:result.append(entry.duplicate(true))
    return result

func document(id: String) -> Dictionary:
    for entry in entries:
        if entry.id!=id:continue
        var file:=FileAccess.open(String(entry.file),FileAccess.READ)
        if file==null:return {"ok":false,"reason":"此来源文件未包含在发行包中。"}
        if file.get_length()!=int(entry.bytes):return {"ok":false,"reason":"来源文件长度与目录不符，未显示不完整文本。"}
        var bytes:=file.get_buffer(int(entry.bytes))
        var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
        if hash.finish().hex_encode()!=entry.sha256:return {"ok":false,"reason":"来源文件与目录记录不符，请使用完整发行包。"}
        if bytes.has(0):return {"ok":false,"reason":"来源文件不是可阅读文本。"}
        var text:=bytes.get_string_from_utf8().trim_prefix(String.chr(65279))
        if text.strip_edges().is_empty():return {"ok":false,"reason":"来源文件不是可阅读文本。"}
        return {"ok":true,"entry":entry.duplicate(true),"text":text}
    return {"ok":false,"reason":"请选择现有来源条目。"}
