extends RefCounted
## Presentation-only memory, separated by the four actual equipment families.
const FAMILIES := ["tool", "thread_skill", "combat_accessory", "travel_accessory"]
const QUERY_LIMIT := 96
var pages: Dictionary = {}

static func normalize(query: String) -> String:
    return query.left(QUERY_LIMIT).replace("　", " ").replace("\t", " ").replace("\n", " ").strip_edges().to_lower()

func remember(family: String, query: String, only_compatible: bool) -> void:
    if family not in FAMILIES:
        return
    pages[family] = {"query":query.left(QUERY_LIMIT), "only_compatible":only_compatible}

func page(family: String) -> Dictionary:
    return pages.get(family, {"query":"", "only_compatible":false}).duplicate(true)

static func matches(entry: Dictionary, query: String) -> bool:
    var needle := normalize(query)
    if needle.is_empty():
        return true
    # Index only the already visible name and catalog ID. Hidden requirements,
    # recipe witnesses and future narrative fields never become search results.
    var public := (String(entry.get("name", "")) + " " + String(entry.get("id", ""))).to_lower()
    for token in needle.split(" ", false):
        if not public.contains(token):
            return false
    return true

static func can_assign(entry: Dictionary, family: String, slot: Dictionary) -> bool:
    if not bool(entry.get("unlocked", true)):
        return false
    if String(entry.get("slot_family", family)) != family:
        return false
    var occupied: Variant=entry.get("equipped_slots",[])
    if not occupied is Array:return false
    var selected:=int(slot.get("index",-1))
    for index in occupied:
        if not index is int or index!=selected:return false
    if slot.is_empty():
        return true
    if not bool(slot.get("unlocked", false)):
        return false
    var compatible: Variant = slot.get("compatible", [])
    return compatible is Array and (compatible.is_empty() or compatible.has(String(entry.get("id", ""))))

static func select(entries: Array, family: String, slot: Dictionary, query: String, only_compatible: bool, validator: Callable = Callable()) -> Dictionary:
    var visible: Array = []
    var total := 0
    for value in entries:
        if not value is Dictionary:
            continue
        var entry: Dictionary = value
        total += 1
        if not matches(entry, query):
            continue
        if only_compatible and not can_assign(entry, family, slot):
            continue
        if only_compatible and validator.is_valid() and not bool(validator.call(entry,family,slot)):
            continue
        visible.append(entry.duplicate(true))
    var empty_reason := "没有匹配的装备，试试其他名称或清除搜索。"
    if only_compatible and not slot.is_empty() and not bool(slot.get("unlocked", false)):
        empty_reason = "当前槽位尚未解锁；可关闭筛选查看已知装备与解锁提示。"
    elif only_compatible:
        empty_reason = "没有匹配当前槽位的装备；可清除搜索或关闭兼容筛选。"
    return {"entries":visible, "total":total, "shown":visible.size(), "empty_reason":empty_reason}

static func first_enabled(grid: Control) -> Button:
    if not is_instance_valid(grid):
        return null
    for node in grid.get_children():
        if node is Button and node.is_visible_in_tree() and not node.disabled and not node.is_queued_for_deletion():
            return node
    return null
