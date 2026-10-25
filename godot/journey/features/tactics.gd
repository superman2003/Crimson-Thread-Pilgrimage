extends "res://journey/core/feature.gd"
const MODEL := preload("res://journey/tactics/model.gd")
const STAGE := preload("res://journey/tactics/stage.gd")
var rows: Array = []
var type := "all"
var favorites_only := false
var comparison := ""
var page := 0
var tab := "catalog"
var speed := 1.0
var reference_distance := 180.0
var pending_clear := ""
var draft_sequence: Array = []
const PAGE_SIZE := 12

func descriptor() -> Dictionary:
    return {"id":"tactics", "name":"战术图解", "summary":"已击败敌人的真实动作字段、时间条、空间示意与阅读检查表"}

func initial() -> Dictionary:
    return MODEL.fresh()

func valid(candidate: Dictionary) -> bool:
    return MODEL.valid(candidate)

func draw(parent: Control) -> void:
    header(parent, "只列已击败的敌种。图解来自当前动作目录，不运行敌人AI，不证明命中、格挡或现场可达性。")
    rows = MODEL.known(context.latest.get("flags", {}))
    var public_attacks := MODEL.attacks(rows, "", "all")
    UI.label(parent, "已公开敌种%d · 目录动作%d · 收藏%d" % [rows.size(), public_attacks.size(), data.favorites.size()])
    if rows.is_empty():
        UI.hint(parent, "击败敌人后才会出现它的动作目录；未知名称和动作不会提前列出。")
        return
    var tabs := UI.row(parent)
    UI.button(tabs, "动作目录", func():tab = "catalog";context.refresh())
    UI.button(tabs, "当前图解", func():tab = "stage";context.refresh())
    UI.button(tabs, "阅读进度", func():tab = "checks";context.refresh())
    UI.button(tabs, "观察串联", func():tab = "sequence";context.refresh())
    if tab == "sequence":
        _sequence_editor(parent)
    elif tab == "checks":
        _checks(parent)
    elif tab == "stage":
        _stage(parent)
    else:
        _catalog(parent)
    UI.divider(parent)
    UI.button(parent, "导出已公开动作与手记", func():export_document("战术图解.txt", MODEL.report(rows, data)))

func _catalog(parent: Control) -> void:
    var controls := UI.row(parent)
    var query := UI.edit(controls, "搜索敌种、动作和机理", search)
    UI.button(controls, "搜索", func():search = query.text;page = 0;context.refresh())
    var available := {"all":true}
    for row in MODEL.attacks(rows, "", "all"):
        available[row.attack.type] = true
    var choices := [{"id":"all", "name":"全部动作类型"}]
    for id in available:
        if id != "all":
            choices.append({"id":id, "name":MODEL.TYPES.get(id, id)})
    var picker := UI.pick(parent, choices, type)
    picker.item_selected.connect(func(_index: int):type = UI.chosen(picker);page = 0;context.refresh())
    UI.toggle(parent, "只看收藏敌种", favorites_only, func(value: bool):favorites_only = value;page = 0;context.refresh())
    var attacks := MODEL.attacks(rows, search, type, data.favorites, favorites_only)
    page = clampi(page, 0, maxi(0, (attacks.size() - 1) / PAGE_SIZE))
    var navigation := UI.row(parent)
    UI.button(navigation, "上一页", func():page -= 1;context.refresh(), page == 0)
    UI.label(navigation, "第%d页 · %d项" % [page + 1, attacks.size()])
    UI.button(navigation, "下一页", func():page += 1;context.refresh(), (page + 1) * PAGE_SIZE >= attacks.size())
    for index in range(page * PAGE_SIZE, mini(attacks.size(), (page + 1) * PAGE_SIZE)):
        var row: Dictionary = attacks[index]
        var card := UI.card(parent)
        UI.label(card, String(row.enemy.name) + " / " + String(row.attack.name))
        UI.hint(card, String(MODEL.TYPES[row.attack.type]) + " · " + String(row.attack.get("mechanic", "")))
        UI.hint(card, "前摇%.2f · 判定%.2f · 收势%.2f · 目录冷却%.2f" % [row.attack.windup, row.attack.active, row.attack.recover, row.attack.cooldown])
        var actions := UI.row(card)
        var key := String(row.key)
        UI.button(actions, "打开字段图解", func():selected = key;tab = "stage";context.refresh())
        UI.button(actions, "设为比较动作", func():comparison = key;context.tell("已选比较动作，打开另一动作可叠加时间条。"))
    if attacks.is_empty():
        UI.hint(parent, "当前筛选没有公开动作。")

