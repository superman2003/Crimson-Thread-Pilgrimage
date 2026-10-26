extends "res://journey/fieldwork/panel.gd"
var history_focus := ""
const DOMAIN := preload("res://journey/fieldwork/prices/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_prices", "name": "改制成本观察簿", "summary": "已公开改制目录成本、个人假设与历史比较"}


func _current(parent: Control) -> void:
    super._current(parent)
    var current: Dictionary = domain.capture(context.snapshot())
    var choices := []
    for row in current.get("quotes", []):
        choices.append({"id":row.id,"name":row.name})
    if choices.is_empty():
        for row in current.get("recipes", []):
            choices.append({"id":row.id,"name":row.name})
    if history_focus.is_empty():
        history_focus = String(current.focus)
    var pick := UI.pick(parent, choices, history_focus)
    pick.item_selected.connect(func(_index: int): history_focus = UI.chosen(pick); context.refresh())
    _sections(parent, domain.history_sections(data.records, history_focus))
