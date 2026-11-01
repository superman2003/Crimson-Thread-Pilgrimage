extends RefCounted
## No actor references survive a tick. At most two acoustic rays per 100ms.
const INTERVAL_MS:=100
const MAX_PER_TICK:=2
var cursor:=0
var next_ms:=0
func choose(count: int,now: int) -> Array[int]:
    var indices: Array[int]=[]
    if count<=0:cursor=0;next_ms=0;return indices
    if now<next_ms:return indices
    next_ms=now+INTERVAL_MS
    for offset in mini(count,MAX_PER_TICK):indices.append((cursor+offset)%count)
    cursor=(cursor+indices.size())%count
    return indices
