extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/recipes/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_recipes", "name": "改制依赖图", "summary": "已获装备的配方依赖、材料展开与循环诊断"}
