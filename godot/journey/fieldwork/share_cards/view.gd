extends VBoxContainer
var card: Dictionary = {}


func _init() -> void:
    custom_minimum_size = Vector2(480, 220)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_theme_constant_override("separation", 8)


func configure(data: Dictionary) -> void:
    card = data.get("body", {}).duplicate(true)
    if is_inside_tree():
        _build()


func _ready() -> void:
    _build()


func _label(text: String, size: int = 16) -> Label:
    var value := Label.new()
    value.text = text
    value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    value.add_theme_font_size_override("font_size", size)
    add_child(value)
    return value


func _build() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    _label(String(card.get("title", "旅途分享卡")), 24)
    if card.has("date"):
        _label("观察日期（UTC日）：" + String(card.date), 13)
    var captions := {
        "summary": "此观察的已知数量",
        "location": "已勾选的地区与房间",
        "abilities": "已勾选的已获能力",
        "equipment": "已勾选的已获装备",
        "quests": "已勾选的已知任务",
        "inventory": "已勾选的持有物资",
        "stats": "已勾选的构筑数值",
        "note": "已勾选的个人备注"
    }
    for key in captions:
        if not card.has(key):
            continue
        var divider := HSeparator.new()
        add_child(divider)
        _label(String(captions[key]), 18)
        var value: Variant = card[key]
        if value is Dictionary:
            for field in value:
                _label(String(field) + "：" + str(value[field]), 15)
        elif value is Array:
            for item in value:
                if item is Dictionary:
                    var fields: Array[String] = []
                    for field in item:
                        fields.append(String(item[field]))
                    _label(" · ".join(fields), 15)
                else:
                    _label(String(item), 15)
        else:
            _label(String(value), 15)
    _label("只有以上内容进入分享卡。校验不证明作者身份，内容不会自动上传。", 12)