func _selected() -> Dictionary:
    var row := MODEL.find(rows, selected)
    if row.is_empty():
        var available := MODEL.attacks(rows, "", "all")
        if not available.is_empty():
            row = available[0]
            selected = String(row.key)
    return row

func _stage(parent: Control) -> void:
    var row := _selected()
    if row.is_empty():
        UI.hint(parent, "当前没有可供图解的公开动作。")
        return
    var other := MODEL.find(rows, comparison)
    UI.label(parent, String(row.enemy.name) + " / " + String(row.attack.name), true)
    UI.hint(parent, String(row.enemy.get("combat_identity", "")))
    UI.hint(parent, "观察信号：" + String(row.enemy.hint))
    UI.hint(parent, "应对思路：" + String(row.enemy.response))
    var stage := STAGE.new()
    stage.configure(row.attack, other.get("attack", {}))
    stage.speed = speed
    stage.target_distance = reference_distance
    parent.add_child(stage)
    var controls := UI.row(parent)
    UI.button(controls, "播放 / 暂停", func():stage.playing = not stage.playing)
    UI.button(controls, "回到动作起点", func():stage.cursor = 0;stage.queue_redraw())
    var rate := UI.spin(controls, speed, 0.25, 2.0, 0.25)
    rate.value_changed.connect(func(value: float):speed = value;stage.speed = value)
    var distance := UI.spin(controls, reference_distance, 0, 800, 10)
    distance.value_changed.connect(func(value: float):reference_distance = value;stage.target_distance = value;stage.queue_redraw())
    UI.hint(parent, "点击时间条可定位并暂停。蓝框为参考站位，不输出命中与安全判定。")
    UI.label(parent, "原始目录字段", true)
    for value in MODEL.values(row.attack):
        var line := UI.row(parent)
        UI.label(line, String(value.name))
        UI.label(line, "%.3f" % value.value)
    if row.attack.get("blockable") is bool:
        UI.hint(parent, "目录标记：可格挡" if row.attack.blockable else "目录标记：不可格挡")
    UI.hint(parent, "目录冷却单独列出，不把它与动作周期相加后当成实际AI下一次出手时刻。")
    if not other.is_empty():
        UI.divider(parent)
        UI.label(parent, "与「%s / %s」比较" % [other.enemy.name, other.attack.name], true)
        for difference in MODEL.compare(row.attack, other.attack):
            UI.label(parent, "%s：%.3f → %.3f（%+.3f）" % [difference.name, difference.left, difference.right, difference.difference])
        UI.button(parent, "清除比较动作", func():comparison = "";context.refresh())
    _annotations(parent, row)

func _annotations(parent: Control, row: Dictionary) -> void:
    UI.divider(parent)
    UI.label(parent, "个人辨读检查", true)
    UI.hint(parent, "这些勾选是自己的阅读记号，不计为训练、能力获得或自然战斗验收。")
    var checks: Dictionary = data.checks.get(row.key, {})
    for definition in [["windup", "已能辨认前摇"], ["active", "已能区分判定阶段"], ["recover", "已能辨认收势"]]:
        var phase := String(definition[0])
        var key := String(row.key)
        UI.toggle(parent, String(definition[1]), bool(checks.get(phase, false)), func(value: bool):commit(MODEL.check_phase(data, rows, key, phase, value)))
    var note := UI.memo(parent, String(data.notes.get(row.key, "")), 100)
    var actions := UI.row(parent)
    var id := String(row.key)
    var enemy_id := String(row.enemy.id)
    UI.button(actions, "保存观察手记", func():commit(MODEL.annotate(data, rows, id, note.text)))
    var favorite: bool = data.favorites.has(enemy_id)
    UI.button(actions, "取消收藏敌种" if favorite else "收藏此敌种", func():commit(MODEL.favorite(data, rows, enemy_id, not favorite)))
    UI.button(actions, "清除此动作阅读记号", func():pending_clear = id;context.refresh())
    if pending_clear == id:
        var confirmation := UI.row(parent)
        UI.button(confirmation, "保留记号", func():pending_clear = "";context.refresh())
        UI.button(confirmation, "确认清除本动作记号", func():
            var candidate := data.duplicate(true)
            candidate.checks.erase(id)
            candidate.notes.erase(id)
            commit(candidate)
            pending_clear = "")

