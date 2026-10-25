extends "res://journey/core/feature.gd"
const MODEL := preload("res://journey/build_lab/model.gd")
var tab := "edit"
var family := "thread_skill"
var slot := 0
var comparison := "live"
var energy_budget := 100
var health_missing := 3
var target_hp := 10
var pending_import: Dictionary = {}
var pending_delete := ""
var reviewed_source := ""

func descriptor() -> Dictionary:
    return {"id":"build_lab", "name":"构筑试算", "summary":"独立装备沙盘、实际规则差异、铭饰边际贡献和资源断点"}

func initial() -> Dictionary:
    return MODEL.fresh()

func valid(candidate: Dictionary) -> bool:
    return MODEL.valid(candidate)

func _snapshot() -> Dictionary:
    return context.snapshot()

func _ensure_draft() -> void:
    if data.draft.is_empty():
        data = MODEL.start(data, _snapshot())

func draw(parent: Control) -> void:
    _ensure_draft()
    header(parent, "在独立构筑实例上调用实际装备规则。这里不会应用装备、消耗物资、改变训练或恢复生命。")
    var snapshot := _snapshot()
    if String(data.source) != VALUES.fingerprint(snapshot.get("build_state", {})):
        UI.hint(parent, "实际构筑已经变化；草案保留，所有候选仍按当前获得条件重新复核。")
    var tabs := UI.row(parent)
    for pair in [["edit", "装备沙盘"], ["compare", "属性比较"], ["resources", "资源断点"], ["saved", "方案与导出"]]:
        var id := String(pair[0])
        UI.button(tabs, String(pair[1]), func():tab = id;context.refresh())
    var evaluated := MODEL.machine(snapshot, data.draft)
    if not evaluated.ok:
        UI.label(parent, String(evaluated.reason))
        UI.button(parent, "从当前实际装备重新开始", func():commit(MODEL.start(data, _snapshot())))
        return
    UI.hint(parent, MODEL.describe(evaluated))
    if tab == "compare":
        _compare(parent, snapshot, evaluated)
    elif tab == "resources":
        _resources(parent, evaluated)
    elif tab == "saved":
        _saved(parent, snapshot)
    else:
        _editor(parent, snapshot, evaluated)

func _editor(parent: Control, snapshot: Dictionary, evaluation: Dictionary) -> void:
    var row := UI.row(parent)
    var crests := MODEL.crest_choices(snapshot)
    var picker := UI.pick(row, crests, String(evaluation.state.crest))
    UI.button(row, "试算此契印", func():_edit("crest", UI.chosen(picker)))
    UI.button(row, "重置为实际装备", func():commit(MODEL.start(data, _snapshot())))
    var families := []
    for id in MODEL.FAMILIES:
        families.append({"id":id, "name":MODEL.FAMILIES[id]})
    var controls := UI.row(parent)
    var family_picker := UI.pick(controls, families, family)
    family_picker.item_selected.connect(func(_index: int):family = UI.chosen(family_picker);slot = 0;context.refresh())
    var capacity: int = 2 if family in ["thread_skill", "tool"] else 3
    var slots := []
    for index in capacity:
        slots.append({"id":str(index), "name":"槽位 %d" % (index + 1)})
    var slot_picker := UI.pick(controls, slots, str(slot))
    slot_picker.item_selected.connect(func(_index: int):slot = int(UI.chosen(slot_picker));context.refresh())
    UI.button(controls, "清空此槽", func():_edit("clear", ""))
    var current: Array = evaluation.state.get("equipped_families", {}).get(family, [])
    var names := MODEL.available_from_view(evaluation.snapshot, family)
    var current_id := String(current[slot]) if slot < current.size() else ""
    UI.label(parent, "%s %d：%s" % [MODEL.FAMILIES[family], slot + 1, names.get(current_id, "空槽")], true)
    var search_row := UI.row(parent)
    var query := UI.edit(search_row, "搜索已经获得的装备", search)
    UI.button(search_row, "搜索", func():search = query.text;context.refresh())
    var shown := 0
    for item in MODEL.available(snapshot, data.draft, family):
        if not VALUES.matches(search, [String(item.name), String(item.description)]):
            continue
        shown += 1
        var card := UI.card(parent)
        UI.label(card, String(item.name))
        UI.hint(card, String(item.description))
        var preview := MODEL.edit(data, snapshot, "equip", String(item.id), family, slot)
        if not preview.get("ok", false):
            UI.hint(card, String(preview.get("reason", "此槽不兼容。")))
        else:
            var candidate: Dictionary = preview.data
            var comparison_result := MODEL.differences(snapshot, data.draft, candidate.draft)
            var lines := []
            if comparison_result.get("ok", false):
                for metric in comparison_result.metrics:
                    if not is_zero_approx(float(metric.difference)):
                        lines.append("%s %+.2f" % [metric.name, metric.difference])
            UI.hint(card, " · ".join(lines) if not lines.is_empty() else "不改变所列基础属性；动作或槽位配置仍可能不同。")
            UI.button(card, "放入沙盘槽位", func():_edit("equip", String(item.id)), current_id == item.id)
    if shown == 0:
        UI.hint(parent, "当前分类没有符合条件的已获装备。")
    UI.divider(parent)
    for constraint in MODEL.constraints(snapshot, data.draft):
        UI.hint(parent, String(constraint.name) + "：" + String(constraint.text))
    UI.hint(parent, "未解锁槽位、重复装备、家族不兼容、互斥组和契印容量由正式 BuildSystem 统一拒绝。")

