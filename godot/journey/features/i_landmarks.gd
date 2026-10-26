extends "res://journey/fieldwork/panel.gd"
const DOMAIN := preload("res://journey/fieldwork/landmarks/model.gd")


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_landmarks", "name": "地标方位台", "summary": "已知现场地标的方位、距离、视窗及筛选"}
