extends RefCounted
## Literal matches over one already-disclosed document, never the journal catalog.
const MAX_TEXT:=65536
const MAX_QUERY:=80
const MAX_MATCHES:=512

static func normalized(text: String) -> String:
    return text.replace("\r\n","\n").replace("\r","\n")

static func line_starts(text: String) -> PackedInt32Array:
    var result:=PackedInt32Array([0])
    var index:=text.find("\n")
    while index>=0:
        result.append(index+1);index=text.find("\n",index+1)
    return result

static func coordinates(starts: PackedInt32Array, position: int) -> Vector2i:
    var low:=0;var high:=starts.size()
    while low+1<high:
        var middle: int=(low+high)/2
        if starts[middle]<=position:low=middle
        else:high=middle
    return Vector2i(position-starts[low],low)

static func search(source: String, query: String, match_case: bool=false) -> Dictionary:
    var result:={"ok":false,"reason":"","text":"","matches":[],"limited":false}
    if source.length()>MAX_TEXT:
        result.reason="本条内容超过页内查找上限，原文和阅读位置保留。";return result
    if query.length()>MAX_QUERY:
        result.reason="查找文字最多80个字符，未截断后猜测匹配。";return result
    var text:=normalized(source);var needle:=normalized(query)
    result.ok=true;result.text=text
    if needle.is_empty():result.reason="输入要在本条正文中查找的字面文字。";return result
    var starts:=line_starts(text)
    var cursor:=0
    var index:=text.find(needle,cursor) if match_case else text.findn(needle,cursor)
    while index>=0 and result.matches.size()<MAX_MATCHES:
        var end:=index+needle.length()
        var first:=coordinates(starts,index);var last:=coordinates(starts,end)
        var preview_start:=maxi(0,index-20)
        var preview:=text.substr(preview_start,mini(text.length()-preview_start,needle.length()+60)).replace("\n"," ↵ ")
        result.matches.append({"start":index,"end":end,"line":first.y,"column":first.x,"end_line":last.y,"end_column":last.x,"preview":preview})
        # Include overlapping literal occurrences; movement still advances one codepoint.
        cursor=index+1
        index=text.find(needle,cursor) if match_case else text.findn(needle,cursor)
    result.limited=index>=0
    result.reason="未在本条正文中找到；不会搜索未知记录。" if result.matches.is_empty() else "至少%d处匹配，仅列前%d处。" % [MAX_MATCHES,MAX_MATCHES] if result.limited else "本条正文共%d处匹配。" % result.matches.size()
    return result

static func navigate(count: int, current: int, direction: int) -> int:
    if count<=0:return -1
    if current<0 or current>=count:return count-1 if direction<0 else 0
    return wrapi(current+(-1 if direction<0 else 1),0,count)
