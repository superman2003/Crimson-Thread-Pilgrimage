extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/share_cards/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_share_cards", "name": "旅途分享卡", "summary": "明确字段白名单、常见隐私格式过滤与校验分享码"}


func _source() -> Dictionary:
    if not draft.is_empty() and domain.validate(draft):
        return draft.duplicate(true)
    if selected_id > 0:
        var record := RECORDS.find(data, selected_id)
        if not record.is_empty():
            return record.payload.duplicate(true)
    return domain.capture(context.snapshot())


func _current(parent: Control) -> void:
    var source := _source()
    UI.hint(parent, "预览使用正在编辑的候选或选中的记录；未选择时使用当前旅途与默认白名单。")
    UI.button(
        parent,
        "从当前旅途建立分享候选",
        func():
            draft = domain.capture(context.snapshot())
            draft_title = "分享白名单配置"
            draft_note = ""
            draft_favorite = false
            selected_id = 0
            tab = "editor"
            context.refresh()
    )
    _sections(parent, domain.analyze(source, context.snapshot()))
    _export_controls(parent, source)


func _export_controls(parent: Control, source: Dictionary) -> void:
    var card: Dictionary = domain.body(source)
    var encoded: Dictionary = domain.encode(card)
    if not encoded.ok:
        UI.hint(parent, String(encoded.reason))
        return
    UI.hint(parent, "以下导出只含上方白名单处理后的公开内容；此功能不提供原始私人观察的通用导出。")
    var row := UI.row(parent)
    UI.button(
        row, "导出公开卡片JSON", func(): export_document("旅途公开分享卡.json", JSON.stringify(card, "  "))
    )
    UI.button(row, "导出校验分享码", func(): export_document("旅途公开分享码.txt", String(encoded.code)))
    var code := UI.memo(parent, String(encoded.code), 110)
    code.editable = false
    UI.hint(parent, "可选中复制分享码。生成和导出均不会自动发送给任何人。")


func _transfer(parent: Control) -> void:
    UI.label(parent, "公开分享卡导出与外部只读预览", true)
    var source := _source()
    _sections(parent, domain.analyze(source, context.snapshot()))
    _export_controls(parent, source)
    UI.divider(parent)
    UI.label(parent, "校验外部分享码", true)
    UI.hint(parent, "只读预览外部内容，不加入自己的旅途事实，不设置任何游戏进度。")
    var input := UI.memo(parent, "", 120)
    var output := UI.column(parent)
    UI.button(
        parent,
        "校验并只读预览",
        func():
            UI.clear(output)
            var decoded: Dictionary = domain.decode(input.text)
            UI.hint(output, String(decoded.reason))
            if decoded.ok:
                _sections(
                    output,
                    [
                        {
                            "kind": "custom",
                            "title": "外部公开内容，不代表你的旅途",
                            "view": DOMAIN.VIEW,
                            "data": {"body": decoded.body}
                        }
                    ]
                )
    )
