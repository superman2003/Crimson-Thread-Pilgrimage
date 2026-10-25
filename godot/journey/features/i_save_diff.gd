extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/save_diff/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_save_diff", "name": "旅途快照差异", "summary": "同槽观察快照的字段差异、分类和只读变更报告"}


func _current(parent: Control) -> void:
    super._current(parent)
    if data.records.size() < 2:
        UI.hint(parent, "保存至少两份公开观察后，可对照所选基线、所选分支和当前状态。")
        return
    var choices := []
    for record in data.records:
        choices.append({"id": str(int(record.id)), "name": String(record.title)})
    UI.label(parent, "三方观察冲突", true)
    var row := UI.row(parent)
    var base_pick := UI.pick(row, choices, str(int(data.records[-1].id)))
    var branch_pick := UI.pick(row, choices, str(int(data.records[0].id)))
    var result_box := UI.column(parent)
    UI.button(
        parent,
        "检查三方公开观察",
        func():
            UI.clear(result_box)
            var baseline := RECORDS.find(data, int(UI.chosen(base_pick)))
            var branch := RECORDS.find(data, int(UI.chosen(branch_pick)))
            if baseline.is_empty() or branch.is_empty():
                return
            var current: Dictionary = domain.capture(context.snapshot())
            var second: Dictionary = branch.payload.duplicate(true)
            for option in ["include_player", "include_story"]:
                current[option] = baseline.payload[option]
                second[option] = baseline.payload[option]
            var report: Dictionary = domain.three_way(
                domain.masked(baseline.payload),
                domain.masked(second),
                domain.masked(current),
                baseline.payload
            )
            UI.hint(result_box, String(report.reason))
            _sections(
                result_box,
                [KNOW.table("保守冲突检查", ["左字段", "右字段", "左变化", "右变化", "说明"], report.conflicts)]
            )
            if report.ok:
                UI.button(
                    result_box,
                    "导出内存合并观察",
                    func():
                        export_document(
                            "三方公开观察.json",
                            JSON.stringify(
                                {
                                    "format": "fieldwork-observation-merge",
                                    "version": 1,
                                    "not_primary_save": true,
                                    "observation": report.value
                                },
                                "  "
                            )
                        )
                )
    )