func _edit(action: String, id: String) -> void:
    var outcome := MODEL.edit(data, _snapshot(), action, id, family, slot)
    if not outcome.get("ok", false):
        announce(outcome)
        return
    if commit(outcome.data):
        context.tell("只更新了辅助沙盘。实际角色保持当前装备。")

func _comparison_state(snapshot: Dictionary) -> Dictionary:
    if comparison == "live":
        return snapshot.get("build_state", {}).duplicate(true)
    return MODEL.scenario(data, comparison).get("state", {}).duplicate(true)

func _compare(parent: Control, snapshot: Dictionary, evaluation: Dictionary) -> void:
    var choices := [{"id":"live", "name":"当前实际构筑"}]
    for record in data.scenarios:
        choices.append({"id":record.id, "name":record.name})
    var picker := UI.pick(parent, choices, comparison)
    picker.item_selected.connect(func(_index: int):comparison = UI.chosen(picker);context.refresh())
    var difference := MODEL.differences(snapshot, _comparison_state(snapshot), data.draft)
    if not difference.get("ok", false):
        UI.hint(parent, String(difference.get("reason", "所选比较方案当前已失效。")))
        return
    UI.label(parent, "左侧基准 → 右侧沙盘", true)
    for metric in difference.metrics:
        var row := UI.row(parent)
        UI.label(row, String(metric.name))
        UI.label(row, "%.3f → %.3f" % [metric.before, metric.after])
        UI.label(row, "%+.3f" % metric.difference)
    UI.divider(parent)
    UI.label(parent, "线术槽位的实际派生值", true)
    for row in difference.skills:
        var card := UI.card(parent)
        var left: Dictionary = row.before
        var right: Dictionary = row.after
        UI.label(card, "槽位%d：%s → %s" % [int(row.slot) + 1, left.name, right.name])
        UI.hint(card, "费用%d→%d · 单次伤害%d→%d · 动作周期%.2f→%.2f秒 · 范围%.0f→%.0f" % [left.cost, right.cost, left.damage, right.damage, left.cycle, right.cycle, left.range, right.range])
    UI.divider(parent)
    UI.label(parent, "铭饰的边际贡献", true)
    for item in MODEL.contributions(snapshot, evaluation.state):
        var card := UI.card(parent)
        UI.label(card, String(item.name))
        UI.hint(card, "%s槽位%d；从此沙盘单独取下后对照实际属性。" % [MODEL.FAMILIES[item.family], int(item.slot) + 1])
        for effect in item.effects:
            UI.label(card, "%s %+.3f" % [effect.name, effect.difference])
        if item.effects.is_empty():
            UI.hint(card, "所列基础属性没有变化；该饰件可能提供情境效果。")

