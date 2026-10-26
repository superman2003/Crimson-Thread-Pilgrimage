extends "res://journey/tests/support.gd"
const MODEL := preload("res://journey/supplies/model.gd")
func run() -> void:
    label = "SUPPLIES"
    var context := fixture("supplies")
    var state := MODEL.fresh()
    state.seen = {"a":"苔壳", "b":"湿壳"}
    var first := MODEL.create(state, "旅途")
    var a := String(first.selected)
    first = MODEL.line(first, a, "a", 8, 0)
    first = MODEL.create(first, "工房")
    var b := String(first.selected)
    first = MODEL.line(first, b, "a", 8, 1)
    first = MODEL.reserve(first, "a", 2)
    var inventory := {"a":10, "b":3}
    var unchanged := inventory.duplicate(true)
    var allocation := MODEL.allocate(first, inventory)
    check(allocation.rows[0].allocated == 8 and allocation.rows[1].allocated == 0, "higher priority consumes each available unit at most once")
    check(MODEL.audit(first, inventory, allocation).ok and inventory == unchanged, "allocation conserves inventory without mutation")
    var altered := allocation.duplicate(true)
    altered.rows[1].allocated = 8
    check(not MODEL.audit(first, inventory, altered).ok, "audit detects deliberate double allocation")
    check(MODEL.valid(first), "two plans and reserves satisfy persistent schema")
    check(MODEL.create(first, "旅途") == first, "duplicate names rejected")
    check(MODEL.line(first, a, "unknown", 3, 0) == first, "unseen materials cannot enter plans")
    var ended := MODEL.set_done(first, a, "a", true)
    check(MODEL.allocate(ended, inventory).rows[0].pack == b, "ended targets release planning allocation")
    var imported := MODEL.import_pack(first, JSON.stringify({"version":1, "lines":[{"item":"b", "target":2, "priority":1}]}), "导入")
    check(imported.ok and MODEL.valid(imported.data), "known imported item creates a validated plan")
    check(not MODEL.import_pack(first, JSON.stringify({"version":1, "lines":[{"item":"x", "target":2}]}), "未知").ok, "import rejects unknown material")
    check(MODEL.compare(first, a, b).size() == 1, "comparison joins by stable item identity")
    var feature := preload("res://journey/features/supplies.gd").new()
    feature.setup(context)
    feature.data = first
    for tab in ["plans", "stock", "compare", "transfer"]:
        var box := node_container()
        feature.tab = tab
        feature.draw(box)
        await process_frame
        check(box.get_child_count() > 2, "supplies tab builds: " + tab)
        box.free()
    context.store.writable = false
    var prior: Dictionary = feature.data.duplicate(true)
    check(not feature.commit(MODEL.rename(first, a, "候选")) and feature.data == prior, "write failure does not publish candidate")

    var cross: Dictionary = context.snapshot()
    cross.inventory = {"thread_dash":1}
    cross.config = {"inventory":{"catalog":{}}}
    var seen := MODEL.observe(MODEL.fresh(), cross)
    check(seen.seen.has("thread_dash"), "held item catalogue survives travelling to another region")
    var plans := MODEL.create(seen, "甲")
    var left := String(plans.selected)
    plans = MODEL.line(plans, left, "thread_dash", 3, 0)
    plans = MODEL.set_done(plans, left, "thread_dash", true)
    plans = MODEL.create(plans, "乙")
    plans = MODEL.line(plans, String(plans.selected), "thread_dash", 2, 0)
    check(MODEL.compare(plans, left, String(plans.selected))[0].left == 0, "completed objectives are excluded from comparisons as well as allocations")
    finish()
