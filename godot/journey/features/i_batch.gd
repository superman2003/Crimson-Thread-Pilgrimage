extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/batch/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_batch", "name": "批量制作试算", "summary": "资金与材料约束下的目标组合、优化与敏感性"}