func _checks(parent: Control) -> void:
    UI.hint(parent, "只汇总当前已公开动作的个人阅读勾选，不列出未知敌种或未来动作总数。")
    var rows_by_enemy := {}
    for row in MODEL.attacks(rows, "", "all"):
        var id := String(row.enemy.id)
        if not rows_by_enemy.has(id):
            rows_by_enemy[id] = {"name":row.enemy.name, "complete":0, "total":0, "attacks":[]}
        var progress: Dictionary = data.checks.get(row.key, {})
        var complete: bool = progress.get("windup", false) and progress.get("active", false) and progress.get("recover", false)
        rows_by_enemy[id].total += 1
        if complete:
            rows_by_enemy[id].complete += 1
        rows_by_enemy[id].attacks.append({"key":row.key, "name":row.attack.name, "complete":complete})
    for id in rows_by_enemy:
        var row: Dictionary = rows_by_enemy[id]
        var card := UI.card(parent)
        UI.label(card, String(row.name))
        UI.progress(card, float(row.complete), float(row.total))
        UI.hint(card, "%d / %d 个已公开动作完成个人辨读勾选" % [row.complete, row.total])
        for attack in row.attacks:
            var key := String(attack.key)
            UI.button(card, ("✓ " if attack.complete else "· ") + String(attack.name), func():selected = key;tab = "stage";context.refresh())

func _sequence_editor(parent: Control) -> void:
    UI.label(parent, "组合动作观察时间条", true)
    UI.hint(parent, "人为串联1至8个已公开动作，供比较节奏；不是敌人实际AI的选招顺序。")
    var options := []
    for row in MODEL.attacks(rows, "", "all"):
        options.append({"id":row.key, "name":String(row.enemy.name) + " / " + String(row.attack.name)})
    var controls := UI.row(parent)
    var picker := UI.pick(controls, options)
    var gap := UI.spin(controls, 0.5, 0, 5, 0.1)
    UI.button(controls, "加入观察串联", func():
        if draft_sequence.size() < 8:
            draft_sequence.append({"key":UI.chosen(picker), "gap":float(gap.value)})
            context.refresh())
    UI.button(parent, "清空未保存串联", func():draft_sequence = [];context.refresh())
    var composed := MODEL.compose(rows, draft_sequence)
    if composed.get("ok", false):
        var view := preload("res://journey/tactics/sequence_view.gd").new()
        view.configure(composed)
        view.action_selected.connect(func(key: String):selected = key;tab = "stage";context.refresh())
        parent.add_child(view)
        for index in draft_sequence.size():
            var position := index
            var entry: Dictionary = draft_sequence[index]
            var known := MODEL.find(rows, String(entry.key))
            var line := UI.row(parent)
            UI.label(line, "%d. %s · 间隔%.1f秒" % [index + 1, known.get("attack", {}).get("name", "当前未公开"), entry.gap])
            UI.button(line, "移除步骤", func():draft_sequence.remove_at(position);context.refresh())
        var title := UI.edit(parent, "观察串联名称（最多8份）", "", 50)
        UI.button(parent, "保存观察串联", func():
            var candidate := MODEL.save_sequence(data, rows, title.text, draft_sequence)
            if candidate == data:
                context.tell("名称重复、内容无效或串联数量已满。")
            else:
                commit(candidate))
    else:
        UI.hint(parent, String(composed.reason))
    for record in data.get("sequences", []):
        var card := UI.card(parent)
        UI.label(card, String(record.name))
        var outcome := MODEL.compose(rows, record.entries)
        UI.hint(card, String(outcome.reason))
        var buttons := UI.row(card)
        UI.button(buttons, "载入观察串联", func():draft_sequence = record.entries.duplicate(true);context.refresh(), not outcome.get("ok", false))
        UI.button(buttons, "删除此串联", func():
            var candidate := data.duplicate(true)
            for index in range(candidate.sequences.size() - 1, -1, -1):
                if candidate.sequences[index].id == record.id:
                    candidate.sequences.remove_at(index)
            commit(candidate))
