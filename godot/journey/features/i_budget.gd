extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/budget/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_budget", "name": "旅途预算沙盘", "summary": "分阶段预算、实际库存基线与现金流情景"}
