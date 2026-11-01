extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/curriculum/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_curriculum", "name": "动作课程编排", "summary": "按已获动作编辑课程、分组和可执行练习步骤"}