func _resources(parent: Control, evaluation: Dictionary) -> void:
    UI.button(parent, "采用当前角色绯线作为预算", func():
        var snapshot: Dictionary = context.snapshot()
        var player: Dictionary = snapshot.get("player", {})
        energy_budget = maxi(0, int(player.get("energy", 0)))
        context.refresh())
    UI.hint(parent, "静态预算计算，不假定每次命中、不模拟敌人移动，也不把同一份绯线同时分配给疗伤与线术。")
    var row := UI.row(parent)
    UI.label(row, "绯线预算")
    var energy := UI.spin(row, energy_budget, 0, 10000)
    UI.label(row, "缺失生命")
    var health := UI.spin(row, health_missing, 0, 100)
    UI.label(row, "目标生命")
    var target := UI.spin(row, target_hp, 1, 1000)
    UI.button(parent, "更新预算", func():energy_budget = int(energy.value);health_missing = int(health.value);target_hp = int(target.value);context.refresh())
    var budget := MODEL.sustainability(evaluation, energy_budget, health_missing, target_hp)
    UI.label(parent, "若优先疗伤：%d 次，最多恢复 %d，剩余绯线 %d" % [budget.heals, budget.healed, budget.remaining])
    for skill in budget.skills:
        var card := UI.card(parent)
        UI.label(card, String(skill.name))
        UI.label(card, "若全部用于此术：最多%d次；静态单次伤害%d，达到目标生命至少%d次。" % [skill.casts, skill.damage, skill.needed])
        UI.hint(card, "预算足够完成上述次数。" if skill.affordable else "预算不足；还需考虑命中、无敌帧和实战回线。")
    UI.button(parent, "导出试算报告", func():export_document("构筑试算.txt", MODEL.report(_snapshot(), data.draft)))

func _saved(parent: Control, snapshot: Dictionary) -> void:
    var row := UI.row(parent)
    var name := UI.edit(row, "方案名称（最多12份）", "", 40)
    var note := UI.memo(parent, "", 75)
    UI.button(parent, "保存当前沙盘", func():
        var candidate := MODEL.save_scenario(data, name.text, note.text, _snapshot())
        if candidate == data:
            context.tell("名称为空、重复、方案已满或当前沙盘无法复核。")
        else:
            commit(candidate))
    for record in data.scenarios:
        var card := UI.card(parent)
        UI.label(card, String(record.name))
        UI.hint(card, String(record.note))
        var actions := UI.row(card)
        UI.button(actions, "载入沙盘", func():
            var outcome := MODEL.load_scenario(data, String(record.id), _snapshot())
            if outcome.get("ok", false):
                commit(outcome.data)
            else:
                announce(outcome))
        UI.button(actions, "导出方案", func():export_document("构筑草案.json", JSON.stringify({"version":1, "state":record.state}, "  ")))
        UI.button(actions, "删除方案", func():pending_delete = String(record.id);context.refresh())
        if pending_delete == String(record.id):
            var confirm := UI.row(card)
            UI.button(confirm, "保留", func():pending_delete = "";context.refresh())
            UI.button(confirm, "确认删除草案", func():commit(MODEL.remove(data, String(record.id)));pending_delete = "")
    UI.divider(parent)
    UI.label(parent, "导入只读构筑草案", true)
    var raw := UI.memo(parent, "", 110)
    UI.button(parent, "复核草案", func():
        pending_import = MODEL.import_draft(data, _snapshot(), raw.text)
        reviewed_source = VALUES.fingerprint(context.latest.get("build_state", {}))
        context.tell(String(pending_import.get("reason", "")))
        context.refresh())
    if pending_import.get("ok", false):
        UI.hint(parent, MODEL.describe(MODEL.machine(snapshot, pending_import.data.draft)))
        var actions := UI.row(parent)
        UI.button(actions, "取消导入", func():pending_import = {};context.refresh())
        UI.button(actions, "确认装入沙盘", func():
            if reviewed_source != VALUES.fingerprint(context.latest.get("build_state", {})):
                pending_import = {}
                context.tell("实际构筑已变化，请重新复核草案。")
                context.refresh()
            elif commit(pending_import.data):
                pending_import = {})
