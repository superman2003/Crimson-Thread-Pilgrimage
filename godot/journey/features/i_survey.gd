extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/survey/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_survey", "name": "现场网格测绘", "summary": "当前已知空间栅格采样、覆盖率与复查清单"}
