extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/prices/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_prices", "name": "改制成本观察簿", "summary": "已遇商店报价的人工记录、单位成本与比较"}


func _current(parent: Control) -> void:
    super._current(parent)
    var current: Dictionary = domain.capture(context.snapshot())
    _sections(parent, domain.history_sections(data.records, String(current.focus)))
